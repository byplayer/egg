;;; egg.el --- Emacs Got Git - Emacs interface to Git

;; Copyright (C) 2008  Linh Dang
;; Copyright (C) 2008  Marius Vollmer
;; Copyright (C) 2009  Tim Moore
;; Copyright (C) 2010  Alexander Prusov
;; Copyright (C) 2011-2018 byplayer
;;
;; Author: Bogolisk <bogolisk@gmail.com>
;; Created: 19 Aug 2008
;; Version: 1.1.4
;; Keywords: git, version control, release management
;;
;; Special Thanks to
;;   Antoine Levitt, Bogolisk,
;;   Christian Köstlin
;;   Max Mikhanosha
;;   Aleksandar Simic
;;   Maksim Golubev
;;   Felix S Klock II
;;
;; Egg is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; Egg is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
;; License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary
;;;    This is my fork of Marius's excellent magit. his work is at:
;;;    http://zagadka.vm.bytemark.co.uk/magit
;;;
;;;    This is my fork of bogolisk egg . his work is at
;;     http://github.com/bogolisk/egg
;;
;;  ssh and github: please use key authentication since egg doesn't
;;                  handle login/passwd prompt
;;
;;  gpg and tag : please add "use-agent" option in your gpg.conf
;;                since egg doesn't handle passphrase prompt.
;;;

;; Options
;; If you want to auto-update egg-status on file save,
;;   you set follow value on your .emacs.
;; (setq egg-auto-update t)
;;
;; Set to nonnil for egg-status to switch to the status buffer in the same window.
;; (setq egg-switch-to-buffer t)
;;
;; If you want to change prefix of lunch egg,
;;  you set follow value on your .emacs.
;; (custom-set-variables
;;   '(egg-mode-key-prefix "C-c v"))

(eval-when-compile (require 'cl))
(require 'egg-custom)
(require 'egg-base)
(require 'egg-const)
(require 'egg-git)
(require 'electric)
(require 'ediff)
(require 'ffap)
(require 'diff-mode)
(require 'rx)

(defconst egg-version "1.1.4")

(defconst egg-basic-map
  (let ((map (make-sparse-keymap "Egg:Basic")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "C-c C-s") 'egg-status)
    (define-key map (kbd "s") 'egg-status)
    (define-key map (kbd "l") 'egg-log)
    (define-key map (kbd "L") 'egg-log-buffer-reflog-ref)
    (define-key map (kbd "/") 'egg-search-changes)
    (define-key map (kbd "c") 'egg-commit-log-edit)
    map)
  "Keymap for a basic egg buffer.
\\{egg-basic-map}")

(defconst egg-file-index-map
  (let ((map (make-sparse-keymap "Egg:FileIndex")))
    (set-keymap-parent map egg-basic-map)
    map)
  "Keymap for an egg buffer show the index version of a file.
\\{egg-file-index-map}")

(defvar egg-global-mode-name nil)
(defvar egg-global-mode nil)
(defun egg-set-global-mode (&optional string)
  (interactive)
  (when (egg-is-in-git)
    (when (boundp 'vc-mode)
      (set 'vc-mode nil))
    (set (make-local-variable 'egg-global-mode) t)
    (set (make-local-variable 'egg-global-mode-name)
         (if string (concat " " string)))
    
    ;; (setq egg-global-mode-name
    ;;       (intern (concat "egg-" (egg-git-dir) "-HEAD")))
    (or (assq 'egg-global-mode minor-mode-alist)
        (push '(egg-global-mode egg-global-mode-name) minor-mode-alist))))




;;(cl-macroexpand '(egg-text blah 'egg-text-3))


(defun egg-show-branch (branch)
  (interactive (list (egg-head-at-point)))
  (let* ((info (and (stringp branch)
                    (egg-git-to-string-list "for-each-ref"
                                            "--format=%(refname:short) %(refname) %(upstream:short)"
                                            (concat "refs/heads/" branch))))
         (name (nth 0 info))
         (full (nth 1 info))
         (upstream (nth 2 info)))
    (when (stringp name)
      (message "local-branch:%s full-name:%s upstream:%s" 
               (egg-text name 'bold) 
               (egg-text full 'bold)
               (if upstream (egg-text upstream 'bold) "none")))))

(defvar egg-atag-info-buffer (get-buffer-create "*tag-info*"))

(defun egg-show-atag (tag)
  (interactive (list (egg-tag-at-point)))
  (let ((dir (egg-work-tree-dir))
        (buf egg-atag-info-buffer)
        (new-buf-name (concat "*tag@" (egg-repo-name) ":" tag "*"))
        (inhibit-read-only t)
        target-type sig-beg sig-end verify pos)
    (with-current-buffer buf
      (setq default-directory dir)
      (setq target-type (egg-git-to-string "for-each-ref" "--format=%(objecttype)"
                                           (concat "refs/tags/" tag)))
      (unless (equal target-type "tag")
        (error "Not an annotated tag: %s" tag))
      (unless (string-equal (buffer-name) new-buf-name)
        (rename-buffer new-buf-name))
      (erase-buffer)
      (unless (egg--git t "show" "-s" tag)
        (error "Failed to show tag %s" tag))
      (save-match-data
        (goto-char (point-min))
        (re-search-forward "^tag ")
        (put-text-property (match-end 0) (line-end-position) 'face 'egg-branch)
        (re-search-forward "^Tagger:\\s-+")
        (put-text-property (match-end 0) (line-end-position) 'face 'egg-text-2)
        (re-search-forward "^Date:\\s-+")
        (put-text-property (match-end 0) (line-end-position) 'face 'egg-text-2)
        (setq pos (line-end-position))
        (when (re-search-forward "-----BEGIN PGP SIGNATURE-----" nil t)
          (setq sig-beg (match-beginning 0))
          (re-search-forward "-----END PGP SIGNATURE-----\n")
          (setq sig-end (match-end 0))
          (goto-char sig-beg)
          (delete-region sig-beg sig-end)
          (with-temp-buffer
            (egg--git t "tag" "-v" tag)
            (goto-char (point-min))
            (re-search-forward "^gpg:")
            (setq verify (buffer-substring-no-properties (match-beginning 0)
                                                         (point-max))))
          (insert verify "\n"))
        (goto-char pos)
        (re-search-forward "^\\(commit\\|gpg:\\)")
        (put-text-property pos (match-beginning 0) 'face 'egg-text-1)
        (re-search-forward "^Author:\\s-+")
        (put-text-property (match-end 0) (line-end-position) 'face 'egg-text-2)
        (re-search-forward "^Date:\\s-+")
        (put-text-property (match-end 0) (line-end-position) 'face 'egg-text-2)
        (put-text-property (line-end-position) (point-max) 'face 'egg-text-1))
      (set-buffer-modified-p nil))
    (pop-to-buffer buf)))

(defun egg-show-remote-branch (branch)
  (interactive (list (egg-remote-at-point)))
  (let* ((info (and (stringp branch)
                    (egg-git-to-string-list "for-each-ref"
                                            "--format=%(refname:short) %(refname)"
                                            (concat "refs/remotes/" branch))))
         (name (nth 0 info))
         (full (nth 1 info))
         (site (and (stringp name) (egg-rbranch-to-remote name)))
         (url (and site (egg-git-to-string "ls-remote" "--get-url" site))))
    (when (stringp name)
      (message "remote-tracking-branch:%s full-name:%s site:%s" 
               (egg-text name 'bold) 
               (egg-text full 'bold)
               (egg-text url 'bold)))))


(defun egg-call-next-action (action &optional ignored-action only-action)
  (when (and action (symbolp action))
    (let ((cmd (plist-get '(log egg-log
                                status egg-status
                                stash egg-status
                                commit egg-commit-log-edit
                                reflog egg-reflog)
                          action))
          (current-prefix-arg nil))
      (when (and (commandp cmd)		;; cmd is a valid command
                 ;; if only-action is specified, then only take
                 ;; action if it's the same as only-action
                 (or (and only-action (eq only-action action))
                     ;; if only-action is not specified, then
                     ;; take the action if it's not ignored.
                     (and (null only-action)
                          (not (if (symbolp ignored-action) 
                                   (eq action ignored-action)
                                 (memq action ignored-action))))))
        (call-interactively cmd)))))



(defsubst egg-tooltip-func ()
  (if egg-enable-tooltip 'egg-buffer-help-echo))


(defun egg-read-tracked-filename (prompt &optional default no-match-ok)
  (concat (egg-work-tree-dir)
          (completing-read prompt #'egg-do-completion
                           #'egg-get-match-files-substring
                           (not no-match-ok) default)))

(defun egg-find-tracked-file (file-name)
  "Open a file tracked by git."
  (interactive (list (egg-read-tracked-filename "Find tracked file: ")))
  (switch-to-buffer (find-file-noselect file-name)))


(defun egg-pretty-head-string (&optional state)
  "Pretty description of HEAD.  if STATE was not nil then use it
as repo state instead of re-read from disc."
  (let* ((state (or state (egg-repo-state)))
         (branch (plist-get state :branch))
         (merge-heads (plist-get state :merge-heads))
         (rebase-head (plist-get state :rebase-head))
         (squash-head (plist-get state :squash-head))
         (rebase-upstream (plist-get state :rebase-upstream))
         (sha1 (plist-get state :sha1)))
    (cond ((and branch merge-heads)
           (concat "Merging to " branch " from: "
                   (mapconcat 'identity merge-heads ",")))
          (merge-heads
           (concat "Merging to " (egg-pretty-short-rev sha1) " from: "
                   (mapconcat 'identity merge-heads ",")))
          ((and branch squash-head)
           (concat "Squashed " squash-head " onto " branch))
          (squash-head
           (concat "Squashed " squash-head "  onto " (egg-pretty-short-rev sha1)))
          ((and rebase-head rebase-upstream)
           (format "Rebasing %s onto %s" rebase-head rebase-upstream))
          (branch branch)
          (t (concat "Detached HEAD: " (egg-describe-rev sha1))))))

(defsubst egg-pretty-head-name (&optional state)
  "Pretty name for HEAD.  if STATE was not nil then use it
as repo state instead of re-read from disc."
  (let* ((state (or state (egg-repo-state)))
         (branch (plist-get state :branch)))
    (or branch (egg-pretty-short-rev (plist-get state :sha1)))))

(defun egg--async-create-signed-commit-handler (buffer-to-update)
  (goto-char (point-min))
  (re-search-forward "EGG-GIT-OUTPUT:\n" nil t)
  (if (not (match-end 0))
      (message "something wrong with git-commit's output!")
    (let* ((proc egg-async-process)
           (ret-code (process-exit-status proc))
           res)
      (goto-char (match-end 0))
      (save-restriction
        (narrow-to-region (point) (point-max))
        (setq res (egg--do-show-output 
                   "GIT-COMMIT-GPG"
                   (egg--do-handle-exit (cons ret-code (current-buffer)) 
                                        #'egg--git-pp-commit-output
                                        buffer-to-update)))
        (when (plist-get res :success)
          (setq res (nconc (list :next-action 'status) res)))
        (egg--buffer-handle-result res t)))))

(defsubst egg-buffer-do-amend-no-edit (&rest args)
  (egg--buffer-handle-result (egg--git-amend-no-edit-cmd t) t))




(defun egg--buffer-do-create-tag (name rev stdin &optional short-msg force ignored-action)
  (let ((args (list name rev))
        (check-name (egg-git-to-string "name-rev" name))
        res)

    (cond (stdin (setq args (nconc (list "-F" "-") args)))
          (short-msg (setq args (nconc (list "-m" short-msg))))
          (t nil))

    (setq force (egg--git-tag-check-name name force))
    (when force (setq args (cons "-f" args)))
    (when (or stdin short-msg) (setq args (cons "-a" args)))

    (setq res (egg--git-tag-cmd (egg-get-log-buffer) stdin args))

    ;;; useless???
    (when (plist-get res :success)
      (setq res (nconc (list :next-action 'log) res)))

    (egg--buffer-handle-result res t ignored-action)))

;;(setenv "GPG_AGENT_INFO" "/tmp/gpg-SbJxGl/S.gpg-agent:28016:1")
;;(getenv "GPG_AGENT_INFO")

(defun egg--async-create-signed-tag-handler (buffer-to-update name rev)
  (goto-char (point-min))
  (re-search-forward "EGG-GIT-OUTPUT:\n" nil t)
  (if (not (match-end 0))
      (message "something wrong with git-tag's output!")
    (let* ((proc egg-async-process)
           (ret-code (process-exit-status proc))
           res)
      (goto-char (match-end 0))
      (save-restriction
        (narrow-to-region (point) (point-max))
        (setq res (egg--do-show-output 
                   "GIT-TAG-GPG"
                   (egg--do-handle-exit (cons ret-code (current-buffer)) 
                                        #'egg--git-tag-cmd-pp
                                        buffer-to-update)))
        (when (plist-get res :success)
          (setq res (nconc (list :next-action 'log) res)))
        (egg--buffer-handle-result res t)))))

(defun egg--async-create-signed-tag-cmd (buffer-to-update msg name rev &optional gpg-uid force)
  (let ((force (egg--git-tag-check-name name force))
        (args (list "-m" msg name rev)))

    (when force (setq args (cons "-f" args)))

    (setq args (if (stringp gpg-uid) (nconc (list "-u" gpg-uid) args) (cons "-s" args)))
    (egg-async-1-args (list #'egg--async-create-signed-tag-handler buffer-to-update name rev)
                      (cons "tag" args))))

(defsubst egg-log-buffer-do-tag-commit (name rev force &optional msg)
  (egg--buffer-do-create-tag name rev nil msg force 'log))

(defsubst egg-status-buffer-do-tag-HEAD (name force &optional msg)
  (egg--buffer-do-create-tag name "HEAD" nil msg force 'status))

(defsubst egg-edit-buffer-do-create-tag (name rev beg end force)
  (egg--buffer-do-create-tag name rev (cons beg end) nil force))

(defun egg--buffer-handle-result (result &optional take-next-action ignored-action only-action)
  "Handle the structure returned by the egg--git-xxxxx-cmd functions.
RESULT is the returned value of those functions. Proceed to the next logical action
if TAKE-NEXT-ACTION is non-nil unless the next action is IGNORED-ACTION.
if ONLY-ACTION is non-nil then only perform the next action if it's the same
as ONLY-ACTION.

See documentation of `egg--git-action-cmd-doc' for structure of RESULT."
  (let ((ok (plist-get result :success))
        (next-action (plist-get result :next-action)))
    (egg-revert-visited-files (plist-get result :files))
    (when (and ok take-next-action)
      (egg-call-next-action next-action ignored-action only-action))
    ok))

(defun egg--buffer-handle-result-with-commit (result commit-args 
                                                     &optional take-next-action
                                                     ignored-action only-action)
  "Handle the structure returned by the egg--git-xxxxx-cmd functions.
RESULT is the returned value of those functions. Proceed to the next logical action
if TAKE-NEXT-ACTION is non-nil unless the next action is IGNORED-ACTION.
if ONLY-ACTION is non-nil then only perform the next action if it's the same
as ONLY-ACTION.

See documentation of `egg--git-action-cmd-doc' for structure of RESULT."
  (let ((ok (plist-get result :success))
        (next-action (plist-get result :next-action)))
    (egg-revert-visited-files (plist-get result :files))
    (when (and ok take-next-action)
      (if (eq next-action 'commit)
          (apply #'egg-commit-log-edit commit-args)
        (egg-call-next-action next-action ignored-action only-action)))
    ok))

(defsubst egg-log-buffer-handle-result (result)
  "Handle the RESULT returned by egg--git-xxxxx-cmd functions.
This function should be used in the log buffer only.

See documentation of `egg--git-action-cmd-doc' for structure of RESULT."
  (egg--buffer-handle-result result t 'log))

(defsubst egg-status-buffer-handle-result (result)
  "Handle the RESULT returned by egg--git-xxxxx-cmd functions.
This function should be used in the status buffer only.

See documentation of `egg--git-action-cmd-doc' for structure of RESULT."
  (egg--buffer-handle-result result t 'status))

(defsubst egg-stash-buffer-handle-result (result)
  "Handle the RESULT returned by egg--git-xxxxx-cmd functions.
This function should be used in the stash buffer only.

See documentation of `egg--git-action-cmd-doc' for structure of RESULT."
  (egg--buffer-handle-result result t 'stash))

(defsubst egg-file-buffer-handle-result (result)
  "Handle the RESULT returned by egg--git-xxxxx-cmd functions.
This function should be used in a file visiting buffer only.

See documentation of `egg--git-action-cmd-doc' for structure of RESULT."

  ;; for file buffer, we only take commit action
  (egg--buffer-handle-result result t nil 'commit))

(defsubst egg-buffer-do-create-branch (name rev force track ignored-action)
  "Create a new branch synchronously when inside an egg special buffer.
NAME is the name of the new branch. REV is the starting point of the branch.
If force is non-nil, then force the creation of new branch even if a branch
NAME already existed. Branch NAME will bet set up to track REV if REV was
a branch and track was non-nil. Take the next logical action unless it's
IGNORED-ACTION."
  (egg--buffer-handle-result
   (egg--git-branch-cmd (egg-get-log-buffer)
                        (nconc (if force (list "-f"))
                               (if track (list "--track"))
                               (list name rev))) t ignored-action))

(defsubst egg-log-buffer-do-co-rev (rev &rest args)
  "Checkout REV using ARGS as arguments when in the log buffer."
  (egg-log-buffer-handle-result (egg--git-co-rev-cmd-args t rev args)))

(defsubst egg-status-buffer-do-co-rev (rev &rest args)
  "Checkout REV using ARGS as arguments when in the status buffer."
  (egg-status-buffer-handle-result (egg--git-co-rev-cmd-args t rev args)))

;;;========================================================
;;; Blame utils
;;;========================================================

(defconst egg-blame-map
  (let ((map (make-sparse-keymap "Egg:Blame")))
    (define-key map (kbd "l") 'egg-blame-locate-commit)
    (define-key map (kbd "RET") 'egg-blame-locate-commit)
    (define-key map (kbd "q") 'egg-file-toggle-blame-mode)
    (define-key map (kbd "n") 'egg-buffer-cmd-navigate-next)
    (define-key map (kbd "p") 'egg-buffer-cmd-navigate-prev)
    map)
  "Keymap for an annotated section.\\{egg-blame-map}")


(defun egg-parse-git-blame (target-buf blame-buf &optional ov-attributes)
  "Parse blame-info in buffer BLAME-BUF and decorate TARGET-BUF buffer.
OV-ATTRIBUTES are the extra decorations for each blame chunk."
  (save-match-data
    (let ((blank (egg-text " " 'egg-blame))
          (nl (egg-text "\n" 'egg-blame))
          (commit-hash (make-hash-table :test 'equal :size 577))
          commit commit-info old-line new-line num old-file subject author
          info ov beg end blame)
      (with-current-buffer blame-buf
        (goto-char (point-min))
        ;; search for a ful commit info
        (while (re-search-forward (rx line-start
                                      (group (= 40 hex-digit)) " "
                                      (group (1+ digit)) " "
                                      (group (1+ digit)) " "
                                      (group (1+ digit)) 
                                      line-end)
                                  nil t)
          (setq commit (match-string-no-properties 1)
                old-line (string-to-number
                          (match-string-no-properties 2))
                new-line (string-to-number
                          (match-string-no-properties 3))
                num (string-to-number
                     (match-string-no-properties 4)))
          ;; was this commit already seen (and stored in the hash)?
          (setq commit-info (gethash commit commit-hash))
          ;; Nope, this is the 1st time, the full commit-info follow.
          (unless commit-info
            (re-search-forward "^author \\(.+\\)$")
            (setq author (match-string-no-properties 1))
            (re-search-forward "^summary \\(.+\\)$")
            (setq subject (match-string-no-properties 1))
            (re-search-forward "^filename \\(.+\\)$")
            (setq old-file (match-string-no-properties 1))
            (setq commit-info (nconc
                               (list :sha1 commit :author author
                                     :subject subject :file old-file)
                               ov-attributes))
            ;; save it in the hash
            (puthash commit commit-info commit-hash))
          ;; add the current blame-block into the list INFO.
          (setq info (cons (list old-line new-line num commit-info)
                           info))))
      ;; now do from beginning
      (setq info (nreverse info))
      (with-current-buffer target-buf
        ;; for every blame chunk
        (dolist (chunk info)
          (setq commit-info (nth 3 chunk)
                old-line (nth 0 chunk)
                new-line (nth 1 chunk)
                num (nth 2 chunk)
                commit (plist-get commit-info :sha1)
                author (plist-get commit-info :author)
                subject (plist-get commit-info :subject))

          (goto-char (point-min))
          (forward-line (1- new-line))
          (setq beg (line-beginning-position)
                end (save-excursion
                      (forward-line num)
                      (line-beginning-position)))
          ;; mark the blame chunk
          (put-text-property beg end :blame chunk)
          (put-text-property beg end :navigation commit)

          ;; make an overlay with blame info as 'before-string
          ;; on the current chunk.
          (setq ov (make-overlay beg end))
          (overlay-put ov :blame chunk)
          (setq blame (concat
                       (egg-text (substring-no-properties commit 0 8)
                                 'egg-blame)
                       blank
                       (egg-text (format "%-20s" author)
                                 'egg-blame-culprit)
                       blank
                       (egg-text subject 'egg-blame-subject)
                       blank nl))
          (overlay-put ov 'before-string blame)
          (overlay-put ov 'local-map egg-blame-map))))))

(defsubst egg-file-buffer-blame-off (buffer)
  (save-excursion
    (save-restriction
      (with-current-buffer buffer
        (widen)
        (mapc (lambda (ov)
                (if (overlay-get ov :blame)
                    (delete-overlay ov)))
              (overlays-in (point-min) (point-max)))))))

(defun egg-file-buffer-blame-on (buffer &rest ov-attributes)
  (egg-file-buffer-blame-off buffer)
  (save-excursion
    (with-current-buffer buffer
      (save-restriction
        (with-temp-buffer
          (when (egg--git t "blame" "-w" "-M" "-C" "--porcelain" "--"
                          (file-name-nondirectory
                           (buffer-file-name buffer)))
            (egg-parse-git-blame buffer (current-buffer)
                                 ov-attributes)))))))

(defun egg-blame-locate-commit (pos &optional all)
  "Jump to a commit in the branch history from an annotated blame section.

   With prefix argument, the history of all refs is used."
  (interactive "d\nP")
  (let ((overlays (overlays-at pos))
        sha1)
    (dolist (ov overlays)
      (if (overlay-get ov :blame)
          (setq sha1 (plist-get (nth 3 (overlay-get ov :blame)) :sha1))))
    (if sha1
        (egg-do-locate-commit sha1))))

;;;========================================================
;;; Diff/Hunk
;;;========================================================

(defun egg-mouse-do-command (event cmd)
  (let* ((window (posn-window (event-end event)))
         (buffer (and window (window-buffer window)))
         (position (posn-point (event-end event))))
    (when (bufferp buffer)
      (save-window-excursion
        (save-excursion
          (select-window window)
          (with-current-buffer buffer
            (goto-char position)
            (call-interactively cmd)))))))

(defun egg-mouse-hide-show-cmd (event)
  (interactive "e")
  (egg-mouse-do-command event 'egg-section-cmd-toggle-hide-show))


(defun list-nav ()
  (interactive)
  (message "nav: %c:%s-%c:%s"
           (preceding-char)
           (get-text-property (1- (point)) :navigation)
           (following-char)
           (get-text-property (point) :navigation)))


(defsubst egg-decorate-diff-header (beg end line-beg line-end)
  (put-text-property line-beg (1+ beg)
                     'display
                     (egg-text
                      (concat "\n"
                              (buffer-substring-no-properties beg
                                                              (1+ beg)))
                      'egg-diff-file-header))
  (put-text-property (1+ beg) end 'face 'egg-diff-file-header)
  (put-text-property (1+ beg) end 'help-echo (egg-tooltip-func)))

(defsubst egg-decorate-cc-diff-header (beg end line-beg line-end)
  (put-text-property line-beg (1+ beg)
                     'display
                     (egg-text
                      (concat "\n"
                              (buffer-substring-no-properties beg
                                                              (1+ beg)))
                      'egg-unmerged-diff-file-header))
  (put-text-property (1+ beg) end 'face 'egg-unmerged-diff-file-header)
  (put-text-property (1+ beg) end 'help-echo (egg-tooltip-func)))

(defsubst egg-decorate-diff-index-line (beg end line-beg line-end)
  (put-text-property line-beg (1+ line-end) 'display ""))

(defsubst egg-decorate-hunk-header (beg end line-beg line-end)
  (put-text-property beg end 'face 'egg-diff-hunk-header)
  (put-text-property end line-end 'face 'egg-diff-none)
  (put-text-property beg end 'help-echo (egg-tooltip-func)))

(defvar egg-internal-buffer-obarray nil)

(defsubst egg-make-navigation (parent child)
  "Make a symbolic and unique navigation id.
return a symbol PARENT-CHILD from an internal obarray."
  (unless (vectorp egg-internal-buffer-obarray)
    (error "Arrg! egg-internal-buffer-obarray is not an obarray!"))
  (intern (format "%s-%s" parent child) egg-internal-buffer-obarray))

(defsubst egg-do-compute-navigation (section pos)
  "Come up with a symbolic and unique navigation id for
section SECTION at position POS."
  (egg-make-navigation (get-text-property pos :navigation)
                       (if (consp section)
                           (car section)
                         section)))

(defun egg-compute-navigation (ignored-1 section pos ignored-2)
  "Come up with a symbolic and unique navigation id for
section SECTION at position POS."
  (egg-do-compute-navigation section pos))

(defun egg-delimit-section (sect-type section beg end
                                      &optional inv-beg
                                      keymap navigation)
  "Mark section for navigation and add local/context keymap.
SECT-TYPE is the type of the section (usually a :symbol).
SECTION is the name of the section (usually a string).  BEG and
END are limits of the section.  INV-BEG is the position after the
position that would remain visible when the section is hidden.
KEYMAP is the local/context keymap for the section.
NAVIGATION is the navigation id of the section. NAVIGATION can also
a function to call to compute the navigation id of the section."
  (let ((nav (cond ((and (not (eq navigation 'file))
                         (functionp navigation))
                    (funcall navigation sect-type section beg end))
                   ((null navigation) beg)
                   (t navigation))))
    (put-text-property beg end :sect-type sect-type)
    (put-text-property beg end sect-type section)
    (put-text-property beg end :navigation nav)
    (when (keymapp keymap)
      (put-text-property beg end 'keymap keymap))
    (when (integer-or-marker-p inv-beg)
      (let ((current-inv (get-text-property inv-beg 'invisible)))
        (add-to-list 'current-inv nav t)
        (put-text-property inv-beg (1- end) 'invisible current-inv)))))

(defsubst egg-make-hunk-info (name beg end diff)
  "Build a hunk info NAME from BEG to END based on DIFF.
Hunk info contains name and posistions of the hunk. Positions are offsets
from DIFF because it can the whole diff can be pushed around inside
the buffer.

The fourth element of hunk info is NIL and is a placeholder for
HUNK-RANGES list to be placed there by `egg-calculate-hunk-ranges'
"
  (let ((b (nth 1 diff)))
    (list name (- beg b) (- end b) nil)))

(defsubst egg-make-diff-info (name beg end head-end)
  "Build a diff info NAME from BEG to END. HEAD-END is the end position
of the diff header.

Diff info contains name and posistions of the diff. The beginning position
is stored as a marker and the others are offset from the beginning posistion
 because the whole diff can be pushed around inside the buffer."
  (let ((b (make-marker))
        info)
    (set-marker b beg)
    ;; no insertion indo the diff
    (set-marker-insertion-type b t)
    ;; all other posistions are offsets from B.
    (setq info (list name b (- end beg) (- head-end beg)))
    (save-match-data
      (save-excursion
        (goto-char beg)
        (if (re-search-forward "new file mode" head-end t)
            (setq info (nconc info (list 'newfile))))))
    info))

(defun egg-decorate-diff-sequence (args)
  "Decorate a sequence of deltas. ARGS is a plist containing the
positions of the sequence as well as the decorations.

:begin :end :diff-map :hunk-map :cc-diff-map :cc-hunk-map
:conflict-map :src-prefix :dst-prefix
"
  (let* ((beg		(plist-get args	:begin))
         (end		(plist-get args	:end))
         (diff-map 	(plist-get args	:diff-map))
         (hunk-map 	(plist-get args	:hunk-map))
         (cc-diff-map 	(plist-get args	:cc-diff-map))
         (cc-hunk-map 	(plist-get args	:cc-hunk-map))
         (conflict-map 	(plist-get args	:conflict-map))
         (a 		(plist-get args	:src-prefix))
         (b 		(plist-get args	:dst-prefix))

         ;; the sub match id of the regexp below
         (diff-no	1)
         (cc-diff-no	2)
         (hunk-no	3)
         (cc-hunk-no	4)
         (src-no 	5)
         (dst-no 	6)
         (index-no	7)
         (conf-beg-no	8)
         (conf-div-no	9)
         (conf-end-no	10)
         (cc-del-no 	11)
         (cc-add-no 	12)
         (del-no 	13)
         (add-no 	14)
         (none-no	15)

         (regexp
          (concat "^\\(?:"
                  "diff --git " a ".+ " b "\\(.+\\)\\|"	;1 diff header
                  "diff --cc \\(.+\\)\\|"		;2 cc-diff header
                  "\\(@@ .+@@\\).*\\|"			;3 hunk
                  "\\(@@@ .+@@@\\).*\\|"		;4 cc-hunk
                  "--- " a "\\(.+\\)\\|"		;5 src
                  "\\+\\+\\+ " b "\\(.+\\)\\|"		;6 dst
                  "index \\(.+\\)\\|"			;7 index
                  "\\+\\+<<<<<<< \\(.+\\)\\(?::.+\\)?\\|";8 conflict start
                  "\\(\\+\\+=======\\)\\|"		;9 conflict div
                  "\\+\\+>>>>>>> \\(.+\\)\\(?::.+\\)?\\|";10 conflict end
                  "\\( -.*\\)\\|"			;11 cc-del
                  "\\( \\+.*\\)\\|"			;12 cc-add
                  "\\(-.*\\)\\|"			;13 del
                  "\\(\\+.*\\)\\|"			;14 add
                  "\\( .*\\)"				;15 none
                  "\\)$"))

         ;; where the hunk end?
         (hunk-end-re "^\\(?:diff \\|@@\\|\\* \\)")
         ;; where the diff end?
         (diff-end-re "^\\(?:diff \\|\\* \\)")

         sub-beg sub-end head-end m-b-0 m-e-0 m-b-x m-e-x
         last-diff last-cc current-delta-is tmp pos)

    (save-match-data
      (save-excursion
        (goto-char beg)
        (while (re-search-forward regexp end t)
          (setq sub-beg (match-beginning 0)
                m-b-0 sub-beg
                m-e-0 (match-end 0))
          (cond ((or (match-beginning del-no)
                     (and (match-beginning cc-del-no) (eq current-delta-is 'cc-diff))) ;; del
                 (put-text-property m-b-0 m-e-0 'face 'egg-diff-del))

                ((or (match-beginning add-no)
                     (and (match-beginning cc-add-no) (eq current-delta-is 'cc-diff))) ;; add
                 (put-text-property m-b-0 m-e-0 'face 'egg-diff-add))

                ((match-beginning none-no) ;; unchanged
                 (put-text-property m-b-0 m-e-0 'face 'egg-diff-none))

                ((match-beginning dst-no) ;; +++ b/file
                 (setq m-b-x (match-beginning dst-no)
                       m-e-x (match-end dst-no))
                 (put-text-property m-b-0 m-b-x 'face 'egg-diff-add)
                 (put-text-property m-b-x m-e-x 'face 'egg-diff-none))

                ((match-beginning src-no) ;; --- a/file
                 (setq m-b-x (match-beginning src-no)
                       m-e-x (match-end src-no))
                 (put-text-property m-b-0 m-b-x 'face 'egg-diff-del)
                 (put-text-property m-b-x m-e-x 'face 'egg-diff-none))

                ((match-beginning conf-beg-no) ;;++<<<<<<<
                 (setq m-b-x (match-beginning conf-beg-no)
                       m-e-x (match-end conf-beg-no)
                       tmp (match-string-no-properties conf-beg-no))
                 (put-text-property m-b-0 m-b-x 'face 'egg-diff-conflict)
                 (put-text-property m-b-x m-e-x 'face 'egg-branch-mono)
                 (put-text-property m-e-x m-e-0 'face 'egg-diff-none)
                 (setq pos (egg-safe-search "^++=======" end))
                 (add-text-properties m-b-0 pos (list :conflict-side 'ours
                                                      :conflict-head tmp))
                 ;; mark the whole conflict section
                 (setq sub-end (egg-safe-search "^++>>>>>>>.+\n" end nil nil t))
                 (egg-delimit-section :conflict (cons sub-beg sub-end) sub-beg sub-end
                                      (+ m-b-0 9) conflict-map 'egg-compute-navigation))

                ((match-beginning conf-end-no) ;;++>>>>>>>
                 (setq m-b-x (match-beginning conf-end-no)
                       m-e-x (match-end conf-end-no)
                       tmp (match-string-no-properties conf-end-no))
                 ;; just decorate, no mark.
                 ;; the section was already mark when the conf-beg-no
                 ;; matched.

                 (setq pos (egg-safe-search "^++=======" beg nil t t))
                 (add-text-properties pos (1+ m-e-0) (list :conflict-side 'theirs
                                                           :conflict-head tmp))

                 (put-text-property m-b-0 m-b-x 'face 'egg-diff-conflict)
                 (put-text-property m-b-x m-e-x 'face 'egg-branch-mono)
                 (put-text-property m-e-x m-e-0 'face 'egg-diff-none))

                ((match-beginning conf-div-no) ;;++=======
                 ;; just decorate, no mark.
                 ;; the section was already mark when the conf-beg-no
                 ;; matched.
                 (put-text-property m-b-0 m-e-0 'face 'egg-diff-conflict))

                ((match-beginning hunk-no) ;; hunk @@
                 (setq m-b-x (match-beginning hunk-no)
                       m-e-x (match-end hunk-no)
                       ;; find the end of the hunk section
                       sub-end (or (egg-safe-search hunk-end-re end)
                                   end))
                 ;; decorate the header
                 (egg-decorate-hunk-header m-b-x m-e-x m-b-0 m-e-0)
                 ;; mark the whole hunk based on the last diff header
                 (egg-delimit-section
                  :hunk (egg-make-hunk-info
                         (match-string-no-properties hunk-no)
                         sub-beg sub-end last-diff)
                  sub-beg sub-end m-e-0 hunk-map
                  'egg-compute-navigation))

                ((match-beginning cc-hunk-no) ;; cc-hunk
                 (setq m-b-x (match-beginning cc-hunk-no)
                       m-e-x (match-end cc-hunk-no)
                       ;; find the end of the hunk section
                       sub-end (or (egg-safe-search hunk-end-re end)
                                   end))
                 ;; decorate the header
                 (egg-decorate-hunk-header m-b-x m-e-x m-b-0 m-e-0)
                 ;; mark the whole hunk based on the last cc-diff header
                 (egg-delimit-section
                  :hunk (egg-make-hunk-info
                         (match-string-no-properties cc-hunk-no)
                         sub-beg sub-end last-cc)
                  sub-beg sub-end m-e-0 cc-hunk-map
                  'egg-compute-navigation))

                ((match-beginning diff-no) ;; diff
                 (setq m-b-x (match-beginning diff-no)
                       m-e-x (match-end diff-no)
                       sub-end (or (egg-safe-search diff-end-re end) end)
                       ;; find the end of the header
                       head-end (or (egg-safe-search "^\\(@@\\|diff\\)" end) end))
                 ;; decorate the header
                 (egg-decorate-diff-header m-b-x m-e-x m-b-0 m-e-0)
                 ;; mark the whole diff
                 (egg-delimit-section
                  :diff (setq last-diff
                              (egg-make-diff-info
                               (match-string-no-properties diff-no)
                               sub-beg sub-end head-end))
                  sub-beg sub-end m-e-0 diff-map 'egg-compute-navigation)

                 (put-text-property (- sub-end 2) sub-end 'intangible t)		 
                 (setq current-delta-is 'diff))

                ((match-beginning cc-diff-no) ;; cc-diff
                 (setq m-b-x (match-beginning cc-diff-no)
                       m-e-x (match-end cc-diff-no)
                       sub-end (or (egg-safe-search diff-end-re end) end)
                       ;; find the end of the header
                       head-end (or (egg-safe-search "^\\(@@@\\|diff\\)" end) end))
                 ;; decorate the header
                 (egg-decorate-cc-diff-header m-b-x m-e-x m-b-0 m-e-0)
                 ;; mark the whole diff
                 (egg-delimit-section
                  :diff (setq last-cc
                              (egg-make-diff-info
                               (match-string-no-properties cc-diff-no)
                               sub-beg sub-end head-end))
                  sub-beg sub-end m-e-0 cc-diff-map
                  'egg-compute-navigation)
                 (put-text-property (- sub-end 2) sub-end 'intangible t)
                 (setq current-delta-is 'cc-diff))

                ((match-beginning index-no) ;; index
                 (setq m-b-x (match-beginning index-no)
                       m-e-x (match-end index-no))
                 (egg-decorate-diff-index-line m-b-x m-e-x m-b-0 m-e-0))
                ) ;; cond
          ) ;; while
        ) ;; save-excursion
      ) ;;; save -match-data

    nil))

(defun egg-decorate-diff-section (&rest args)
  "Decorate a section containing a sequence of diffs.
See `egg-decorate-diff-sequence'."
  (let ((beg (plist-get args	 :begin))
        (end (plist-get args	 :end))
        (a   (or (plist-get args :src-prefix) "a/"))
        (b   (or (plist-get args :dst-prefix) "b/"))
        (a-rev (plist-get args 	 :src-revision))
        (b-rev (plist-get args 	 :dst-revision)))
    (when (stringp a-rev)
      (put-text-property beg end :src-revision a-rev))
    (when (stringp b-rev)
      (put-text-property beg end :dst-revision b-rev))
    (egg-decorate-diff-sequence
     (nconc (list :src-prefix a :dst-prefix b) args))))

(defsubst egg-hunk-info-at (pos)
  "Rebuild the hunk info at POS.
Hunk info are relative offsets. This function compute the
physical offsets. The hunk-line may be NIL if this is not status
or commit buffer and `egg-calculate-hunk-ranges' was
not called"
  (let* ((diff-info (get-text-property pos :diff))
         (head-beg (nth 1 diff-info))
         (hunk-info (get-text-property pos :hunk))
         (hunk-beg (and hunk-info (+ (nth 1 hunk-info) head-beg)))
         (hunk-end (and hunk-info (+ (nth 2 hunk-info) head-beg)))
         (hunk-ranges (and hunk-info (nth 3 hunk-info))))
    (and hunk-info
         (list (car diff-info) (car hunk-info) hunk-beg hunk-end hunk-ranges))))

(defun egg-diff-section-cmd-visit-file (file)
  "Visit file FILE."
  (interactive (list (car (get-text-property (point) :diff))))
  (find-file file))

(defun egg-staged-diff-section-cmd-visit-index (file &optional use-wdir-file)
  "Visit the index of FILE.
With C-u prefix, visit the work-tree's file instead."
  (interactive (list (car (get-text-property (point) :diff))
                     current-prefix-arg))
  (if use-wdir-file
      (find-file file)
    (egg-buffer-pop-to-file file ":0")))

(defun egg-staged-diff-section-cmd-visit-index-other-window (file &optional use-wdir-file)
  (interactive (list (car (get-text-property (point) :diff))
                     current-prefix-arg))
  (if use-wdir-file
      (find-file-other-window file)
    (egg-buffer-pop-to-file file ":0" t)))

(defun egg-staged-hunk-cmd-visit-index-other-window (use-wdir-file file hunk-header hunk-beg &rest ignored)
  (interactive (cons current-prefix-arg (egg-hunk-info-at (point))))
  (egg-buffer-pop-to-file file 
                          (unless use-wdir-file ":0")
                          t
                          use-wdir-file
                          (egg-hunk-compute-line-no hunk-header hunk-beg)))

(defun egg-staged-hunk-cmd-visit-index (use-wdir-file file hunk-header hunk-beg &rest ignored)
  (interactive (cons current-prefix-arg (egg-hunk-info-at (point))))
  (egg-buffer-pop-to-file file 
                          (unless use-wdir-file ":0")
                          nil
                          use-wdir-file
                          (egg-hunk-compute-line-no hunk-header hunk-beg)))

(defun egg-diff-section-cmd-visit-file-other-window (file)
  "Visit file FILE in other window."
  (interactive (list (car (get-text-property (point) :diff))))
  (find-file-other-window file))

(defun egg-unmerged-section-cmd-ediff3 (file)
  "Run ediff3 to resolve merge conflicts in FILE."
  (interactive (list (car (get-text-property (point) :diff))))
  (egg-resolve-merge-with-ediff file))

(defun egg-unstaged-section-cmd-ediff (file)
  "Compare FILE and its staged copy using ediff."
  (interactive (list (car (get-text-property (point) :diff))))
  (egg--ediff-file-revs file nil nil ":0" "INDEX"))

(defun egg-staged-section-cmd-ediff3 (file &optional ediff2)
  "Compare the staged copy of FILE and the version in HEAD using ediff."
  (interactive (list (car (get-text-property (point) :diff)) current-prefix-arg))

  (if ediff2
      (egg--ediff-file-revs file ":0" "INDEX" (egg-branch-or-HEAD) nil)
    (egg--ediff-file-revs file nil nil ":0" "INDEX" (egg-branch-or-HEAD) nil)))

(defvar egg-diff-buffer-info nil
  "Data for the diff buffer.
This is built by `egg-build-diff-info'")

(defun egg-diff-section-cmd-ediff (file pos)
  "Ediff src and dest versions of FILE based on the diff at POS."
  (interactive (list (car (get-text-property (point) :diff))
                     (point)))
  (let ((commit (get-text-property pos :commit))
        (diff-info egg-diff-buffer-info))
    (cond ((stringp commit)
           (egg--commit-do-ediff-file-revs (egg-pretty-short-rev commit) file))
          ((consp diff-info)
           (egg--diff-do-ediff-file-revs diff-info file)))))

(defun egg-hunk-compute-line-no (hunk-header hunk-beg &optional hunk-ranges)
  "Calculate the effective line number in the original file based
on the position of point in a hunk. HUNK-HEADER is the header and
HUNK-BEG is the starting position of the current hunk."
  (let ((limit (line-end-position))
        (line
         (or
          (when hunk-ranges
            ;; 3rd element of real range
            (third (third hunk-ranges)))
          (string-to-number
           (nth 2 (save-match-data
                    (split-string hunk-header "[ @,\+,-]+" t))))))
        (adjust 0))
    (save-excursion
      (goto-char hunk-beg)
      (forward-line 1)
      (end-of-line)
      (while (and (< (point) limit) 
                  (re-search-forward "^\\(?:\\+\\| \\).*" limit t))
        (setq adjust (1+ adjust))))
    (+ line adjust)))

(defun egg-hunk-section-cmd-visit-file (file hunk-header hunk-beg hunk-end
                                             hunk-ranges &rest ignored)
  "Visit FILE and goto the current line of the hunk."
  (interactive (egg-hunk-info-at (point)))
  (let ((line (egg-hunk-compute-line-no hunk-header hunk-beg hunk-ranges)))
    (find-file file)
    (goto-char (point-min))
    (forward-line (1- line))))

(defun egg-hunk-section-cmd-visit-file-other-window (file hunk-header hunk-beg hunk-end
                                                          hunk-ranges &rest ignored)
  "Visit FILE in other-window and goto the current line of the hunk."
  (interactive (egg-hunk-info-at (point)))
  (let ((line (egg-hunk-compute-line-no hunk-header hunk-beg hunk-ranges)))
    (find-file-other-window file)
    (goto-char (point-min))
    (forward-line (1- line))))

(defun egg-unmerged-conflict-checkout-side (pos)
  "Checkout one side of the conflict at POS."
  (interactive "d")
  (let* ((side (or (get-text-property pos :conflict-side) "theirs"))
         (head (or (get-text-property pos :conflict-head) "ours"))
         (file (car (get-text-property pos :diff))))
    (unless (memq :unmerged (assoc file egg-status-buffer-changed-files-status))
      (error "Not an unmerged file: %s" file))
    (when (y-or-n-p (format "use %s's contents for unmerged file %s? " head file))
      (when (egg-status-buffer-handle-result 
             (egg--git-co-files-cmd (current-buffer) file (concat "--" (symbol-name side))))
        (when (y-or-n-p (format "stage %s? " file))
          (egg-status-buffer-handle-result (egg--git-add-cmd (current-buffer) file)))))))

(defun egg-unmerged-conflict-take-side (pos)
  "Interactive resolve conflict at POS."
  (interactive "d")
  (let* ((hunk-info (egg-hunk-info-at pos))
         (file (and hunk-info (car hunk-info)))
         (hunk-header (and hunk-info (nth 1 hunk-info)))
         (hunk-beg (and hunk-info (nth 2 hunk-info)))
         (hunk-end (and hunk-info (nth 3 hunk-info)))
         (hunk-ranges (and hunk-info (nth 4 hunk-info)))
         (line (and hunk-info (egg-hunk-compute-line-no hunk-header hunk-beg hunk-ranges)))
         (side (get-text-property pos :conflict-side))
         our-head their-head resolution)
    (save-window-excursion
      (save-excursion
        (with-current-buffer (find-file-noselect file)
          (select-window (display-buffer (current-buffer)))
          (let (conf-beg conf-end ours-beg ours-end theirs-beg theirs-end
                         ours theirs conflict bg)
            (goto-char (point-min))
            (forward-line (1- line))
            (if (eq side 'theirs)
                (progn
                  (unless (re-search-backward "^<<<<<<< \\(.+\\)\n" nil t)
                    (error "Failed searching for <<<<<<<"))
                  (setq our-head (match-string-no-properties 1))
                  (setq conf-beg (copy-marker (match-beginning 0) nil))
                  (setq ours-beg (match-end 0))
                  (unless (re-search-forward "^=======\n" nil t)
                    (error "Failed searching for ======="))
                  (setq ours-end (match-beginning 0))
                  (setq theirs-beg (match-end 0))
                  (unless (re-search-forward "^>>>>>>> \\(.+\\)\n")
                    (error "Failed searching for >>>>>>>"))
                  (setq their-head (match-string-no-properties 1))
                  (setq theirs-end (match-beginning 0))
                  (setq conf-end (copy-marker (match-end 0) t)))
              (unless (re-search-forward "^>>>>>>> \\(.+\\)\n")
                (error "Failed searching for >>>>>>>"))
              (setq their-head (match-string-no-properties 1))
              (setq theirs-end (match-beginning 0))
              (setq conf-end (copy-marker (match-end 0) t))
              (unless (re-search-backward "^=======\n" nil t)
                (error "Failed searching for ======="))
              (setq ours-end (match-beginning 0))
              (setq theirs-beg (match-end 0))
              (unless (re-search-backward "^<<<<<<< \\(.+\\)\n" nil t)
                (error "Failed searching for <<<<<<<"))
              (setq our-head (match-string-no-properties 1))
              (setq ours-beg (match-end 0))
              (setq conf-beg (copy-marker (match-beginning 0) nil)))
            (setq ours (buffer-substring-no-properties ours-beg ours-end))
            (setq theirs (buffer-substring-no-properties theirs-beg theirs-end))
            (setq conflict (buffer-substring-no-properties conf-beg conf-end))

            (goto-char conf-beg)
            (delete-region conf-beg conf-end)
            (insert (if (eq side 'theirs) theirs ours))
            (setq bg (make-overlay conf-beg conf-end nil nil t))
            (overlay-put bg 'face 'egg-add-bg)
            (setq resolution 
                  (if (y-or-n-p (format "keep %s's delta? " 
                                        (if (eq side 'theirs) their-head our-head)))
                      side
                    (goto-char conf-beg)
                    (delete-region conf-beg conf-end)
                    (insert (if (eq side 'theirs) ours theirs))
                    (setq bg (move-overlay bg conf-beg conf-end))
                    (if (y-or-n-p (format "keep %s's delta? " 
                                          (if (eq side 'theirs) our-head their-head)))
                        (if (eq side 'theirs) 'ours 'theirs)
                      nil)))
            (if resolution
                (basic-save-buffer)
              (goto-char conf-beg)
              (delete-region conf-beg conf-end)
              (insert conflict)
              (set-buffer-modified-p nil))
            (delete-overlay bg)))))
    (when resolution
      (egg-buffer-cmd-refresh)
      ;; (when (egg-git-ok nil "diff" "--cc" "--quiet" file)
      ;; 	(when (y-or-n-p (format "no more conflict in %s, stage %s? " file file))
      ;; 	  (egg-status-buffer-handle-result (egg--git-add-cmd (current-buffer) file))))
      )))

(defun egg-hunk-compute-replacement-text (hunk-info)
  (let ((file (nth 0 hunk-info))
        (b-beg (nth 2 hunk-info))
        (b-end (nth 3 hunk-info))
        (ranges (nth 4 hunk-info))
        range
        new-1st-line new-num-lines
        old-1st-line old-num-lines
        hunk-text new-text old-text
        old-ranges new-ranges
        start-c current-prefix current-range)
    (setq range (nth 1 ranges))
    (setq old-1st-line (nth 0 range)
          old-num-lines (nth 1 range)
          new-1st-line (nth 2 range)
          new-num-lines (nth 3 range))
    (setq hunk-text (buffer-substring-no-properties 
                     (save-excursion
                       (goto-char b-beg)
                       (forward-line 1)
                       (point))
                     b-end))
    (with-temp-buffer
      (erase-buffer)
      (insert hunk-text)
      (goto-char (point-min))
      (flush-lines "^\\+")
      (goto-char (point-min))
      (while (not (eobp))
        (delete-char 1)
        (forward-line 1))
      (setq old-text (buffer-string))

      (erase-buffer)
      (insert hunk-text)
      (goto-char (point-min))
      (flush-lines "^-")
      (goto-char (point-min))
      (while (not (eobp))
        (delete-char 1)
        (forward-line 1))
      (setq new-text (buffer-string))

      (erase-buffer)
      (insert hunk-text)
      (goto-char (point-min))
      (setq current-prefix (char-after))
      (while (not (eobp))
        (setq start-c (char-after))
        (delete-char 1)
        (unless (= start-c current-prefix)
          (cond ((eq current-prefix ?+)
                 (setcdr current-range (1- (point)))
                 (push current-range new-ranges))
                ((eq current-prefix ?-)
                 (setcdr current-range (1- (point)))
                 (push current-range old-ranges)))
          (setq current-range (list (1- (point))))
          (setq current-prefix start-c))
        (forward-line 1))
      (unless (eq current-prefix ? )
        (cond ((eq current-prefix ?+)
               (setcdr current-range (1- (point)))
               (push current-range new-ranges))
              ((eq current-range ?-)
               (setcdr current-range (1- (point)))
               (push current-range old-ranges))))
      (setq hunk-text (buffer-string)))

    (list file
          (list old-1st-line old-num-lines old-text)
          (list new-1st-line new-num-lines new-text)
          (list old-ranges new-ranges hunk-text))))



(defun egg-section-cmd-toggle-hide-show (nav)
  "Toggle the hidden state of the current section."
  (interactive (list (get-text-property (point) :navigation)))

  ;; emacs's bug? caused by tooltip
  (if (eq buffer-invisibility-spec t)
      (setq buffer-invisibility-spec nil))

  (if (assoc nav buffer-invisibility-spec)
      (remove-from-invisibility-spec (cons nav t))
    (add-to-invisibility-spec (cons nav t)))
  (force-window-update (current-buffer)))

(defun egg-section-cmd-toggle-hide-show-children (pos sect-type)
  "Toggle the hidden state of the subsections of the current section."
  (interactive (list (previous-single-property-change (1+ (point))
                                                      :navigation)
                     (get-text-property (point) :sect-type)))
  (unless pos
    (setq pos (point)))
  (let ((end (next-single-property-change pos sect-type nil (point-max)))
        child-pos child-nav
        currently-hidden)
    ;; guess the current state
    (setq child-pos (next-single-property-change pos :navigation nil end))
    (when child-pos
      (setq child-nav (get-text-property child-pos :navigation))
      (setq currently-hidden (and child-nav
                                  (assoc child-nav
                                         buffer-invisibility-spec))))
    (setq child-pos pos)
    ;; toggle every child
    (while (< (setq child-pos (next-single-property-change child-pos :navigation nil end))
              end)
      (setq child-nav (get-text-property child-pos :navigation))
      (if currently-hidden
          (remove-from-invisibility-spec (cons child-nav  t))
        (add-to-invisibility-spec (cons child-nav t))))
    (force-window-update (current-buffer))))

(defun egg-diff-section-patch-string (&optional pos)
  "Build a file patch based on the diff section at POS."
  (let* ((diff-info (get-text-property (or pos (point)) :diff))
         (beg (nth 1 diff-info))
         (end (+ (nth 2 diff-info) beg)))
    (buffer-substring-no-properties beg end)))

(defun egg-hunk-section-patch-string (&optional pos reverse)
  "Build a single hunk patch based on the delta hunk at POS."
  (let* ((diff-info (get-text-property (or pos (point)) :diff))
         (head-beg (nth 1 diff-info))
         (head-end (+ (nth 3 diff-info) head-beg))
         (hunk-info (get-text-property (or pos (point)) :hunk))
         (hunk-beg (+ (nth 1 hunk-info) head-beg))
         (hunk-end (+ (nth 2 hunk-info) head-beg)))
    ;; craete diff patch
    (if (egg-use-region-p)
        (egg-hunk-section-patch-region-string pos diff-info reverse)
      (concat (buffer-substring-no-properties head-beg head-end)
              (buffer-substring-no-properties hunk-beg hunk-end)))))

(defun egg-hunk-section-patch-region-string (pos diff-info reverse)
  "Build a patch string usable as input for git apply.
The patch is built based on the hunk enclosing POS. DIFF-INFO
is the file-level diff information enclosing the hunk. Build a
reversed patch if REVERSE was non-nil."
  (let* ((head-beg (nth 1 diff-info))
         (head-end (+ (nth 3 diff-info) head-beg))
         (hunk-info (get-text-property (or pos (point)) :hunk))
         (hunk-beg (+ (nth 1 hunk-info) head-beg))
         (hunk-end (+ (nth 2 hunk-info) head-beg))
         (beg (region-beginning))
         (end (region-end))
         (hunk-buf (current-buffer)))
    (with-temp-buffer
      (let ((buf (current-buffer)))
        (with-current-buffer hunk-buf
          ;; insert header
          (egg-insert-string-buffer
           (buffer-substring-no-properties head-beg head-end) buf)
          (goto-char hunk-beg)
          ;; insert beginning of hunk
          (egg-insert-current-line-buffer buf)
          (forward-line)
          (let ((copy-op (if reverse "+" "-")))
            (while (< (point) hunk-end)
              (if (and (<= beg (point)) (< (point) end))
                  (egg-insert-current-line-buffer buf)
                (cond ((looking-at " ")
                       (egg-insert-current-line-buffer buf))
                      ((looking-at copy-op)
                       (egg-insert-string-buffer
                        (concat
                         " "
                         (buffer-substring-no-properties
                          (+ (point) 1) (line-beginning-position 2))) buf))))
              (forward-line))))
        ;; with current buffer `buf'
        (diff-fixup-modifs (point-min) (point-max))
        (buffer-string)))))

;;;========================================================
;;; Buffer
;;;========================================================


;; (defun egg-buffer-cmd-refresh ()
;;   "Refresh the current egg special buffer."
;;   (interactive)
;;   (when (and (egg-git-dir)
;;              (functionp egg-buffer-refresh-func))
;;     (funcall egg-buffer-refresh-func (current-buffer))))
(defun egg-buffer-cmd-refresh ()
  "Refresh the current egg special buffer."
  (interactive)
  (when (egg-git-dir) 
    (egg-refresh-buffer (current-buffer))))

(defun egg-buffer-cmd-next-block (nav-prop)
  "Move to the next block indentified by text property NAV-PROP."
  (goto-char (or (next-single-property-change (point) nav-prop)
                 (point))))

(defun egg-buffer-cmd-prev-block (nav-prop)
  "Move to the previous block indentified by text property NAV-PROP."
  (goto-char (previous-single-property-change (point) nav-prop
                                              nil (point-min))))

(defun egg-buffer-cmd-navigate-next (&optional at-level)
  "Move to the next section.
With C-u prefix, move to the next section of the same type."
  (interactive "P")
  (egg-buffer-cmd-next-block
   (if (not at-level) :navigation
     (or (get-text-property (point) :sect-type) :navigation))))

(defun egg-buffer-cmd-navigate-prev (&optional at-level)
  "Move to the previous section.
With C-u prefix, move to the previous section of the same type."
  (interactive "P")
  (egg-buffer-cmd-prev-block 
   (if (not at-level) :navigation
     (or (get-text-property (point) :sect-type) :navigation))))

(defun egg-get-buffer (fmt create)
  "Get a special egg buffer. If buffer doesn't exist and CREATE was not nil then
creat the buffer. FMT is used to construct the buffer name. The name is built
as: (format FMT current-dir-name git-dir-full-path)."
  (let* ((git-dir (egg-git-dir))
         (dir (egg-work-tree-dir git-dir))
         (dir-name (egg-repo-name git-dir))
         (buf-name (format fmt dir-name git-dir))
         (default-directory dir)
         (buf (get-buffer buf-name)))
    (unless (or (bufferp buf) (not create))
      (setq buf (get-buffer-create buf-name)))
    buf))

(defvar egg-orig-window-config nil)

(defun egg-quit-buffer (&optional win)
  "Leave (and burry) an egg special buffer"
  (interactive)
  (let ((orig-win-cfg egg-orig-window-config)
        (mode major-mode))
    (quit-window (memq 'kill (cdr (assq mode egg-quit-window-actions))) win)
    (if (and orig-win-cfg
             (window-configuration-p orig-win-cfg)
             (memq 'restore-windows (cdr (assq mode egg-quit-window-actions))))
        (set-window-configuration orig-win-cfg))))

(defmacro define-egg-buffer (type name-fmt &rest body)
  "Define an egg-special-file type."
  (let* ((type-name (symbol-name type))
         (get-buffer-sym (intern (concat "egg-get-" type-name "-buffer")))
         (buffer-mode-sym (intern (concat "egg-" type-name "-buffer-mode")))
         (buffer-mode-hook-sym (intern (concat "egg-" type-name "-buffer-mode-hook")))
         (buffer-mode-map-sym (intern (concat "egg-" type-name "-buffer-mode-map")))
         (update-buffer-no-create-sym (intern (concat "egg-update-" type-name "-buffer-no-create"))))
    `(progn
       (defun ,buffer-mode-sym ()
         ,@body
         (set (make-local-variable 'egg-orig-window-config)
              (current-window-configuration))
         ;; (message "buffer %s win-cfg %s" (buffer-name) egg-orig-window-config)
         (set (make-local-variable 'egg-internal-buffer-obarray)
              (make-vector 67 0)))

       (defun ,get-buffer-sym (&optional create)
         (let ((buf (egg-get-buffer ,name-fmt create)))
           (when (bufferp buf)
             (with-current-buffer buf
               (unless (and (not create) (eq major-mode ',buffer-mode-sym))
                 (,buffer-mode-sym))))
           buf))
       ,(unless (string-match ":" type-name)
          `(progn
             (defun ,update-buffer-no-create-sym ()
               (let ((buf (,get-buffer-sym)))
                 (when (bufferp buf)
                   (egg-refresh-buffer buf))))
             (add-hook 'egg-buffers-refresh-hook ',update-buffer-no-create-sym))))))


;; (cl-macroexpand '(define-egg-buffer diff "*diff-%s@egg:%s*"))
;; (cl-macroexpand ' (define-egg-buffer diff (buf) "*diff-%s@egg:%s*" (show-diff buf) ))



;;;========================================================
;;; Status Buffer
;;;========================================================
(defun egg-buffer-do-rebase (upstream-or-action &optional onto current-action)
  "Perform rebase action from an egg special buffer.
See `egg-do-rebase-head'."
  (let ((rebase-dir (plist-get (egg-repo-state :rebase-dir) :rebase-dir))
        (git-dir (egg-git-dir))
        res)
    (if (stringp upstream-or-action)
        (unless (egg-repo-clean)
          (egg-status nil nil)
          (error "Repo %s is not clean" git-dir))
      (unless rebase-dir
        (error "No rebase in progress in directory %s"
               (egg-work-tree-dir git-dir))))
    (egg-do-rebase-head upstream-or-action onto current-action)))

(defun egg-buffer-rebase-continue ()
  "Continue the current rebase session."
  (interactive)
  (message "continue with current rebase")
  (egg-buffer-do-rebase :continue nil
                        (cdr (assq major-mode '((egg-status-buffer-mode . status)
                                                (egg-log-buffer-mode . log))))))

(defsubst egg-do-async-rebase-continue (callback closure &optional
                                                 action
                                                 exit-code)
  "Continue the current rebase session asynchronously."
  (let ((process-environment (copy-sequence process-environment))
        (action (or action "--continue"))
        (buffer (current-buffer))
        proc)
    (setenv "EDITOR" "\nplease commit in egg")
    (setq proc (egg-async-1 (list callback closure) "rebase" action))
    (process-put proc :orig-buffer buffer)
    proc))

(defun egg-buffer-selective-rebase-action (action)
  "Perform ACTION to continue the current rebase session.
The mode, sync or async, will depend on the nature of the current
rebase session."
  (if (not (egg-interactive-rebase-in-progress))
      (egg-buffer-do-rebase action nil 
                            (cdr (assq major-mode '((egg-status-buffer-mode . status)
                                                    (egg-log-buffer-mode . log)))))
    (setq action (cdr (assq action '((:skip . "--skip")
                                     (:continue . "--continue")
                                     (:abort . "--abort")))))
    (with-egg-debug-buffer
      (egg-do-async-rebase-continue
       #'egg-handle-rebase-interactive-exit
       (egg-pick-file-contents (concat (egg-git-rebase-dir) "head-name") "^.+$")
       action))))

(defun egg-buffer-selective-rebase-continue ()
  "Continue the current rebase session.
The mode, sync or async, will depend on the nature of the current
rebase session."
  (interactive)
  (message "continue with current rebase")
  (egg-buffer-selective-rebase-action :continue))

(defun egg-buffer-selective-rebase-skip ()
  "Skip the current commit and continue the current rebase session.
The mode, sync or async, will depend on the nature of the current
rebase session."
  (interactive)
  (message "skip rebase's current commit")
  (egg-buffer-selective-rebase-action :skip))

(defun egg-buffer-rebase-abort ()
  (interactive)
  (message "abort current rebase")
  (egg-buffer-do-rebase :abort  nil
                        (cdr (assq major-mode '((egg-status-buffer-mode . status)
                                                (egg-log-buffer-mode . log))))))

(defvar egg-status-buffer-changed-files-status nil)
(defvar egg-status-buffer-interactive-stash-info nil)

(defun egg-sb-setup-interactive-stash ()
  (make-local-variable 'egg-status-buffer-interactive-stash-info)
  (let ((dir (egg-work-tree-dir))
        (stash-index-file (make-temp-name (concat (egg-git-dir) "/index.stash.")))
        info base-commit index-commit index-tree
        branch head-desc
        worktree-unchanged index-unchanged)
    (with-current-buffer "*i-stash-debug*"
      (erase-buffer)
      (setq default-directory dir)
      (setq index-unchanged (egg-git-ok t "diff-index" "--exit-code" "--cached" "HEAD" 
                                        "--ignore-submodules"))
      (setq worktree-unchanged (egg-git-ok t "diff-files" "--exit-code"
                                           "--ignore-submodules"))
      (when (and worktree-unchanged index-unchanged)
        (error "nothing to stash"))
      (unless (egg-git-ok t "update-index" "--refresh")
        (error "git update-index failed!"))
      (setq base-commit (egg-git-to-string "rev-parse" "--verify" "HEAD"))
      (setq head-desc (egg-git-to-string "rev-list" "--oneline" "-n1" "HEAD" "--"))
      (setq branch (or (egg-current-branch) "(no branch)"))
      (setq index-tree (egg-git-to-string "write-tree"))
      (unless index-tree
        (error "git write-tree failed to write original index to database."))
      (setq index-commit (egg-git-to-string "commit-tree" "-p" base-commit 
                                            "-m" 
                                            (format "index on %s: %s" branch head-desc)
                                            index-tree))
      (unless index-commit
        (error "git commit-tree failed to create commit object for original index"))
      (unless (egg-git-ok t "read-tree" (format "--index-output=%s" stash-index-file)
                          "HEAD")
        (error "git read-tree failed read HEAD into stash index file %s"
               stash-index-file))
      (setq info (list :stash-index-file stash-index-file
                       :base-commit base-commit
                       :index-commit index-commit
                       :branch branch
                       :head-desc head-desc)))
    (setq egg-status-buffer-interactive-stash-info info)
    (egg-status nil t)
    (set (make-local-variable 'egg--internal-index-file) stash-index-file)))

(defun egg-sb-istash-abort ()
  (interactive)
  (unless (consp egg-status-buffer-interactive-stash-info)
    (error "Something wrong, no interactive stash session is in progress!"))
  (let ((info egg-status-buffer-interactive-stash-info))
    (setq egg--internal-index-file nil)
    (delete-file (plist-get info :stash-index-file))
    (egg-status nil t)))

(defun egg-sb-istash-go ()
  (interactive)
  (unless (consp egg-status-buffer-interactive-stash-info)
    (error "Something wrong, no interactive stash session is in progress!"))
  (let ((info egg-status-buffer-interactive-stash-info)
        (msg (read-string "Sort message for this WiP: "))
        (stash-ref-file (concat (egg-git-dir) "/refs/stash"))
        worktree-commit workdir-tree old-stash patch res)
    (setq workdir-tree (egg-git-to-string "write-tree"))
    (setq msg (format "On %s: %s" (plist-get info :branch) msg))
    (setq patch (egg-git-to-string "diff-tree" "HEAD" workdir-tree))
    (unless (> (length patch) 1)
      (error "No changes selected to stash!"))
    (setq worktree-commit (egg-git-to-string "commit-tree" 
                                             "-p" (plist-get info :base-commit)
                                             "-p" (plist-get info :index-commit)
                                             "-m" msg workdir-tree))
    (when (file-exists-p stash-ref-file)
      (setq old-stash (egg-git-to-string "rev-parse" "--verify" "refs/stash"))
      (egg--git "update-ref" "-d" "refs/stash" old-stash))
    (write-region (point-min) (point-min) stash-ref-file t)
    (unless (egg-git-ok "update-ref" "-m" msg "refs/stash" worktree-commit)
      (error "Failed to stash WiP!"))

    (setq egg--internal-index-file nil)
    (delete-file (plist-get info :stash-index-file))
    (setq egg-status-buffer-interactive-stash-info nil)

    (if (y-or-n-p "Discard unstashed local changes? ")
        (egg-sb-undo-wdir-back-to-HEAD t t 'status)
      (egg-status-buffer-handle-result
       (egg--git-apply-cmd (current-buffer) patch (list "--reverse"))))))

(defun egg-sb-interactive-stash-wip ()
  (message "TBD"))

(defun egg-sb-insert-repo-section ()
  "Insert the repo section into the status buffer."
  (let* ((state (egg-repo-state))
         (sha1 (plist-get state :sha1))
         (beg (point))
         (map egg-section-map)
         (rebase-step (plist-get state :rebase-step))
         (rebase-num (plist-get state :rebase-num))
         (rebase-stopped-sha (plist-get state :rebase-stopped))
         inv-beg help-beg help-inv-beg rebase-beg)

    (unless (and sha1 state)
      (error "Invalid repo state: sha1 = %s, state = %S"
             sha1 state))

    ;; head, sha1 and git-dir
    (insert (egg-text (egg-pretty-head-string state) 'egg-branch) "\n"
            (egg-text sha1 'font-lock-string-face) "\n"
            (egg-text (plist-get state :gitdir) 'font-lock-constant-face)
            "\n")
    ;; invisibility start at the newline
    (setq inv-beg (1- (point)))
    (when egg-status-buffer-interactive-stash-info
      ;; Interactive stash info
      (insert (egg-text "Interactive stashing in progress\n" 'egg-text-2)
              (egg-text "s: Select/Unselect deltas for stashing\n" 'egg-text-1)))
    (when rebase-step
      ;; Rebase info and keybindings
      (insert (format "Rebase: commit %s of %s" rebase-step rebase-num))
      (when rebase-stopped-sha
        (insert " (" (egg-git-to-string "log" "--no-walk" "--pretty=%h:%s" 
                                        rebase-stopped-sha)
                ")"))
      (insert "\n")
      (setq map egg-status-buffer-rebase-map))
    (when (memq :status egg-show-key-help-in-buffers)
      ;; Help
      (insert "\n")
      (setq help-beg (point))
      (insert (egg-text "Help" 'egg-help-header-1) "\n")
      (put-text-property help-beg (point) 'help-echo (egg-tooltip-func))
      (setq help-inv-beg (1- (point)))
      (insert egg-status-buffer-common-help-text)
      (when (eq egg-status-buffer-rebase-map map)
        (insert egg-status-buffer-rebase-help-text))
      (insert egg-status-buffer-diff-help-text)
      (insert egg-stash-help-text))
    ;; Mark the repo section
    (egg-delimit-section :section 'repo beg (point) inv-beg map 'repo)
    (when help-beg
      ;; Mark the help sub-section so it can be hidden
      (egg-delimit-section :help 'help help-beg (point) help-inv-beg map
                           'egg-compute-navigation))
    (put-text-property (- (point) 2) (point) 'intangible t)
    (put-text-property beg (or help-beg (point))
                       'help-echo (egg-tooltip-func))))

(defun egg-ignore-pattern-from-string-at-point ()
  "Add an ignore pattern based on the string at point."
  (interactive)
  (let ((string (egg-string-at-point))
        (file (ffap-file-at-point))
        dir pattern gitignore)
    (setq pattern (read-string "ignore pattern: "
                               (if (string-match "\\.[^.]+\\'" string)
                                   (match-string-no-properties 0 string)
                                 string)))
    (when (equal pattern "")
      (error "Can't ignore empty string!"))
    (setq dir (if (stringp file)
                  (file-name-directory (expand-file-name file))
                default-directory))
    (setq gitignore
          (read-file-name (format "add pattern `%s' to: " pattern)
                          dir nil nil ".gitignore"))
    (save-excursion
      (with-current-buffer (find-file-noselect gitignore t t)
        (goto-char (point-max))
        (insert pattern "\n")
        (save-buffer)
        (kill-buffer (current-buffer))))
    (egg-buffer-cmd-refresh)))

(defun egg-status-buffer-stage-untracked-file (&optional no-stage)
  "add untracked file(s) to the repository

acts on a single file or on a region which contains the names of
untracked files. If NO-STAGE, then only create the index entries without
adding the contents."
  (interactive "P")
  (let ((files (if mark-active
                   (progn
                     (if (< (point) (mark))
                         (progn
                           (goto-char (line-beginning-position))
                           (exchange-point-and-mark)
                           (goto-char (line-end-position)))
                       (progn
                         (goto-char (line-end-position))
                         (exchange-point-and-mark)
                         (goto-char (line-beginning-position))))
                     (split-string
                      (buffer-substring-no-properties (point) (mark)) "\n" t))
                 (list (buffer-substring-no-properties
                        (line-beginning-position) (line-end-position)))))
        args files-string)
    (setq files (delete "" files))
    (setq files (delete nil files))
    (if (consp files)
        (setq files-string (mapconcat 'identity files ", "))
      (error "No file to stage!"))
    (setq args (nconc (list "-v" "--") files))
    (if no-stage
        (setq args (cons "-N" args)))
    
    (when (apply 'egg--git-add-cmd (current-buffer) args)
      (message "%s %s to git." (if no-stage "registered" "added") files-string))))


(defun egg-sb-insert-untracked-section ()
  "Insert the untracked files section into the status buffer."
  (let ((beg (point)) inv-beg end)
    (insert (egg-prepend "Untracked Files:" "\n\n"
                         'face 'egg-section-title
                         'help-echo (egg-tooltip-func))
            "\n")
    (setq inv-beg (1- (point)))
    (egg--git t "ls-files" "--others" "--exclude-standard")
    (setq end (point))
    (egg-delimit-section :section 'untracked beg end
                         inv-beg egg-section-map 'untracked)
    (put-text-property inv-beg end 'keymap egg-untracked-file-map)
    (put-text-property (1+ inv-beg) end 'help-echo (egg-tooltip-func))

    (put-text-property (- end 2) end 'intangible t)))

(defun egg-sb-buffer-show-stash (pos)
  "Load the details of the stash at POS."
  (interactive "d")
  (let* ((next (next-single-property-change pos :diff))
         (stash (and next (get-text-property next :stash))))
    (unless (equal (get-text-property pos :stash) stash)
      (egg-buffer-do-insert-stash pos))))


(defun egg-decorate-stash-list (start line-map section-prefix)
  (let (stash-beg stash-end beg end msg-beg msg-end name msg)
    (save-excursion
      (goto-char start)
      (while (re-search-forward "^\\(stash@{[0-9]+}\\): +\\(.+\\)$" nil t)
        (setq beg (match-beginning 0)
              stash-end (match-end 1)
              msg-beg (match-beginning 2)
              end (match-end 0))

        (setq name (buffer-substring-no-properties beg stash-end)
              msg (buffer-substring-no-properties msg-beg end))

        ;; entire line
        (add-text-properties beg (1+ end)
                             (list :navigation (concat section-prefix name)
                                   :stash name
                                   'keymap line-map))

        ;; comment
        (put-text-property beg stash-end 'face 'egg-stash-mono)
        (put-text-property msg-beg end 'face 'egg-text-2)))))

(defun egg-sb-insert-stash-section ()
  (let ((beg (point)) inv-beg stash-beg end)
    (insert (egg-prepend "Stashed WIPs:" "\n\n"
                         'face 'egg-section-title
                         'help-echo (egg-tooltip-func))
            "\n")
    (setq inv-beg (1- (point)))
    (setq stash-beg (point))
    (egg-list-stash)
    (setq end (point))
    (egg-delimit-section :section 'stash beg end
                         inv-beg egg-section-map 'stash)
    (egg-decorate-stash-list stash-beg egg-stash-map "stash-")
    (put-text-property (- end 2) end 'intangible t)
    ;;(put-text-property (1+ inv-beg) end 'help-echo (egg-tooltip-func))
    ))

(defun egg-sb-decorate-unmerged-entries-in-section (beg end sect-type)
  (save-excursion
    (goto-char beg)
    (let (status tmp path)
      (save-match-data
        (while (re-search-forward (rx line-start "* Unmerged path " 
                                      (group (1+ not-newline)) line-end)
                                  end t)
          (setq path (match-string-no-properties 1))
          (setq tmp (propertize (concat "\n" (substring path 0 1))
                                'face 'egg-unmerged-diff-file-header))
          (add-text-properties (match-beginning 0) (1+ (match-beginning 1))
                               (list 'display tmp 'intangible t))
          (put-text-property (1+ (match-beginning 1)) (match-end 1)
                             'face 'egg-unmerged-diff-file-header)

          (setq status (assoc path egg-status-buffer-changed-files-status))
          (when status
            (egg-delimit-section sect-type status
                                 (match-beginning 0) (match-end 0) nil nil
                                 #'egg-compute-navigation)
            (put-text-property (match-beginning 0) (match-end 0)
                               'keymap (if (eq sect-type :merged) 
                                           egg-unmerged-index-file-map
                                         egg-unmerged-wdir-file-map))
            (setq tmp (buffer-substring-no-properties (match-end 0) (1+ (match-end 0))))
            (setq tmp (concat (cond ((memq :we-deleted status) ": deleted by us")
                                    ((memq :they-deleted status) ":  deleted by them")
                                    ((memq :both-deleted status) ":  deleted by both")
                                    ((memq :both-modified status) ":  modified by both, please resolve in worktree")
                                    ((memq :we-added status) ":  added by us, please resolve in worktree")
                                    ((memq :they-added status) ":  added by them, please resolve in worktree")
                                    ((memq :both-added status) ":  added by both, please reolsve in worktree")
                                    (t "")) tmp))
            
            (put-text-property (match-end 0) (1+ (match-end 0)) 'display tmp)))))))

(defun egg-sb-insert-unstaged-section (title &rest extra-diff-options)
  "Insert the unstaged changes section into the status buffer."
  (let ((beg (point)) inv-beg diff-beg end path tmp status)
    (insert (egg-prepend title "\n\n" 'face 'egg-section-title
                         'help-echo (egg-tooltip-func))
            "\n")
    (setq diff-beg (point))
    (setq inv-beg (1- (point)))
    (egg-git-ok-args t (append (if egg-status-buffer-interactive-stash-info
                                   (list "diff" "--no-color" "-M" "-p"
                                         "--src-prefix=WiP:/"
                                         "--dst-prefix=Trash:/" )
                                 (list "diff" "--no-color" "-M" "-p"
                                       "--src-prefix=INDEX:/"
                                       "--dst-prefix=WORKDIR:/" ))
                               egg-git-diff-options
                               extra-diff-options))
    (setq end (point))
    (egg-delimit-section :section 'unstaged beg (point)
                         inv-beg egg-section-map 'unstaged)
    (if egg-status-buffer-interactive-stash-info
        (egg-decorate-diff-section :begin diff-beg
                                   :end (point)
                                   :src-prefix "WiP:/"
                                   :dst-prefix "Trash:/"
                                   :diff-map egg-unstaged-diff-section-map
                                   :hunk-map egg-unstaged-hunk-section-map)
      ;; this section might contains merge conflicts, thus cc-diff
      (egg-decorate-diff-section :begin diff-beg
                                 :end (point)
                                 :src-prefix "INDEX:/"
                                 :dst-prefix "WORKDIR:/"
                                 :diff-map egg-unstaged-diff-section-map
                                 :hunk-map egg-unstaged-hunk-section-map
                                 :cc-diff-map egg-unmerged-diff-section-map
                                 :cc-hunk-map egg-unmerged-hunk-section-map
                                 :conflict-map egg-unmerged-conflict-map))
    (egg-sb-decorate-unmerged-entries-in-section diff-beg end :unmerged)
    (put-text-property (- end 2) end 'intangible t)))

(defun egg-sb-insert-staged-section (title &rest extra-diff-options)
  "Insert the staged changes section into the status buffer."
  (let ((beg (point)) inv-beg diff-beg end)
    (insert (egg-prepend title "\n\n"
                         'face 'egg-section-title
                         'help-echo (egg-tooltip-func))
            "\n")
    (put-text-property (- beg 2) beg 'intangible t)
    (setq diff-beg (point)
          inv-beg (1- diff-beg))
    (egg-git-ok-args t (append (if egg-status-buffer-interactive-stash-info
                                   (list "diff" "--no-color" "--cached" "-M" "-p"
                                         "--src-prefix=Base:/"
                                         "--dst-prefix=WiP:/")
                                 (list "diff" "--no-color" "--cached" "-M" "-p"
                                       "--src-prefix=HEAD:/"
                                       "--dst-prefix=INDEX:/"))
                               egg-git-diff-options 
                               extra-diff-options))
    (setq end (point))
    (egg-delimit-section :section 'staged beg (point)
                         inv-beg egg-section-map 'staged)
    ;; this section never contains merge conflicts, thus no cc-diff
    (if egg-status-buffer-interactive-stash-info
        (egg-decorate-diff-section :begin diff-beg
                                   :end (point)
                                   :src-prefix "Base:/"
                                   :dst-prefix "WiP:/"
                                   :diff-map egg-staged-diff-section-map
                                   :hunk-map egg-staged-hunk-section-map)
      (egg-decorate-diff-section :begin diff-beg
                                 :end (point)
                                 :src-prefix "HEAD:/"
                                 :dst-prefix "INDEX:/"
                                 :diff-map egg-staged-diff-section-map
                                 :hunk-map egg-staged-hunk-section-map))
    (egg-sb-decorate-unmerged-entries-in-section diff-beg end :merged)
    (put-text-property (- end 2) end 'intangible t)))

(defvar egg-hunk-ranges-cache nil
  "A list of (FILENAME HUNK-RANGE-INFO ...)) for each file in the
buffer. Each HUNK-RANGE-INFO has the form of (SECTION BUFFER-RANGE REAL-RANGE SINGLE-RANGE)

SECTION is either 'staged or 'unstaged

Each RANGE is a list of four numbers (L1 S1 L2 S2) from the \"@@
-L1,S1 +L2,S2 @@\" hunk header.

Each of the three ranges have the following meaning:

* BUFFER-RANGE : The parsed number from the git hunk header in
  the buffer. They change as hunks are staged or unstaged. In the
  unstaged area, line numbers refer to actual working directory
  file. In the staged area, line numbers refer to the INDEX copy
  of the file, with all other staged hunks also applied

* REAL-RANGE : For the unstaged hunks, same as BUFFER-RANGE, but
  for the staged hunks, its the line numbers are in relation to
  working directory file, rather then INDEX + staged changes. This range
  will stay constant if hunk is staged or unstaged, but may change
  if new unstaged changes are added to what Egg buffer reflects.

* SINGLE-RANGE : This is a hunk range, artificially adjusted so
  that line numbers are in relation to the INDEX, as if this hunk
  was the only hunk staged.. This range will remain constant, when
  hunks are staged, unstaged, or new unstaged hunks are introduced, as long

  It may change only if user had extended the hunk by changing
  more lines abutting it, so that the hunk is extended or
  shrunken.

The only range that we really need, is SINGLE-RANGE, because it
is as close as we can get to unique hunk identifier, that will
remain constant in most circumstances.. But we need the other two
ranges in order to calculate the SINGLE-RANGE

For unstaged hunk, the SINGLE range is REAL-RANGE, adjusted for the total delta
of all staged and unstaged hunks before it

For staged hunk, the SINGLE range is BUFFER-RANGE adjusted for for the total
delta of staged hunks before it.
")

(defvar egg-section-visibility-info nil
  "Info on invisibility of file and its hunks before stage or unstage.
Each member of this list is (FILE-OR-SECTION VISIBILITY UNSTAGED-VISIBILITY
LINE-NUMBERS)

* FILE-OR-SECTION     : When string its a file, otherwise :NAVIGATION property
                      of the section

* VISIBILITY          : One of the following values:

  * :HIDDEN   : File is hidden
  * :VISIBLE  : File is showing
  * NIL       : File is not present in the section (only for files)

* UNSTAGED-VISIBILITY : Only for files, same as VISIBILITY but
  in unstaged section

* LINE-NUMBERS        : Real line numbers of hidden hunks (only for files)

The reason we use line numbers and not hunk ids, is because under
git hunk ids will not be the same, if hunks that are before them
in the same file are unstaged")

(defvar egg-around-point-section-info nil
  "The list of three elements (BEFORE-POINT AT-POINT
AFTER-POINT), that describe the previous, current and next
visible section of the egg status or diff buffer.

Each element is a list (FILE-OR-SECTION SECTION HUNK-LINE-NUMBER)

* FILE-OR-SECTION : When string its a file, otherwise value of
  :navigation property of the section

* SECTION : The value of :section property

* HUNK-LINE-NUMBER : Real hunk line number in the unstaged file

This information is used to restore the point to a good place
after buffer is refreshed, for example if last hunk in a diff is
staged or unstaged, point will move to the next one or previous
if no next hunk existed, or to the section if it was last hunk in
the section.
")

(make-variable-buffer-local 'egg-hunk-ranges-cache)
(make-variable-buffer-local 'egg-section-visibility-info)
(make-variable-buffer-local 'egg-around-point-section-info)


(defun egg-get-hunk-range (pos)
  "Return the 4 numbers from hunk header as list of integers"
  (destructuring-bind (file hunk-header hunk-beg &rest ignore)
      (egg-hunk-info-at pos)
    (let* ((range-as-strings
            (save-match-data
              (split-string hunk-header "[ @,\+,-]+" t)))
           (range
            (mapcar 'string-to-number range-as-strings))
           (len (length range)))
      ;; normalize hunk range, sorted in order of most frequent
      (cond
       ;; Normal hunk
       ((= 4 len) range)
       ;; 3 way diff when merging, never seen >6
       ((= 6 len) (append (subseq range 0 2)
                          (subseq range 4 6)))
       ;; Adding sub-modules
       ((= 2 len) (append range range))
       ;; Adding symbolic links
       ((= 3 len) (append range (list (second range))))
       ;; Never seen this 5 line numbers hunk, treat as 4
       ((= 5 len) (subseq range 0 4))
       ;; Never seen 1 line number hunk
       ((= 1 len) (list (car range) (car range) (car range) (car range)))
       ;; never seen hunk header with no line numbers
       ((zerop len) (list 1 1 1 1))
       ;; more then 6 numbers
       (t (warn "Weird hunk header %S" hunk-header)
          ;; treat as 6 line one
          (append (subseq range 0 2)
                  (subseq range 4 6)))))))

(defun egg-ensure-hunk-ranges-cache ()
  "Returns `egg-hunk-ranges-cache' re-creating it if its NIL."
  (or egg-hunk-ranges-cache
      (save-excursion
        (let ((pos (point-min)) nav
              last-file
              list)
          (while (setq pos (next-single-property-change (1+ pos) :navigation))
            (let ((sect (get-text-property pos :section))
                  (type (get-text-property pos :sect-type))
                  (file (first (get-text-property pos :diff)))
                  (nav (get-text-property pos :navigation)))
              (when (and nav file sect)
                (when (and (eq type :hunk))
                  (when (not (equal last-file file))
                    (push (setq list (cons file nil)) egg-hunk-ranges-cache)
                    (setq last-file file))
                  (let* ((range (egg-get-hunk-range pos))
                         (elem (list sect range
                                     (copy-sequence range)
                                     (copy-sequence range)))
                         (hunk-info (get-text-property pos :hunk)))
                    (setcdr list (cons elem (cdr list)))
                    (setf (fourth hunk-info) elem))))))
          egg-hunk-ranges-cache))))

(defun egg-unstaged-lines-delta-before-hunk (file line)
  "Count how many lines any unstaged patches add before LINE line number"
  (let ((cnt 0))
    (dolist (elem (cdr (assoc file (egg-ensure-hunk-ranges-cache))))
      (let ((sect (first elem))
            (range (second elem))
            (real-range (third elem))
            (single-range (fourth elem)))
        (when (eq sect 'unstaged)
          (destructuring-bind (l1 s1 l2 &optional s2) range
            (when (< l2 line)
              ;; Increment adjustment by how many lines were added
              (incf cnt (- (or s2 s1) s1)))))))
    cnt))

(defun egg-staged-lines-delta-before-hunk (file line)
  "Count how many lines any staged patches add before LINE line number"
  (let ((cnt 0))
    (dolist (elem (cdr (assoc file (egg-ensure-hunk-ranges-cache))))
      (let ((sect (first elem))
            (range (second elem))
            (real-range (third elem))
            (single-range (fourth elem)))
        (when (eq sect 'staged)
          (destructuring-bind (l1 s1 l2 &optional s2) range
            (when (< l2 line)
              ;; Increment adjustment by how many lines were added
              (incf cnt (- (or s2 s1) s1)))))))
    cnt))

(defun egg-calculate-hunk-ranges ()
  "Calculate the correct line number in the real unstaged file,
of each hunk in the current buffer, and store in the fourth
element of the :hunk info"

  ;; Refresh it
  (setq egg-hunk-ranges-cache nil)
  (egg-ensure-hunk-ranges-cache)

  ;; First create correct real range, for all staged changes
  (save-excursion
    (let ((pos (point-min)) nav
          last-file
          list)
      ;; first do all staged
      (while (setq pos (next-single-property-change (1+ pos) :navigation))
        (when (eq (get-text-property pos :sect-type) :hunk)
          (let* ((hunk-info (get-text-property pos :hunk))
                 (hunk-ranges (fourth hunk-info))
                 (file (first (get-text-property pos :diff))))
            (when (eq (get-text-property pos :section) 'staged)
              ;; set real range
              (let* ((real-range (third hunk-ranges))
                     (delta (egg-unstaged-lines-delta-before-hunk
                             file
                             (third real-range))))
                ;; (incf (first real-range) delta)
                (incf (third real-range) delta))))))))
  ;; Now create correct single-range for both staged and unstaged changes
  (save-excursion
    (let ((pos (point-min)) nav
          last-file
          list)
      (while (setq pos (next-single-property-change (1+ pos) :navigation))
        (when (eq (get-text-property pos :sect-type) :hunk)
          (let* ((hunk-info (get-text-property pos :hunk))
                 (file (first (get-text-property pos :diff)))
                 (hunk-ranges (fourth hunk-info))
                 (buffer-range (second hunk-ranges))
                 (real-range (third hunk-ranges))
                 (single-range (fourth hunk-ranges)))
            (if (eq (get-text-property pos :section) 'unstaged)
                (let* (
                       (delta-unstaged
                        (egg-unstaged-lines-delta-before-hunk
                         file
                         (third real-range)))
                       (delta-staged
                        (egg-staged-lines-delta-before-hunk
                         file
                         (- (third buffer-range)
                            delta-unstaged))))
                  (decf (first single-range) delta-staged)
                  (decf (third single-range) (+ delta-unstaged delta-staged)))
              (let ((delta
                     (egg-staged-lines-delta-before-hunk
                      file (third buffer-range))))
                ;; (decf (first single-range) delta)
                (decf (third single-range) delta)))))))))


(defun egg-hunk-real-line-number (&optional pos)
  "Return hunks line number in the unstaged file"
  (multiple-value-bind (file hunk-header hunk-beg hunk-end
                             ranges &rest ignored)
      (egg-hunk-info-at (or pos (point)))
    (or (when ranges (third (third ranges)))
        (string-to-number
         (nth 2 (save-match-data
                  (split-string hunk-header "[ @,\+,-]+" t)))))))

(defun egg-save-section-visibility ()
  "Save the visibility status of each file, and each hunk in the
buffer into `egg-section-visibility-info'. Hunks are indexed by
their real file line number.

Also the the first section after the point in `my-egg-stage/unstage-point"
  (setq egg-section-visibility-info nil)
  (setq egg-around-point-section-info (list nil nil nil))
  (let* ((pos (point-min)) nav
         (nav-at-point (get-text-property (point) :navigation))
         (nav-at-point-type (get-text-property (point) :sect-type))
         (nav-at-point-sect (get-text-property (point) :section))
         (nav-next
          (let (nav (pos (next-single-property-change (point) :navigation)))
            (while (and pos (or (invisible-p pos)
                                (eq nav-at-point
                                    (get-text-property pos :navigation))
                                (not (eq nav-at-point-type
                                         (get-text-property pos :sect-type)))
                                (and (not (eq nav-at-point-type :section))
                                     (not (eq nav-at-point-sect
                                              (get-text-property pos :section))))))
              (setq pos (next-single-property-change pos :navigation)))
            (and pos (get-text-property pos :navigation))))
         (nav-prev
          (let (nav (pos (previous-single-property-change (point) :navigation)))
            (and pos (setq pos (line-beginning-position)))
            (while (and pos
                        (or (invisible-p pos)
                            (eq nav-at-point
                                (get-text-property pos :navigation))
                            (not (eq nav-at-point-type
                                     (get-text-property pos :sect-type)))
                            (and (not (eq nav-at-point-type :section))
                                 (not (eq nav-at-point-sect
                                          (get-text-property pos :section))))))
              (setq pos (previous-single-property-change pos :navigation)))
            (and pos (get-text-property pos :navigation)))))
    (while (setq pos (next-single-property-change (min (1+ pos) (point-max)) :navigation))
      (let* ((sect (get-text-property pos :section))
             (type (get-text-property pos :sect-type))
             (file (first (get-text-property pos :diff)))
             (nav (get-text-property pos :navigation))
             (hunk-ranges (fourth (get-text-property pos :hunk)))
             (file-or-sect (or file nav)))
        ;; Save current section visibility
        (when (and nav sect)
          (let ((info
                 (or (assoc file-or-sect egg-section-visibility-info)
                     (first (push (list file-or-sect nil nil nil)
                                  egg-section-visibility-info))))
                (state (if (assoc nav buffer-invisibility-spec) :hidden :visible)))
            (cond ((and (eq sect 'staged) (eq type :diff))
                   (setf (second info) state))
                  ((and (eq sect 'unstaged) (eq type :diff))
                   (setf (third info) state))
                  ((and (eq type :hunk))
                   (push (list hunk-ranges state)
                         (fourth info)))
                  ((not (memq type '(:hunk :diff)))
                   ;; some other section like help or entire staged/unstaged
                   (setf (second info) state)))))
        ;; Remember previous, current and next sections at point
        (cond ((eq nav nav-prev)
               (setf (first egg-around-point-section-info)
                     (list file-or-sect sect hunk-ranges)))
              ((eq nav nav-at-point)
               (setf (second egg-around-point-section-info)
                     (list file-or-sect sect hunk-ranges)))
              ((eq nav nav-next)
               (setf (third egg-around-point-section-info)
                     (list file-or-sect sect hunk-ranges))))))))

(defun egg-restore-section-visibility ()
  "Restore the visibility of sections and hunks"
  (let* ( ;; these are sections before refresh
         (before-point (first egg-around-point-section-info))
         (at-point (second egg-around-point-section-info))
         (after-point (third egg-around-point-section-info))
         restore-pt restore-before-pt restore-after-pt
         at-point-section-same-p
         (at-point-was-file-or-hunk-p (stringp (first at-point))))
    (let ((pos (point-min)))
      (while (setq pos (next-single-property-change (1+ pos) :navigation))
        (let* ((sect (get-text-property pos :section))
               (type (get-text-property pos :sect-type))
               (file (first (get-text-property pos :diff)))
               (nav (get-text-property pos :navigation))
               (file-or-sect (or file nav))
               (hunk-ranges (when (eq type :hunk)
                              (fourth (get-text-property pos :hunk)))))
          (when (and nav file-or-sect)
            (let ((info (assoc file-or-sect egg-section-visibility-info)))
              (when info
                (cond
                 ((eq type :diff)
                  (let* ((was-present-here
                          (if (eq sect 'staged)
                              (second info)
                            (third info)))
                         (was-present-there
                          (if (eq sect 'staged)
                              (third info)
                            (second info)))
                         (was-invisible-here (eq :hidden was-present-here))
                         (was-invisible-there (eq :hidden was-present-there)))
                    ;; only make invisible if it was invisible in that section before
                    ;; or if it was not present, and opposite section was invisible
                    (when (and was-invisible-there
                               (or
                                was-invisible-here
                                (not was-present-here))
                               (not (assoc nav buffer-invisibility-spec)))
                      (add-to-invisibility-spec (cons nav t)))))
                 ;; for hunks, unconditionally restore invisibility
                 ((and (eq type :hunk))
                  (let* ((old-state
                          (egg-find-if
                           (lambda (elem)
                             (destructuring-bind (old-ranges old-state)
                                 elem
                               (equal (fourth hunk-ranges)
                                      (fourth old-ranges))))
                           (fourth info)))
                         (was-invisile (and old-state (eq (second old-state) :hidden)))
                         (is-invisible (assoc nav buffer-invisibility-spec)))
                    (cond ((and was-invisile (not is-invisible))
                           (add-to-invisibility-spec (cons nav t)))
                          ;; below restores visibility, if it was visible before
                          ;; so that moving folded hunk to staged, then unfolding it
                          ;; and moving it back, moves it back unfolded
                          ((and (not was-invisile) is-invisible)
                           (remove-from-invisibility-spec (cons nav t))))))))))
          (when file-or-sect
            (cond
             ;; when point was not on file or hunk, simply restore it
             ((and (not at-point-was-file-or-hunk-p)
                   (eq nav (first at-point)))
              (setq restore-pt (save-excursion
                                 (goto-char pos)
                                 (line-beginning-position))))
             ;; when point was on hunk or file, see if its section had changed
             ((and at-point-was-file-or-hunk-p
                   (equal file-or-sect (first at-point))
                   (equal (fourth hunk-ranges)
                          (fourth (third at-point))))
              (when (setq at-point-section-same-p (eq sect (second at-point)))
                (setq restore-pt (save-excursion
                                   (goto-char pos)
                                   (line-beginning-position)))))
             ;; need these in case piece where point was had moved
             ((and (equal file-or-sect (first before-point))
                   (equal (fourth hunk-ranges)
                          (fourth (third before-point)))
                   (equal sect (second before-point)))
              (setq restore-before-pt (save-excursion
                                        (goto-char pos)
                                        (let ((end
                                               (1- (next-single-property-change
                                                    (point) :navigation nil
                                                    (1+ (point-max))))))
                                          (unless
                                              (save-excursion
                                                (goto-char end)
                                                (invisible-p (line-beginning-position)))
                                            (goto-char end)))
                                        ;; TODO move back until visible
                                        (line-beginning-position))))
             ((and (equal file-or-sect (first after-point))
                   (equal (fourth hunk-ranges)
                          (fourth (third after-point)))
                   (equal sect (second after-point)))
              (setq restore-after-pt (save-excursion
                                       (goto-char pos)
                                       (line-beginning-position)))))))))
    (cond (restore-pt
           (goto-char restore-pt))
          ;; If point was at file/hunk, and there was one after
          ;; it (in the same section), then move point to it
          ((and at-point-was-file-or-hunk-p
                (not at-point-section-same-p)
                (stringp (first after-point))
                restore-after-pt)
           (goto-char restore-after-pt))
          ;; Otherwise if there was file/hunk before it
          ((and at-point-was-file-or-hunk-p
                (not at-point-section-same-p)
                (stringp (first before-point))
                restore-before-pt)
           (goto-char restore-before-pt))
          ;; Otherwise if point was on file/hunk, move point
          ;; to the section it was in
          ((and at-point-was-file-or-hunk-p
                (setq restore-pt
                      (let ((pos (point-min)))
                        (while (and pos (not (eq (second at-point)
                                                 (get-text-property pos :section))))
                          (setq pos (next-single-property-change pos :section)))
                        pos)))
           (goto-char restore-pt))
          ;; Should not happen (somehow file section had disappeared)
          (t ;; (when at-point
           ;;   (warn "Unable to find section %S that file %s was in"
           ;;         (second at-point)
           ;;         (first at-point)))
           (if (setq restore-pt (or restore-before-pt restore-after-pt))
               (goto-char restore-pt)
             (goto-char (point-min)))))))

(defun egg-unmerged-file-del-action (pos)
  (interactive "d")
  (let* ((status (or (get-text-property pos :unmerged) (get-text-property pos :merged)))
         (file (and status (car status))))
    (unless (or (memq :we-deleted status) (memq :they-deleted status) (memq :both-deleted status))
      (error "don't know how to handle status %S" status))
    (if (y-or-n-p (format "delete file %s?" file))
        (egg-status-buffer-handle-result (egg--git-rm-cmd (current-buffer) file))
      (if (y-or-n-p (format "keep file %s alive?" file))
          (egg-status-buffer-handle-result (egg--git-add-cmd (current-buffer) file))
        (message "deleted file %s is still unmerged!" file)))))

(defun egg-unmerged-file-add-action (pos)
  (interactive "d")
  (let* ((status (or (get-text-property pos :unmerged) (get-text-property pos :merged)))
         (file (and status (car status))))
    (unless (or (memq :we-added status) (memq :they-added status) (memq :both-added status))
      (error "don't know how to handle status %S" status))
    (if (y-or-n-p (format "add file %s?" file))
        (egg-status-buffer-handle-result (egg--git-add-cmd (current-buffer) file))
      (if (y-or-n-p (format "delete file %s" file))
          (egg-status-buffer-handle-result (egg--git-rm-cmd (current-buffer) file))
        (message "added file %s is still unmerged!" file)))))

(defun egg-unmerged-file-checkout-action (pos)
  (interactive "d")
  (let* ((status (get-text-property pos :merged))
         (file (and status (car status))))
    (unless (memq :unmerged status)
      (error "don't know how to handle status %S" status))
    (when (y-or-n-p (format "undo all merge results in %s? " file))
      (egg-status-buffer-handle-result (egg--git-co-files-cmd (current-buffer) file "-m")))))

(defun egg-unmerged-file-ediff-action (pos)
  (interactive "d")  
  (let* ((status (or (get-text-property pos :unmerged) (get-text-property pos :merged)))
         (file (and status (car status))))
    (unless (memq :unmerged status)
      (error "don't know how to handle status %S" status))
    (egg-resolve-merge-with-ediff file)))

(defun egg-unmerged-wdir-file-next-action (pos)
  (interactive "d")
  (let* ((status (get-text-property pos :unmerged))
         (file (and status (car status))))
    (unless (memq :unmerged status)
      (error "don't know how to handle status %S" status))
    (cond ((or (memq :we-added status) (memq :they-added status) (memq :both-added status))
           (egg-unmerged-file-add-action pos))
          ((or (memq :we-deleted status) (memq :they-deleted status) (memq :both-deleted status))
           (egg-unmerged-file-del-action pos))
          ((memq :both-modified status)
           (egg-unmerged-file-ediff-action pos))
          (t (message "don't know how to handle status %S" status)))))

(defun egg-unmerged-index-file-next-action (pos)
  (interactive "d")
  (let* ((status (get-text-property pos :merged))
         (file (and status (car status))))
    (unless (memq :unmerged status)
      (error "don't know how to handle status %S" status))
    (cond ((or (memq :we-deleted status) (memq :they-deleted status) (memq :both-deleted status))
           (egg-unmerged-file-del-action pos))
          ((memq :both-modified status)
           (egg-unmerged-file-ediff-action pos))
          (t (message "don't know how to handle status %S" status)))))

(defun egg-status-buffer-checkout-ref (&optional force name)
  "Prompt a revision to checkout. Default is name."
  (interactive (list current-prefix-arg (egg-ref-at-point)))
  (setq name (egg-read-local-ref "checkout (branch or tag): " name))
  (if force 
      (egg-status-buffer-do-co-rev name "-f")
    (egg-status-buffer-do-co-rev name)))

(defun egg-buffer-hide-all (&optional show-all)
  "Hide all sections in current special egg buffer."
  (interactive "P")
  (if show-all
      (setq buffer-invisibility-spec nil) ;; show all
    (let ((pos (point-min)) nav)
      (while (setq pos (next-single-property-change (1+ pos) :navigation))
        (setq nav (get-text-property pos :navigation))
        (add-to-invisibility-spec (cons nav t)))))
  (if (invoked-interactively-p)
      (force-window-update (current-buffer))))

(defsubst egg-buffer-show-all ()
  "UnHide all hidden sections in the current special egg buffer."
  (interactive)
  (setq buffer-invisibility-spec nil)
  (if (invoked-interactively-p)
      (force-window-update (current-buffer))))



(defsubst egg-buffer-hide-section-type (sect-type &optional beg end)
  "Hide sections of SECT-TYPE in current special egg buffer."
  (let ((pos (or beg (point-min)))
        (end (or end (point-max))) 
        nav)
    (while (and (setq pos (next-single-property-change (1+ pos) sect-type))
                (< pos end))
      (when (get-text-property pos sect-type)
        (setq nav (get-text-property pos :navigation))
        (add-to-invisibility-spec (cons nav t))))))

(defsubst egg-buffer-maybe-hide-all ()
  "If requested, hide all sections in current special egg buffer.
See `egg-buffer-hide-sub-blocks-on-start'."
  (let ((sect-type (cdr (assq major-mode
                              egg-buffer-hide-section-type-on-start))))
    (cond ((memq major-mode egg-buffer-hide-sub-blocks-on-start)
           (egg-buffer-hide-all))
          ((and sect-type (symbolp sect-type))
           (egg-buffer-hide-section-type sect-type)))))

(defsubst egg-buffer-maybe-hide-help (help-nav &optional top-nav)
  "If requested, hide the help section in the current special buffer.
See `egg-buffer-hide-help-on-start'."
  (if (memq major-mode egg-buffer-hide-help-on-start)
      (add-to-invisibility-spec
       (cons (if (symbolp help-nav) help-nav
               (egg-make-navigation top-nav help-nav))
             t))))



(defun egg-status-buffer-redisplay (buf &optional init)
  "(Re)Display the contents of the status buffer in BUF.
If INIT was not nil, then perform 1st-time initializations as well."
  (with-current-buffer buf
    (let ((inhibit-read-only t)
          (state (egg-repo-state))
          (win (get-buffer-window buf))
          pos)

      (set (make-local-variable 'egg-status-buffer-changed-files-status)
           (egg--get-status-code))
      ;; Emacs tries to be too smart, if we erase and re-fill the buffer
      ;; that is currently being displayed in the other window,
      ;; it remembers it, and no matter where we move the point, it will
      ;; force it to be at (point-min). Making a buffer selected
      ;; while we erase and re-fill it, seems to fix this behavour
      (save-selected-window
        (when win
          (select-window win t))
        (egg-save-section-visibility)
        (erase-buffer)
        (dolist (sect egg-status-buffer-sections)
          (cond ((eq sect 'repo) (egg-sb-insert-repo-section))
                ((eq sect 'unstaged) 
                 (setq pos (point))
                 (egg-sb-insert-unstaged-section 
                  (cond ((consp egg-status-buffer-interactive-stash-info) "To be Removed:")
                        ((egg-is-merging state) "Unmerged Changes:")
                        (t "Unstaged Changes:"))))
                ((eq sect 'staged) 
                 (egg-sb-insert-staged-section 
                  (cond ((consp egg-status-buffer-interactive-stash-info) "To be Stashed:")
                        ((egg-is-merging state) "Merged Changes:")
                        (t "Staged Changes:"))))
                ((eq sect 'untracked) (egg-sb-insert-untracked-section))
                ((eq sect 'stash) (egg-sb-insert-stash-section))))
        (egg-calculate-hunk-ranges)
        (if init
            (progn
              (egg-buffer-maybe-hide-all)
              (egg-buffer-maybe-hide-help "help" 'repo))
          (egg-restore-section-visibility))
        (goto-char pos)
        (goto-char (egg-previous-non-hidden (point)))
        ))))

(defun egg-internal-background (proc msg)
  "Background job sentinel."
  (let ((name (process-name proc)))
    (cond ((string= msg "finished\n")
           (message "EGG BACKGROUND: %s finished." name))
          ((string= msg "killed\n")
           (message "EGG BACKGROUND: %s was killed." name))
          ((string-match "exited abnormally" msg)
           (message "EGG BACKGROUND: %s failed." name))
          (t (message "EGG BACKGROUND: %s is weird!" name)))))

(defun egg-internal-background-refresh-index (buffer-name)
  (let ((buffer (get-buffer buffer-name))
        proc)
    (when (and buffer (buffer-live-p buffer))
      (with-current-buffer buffer
        (setq proc (start-process (format "refresh index in %s"
                                          default-directory)
                                  nil
                                  egg-git-command "update-index"
                                  "-q" "--really-refresh" "--unmerged"))
        (set-process-sentinel proc #'egg-internal-background)))))

(defvar egg-internal-status-buffer-names-list nil)
(defvar egg-internal-background-jobs-timer nil)

(defun egg-internal-background-jobs-restart ()
  (cancel-function-timers #'egg-status-buffer-background-job)
  (setq egg-internal-background-jobs-timer
        (run-with-idle-timer egg-background-idle-period t
                             #'egg-status-buffer-background-job)))

(defun egg-set-background-idle-period (var val)
  (custom-set-default var val)
  (egg-internal-background-jobs-restart))

(defcustom egg-background-idle-period 30
  "How long emacs has been idle before we trigger background jobs."
  :group 'egg
  :set #'egg-set-background-idle-period
  :type 'integer)


(defun egg-status-buffer-background-job ()
  (when egg-refresh-index-in-backround
    (mapcar #'egg-internal-background-refresh-index
            egg-internal-status-buffer-names-list)))

(egg-internal-background-jobs-restart)

(define-egg-buffer status "*%s-status@%s*"
  "Major mode to display the egg status buffer."
  (kill-all-local-variables)
  (setq buffer-read-only t)
  (setq major-mode 'egg-status-buffer-mode
        mode-name  "Egg-Status"
        mode-line-process ""
        truncate-lines t)
  (use-local-map egg-status-buffer-mode-map)
  (set (make-local-variable 'egg-buffer-refresh-func)
       'egg-status-buffer-redisplay)
  (setq buffer-invisibility-spec nil)
  (add-to-list 'egg-internal-status-buffer-names-list (buffer-name))
  (run-mode-hooks 'egg-status-buffer-mode-hook))


;;; I'm here
(defun egg-status-make-section-menu (&optional name)
  (let ((map (make-sparse-keymap name)))
    (define-key map [f-stage] (list 'menu-item "Stage File"
                                    'egg-diff-section-cmd-stage
                                    :visible '(egg-diff-at-point)
                                    :enable '(egg-point-in-section 'unstaged)))

    (define-key map [f-unstage] (list 'menu-item "Unstage File"
                                      'egg-diff-section-cmd-unstage
                                      :visible '(egg-diff-at-point)
                                      :enable '(egg-point-in-section 'staged)))

    (define-key map [f-undo] (list 'menu-item "Undo File's Modifications"
                                   'egg-diff-section-cmd-undo
                                   :visible '(egg-diff-at-point)
                                   :enable '(egg-point-in-section 'unstaged)))

    (define-key map [h-stage] (list 'menu-item "Stage Hunk"
                                    'egg-hunk-section-cmd-stage
                                    :visible '(egg-hunk-at-point)
                                    :enable '(egg-point-in-section 'unstaged)))

    (define-key map [h-unstage] (list 'menu-item "Unstage Hunk"
                                      'egg-hunk-section-cmd-unstage
                                      :visible '(egg-hunk-at-point)
                                      :enable '(egg-point-in-section 'staged)))

    (define-key map [h-undo] (list 'menu-item "Undo Hunk"
                                   'egg-hunk-section-cmd-undo
                                   :visible '(egg-hunk-at-point)
                                   :enable '(egg-point-in-section 'unstaged)))

    (define-key map [sp9] '("--"))
    (define-key map [prev] (list 'menu-item "Goto Prev Block"
                                 'egg-buffer-cmd-navigate-prev
                                 :enable '(egg-navigation-at-point)))
    (define-key map [next] (list 'menu-item "Goto Next Block"
                                 'egg-buffer-cmd-navigate-next
                                 :enable '(egg-navigation-at-point)))
    (define-key map [hs] (list 'menu-item "Hide/Show Current Block"
                               'egg-section-cmd-toggle-hide-show
                               :enable '(egg-navigation-at-point)))
    (define-key map [hs-sub] (list 'menu-item "Hide/Show SubBlocks"
                                   'egg-section-cmd-toggle-hide-show-children
                                   :enable '(egg-navigation-at-point)))
    (define-key map [sp8] '("--"))
    (define-key map [goto-file] (list 'menu-item "Open File"
                                      'egg-diff-section-cmd-visit-file-other-window
                                      :visble '(and (egg-diff-at-point) 
                                                    (not (egg-hunk-at-point)))))
    (define-key map [goto-line] (list 'menu-item "Locate Line"
                                      'egg-hunk-section-cmd-visit-file-other-window
                                      :visible '(egg-hunk-at-point)))
    (define-key map [ediff] (list 'menu-item "Ediff: WorkDir vs INDEX"
                                  'egg-unstaged-section-cmd-ediff
                                  :visible '(egg-diff-at-point)
                                  :enable '(egg-point-in-section 'unstaged)))
    (define-key map [ediff3] (list 'menu-item "Ediff3: WorkDir vs INDEX vs HEAD"
                                   'egg-staged-section-cmd-ediff3
                                   :visible '(egg-diff-at-point)
                                   :enable '(egg-point-in-section 'staged)))
    map))

(defconst egg-status-buffer-unstaged-diff-menu (egg-status-make-section-menu "Unstaged Delta"))
(defconst egg-status-buffer-unstaged-hunk-menu (egg-status-make-section-menu "Unstaged Hunk"))
(defconst egg-status-buffer-staged-diff-menu (egg-status-make-section-menu "Staged Delta"))
(defconst egg-status-buffer-staged-hunk-menu (egg-status-make-section-menu "Staged Hunk"))
(defconst egg-status-buffer-mode-delta-menu (egg-status-make-section-menu))

(defun egg-status-popup-delta-menu (event menu)
  (let* ((keys (progn
                 (force-mode-line-update)
                 (x-popup-menu event menu)))
         (cmd (and keys (lookup-key menu (apply 'vector keys)))))
    (when (and cmd (commandp cmd))
      (call-interactively cmd))))

(defun egg-status-popup-unstaged-diff-menu (event)
  (interactive "e")
  (egg-status-popup-delta-menu event egg-status-buffer-unstaged-diff-menu))

(defun egg-status-popup-staged-diff-menu (event)
  (interactive "e")
  (egg-status-popup-delta-menu event egg-status-buffer-staged-diff-menu))

(defun egg-status-popup-unstaged-hunk-menu (event)
  (interactive "e")
  (egg-status-popup-delta-menu event egg-status-buffer-unstaged-hunk-menu))

(defun egg-status-popup-staged-hunk-menu (event)
  (interactive "e")
  (egg-status-popup-delta-menu event egg-status-buffer-staged-hunk-menu))


(defconst egg-status-buffer-menu (make-sparse-keymap "Egg (Git)"))

(define-key egg-status-buffer-mode-map
  [menu-bar egg-status-buffer-mode] (cons "Egg (Git)" egg-status-buffer-menu))

(let ((menu egg-status-buffer-menu))
  (define-key menu [quit] '(menu-item "Close Status View" egg-quit-buffer))
  (define-key menu [refresh] '(menu-item "Refresh Status View" egg-buffer-cmd-refresh))
  (define-key menu [log] '(menu-item "Show Branch History" egg-log))
  (define-key menu [sp3] '("--"))
  (define-key menu [rb-skip] '(menu-item "Skip Rebase Session's Current Commit"
                                         egg-buffer-selective-rebase-skip
                                         :enable (egg-rebase-in-progress)))
  (define-key menu [rb-abort] '(menu-item "Abort Rebase Session"
                                          egg-buffer-rebase-abort
                                          :enable (egg-rebase-in-progress)))
  (define-key menu [rb-cont] '(menu-item "Resume Rebase Session"
                                         egg-buffer-selective-rebase-continue
                                         :enable (egg-rebase-in-progress)))
  (define-key menu [sp2] '("--"))
  (define-key menu [delta] (list 'menu-item "Delta"
                                 egg-status-buffer-mode-delta-menu
                                 :enable '(egg-diff-at-point)))
  (define-key menu [commit] '(menu-item "Commit Staged Changes"
                                        egg-commit-log-edit))
  (define-key menu [stage] '(menu-item "Stage All Modifications"
                                       egg-stage-all-files
                                       :enable (egg-wdir-dirty)))
  (define-key menu [unstage] '(menu-item "UnStage All Staged Modifications"
                                         egg-unstage-all-files
                                         :enable (egg-staged-changes)))
  (define-key menu [stage-untracked] '(menu-item "Stage All Untracked Files"
                                                 egg-stage-untracked-files))
  (define-key menu [sp1] '("--"))
  (define-key menu [hide-all] '(menu-item "Hide All" egg-buffer-hide-all))
  (define-key menu [show-all] '(menu-item "Show All" egg-buffer-show-all))
  (define-key menu [hs] '(menu-item "Hide/Show Block"
                                    egg-section-cmd-toggle-hide-show
                                    :enable (egg-navigation-at-point)))
  (define-key menu [hs-sub] '(menu-item "Hide/Show SubBlocks"
                                        egg-section-cmd-toggle-hide-show-children
                                        :enable (egg-navigation-at-point)))
  (define-key menu [prev] '(menu-item "Goto Previous Block" egg-buffer-cmd-navigate-prev
                                      :enable (egg-navigation-at-point)))
  (define-key menu [next] '(menu-item "Goto Next Block" egg-buffer-cmd-navigate-next
                                      :enable (egg-navigation-at-point))))

(defvar egg-switch-to-buffer nil
  "Set to nonnil for egg-status to switch to the status buffer in the same window.")


(defun egg-status (called-interactively select &optional caller)
  "Show the status of the current repo."
  (interactive "p\nP")
  (let* ((egg-internal-current-state
          (egg-repo-state (if (invoked-interactively-p) :error-if-not-git)))
         (buf (egg-get-status-buffer 'create))
         (select (if called-interactively ;; only do this for commands
                     (if egg-cmd-select-special-buffer 
                         (not select)	;; select by default (select=nil), C-u not select
                       select)		;; not select by default (select=nil), C-u select
                   select)))
    (with-current-buffer buf
      (egg-status-buffer-redisplay buf 'init))
    (cond ((eq caller :sentinel) (pop-to-buffer buf))
          (select (pop-to-buffer buf))
          (egg-switch-to-buffer (switch-to-buffer buf))
          (called-interactively (display-buffer buf))
          (t (display-buffer buf)))))

;;;========================================================
;;; log message
;;;========================================================

(require 'derived)
(require 'ring)

(defvar egg-log-msg-ring (make-ring 32))
(defvar egg-log-msg-ring-idx nil)

(defvar egg-log-msg-closure nil 
  "Closure for be called when done composing a message.
It must be a local variable in the msg buffer. It's a list
in the form (func arg1 arg2 arg3...).

func should be a function expecting the following args:
PREFIX-LEVEL the prefix argument converted to a number.
BEG a marker for the beginning of the composed text.
END a marker for the end of the composed text.
NEXT-BEG is a marker for the beginnning the next section.
ARG1 ARG2 ARG3... are the items composing the closure
when the buffer was created.")

(defsubst egg-log-msg-func () (car egg-log-msg-closure))
(defsubst egg-log-msg-args () (cdr egg-log-msg-closure))
(defsubst egg-log-msg-prefix () (nth 0 (egg-log-msg-args)))
(defsubst egg-log-msg-gpg-uid () (nth 1 (egg-log-msg-args)))
(defsubst egg-log-msg-text-beg () (nth 2 (egg-log-msg-args)))
(defsubst egg-log-msg-text-end () (nth 3 (egg-log-msg-args)))
(defsubst egg-log-msg-next-beg () (nth 4 (egg-log-msg-args)))
(defsubst egg-log-msg-extras () (nthcdr 5 (egg-log-msg-args)))
(defsubst egg-log-msg-set-prefix (prefix) (setcar (egg-log-msg-args) prefix))
(defsubst egg-log-msg-set-gpg-uid (uid) (setcar (cdr (egg-log-msg-args)) uid))
(defsubst egg-log-msg-mk-closure-input (func &rest args)
  (cons func args))
(defsubst egg-log-msg-mk-closure-from-input (input gpg-uid prefix beg end next)
  (cons (car input) (nconc (list prefix gpg-uid beg end next) (cdr input))))
(defsubst egg-log-msg-apply-closure (prefix) 
  (egg-log-msg-set-prefix prefix)
  (apply (egg-log-msg-func) (egg-log-msg-args)))


(define-derived-mode egg-log-msg-mode text-mode "Egg-LogMsg"
  "Major mode for editing Git log message.\n\n
\{egg-log-msg-mode-map}."
  (setq default-directory (egg-work-tree-dir))
  (set (make-local-variable 'egg-log-msg-closure) nil)
  (set (make-local-variable 'egg-log-msg-ring-idx) nil))

(define-key egg-log-msg-mode-map (kbd "C-c C-c") 'egg-log-msg-done)
(define-key egg-log-msg-mode-map (kbd "C-c C-k") 'egg-log-msg-cancel)
(define-key egg-log-msg-mode-map (kbd "C-c C-s") 'egg-log-msg-buffer-toggle-signed)
(define-key egg-log-msg-mode-map (kbd "M-p") 'egg-log-msg-older-text)
(define-key egg-log-msg-mode-map (kbd "M-n") 'egg-log-msg-newer-text)
(define-key egg-log-msg-mode-map (kbd "C-l") 'egg-buffer-cmd-refresh)

(defsubst egg-log-msg-commit (prefix gpg-uid text-beg text-end &rest ignored)
  "Commit the index using the text between TEXT-BEG and TEXT-END as message.
PREFIX and IGNORED are ignored."
  (egg-cleanup-n-commit-msg (if gpg-uid
                                #'egg--async-create-signed-commit-cmd
                              #'egg--git-commit-with-region-cmd)
                            text-beg text-end gpg-uid))

(defsubst egg-log-msg-amend-commit (prefix gpg-uid text-beg text-end &rest ignored)
  "Amend the last commit with the index using the text between TEXT-BEG and TEXT-END
as message. PREFIX and IGNORED are ignored."
  (egg-cleanup-n-commit-msg (if gpg-uid
                                #'egg--async-create-signed-commit-cmd
                              #'egg--git-commit-with-region-cmd)
                            text-beg text-end gpg-uid "--amend"))

(defun egg-log-msg-buffer-toggle-signed ()
  "Toggle the to-be-gpg-signed state of the message being composed."
  (interactive)
  (let* ((gpg-uid (egg-log-msg-gpg-uid))
         (new-uid (if gpg-uid 
                      "None"
                    (read-string "Sign with gpg key uid: " (egg-user-name))))
         (inhibit-read-only t))
    (egg-log-msg-set-gpg-uid (if gpg-uid nil new-uid))
    (save-excursion
      (save-match-data
        (goto-char (point-min))
        (re-search-forward "^GPG-Signed by: \\(.+\\)$" (egg-log-msg-text-beg))
        (replace-match (egg-text new-uid 'egg-text-2) nil t nil 1)
        (set-buffer-modified-p nil)))))

(defun egg-log-msg-done (level)
  "Take action with the composed message.
This usually means calling the lambda returned from (egg-log-msg-func)
with the appropriate arguments."
  (interactive "p")
  (widen)
  (let* ((text-beg (egg-log-msg-text-beg))
         (text-end (egg-log-msg-text-end))
         (diff-beg (egg-log-msg-next-beg)))
    (goto-char text-beg)
    (if (save-excursion (re-search-forward "\\sw\\|\\-" text-end t))
        (when (functionp (egg-log-msg-func))
          (ring-insert egg-log-msg-ring
                       (buffer-substring-no-properties text-beg text-end))
          (save-excursion (egg-log-msg-apply-closure level))
          (let ((inhibit-read-only t)
                (win (get-buffer-window (current-buffer))))
            (erase-buffer)
            (kill-buffer)))
      (message "Please enter a log message!")
      (ding))))

(defun egg-log-msg-cancel ()
  "Cancel the current message editing."
  (interactive)
  (kill-buffer))

(defun egg-log-msg-hist-cycle (&optional forward)
  "Cycle through message log history."
  (let* ((len (ring-length egg-log-msg-ring))
         (text-beg (egg-log-msg-text-beg))
         (text-end (egg-log-msg-text-end)))
    (cond ((<= len 0)
           ;; no history
           (message "No previous log message.")
           (ding))
          ;; don't accidentally throw away unsaved text
          ((and  (null egg-log-msg-ring-idx)
                 (> text-end text-beg)
                 (not (y-or-n-p "throw away current text? "))))
          ;; do it
          (t (delete-region text-beg text-end)
             (setq egg-log-msg-ring-idx
                   (if (null egg-log-msg-ring-idx)
                       (if forward
                           ;; 1st-time + fwd = oldest
                           (ring-minus1 0 len)
                         ;; 1st-time + bwd = newest
                         0)
                     (if forward
                         ;; newer
                         (ring-minus1 egg-log-msg-ring-idx len)
                       ;; older
                       (ring-plus1 egg-log-msg-ring-idx len))))
             (goto-char text-beg)
             (insert (ring-ref egg-log-msg-ring egg-log-msg-ring-idx))))))

(defun egg-log-msg-older-text ()
  "Cycle backward through comment history."
  (interactive)
  (egg-log-msg-hist-cycle))

(defun egg-log-msg-newer-text ()
  "Cycle forward through comment history."
  (interactive)
  (egg-log-msg-hist-cycle t))

(defun egg-commit-log-buffer-show-diffs (buf &optional init diff-beg)
  "Show the diff sections in the commit buffer.
See `egg-commit-buffer-sections'"
  (with-current-buffer buf
    (let* ((inhibit-read-only t)
           (diff-beg (or diff-beg (egg-log-msg-next-beg)))
           beg)
      (egg-save-section-visibility)
      (goto-char diff-beg)
      (delete-region (point) (point-max))
      (setq beg (point))

      (dolist (sect egg-commit-buffer-sections)
        (cond ((eq sect 'staged)
               (egg-sb-insert-staged-section "Changes to Commit:" "--stat"))
              ((eq sect 'unstaged)
               (egg-sb-insert-unstaged-section "Deferred Changes:"))
              ((eq sect 'untracked)
               (egg-sb-insert-untracked-section))))
      (egg-calculate-hunk-ranges)
      (put-text-property beg (point) 'read-only t)
      (put-text-property beg (point) 'front-sticky nil)
      (if init (egg-buffer-maybe-hide-all))
      (egg-restore-section-visibility)
      (force-window-update buf))))

(define-egg-buffer commit "*%s-commit@%s*"
  (egg-log-msg-mode)
  (setq major-mode 'egg-commit-buffer-mode
        mode-name "Egg-Commit"
        mode-line-process ""
        truncate-lines t)
  (set (make-local-variable 'egg-buffer-refresh-func)
       'egg-commit-log-buffer-show-diffs)
  (setq buffer-invisibility-spec nil)
  (run-mode-hooks 'egg-commit-buffer-mode-hook))

(defun egg-commit-log-edit (title-function
                            action-closure
                            insert-init-text-function &optional amend-no-msg)
  "Open the commit buffer for composing a message.
With C-u prefix, the message will be use to amend the last commit.
With C-u C-u prefix, just amend the last commit with the old message.
For non interactive use:
TITLE-FUNCTION is either a string describing the text to compose or
a function return a string for the same purpose.
ACTION-CLOSURE is the input to build `egg-log-msg-closure'. It should
be the results of `egg-log-msg-mk-closure-from-input'.
INSERT-INIT-TEXT-FUNCTION is either a string or function returning a string
describing the initial text in the editing area.
if AMEND-NO-MSG is non-nil, the do nothing but amending the last commit
using git's default msg."
  (interactive (let ((prefix (prefix-numeric-value current-prefix-arg)))
                 (cond ((> prefix 15)	;; C-u C-u
                        ;; only set amend-no-msg
                        (list nil nil nil t))
                       ((> prefix 3)	;; C-u
                        (list (concat
                               (egg-text "Amending  " 'egg-text-3)
                               (egg-text (egg-pretty-head-name) 'egg-branch))
                              (egg-log-msg-mk-closure-input #'egg-log-msg-amend-commit)
                              (egg-commit-message "HEAD")))
                       (t 		;; regular commit
                        (list (concat
                               (egg-text "Committing into  " 'egg-text-3)
                               (egg-text (egg-pretty-head-name) 'egg-branch))
                              (egg-log-msg-mk-closure-input #'egg-log-msg-commit)
                              nil)))))
  (if amend-no-msg
      (egg-buffer-do-amend-no-edit)
    (let* ((git-dir (egg-git-dir))
           (default-directory (egg-work-tree-dir git-dir))
           (buf (egg-get-commit-buffer 'create))
           (state (egg-repo-state :name :email))
           (head-info (egg-head))
           (head (or (cdr head-info)
                     (format "Detached HEAD! (%s)" (car head-info))))
           (inhibit-read-only inhibit-read-only)
           text-beg text-end diff-beg)
      (with-current-buffer buf
        (setq inhibit-read-only t)
        (erase-buffer)

        (insert (cond ((functionp title-function)
                       (funcall title-function state))
                      ((stringp title-function) title-function)
                      (t "Shit happens!"))
                "\n"
                (egg-text "Repository: " 'egg-text-1) 
                (egg-text git-dir 'font-lock-constant-face) "\n"
                (egg-text "Committer: " 'egg-text-1) 
                (egg-text (plist-get state :name) 'egg-text-2) " "
                (egg-text (concat "<" (plist-get state :email) ">") 'egg-text-2) "\n"
                (egg-text "GPG-Signed by: " 'egg-text-1)
                (egg-text "None" 'egg-text-2) "\n"
                (egg-text "-- Commit Message (type `C-c C-c` when done or `C-c C-k` to cancel) -"
                          'font-lock-comment-face))
        (put-text-property (point-min) (point) 'read-only t)
        (put-text-property (point-min) (point) 'rear-sticky nil)
        (insert "\n")

        (setq text-beg (point-marker))
        (set-marker-insertion-type text-beg nil)
        (put-text-property (1- text-beg) text-beg :navigation 'commit-log-text)
        
        (insert (egg-prop "\n------------------------ End of Commit Message ------------------------"
                          'read-only t 'front-sticky nil
                          'face 'font-lock-comment-face))
        
        (setq diff-beg (point-marker))
        (set-marker-insertion-type diff-beg nil)
        (egg-commit-log-buffer-show-diffs buf 'init diff-beg)

        (goto-char text-beg)
        (cond ((functionp insert-init-text-function)
               (funcall insert-init-text-function))
              ((stringp insert-init-text-function)
               (insert insert-init-text-function)))

        (setq text-end (point-marker))
        (set-marker-insertion-type text-end t)

        (set (make-local-variable 'egg-log-msg-closure)
             (egg-log-msg-mk-closure-from-input action-closure 
                                                nil nil text-beg text-end diff-beg)))
      (pop-to-buffer buf))))

;;;========================================================
;;; action
;;;========================================================

(defun egg-revert-visited-files (file-or-files)
  "Revert the buffers of FILE-OR-FILES.
FILE-OR-FILES can be a string or a list of strings.
Each string should be a file name relative to the work tree."
  (let* ((git-dir (egg-git-dir))
         (default-directory (egg-work-tree-dir git-dir))
         (files (if (listp file-or-files)
                    file-or-files
                  (list file-or-files))))
    (mapcar (lambda (file)
              (let ((buf (get-file-buffer file)))
                (when (bufferp buf)
                  (with-current-buffer buf
                    (when (equal (egg-git-dir) git-dir)
                      (revert-buffer t t t))))))
            files)))

(defun egg-revert-all-visited-files ()
  (let* ((git-dir (egg-git-dir))
         (default-directory (egg-work-tree-dir git-dir))
         bufs files)
    (setq files
          (delq nil (mapcar (lambda (buf)
                              (with-current-buffer buf
                                (when (and (buffer-file-name buf)
                                           (equal (egg-git-dir) git-dir))
                                  (buffer-file-name buf))))
                            (buffer-list))))
    (when (consp files)
      (setq files (mapcar 'expand-file-name
                          (apply 'egg-git-to-lines "ls-files" files)))
      (when (consp files)
        (egg-revert-visited-files files)))))

(defun egg-hunk-section-apply-cmd (pos &rest args)
  "Apply using git apply with ARGS as arguments.
The patch (input to git apply) will be built based on the hunk enclosing
POS."
  (let ((patch (egg-hunk-section-patch-string pos (member "--reverse" args)))
        (file (car (get-text-property pos :diff)))
        res)
    (unless (stringp file)
      (error "No diff with file-name here!"))
    (setq res (egg--git-apply-cmd t patch args))
    (unless (member "--cached" args)
      (egg-revert-visited-files (plist-get res :files)))
    (plist-get res :success)))

(defun egg-show-applied-hunk-in-buffer (buf before after
                                            hunk-text b-ranges a-ranges
                                            question yes no)
  (let ((inhibit-read-only t)
        (before-1st-line (nth 0 before))
        (before-num-lines (nth 1 before))
        (before-text (nth 2 before))
        (after-text (nth 2 after))
        beg end bg answer)
    (with-current-buffer buf
      (goto-char (point-min))
      (forward-line (1- before-1st-line))
      (setq beg (point))
      (setq end (save-excursion (forward-line before-num-lines) (point)))
      (delete-region beg end)
      (goto-char beg)
      (insert hunk-text)
      (setq end (point))
      
      (dolist (range b-ranges)
        (setq bg (make-overlay (+ (car range) beg) (+ (cdr range) beg) nil nil t))
        (overlay-put bg 'face 'egg-del-bg)
        (overlay-put bg 'evaporate t))

      (dolist (range a-ranges)
        (setq bg (make-overlay (+ (car range) beg) (+ (cdr range) beg) nil nil t))
        (overlay-put bg 'face 'egg-add-bg)
        (overlay-put bg 'evaporate t)))

    (with-selected-window (display-buffer buf t)
      (goto-char beg)
      (recenter)
      (setq answer (y-or-n-p question))
      (bury-buffer buf))

    (with-current-buffer buf
      (goto-char beg)
      (delete-region beg end)
      (if answer
          (cond ((eq yes :cleanup)
                 (set-buffer-modified-p nil))
                ((eq yes :kill)
                 (kill-buffer buf))
                ((eq yes :save)
                 (insert after-text)
                 (basic-save-buffer))
                (t nil))
        (cond ((eq no :cleanup)
               (set-buffer-modified-p nil))
              ((eq no :kill)
               (kill-buffer buf))
              ((eq no :restore)
               (insert before-text)
               (set-buffer-modified-p nil))
              (t nil)))
      answer)))

(defun egg-hunk-section-show-n-ask-staging (pos)
  (let* ((hunk (egg-hunk-info-at pos))
         (info (egg-hunk-compute-replacement-text hunk))
         (file (car info))
         (index (nth 1 info))
         (worktree (nth 2 info))
         (hunk-ranges-n-text (nth 3 info))
         (hunk-text (nth 2 hunk-ranges-n-text))
         (index-ranges (nth 0 hunk-ranges-n-text))
         (worktree-ranges (nth 1 hunk-ranges-n-text))
         (buf (egg-file-get-other-version file ":0" nil t)))
    (if (egg-show-applied-hunk-in-buffer buf index worktree
                                         hunk-text index-ranges worktree-ranges
                                         (format "update Index's %s as shown? " file)
                                         :kill :kill)
        t
      (message "Cancel staging %s's hunk %s" file (nth 1 hunk))
      nil)))

(defun egg-hunk-section-show-n-ask-unstaging (pos)
  (let* ((hunk (egg-hunk-info-at pos))
         (info (egg-hunk-compute-replacement-text hunk))
         (file (car info))
         (head (nth 1 info))
         (index (nth 2 info))
         (hunk-ranges-n-text (nth 3 info))
         (hunk-text (nth 2 hunk-ranges-n-text))
         (head-ranges (nth 0 hunk-ranges-n-text))
         (index-ranges (nth 1 hunk-ranges-n-text))
         (buf (egg-file-get-other-version file ":0" nil t)))
    (if (egg-show-applied-hunk-in-buffer buf index head
                                         hunk-text index-ranges head-ranges
                                         (format "restore Index's %s as shown? " file)
                                         :kill :kill)
        t
      (message "Cancel unstaging %s's hunk %s" file (nth 1 hunk))
      nil)))

(defun egg-sb-relocate-hunk (hunk-info)
  (let* ((file (nth 0 hunk-info))
         (ranges (nth 4 hunk-info))
         (before-type (nth 0 ranges))
         (type (cond ((eq before-type 'staged) 'unstaged)
                     ((eq before-type 'unstaged) 'staged)
                     (t before-type)))
         (range (nth 3 ranges))
         (pos (point-min))
         hunk found)
    (while (and (not found)
                (setq pos (next-single-property-change (1+ pos) :hunk)))
      (when (and (setq hunk (egg-hunk-info-at pos))
                 (equal (car hunk) file)
                 (equal (car (nth 4 hunk)) type)
                 (equal (nth 3 (nth 4 hunk)) range))
        (setq found pos)))
    (unless (or found (eq type before-type))
      (setq type before-type)
      (setq pos (point-min))
      (while (and (not found)
                  (setq pos (next-single-property-change (1+ pos) :hunk)))
        (when (and (setq hunk (egg-hunk-info-at pos))
                   (equal (car hunk) file)
                   (equal (car (nth 4 hunk)) type)
                   (equal (nth 3 (nth 4 hunk)) range))
          (setq found pos))))
    (when found
      (goto-char found))))


(defmacro with-current-hunk (pos &rest body)
  "remember the hunk at POS, eval BODY then relocate the moved hunk."
  (declare (indent 1) (debug t))
  (let ((hunk-info (make-symbol "hunk-info")))
    `(let ((,hunk-info (egg-hunk-info-at ,pos)))
       ,@body
       (egg-sb-relocate-hunk ,hunk-info))))

(defun egg-hunk-section-cmd-stage (pos)
  "Add the hunk enclosing POS to the index."
  (interactive "d")
  (when (or (not egg-confirm-staging) 
            (egg-hunk-section-show-n-ask-staging pos))
    (with-current-hunk pos
      (egg-hunk-section-apply-cmd pos "--cached"))))

(defun egg-hunk-section-cmd-unstage (pos)
  "Remove the hunk enclosing POS from the index."
  (interactive "d")
  (when (or (not egg-confirm-staging) 
            (egg-hunk-section-show-n-ask-unstaging pos))
    (with-current-hunk pos
      (egg-hunk-section-apply-cmd pos "--cached" "--reverse"))))


(defun egg-hunk-section-show-n-undo (pos)
  (let* ((hunk (egg-hunk-info-at pos))
         (info (egg-hunk-compute-replacement-text hunk))
         (file (car info))
         (new (nth 2 info))
         (old (nth 1 info))
         (hunk-ranges-n-text (nth 3 info))
         (buf (find-file-noselect file)) bg res)
    (if (egg-show-applied-hunk-in-buffer buf new old
                                         (nth 2 hunk-ranges-n-text)
                                         (nth 1 hunk-ranges-n-text)
                                         (nth 0 hunk-ranges-n-text)
                                         (format "restore %s's text as shown? " file)
                                         :save :restore)
        (egg-refresh-buffer (current-buffer))
      (message "Cancel undo %s's hunk %s!" file (nth 1 hunk)))))


(defun egg-sb-relocate-diff-file (diff-info)
  (let ((file (car diff-info))
        (marker (nth 1 diff-info))
        (pos (point-min))
        diff found)
    (while (and (not found)
                (setq pos (next-single-property-change (1+ pos) :diff)))
      (when (and (setq diff (get-text-property pos :diff))
                 (equal (car diff) file))
        (setq found (nth 1 diff))))
    (when found
      (goto-char found))))

(defmacro with-current-diff (pos &rest body)
  "remember the diff at POS, eval BODY then relocate the moved diff."
  (declare (indent 1) (debug t))
  (let ((diff-info (make-symbol "diff-info")))
    `(let ((,diff-info (get-text-property ,pos :diff)))
       ,@body
       (egg-sb-relocate-diff-file ,diff-info))))

(defun egg-hunk-section-cmd-undo (pos)
  "Remove the file's modification described by the hunk enclosing POS."
  (interactive "d")
  (cond ((null egg-confirm-undo)
         (egg-hunk-section-apply-cmd pos "-p1" "--reverse"))
        ((or (eq egg-confirm-undo 'prompt)
             ;; only status buffer can do "show-n-undo"
             ;; fallback to prompt
             (not (eq major-mode 'egg-status-buffer-mode)))
         (if (y-or-n-p "irreversibly remove the hunk under cursor? ")
             (egg-hunk-section-apply-cmd pos "-p1" "--reverse")
           (message "Too chicken to proceed with undo operation!")))
        ((eq egg-confirm-undo 'show)
         (egg-hunk-section-show-n-undo pos))))

(defun egg-diff-section-cmd-stage (pos)
  "Update the index with the file at POS.
If the file was delete in the workdir then remove it from the index."
  (interactive "d")
  (let ((file (car (get-text-property pos :diff))))
    (cond ((not (stringp file))
           (error "No diff with file-name here!"))
          ((file-exists-p file)
           ;; add file to index, nothing change in wdir
           ;; diff and status buffers must be updated
           ;; just update them all
           (with-current-diff pos
             (egg--git-add-cmd t "-v" file)))
          (t ;; file is deleted, update the index
           (egg--git-rm-cmd t file)))))

(defun egg-diff-section-cmd-unstage (pos)
  "For the file at POS, revert its stage in the index to original.
If the file was a newly created file, it will be removed from the index.
If the file was added after a merge resolution, it will reverted back to
conflicted state. Otherwise, its stage will be reset to HEAD."
  (interactive "d")
  (let ((is-merging (egg-is-merging (egg-repo-state)))
        (diff-info (get-text-property pos :diff))
        file newfile)
    (setq newfile (memq 'newfile diff-info)
          file (car diff-info))
    (cond (newfile (egg--git-rm-cmd t "--cached" file))
          (is-merging (with-current-diff pos
                        (egg--git-co-files-cmd t file "-m")))
          (t (with-current-diff pos
               (egg--git-reset-files-cmd t nil file))))))

(defun egg-diff-section-cmd-undo (pos)
  "For the file at POS, remove its differences vs the source revision.
Usually, this command revert the file to its staged state in the index. However,
in a diff special egg buffer, it can change the file's contents to the one of
the source revision."
  (interactive "d")
  (unless (or (not egg-confirm-undo)
              (y-or-n-p "irreversibly remove the delta under cursor? "))
    (error "Too chicken to proceed with undo operation!"))

  (let ((file (car (or (get-text-property pos :diff)
                       (error "No diff with file-name here!"))))
        (src-rev (get-text-property pos :src-revision)))
    
    (egg-revert-visited-files 
     (plist-get (cond ((stringp src-rev)
                       (egg--git-co-files-cmd t file src-rev))
                      ((consp src-rev)
                       (egg--git-co-files-cmd 
                        t file (egg-git-to-string "merge-base" 
                                                  (car src-rev) (cdr src-rev))))
                      (t (egg--git-co-files-cmd t file)))
                :files))))

(defun egg-diff-section-cmd-revert-to-head (pos)
  "Revert the file and its slot in the index to its state in HEAD."
  (interactive "d")
  (let ((file (car (or (get-text-property pos :diff)
                       (error "No diff with file-name here!")))))
    (unless (or (not egg-confirm-undo)
                (y-or-n-p (format "irreversibly revert %s to HEAD? " file)))
      (error "Too chicken to proceed with reset operation!"))
    (egg-revert-visited-files 
     (plist-get (egg--git-co-files-cmd t file "HEAD") :files))))

(defun egg-file-stage-current-file ()
  "Add the current's file contents into the index."
  (interactive)
  (let* ((short-file (file-name-nondirectory (buffer-file-name)))
         (egg--do-no-output-message (format "staged %s's modifications" short-file)))
    (egg-file-buffer-handle-result (egg--git-add-cmd (egg-get-status-buffer) "-v" 
                                                     (buffer-file-name)))))

(defun egg-stage-all-files ()
  "Stage all tracked files in the repository."
  (interactive)
  (let ((default-directory (egg-work-tree-dir))
        (egg--do-no-output-message "staged all tracked files's modifications"))
    (egg-file-buffer-handle-result (egg--git-add-cmd (egg-get-status-buffer) "-v" "-u"))))

(defsubst egg-log-buffer-do-move-head (reset-mode rev)
  (egg-buffer-do-move-head reset-mode rev 'log))

(defsubst egg-status-buffer-do-move-head (reset-mode rev)
  (egg-buffer-do-move-head reset-mode rev 'status))

(defun egg-unstage-all-files ()
  "Unstage all files in the index."
  (interactive)
  (let ((default-directory (egg-work-tree-dir)))
    (when (egg-status-buffer-do-move-head "--mixed" "HEAD")
      (message "unstaged all modfications in INDEX"))))

(defun egg-sb-undo-wdir-back-to-index (really-do-it take-next-action ignored-action)
  "When in the status buffer, reset the work-tree to the state in the index.
When called interactively, do nothing unless REALLY-DO-IT is non-nil.
Take the next logical action if TAKE-NEXT-ACTION is non-nil unless the
next action is IGNORED-ACTION."
  (interactive (list (or current-prefix-arg
                         (y-or-n-p "throw away all unstaged modifications? "))
                     t nil))
  (when really-do-it
    (let ((default-directory (egg-work-tree-dir))
          (egg--do-no-output-message "reverted work-dir to INDEX"))
      (egg-status-buffer-do-co-rev :0 "-f" "-a"))))

(defun egg-sb-undo-wdir-back-to-HEAD (really-do-it take-next-action ignored-action)
  "When in the status buffer, reset the work-tree and the index to HEAD.
When called interactively, do nothing unless REALLY-DO-IT is non-nil.
Take the next logical action if TAKE-NEXT-ACTION is non-nil unless the
next action is IGNORED-ACTION."
  (interactive (list (y-or-n-p "throw away all (staged and unstaged) modifications? ")))
  (when really-do-it
    (let ((default-directory (egg-work-tree-dir)))
      (egg-status-buffer-do-move-head "--hard" "HEAD"))))

(defun egg-status-buffer-undo-wdir (harder)
  "When in the status buffer, throw away local modifications in the work-tree.
if HARDER is non-nil (prefixed with C-u), reset the work-tree to its state
in HEAD. Otherwise, reset the work-tree to its staged state in the index."
  (interactive "P")
  (funcall (if harder
               #'egg-sb-undo-wdir-back-to-HEAD
             #'egg-sb-undo-wdir-back-to-index) 
           (y-or-n-p (format "throw away ALL %s modifications? " 
                             (if harder "(staged AND unstaged)" "unstaged")))
           t 'status))

(defun egg-stage-untracked-files ()
  "Add all untracked files to the index."
  (interactive)
  (let ((default-directory (egg-work-tree-dir))
        (egg--do-git-quiet t))
    (when (egg--git-add-cmd t "-v" ".")
      (message "staged all untracked files"))))

(defun egg-buffer-do-move-head (reset-mode rev &optional ignored-action)
  "Move (reset) HEAD to REV using RESET-MODE.
REV should be a valid git rev (branch, tag, commit,...)
RESET-MODE should be a valid reset option such as --hard.
The command usually takes the next action recommended by the results, but
if the next action is IGNORED-ACTION then it won't be taken."
  (let* ((egg--do-no-output-message 
          (format "detached %s and re-attached on %s" 
                  (egg-branch-or-HEAD) rev))
         (res (egg--git-reset-cmd t reset-mode rev)))
    (egg--buffer-handle-result res t ignored-action)
    (plist-get res :success)))

(defun egg-buffer-do-merge-to-head (rev &optional merge-mode-flag msg ignored-action)
  "Merge REV to HEAD.
REV should be a valid git rev (branch, tag, commit,...)
MERGE-MODE should be a valid reset option such as --ff-only.
MSG will be used for the merge commit.
Thecommand  usually take the next action recommended by the results, but
if the next action is IGNORED-ACTION then it won't be taken."
  (let ((msg (or msg (concat "merging in " rev)))
        merge-cmd-ok res modified-files options
        need-commit force-commit-to-status line fix-line-func)

    (setq modified-files (egg-git-to-lines "diff" "--name-only" rev))
    (cond ((equal merge-mode-flag "--commit")
           (setq options egg-git-merge-strategy-options)
           (setq need-commit t)
           (setq merge-mode-flag "--no-commit")
           (setq fix-line-func
                 (lambda (merge-res)
                   (let (line)
                     (when (and (plist-get merge-res :success)
                                (setq line (plist-get merge-res :line)))
                       (save-match-data
                         (when (string-match "stopped before committing as requested" line)
                           (setq line 
                                 "Auto-merge went well, please prepare the merge message")
                           (plist-put merge-res :line line)))))
                   merge-res)))
          ((member merge-mode-flag '("--no-commit" "--squash"))
           (setq options egg-git-merge-strategy-options)
           (setq force-commit-to-status t)))

    (setq res (nconc (egg--git-merge-cmd-args 'all fix-line-func
                                              (append (cons merge-mode-flag options)
                                                      (list "--log" rev)))
                     (list :files modified-files)))
    (if need-commit
        (egg--buffer-handle-result-with-commit
         res (list (concat (egg-text "Merge in:  " 'egg-text-3)
                           (egg-text rev 'egg-branch))
                   (egg-log-msg-mk-closure-input #'egg-log-msg-commit)
                   msg)
         t ignored-action)
      (when (and (eq (plist-get res :next-action) 'commit)
                 force-commit-to-status)
        (plist-put res :next-action 'status))
      (egg--buffer-handle-result res t ignored-action))))

(defsubst egg-log-buffer-do-merge-to-head (rev &optional merge-mode-flag)
  "Merge REV to HEAD when the log special buffer.
see `egg-buffer-do-merge-to-head'."
  (egg-buffer-do-merge-to-head rev merge-mode-flag nil 'log))

(defun egg-do-rebase-head (upstream-or-action &optional onto current-action)
  "Rebase HEAD based on UPSTREAM-OR-ACTION.
If UPSTREAM-OR-ACTION is a string then it used as upstream for the rebase operation.
If ONTO is non-nil, then rebase HEAD onto ONTO using UPSTREAM-OR-ACTION as upstream.
If UPSTREAM-OR-ACTION is one of: :abort, :skip and :continue then
perform the indicated rebase action."
  (let ((pre-merge (egg-get-current-sha1))
        cmd-res modified-files feed-back old-choices)
    (with-egg-debug-buffer

      (unless (eq upstream-or-action :abort) ;; keep for debugging
        (erase-buffer))
      
      (setq cmd-res
            (cond ((and (stringp onto) (stringp upstream-or-action))
                   (egg--git-rebase-merge-cmd-args 
                    t nil (append egg-git-merge-strategy-options
                                  (list "-m" "--onto" onto upstream-or-action))))
                  ((eq upstream-or-action :abort)
                   (egg--git-rebase-merge-cmd t nil "--abort"))
                  ((eq upstream-or-action :skip)
                   (egg--git-rebase-merge-cmd t nil "--skip"))
                  ((eq upstream-or-action :continue)
                   (egg--git-rebase-merge-cmd t nil "--continue"))
                  ((stringp upstream-or-action)
                   (egg--git-rebase-merge-cmd-args
                    t nil (append egg-git-merge-strategy-options
                                  (list "-m" upstream-or-action))))))
      (setq modified-files (egg-git-to-lines "diff" "--name-only" pre-merge))
      (when (consp cmd-res) (plist-put cmd-res :files modified-files))
      (egg--buffer-handle-result cmd-res t current-action))))

;;;========================================================
;;; diff-mode
;;;========================================================
(defconst egg-diff-buffer-mode-map
  (let ((map (make-sparse-keymap "Egg:DiffBuffer")))
    (set-keymap-parent map egg-buffer-mode-map)
    (define-key map "G"       'egg-diff-buffer-run-command)
    (define-key map "s"       'egg-status)
    (define-key map "l"       'egg-log)
    (define-key map "/"       'egg-search-changes)
    (define-key map "C-c C-/" 'egg-search-changes-all)
    map)
  "\\{egg-diff-buffer-mode-map}")

(defun egg-diff-buffer-run-command ()
  "Re-run the command that create the buffer."
  (interactive)
  (call-interactively (or (plist-get egg-diff-buffer-info :command)
                          #'egg-buffer-cmd-refresh)))

(defun egg-buffer-ask-pickaxe-mode (pickaxe-action search-code &optional default-term)
  (let* ((key-type-alist '((?s "string" identity)
                           (?r "posix regex" (lambda (s) (list s :regexp)))
                           (?l "line matching regex" (lambda (s) (list s :line)))))
         (search-info (assq search-code key-type-alist))
         (search-type (nth 1 search-info))
         (make-term-func (nth 2 search-info))
         key term)
    (while (not (stringp search-type))
      (setq key (read-key-sequence 
                 (format "match type to %s: (s)tring, (r)egex, (l)line or (q)uit? "
                         pickaxe-action)))
      (setq key (string-to-char key))
      (setq search-info (assq key key-type-alist))
      (when (= key ?q) (error "%s: aborted" pickaxe-action))
      (setq search-type (nth 1 search-info))
      (setq make-term-func (nth 2 search-info))
      (setq search-code key)
      (unless (consp search-info)
        (message "invalid choice: %c! (must be of of s,r,l or q)" key)
        (ding)
        (sit-for 1)))
    (setq term (read-string 
                (format "%s with changes containing %s: " pickaxe-action search-type)
                default-term))    
    (unless (> (length term) 1)
      (error "Cannot match %s: %s!!" (nth 1 key) term))
    (setq term (funcall make-term-func term))
    (when (and (memq search-code '(?r ?l))
               (y-or-n-p "ignore case when matching regexp? "))
      (setq term (append term (list :ignore-case))))
    term))

(defun egg-buffer-prompt-pickaxe (pickaxe-action default-search default-term
                                                 &optional ask-mode ask-regexp ask-term)
  "Prompt for pickaxe.
SEARCH-SCOPE is a string such as \"diffs\" or \"history\"
DEFAULT-SEARCH-CODE is used asking the term and is one of: :string,:regexp or :line
DEFAULT-TERM is used a the initial value when reading user's input.
If ASK-MODE is non-nil then ask for the mode (string, regexp or line) then ask for the term.
Else if ASK-REGEXP is non-nil then ask for a regexp (the term).
Else if ASK-TERM is non-nil then ask for the term using DEFAULT-SEARCH as search type."
  (cond (ask-mode
         (egg-buffer-ask-pickaxe-mode pickaxe-action nil default-term))
        (ask-regexp
         (egg-buffer-ask-pickaxe-mode pickaxe-action ?r default-term))
        (ask-term
         (egg-buffer-ask-pickaxe-mode pickaxe-action (assoc-default default-search
                                                                    '((:string . ?s)
                                                                      (:regexp . ?r)
                                                                      (:line   . ?l)))
                                      default-term))
        (t nil)))

(defsubst egg-pickaxe-to-args (pickaxe)
  (cond ((stringp pickaxe) (list "-S" pickaxe))
        ((and (consp pickaxe) (memq :line pickaxe))
         (nconc (list "-G" (car pickaxe))
                (if (memq :ignore-case pickaxe) (list "--regexp-ignore-case"))))
        ((and (consp pickaxe) (memq :regexp pickaxe))
         (nconc (list "-S" (car pickaxe) "--pickaxe-regex")
                (if (memq :ignore-case pickaxe) (list "--regexp-ignore-case"))))
        (t nil)))

(defsubst egg-pickaxe-term (pickaxe)
  (if (stringp pickaxe) pickaxe (car pickaxe)))

(defsubst egg-pickaxe-highlight (pickaxe)
  (if (stringp pickaxe) 
      (regexp-quote pickaxe)
    (egg-unquote-posix-regexp (car pickaxe))))

(defsubst egg-pickaxe-pick-item (pickaxe string-item regexp-item line-item)
  (cond ((stringp pickaxe) string-item)
        ((and (consp pickaxe) (memq :line pickaxe)) line-item)
        ((and (consp pickaxe) (memq :regexp pickaxe)) regexp-item)
        (t nil)))

(defun egg-buffer-highlight-pickaxe (highlight-regexp beg end &optional is-cc-diff)
  (when (stringp highlight-regexp)
    (when (eq (aref highlight-regexp 0) ?^)
      (setq highlight-regexp
            (concat "^" (make-string (if is-cc-diff 2 1) ?.)
                    (substring highlight-regexp 1))))
    (goto-char beg)
    (while (re-search-forward highlight-regexp end t)
      (unless (or (not (get-text-property (match-beginning 0) :hunk))
                  (if is-cc-diff 
                      (string-equal (buffer-substring-no-properties 
                                     (line-beginning-position) 
                                     (+ (line-beginning-position) 2))
                                    "  ")
                    (eq (char-after (line-beginning-position)) ? ))
                  (eq (char-after (line-beginning-position)) ?@))
        (put-text-property (match-beginning 0) (match-end 0) 'face 'highlight)))))

(defun egg-diff-buffer-insert-diffs (buffer)
  "Insert contents from `egg-diff-buffer-info' into BUFFER.
egg-diff-buffer-info is built using `egg-build-diff-info'."
  (with-current-buffer buffer
    (let ((args (plist-get egg-diff-buffer-info :args))
          (title (plist-get egg-diff-buffer-info :title))
          (prologue (plist-get egg-diff-buffer-info :prologue))
          (src-prefix (plist-get egg-diff-buffer-info :src))
          (dst-prefix (plist-get egg-diff-buffer-info :dst))
          (help (plist-get egg-diff-buffer-info :help))
          (pickaxe (plist-get egg-diff-buffer-info :pickaxe))
          
          (inhibit-read-only t)
          pickaxe-term highlight-regexp is-cc-diff
          pos beg end inv-beg help-beg help-end help-inv-beg cmd-ok)

      (setq highlight-regexp (and pickaxe (egg-pickaxe-highlight pickaxe)))
      (setq pickaxe-term (and pickaxe (egg-pickaxe-term pickaxe)))

      (erase-buffer)
      (insert (egg-text title 'egg-section-title) "\n")
      (insert prologue "\n")
      (setq inv-beg (1- (point)))
      (when help
        (insert "\n")
        (setq help-beg (point))
        (insert (egg-text "Help" 'egg-help-header-1) "\n")
        (setq help-inv-beg (1- (point)))
        (insert help)
        (setq help-end (point)))
      (setq pos (point))
      (setq beg (point))
      (egg-cmd-log "RUN: git diff" (mapconcat #'identity args " ") "\n")
      (setq cmd-ok (egg-git-ok-args t (cons "diff" args)))
      (egg-cmd-log (format "RET:%s\n" cmd-ok))
      (setq end (point))
      (unless (> end beg)
        (if pickaxe
            (insert (egg-text "No difference containing: " 'egg-text-4)
                    (egg-text pickaxe-term 'egg-text-4)
                    (egg-text "!\n" 'egg-text-4))
          (insert (egg-text "No difference!\n" 'egg-text-4))))
      (egg-delimit-section :section 'file (point-min) (point) inv-beg
                           egg-section-map 'file)
      (egg-delimit-section :help 'help help-beg help-end help-inv-beg
                           egg-section-map 'egg-compute-navigation)
      (apply 'egg-decorate-diff-section
             ;; :begin (point-min)
             :begin beg
             :end end
             :src-prefix src-prefix
             :dst-prefix dst-prefix
             egg-diff-buffer-info)
      (egg-buffer-highlight-pickaxe highlight-regexp beg end
                                    (save-excursion
                                      (goto-char beg)
                                      (save-match-data
                                        (re-search-forward "^@@@" end t))))
      (goto-char pos))))

(define-egg-buffer diff "*%s-diff@%s*"
  "Major mode to display the git diff output."
  (kill-all-local-variables)
  (setq buffer-read-only t)
  (setq major-mode 'egg-diff-buffer-mode
        mode-name  "Egg-Diff"
        mode-line-process ""
        truncate-lines t)
  (use-local-map egg-diff-buffer-mode-map)
  (set (make-local-variable 'egg-buffer-refresh-func)
       'egg-diff-buffer-insert-diffs)
  (setq buffer-invisibility-spec nil)
  (run-mode-hooks 'egg-diff-buffer-mode-hook))



(defun egg-diff-info-add-help (info)
  (let ((map (plist-get info :diff-map)) help)
    (setq help
          (concat egg-diff-buffer-common-help-text
                  egg-diff-buffer-diff-help-heading
                  (cond ((eq map egg-unstaged-diff-section-map)
                         egg-unstaged-diff-help-text)
                        ((eq map egg-staged-diff-section-map)
                         egg-staged-diff-help-text)
                        ((eq map egg-diff-section-map)
                         egg-plain-diff-help-text)
                        ((eq map egg-wdir-diff-section-map)
                         egg-wdir-diff-help-text))))
    (plist-put info :help help)))

(defun egg-do-diff (diff-info)
  "Build the diff buffer based on DIFF-INFO and return the buffer."
  (let* ((default-directory (egg-work-tree-dir))
         (buf (egg-get-diff-buffer 'create)))
    (with-current-buffer buf
      (set (make-local-variable 'egg-diff-buffer-info) diff-info)
      (egg-diff-buffer-insert-diffs buf))
    buf))


(defun egg-re-do-diff (file-name pickaxe only-dst-path)
  (let* ((dst (egg-read-rev "Compare rev: " (plist-get egg-diff-buffer-info :dst-revision)))
         (old-src (plist-get egg-diff-buffer-info :src-revision))
         (src (egg-read-rev (format "Compare %s vs %s: " dst 
                                    (if only-dst-path "upstream" "base revision"))
                            (if (consp old-src) (car old-src) old-src)))
         (command (plist-get egg-diff-buffer-info :command))
         (info (egg-build-diff-info src dst file-name pickaxe only-dst-path)))
    (when command
      (plist-put info :command command))
    (egg-do-diff info)))

(defun egg-build-diff-info (src dst &optional file pickaxe only-dst-path)
  "Build the data for the diff buffer.
This data is based on the delta between SRC and DST. The delta is restricted
to FILE if FILE is non-nil. SRC and DST should be valid git revisions.
if DST is nil then use work-dir as destination. if SRC and DST are both
nil then compare the index and the work-dir."
  (let ((dir (egg-work-tree-dir))
        (search-string (if pickaxe (format "Search for %s " 
                                           (if (stringp pickaxe) pickaxe (car pickaxe)))
                         ""))
        info tmp options)

    (setq options 
          (append '("--no-color" "-p")
                  (copy-sequence
                   (if (stringp file)
                       (assoc-default (assoc-default file auto-mode-alist #'string-match)
                                      egg-git-diff-file-options-alist #'eq
                                      egg-git-diff-options)
                     egg-git-diff-options))))
    
    (setq info
          (cond ((and (null src) (null dst))
                 (list :args (nconc options (list "--src-prefix=INDEX/"
                                                  "--dst-prefix=WORKDIR/"))
                       :title (format "%sfrom INDEX to %s" search-string dir)
                       :prologue "hunks can be removed or added into INDEX."
                       :src "INDEX/" :dst "WORKDIR/"
                       :diff-map egg-unstaged-diff-section-map
                       :hunk-map egg-unstaged-hunk-section-map))
                ((and (equal src "HEAD") (equal dst "INDEX"))
                 (list :args (nconc options (list "--cached"
                                                  "--src-prefix=INDEX/"
                                                  "--dst-prefix=WORKDIR/"))
                       :title (format "%sfrom HEAD to INDEX" search-string)
                       :prologue "hunks can be removed from INDEX."
                       :src "HEAD/" :dst "INDEX/"
                       :diff-map egg-staged-diff-section-map
                       :hunk-map egg-staged-hunk-section-map))
                ((and (stringp src) (stringp dst))
                 (list :args (nconc options (list (concat src 
                                                          (if only-dst-path "..." "..") 
                                                          dst)))
                       :title (format "%sfrom %s to %s" search-string 
                                      (if only-dst-path (concat dst "@" src) src)
                                      dst)
                       :prologue (format "a: %s\nb: %s" 
                                         (if only-dst-path (concat dst "@" src) src) 
                                         dst)
                       :src-revision (if only-dst-path (cons src dst) src)
                       :dst-revision dst
                       :diff-map egg-diff-section-map
                       :hunk-map egg-hunk-section-map))
                ((and (stringp src) (null dst))
                 (list :args (nconc options (list src))
                       :title (format "%sfrom %s to %s" search-string src dir)
                       :prologue (concat (format "a: %s\nb: %s\n" src dir)
                                         "hunks can be removed???")
                       :src-revision src
                       :diff-map egg-wdir-diff-section-map
                       :hunk-map egg-wdir-hunk-section-map))))
    (if (memq :diff egg-show-key-help-in-buffers)
        (egg-diff-info-add-help info))
    (if (stringp file)
        (progn
          (plist-put info :file file)
          (setq file (list file)))
      (setq tmp (plist-get info :args))
      (setq tmp (cons "-M" tmp))
      (plist-put info :args tmp))
    (when pickaxe
      (plist-put info :pickaxe pickaxe)
      (plist-put info :highlight (egg-pickaxe-highlight pickaxe))
      (plist-put info :args
                 (append (egg-pickaxe-to-args pickaxe) (plist-get info :args))))
    (when (consp file)
      (setq tmp (plist-get info :prologue))
      (setq tmp (concat (egg-text (mapconcat 'identity file "\n")
                                  'egg-text-3)
                        "\n"
                        (egg-text tmp 'egg-text-1)))
      (plist-put info :prologue tmp)
      (setq tmp (plist-get info :args))
      (setq tmp (append tmp (cons "--" file)))
      (plist-put info :args tmp))
    info))

(defun egg-diff-ref (&optional default do-pickaxe)
  "Prompt a revision to compare against worktree."
  (interactive (list (egg-ref-at-point) (prefix-numeric-value current-prefix-arg)))
  (let* ((src (egg-read-rev "compare work tree vs revision: " default))
         (diff-info (egg-build-diff-info src nil nil
                                         (egg-buffer-prompt-pickaxe "restrict diffs" 
                                                                    :string nil
                                                                    (> do-pickaxe 15)
                                                                    nil
                                                                    (> do-pickaxe 3))))
         (buf (progn (plist-put diff-info :command 'egg-diff-ref)
                     (egg-do-diff diff-info))))
    (pop-to-buffer buf)))

(defun egg-diff-upstream (ref &optional prefix)
  "Prompt compare upstream to REF."
  (interactive (list (if current-prefix-arg
                         (egg-read-local-ref "ref to compare: " (egg-branch-or-HEAD))
                       (egg-branch-or-HEAD))
                     (prefix-numeric-value current-prefix-arg)))
  (let* ((branch-upstream (egg-upstream ref))
         (upstream (egg-read-ref (format "upstream of %s: " ref) branch-upstream))
         (diff-info (egg-build-diff-info upstream ref nil 
                                         (egg-buffer-prompt-pickaxe "restrict diffs"
                                                                    :string nil
                                                                    (> prefix 63)
                                                                    nil
                                                                    (> prefix 15)) 
                                         t))
         (buf (progn (plist-put diff-info :command 'egg-diff-upstream)
                     (egg-do-diff diff-info))))
    (pop-to-buffer buf)))

(defun egg-buffer-pop-to-file (file sha1 &optional other-win use-wdir-file line)
  "Put the contents of FILE from SHA1 to a buffer and show it.
show the buffer in the other window if OTHER-WIN is not nil.
Use the the contents from the work-tree if USE-WDIR-FILE is not nil.
Jump to line LINE if it's not nil."
  (funcall (if other-win #'pop-to-buffer #'switch-to-buffer)
           (if (or (equal (egg-current-sha1) sha1)
                   use-wdir-file)
               (progn
                 (message "file:%s dir:%s" file default-directory)
                 (find-file-noselect file))
             (egg-file-get-other-version file (if (= (aref sha1 0) ?:)
                                                  sha1 ;; index
                                                (egg-short-sha1 sha1)) 
                                         nil t)))
  (when (numberp line)
    (goto-char (point-min))
    (forward-line (1- line))))

;;;========================================================
;;; log browsing
;;;========================================================
(defun egg-log-buffer-get-commit-pos (commit &optional beg end)
  (let* ((sha1 (egg-sha1 commit))
         (beg (or beg (point-min)))
         (end (or end (point-max)))
         (pos beg))
    (while (and pos (not (equal (get-text-property pos :commit) sha1)))
      (setq pos (next-single-property-change pos :commit nil end))
      (unless (< pos end)
        (setq pos nil)))
    pos))

(defvar egg-log-buffer-comment-column nil)
(defvar egg-internal-log-buffer-closure nil)




(defun egg-log-show-ref (pos)
  "Show information about ref at POS."
  (interactive "d")
  (let* ((ref-info (get-text-property pos :ref))
         (reflog (unless ref-info (get-text-property pos :reflog)))
         (ref-type (and (cdr ref-info)))
         (mark-pos (if (get-text-property pos :mark)
                       pos
                     (if (get-text-property (1- pos) :mark) (1- pos))))
         (mark (and mark-pos (get-text-property mark-pos :mark)))
         (append-to (and mark-pos (get-text-property mark-pos :append-to)))
         (followed-by (and mark-pos (get-text-property mark-pos :followed-by)))
         (reflog-time (and reflog (get-text-property pos :time)))
         into is-squashed)
    (if (or ref-info mark)
        (cond ((eq ref-type :head) (egg-show-branch (car ref-info)))
              ((eq ref-type :tag) (egg-show-atag (car ref-info)))
              ((eq ref-type :remote) (egg-show-remote-branch (car ref-info)))
              ((eq mark (egg-log-buffer-base-mark)) (message "BASE mark"))
              (mark
               (setq is-squashed 
                     (memq mark (list (egg-log-buffer-squash-mark) (egg-log-buffer-fixup-mark)))
                     into (if is-squashed "into" "right after"))
               (setq append-to (and append-to (egg-pretty-short-rev append-to)))
               (setq followed-by (and followed-by (egg-pretty-short-rev followed-by)))
               (message "marked to be %s%s in the upcoming interactive rebase"
                        (cond ((eq mark (egg-log-buffer-pick-mark)) "picked")
                              ((eq mark (egg-log-buffer-edit-mark)) "edited")
                              ((eq mark (egg-log-buffer-squash-mark)) "squashed")
                              ((eq mark (egg-log-buffer-fixup-mark)) "absorbed")
                              (t (error "unknown mark: %s" mark)))
                        (cond ((and append-to followed-by)
                               (format " %s %s and to be followed by %s" 
                                       into append-to followed-by))
                              (append-to (format " %s %s" into append-to))
                              (followed-by (format " and followed by %s" followed-by))
                              (t ""))))
              (t nil))
      (when reflog
        (setq reflog (substring-no-properties reflog))
        (setq reflog-time (substring-no-properties reflog-time))
        (put-text-property 0 (length reflog) 'face 'bold reflog)
        (put-text-property 0 (length reflog-time) 'face 'bold reflog-time)
        (message "reflog:%s created:%s" reflog reflog-time)))))


(defun egg-log-buffer-style-command ()
  "Re-run the command that create the buffer."
  (interactive)
  (call-interactively (or (plist-get egg-internal-log-buffer-closure :command)
                          #'egg-buffer-cmd-refresh)))

(defun egg-log-style-buffer-mode (mode name &optional map hook)
  (kill-all-local-variables)
  (setq buffer-read-only t)
  (setq major-mode mode
        mode-name name
        mode-line-process ""
        truncate-lines t)
  (use-local-map (or map egg-log-style-buffer-map))
  (set (make-local-variable 'egg-buffer-refresh-func)
       'egg-log-buffer-simple-redisplay)
  (set (make-local-variable 'egg-log-buffer-comment-column) 0)
  (set (make-local-variable 'egg-internal-log-buffer-closure) nil)

  (setq buffer-invisibility-spec nil)
  (run-mode-hooks (or hook 'egg-log-style-buffer-hook)))

(defconst egg-log-style-help-text
  (concat
   (egg-text "Common Key Bindings:" 'egg-help-header-2) "\n"
   (egg-pretty-help-text
    "\\<egg-log-style-buffer-map>"
    "\\[egg-log-buffer-next-ref]:next thing  "
    "\\[egg-log-buffer-prev-ref]:previous thing  "
    "\\[egg-status]:show repo's status  "
    "\\[egg-log]:show repo's history  "
    "\\[egg-buffer-cmd-refresh]:redisplay  "
    "\\[egg-quit-buffer]:quit\n" )
   (egg-text "Extra Key Bindings for a Commit line:" 'egg-help-header-2) "\n"
   (egg-pretty-help-text
    "\\<egg-secondary-log-commit-map>"
    "\\[egg-log-locate-commit]:locate commit in history  "
    "\\[egg-log-buffer-insert-commit]:load details  "
    "\\[egg-section-cmd-toggle-hide-show]:hide/show details  "
    "\\[egg-section-cmd-toggle-hide-show-children]:hide sub-blocks\n"
    "\\[egg-log-buffer-anchor-head]:anchor HEAD  "
    "\\[egg-log-buffer-checkout-commit]:checkout  "
    "\\[egg-log-buffer-tag-commit]:new tag  "
    "\\[egg-log-buffer-atag-commit]:new annotated tag\n"
    )
   (egg-text "Extra Key Bindings for a Diff Block:" 'egg-help-header-2) "\n"
   (egg-pretty-help-text
    "\\<egg-log-diff-map>"
    "\\[egg-log-diff-cmd-visit-file-other-window]:visit version/line\n")
   ))

(defun egg--log-parse-decoration-refs (dec-ref-start dec-ref-end repo-refs-prop-alist
                                                     pseudo-refs-list &rest extras-properties)
  (let ((pos dec-ref-start)
        ref-full-name ref
        short-ref-list decorated-refs 
        full-ref-list 
        ref-string)
    (when (and dec-ref-start (> dec-ref-start 0))
      (goto-char pos)
      (while (> (skip-chars-forward "^ ,:" dec-ref-end) 0)
        (setq ref-full-name (buffer-substring-no-properties pos (point)))
        (when (looking-at " *-> *\\|, *\\|: *\\| +")
          (goto-char (match-end 0)))
        (setq pos (point))
        (unless (or 
                 ;; (equal ref-full-name "HEAD") 
                 (equal ref-full-name "tag")
                 (and (> (length ref-full-name) 5)
                      (equal (substring ref-full-name -5) "/HEAD")))
          (setq ref (assoc-default ref-full-name repo-refs-prop-alist))
          (when ref
            (add-to-list 'decorated-refs ref)
            (add-to-list 'full-ref-list ref-full-name)
            (add-to-list 'short-ref-list (car (get-text-property 0 :ref ref)))))))

    (setq ref-string (mapconcat 'identity (append pseudo-refs-list decorated-refs) " "))
    (if (equal ref-string "")
        (setq ref-string nil)
      (add-text-properties 0 (length ref-string)
                           (nconc (if decorated-refs
                                      (list :references short-ref-list
                                            :full-references full-ref-list)) 
                                  extras-properties)
                           ref-string))
    
    ref-string))



(defun egg-decorate-log (&optional line-map head-map tag-map remote-map remote-site-map
                                   sha1-pseudo-refs-alist)
  "Decorate a log buffer.
LINE-MAP is used as local keymap for a commit line.
HEAD-MAP is used as local keymap for the name of a head.
TAG-MAP is used as local keymap for the name of a tag.
REMOTE-MAP is used as local keymap for the name of a remote head.
REMOTE-SITE-MAP is used as local keymap for the name of a remote site."
  (let ((start (point))
        (head-sha1 (egg-get-current-sha1))
        (dash-char (aref egg-log-graph-chars 2))
        (ov (make-overlay (point-min) (point-min) nil t))
        (graph-map (unless (equal egg-log-graph-chars "*|-/\\")
                     (let (lst)
                       (dotimes (i (length egg-log-graph-chars))
                         (push (cons (aref "*|-/\\" i) (aref egg-log-graph-chars i))
                               lst))
                       lst)))
        (dec-ref-alist
         (egg-full-ref-decorated-alist
          (list 'face 'egg-branch-mono 'keymap head-map 'help-echo (egg-tooltip-func))
          (list 'face 'egg-tag-mono 'keymap tag-map 'help-echo (egg-tooltip-func))
          (list 'face 'egg-an-tag-mono 'keymap tag-map 'help-echo (egg-tooltip-func))
          (list 'face 'egg-branch-mono 'keymap remote-map 'help-echo (egg-tooltip-func))
          (list 'face 'egg-remote-mono 'keymap remote-site-map 'help-echo (egg-tooltip-func))
          (list 'face 'egg-log-HEAD-name 'keymap head-map 'help-echo (egg-tooltip-func))
          (list 'face 'egg-reflog-mono 'keymap line-map 'help-echo (egg-tooltip-func))))
        (ref-string-len 0)
        (dashes-len 0)
        (min-dashes-len 300)
        separator ref-string sha1 pseudo-refs-list
        line-props graph-len beg end sha-beg sha-end subject-beg
        refs-start refs-end
        head-line)

    (dolist (sha1-pseudo-refs sha1-pseudo-refs-alist)
      (dolist (pseudo-ref (cdr sha1-pseudo-refs))
        (put-text-property 0 (length pseudo-ref) 'keymap line-map pseudo-ref)))

    (save-excursion
      (while (< (point) (point-max))
        (if (not (looking-at "^.*\\([0-9a-f]\\{40\\}\\) .+$"))
            (when graph-map
              (setq end (line-end-position))
              (egg-redraw-chars-in-region (line-beginning-position)
                                          (1- (line-end-position))
                                          graph-map))
          (setq sha-beg (match-beginning 1)
                sha-end (match-end 1)
                subject-beg (1+ sha-end)
                beg (line-beginning-position)
                end (match-end 0)
                refs-start nil)
          (setq graph-len (if (= beg sha-beg) 0 (- sha-beg beg 1))
                sha1 (buffer-substring-no-properties sha-beg sha-end)
                subject-beg (if (or (/= (char-after subject-beg) ?\()
                                    (and (not (member (buffer-substring-no-properties 
                                                       subject-beg (+ subject-beg 6))
                                                      '("(refs/" "(tag: " "(HEAD," "(HEAD)")))
                                         (not (member (buffer-substring-no-properties 
                                                       subject-beg (+ subject-beg 8))
                                                      '("(HEAD ->")))))
                                subject-beg
                              (setq refs-start (1+ subject-beg))
                              (goto-char subject-beg)
                              (skip-chars-forward "^)")
                              (setq refs-end (point))
                              (+ (point) 2)))

          (when (and graph-map graph-len)
            (egg-redraw-chars-in-region (line-beginning-position) (1- sha-beg) graph-map)
            (goto-char end))

          (setq pseudo-refs-list (assoc-default sha1 sha1-pseudo-refs-alist))
          
          (setq ref-string
                (egg--log-parse-decoration-refs refs-start refs-end dec-ref-alist 
                                                pseudo-refs-list 
                                                :navigation sha1 :commit sha1))
          ;; common line decorations
          (setq line-props (nconc (list :navigation sha1 :commit sha1)
                                  (if line-map (list 'keymap line-map))
                                  (if ref-string 
                                      (list :references
                                            (get-text-property 0 :references ref-string)))))
          

          ;; (when (and (not ref-string) pseudo-ref)
          ;;   (setq ref-string pseudo-ref)
          ;;   (add-text-properties 0 (length ref-string) line-props ref-string))

          (setq separator (apply 'propertize " " line-props))
          (setq ref-string-len (if ref-string (length ref-string)))

          ;; entire line
          (add-text-properties beg (1+ end) line-props)

          ;; comment
          (put-text-property subject-beg end 'face 'egg-text-2)
          ;; delete refs list (they're already parsed)
          (if refs-start
              (delete-region (1- refs-start) (+ refs-end 2)))

          ;; shorten sha
          (delete-region (+ sha-beg 8) sha-end)
          (put-text-property sha-beg (+ sha-beg 8)
                             'face 'font-lock-constant-face)
          (put-text-property sha-beg (+ sha-beg 8)
                             'help-echo (egg-tooltip-func))

          (setq dashes-len (- 300 graph-len 1
                              (if ref-string (1+ ref-string-len) 0)))
          (setq min-dashes-len (min min-dashes-len dashes-len))

          (put-text-property sha-beg (1+ sha-beg)
                             :dash-refs
                             (apply 'concat
                                    (apply 'propertize
                                           (make-string dashes-len dash-char)
                                           (nconc (list 'face 'egg-graph)
                                                  line-props))
                                    separator
                                    (if ref-string
                                        (list ref-string separator))))
;;; 	(when (string= sha1 head-sha1)
;;; 	  (overlay-put ov 'face 'egg-log-HEAD)
;;; 	  (overlay-put ov 'evaporate t)
;;; 	  (move-overlay ov beg (1+ (line-end-position))))
          (when (string= sha1 head-sha1)
            (setq head-line (point-marker))))
        (forward-line 1))

      (if (= min-dashes-len 300)
          (insert (egg-text "nothing found!" 'egg-warning))


        ;; compute how many dashes can be deleted while
        ;; leaving at least 1 dash
        (setq min-dashes-len (1- min-dashes-len))

        ;; before cut
        ;; type a: 300 = graph spc dashes
        ;; type b: 300 = graph spc dashes spc ref-string
        ;;
        ;; after cut
        ;; type a: 300 - min-dashes-len = graph spc dashes
        ;; type b: 300 - min-dashes-len = graph spc dashes spc ref-string
        ;;
        ;; a: comment-column = graph spc dashes spc sha1-8 spc
        ;; b: comment-column = graph spc dashes spc ref-string spc sha1-8 spc
        ;; need to remove the 1st spc if graph-len = 0
        (set (make-local-variable 'egg-log-buffer-comment-column)
             (+ (- 300 min-dashes-len (if (> graph-len 0) 0 1)) 1 8 1))

        (when (and (> min-dashes-len 0))
          (goto-char (1- start))
          (while (setq start (next-single-property-change (point)
                                                          :dash-refs))
            (goto-char start)
            (insert (substring (get-text-property start :dash-refs)
                               min-dashes-len))
            (forward-char 2)))

        ;; (when head-line
        ;;   (goto-char head-line)
        ;;   (overlay-put ov 'face 'egg-log-HEAD)
        ;;   (overlay-put ov 'evaporate t)
        ;;   (move-overlay ov (line-beginning-position)
        ;;                 (1+ (line-end-position))))

        head-line))))

(defun egg-insert-logs-with-decoration (ref git-log-extra-options paths
                                            keymap-plist sha1-pseudo-refs-alist)
  (let ((beg (point)))
    (egg-run-git-log ref git-log-extra-options paths)
    (unless (= (char-before (point-max)) ?\n)
      (goto-char (point-max))
      (insert ?\n))
    (goto-char beg)
    (egg-decorate-log (plist-get keymap-plist :line)
                      (plist-get keymap-plist :branch)
                      (plist-get keymap-plist :tag)
                      (plist-get keymap-plist :remote)
                      (plist-get keymap-plist :site)
                      sha1-pseudo-refs-alist)))

(defun egg-insert-logs-with-simple-decoration (ref &optional git-log-extra-options paths)
  (egg-insert-logs-with-decoration ref 
                                   (append '("--graph" "--topo-order") git-log-extra-options) 
                                   paths
                                   (list :line egg-secondary-log-commit-map
                                         :branch egg-secondary-log-commit-map
                                         :tag egg-secondary-log-commit-map
                                         :remote egg-secondary-log-commit-map
                                         :site egg-secondary-log-commit-map)
                                   nil))

(defun egg-insert-logs-with-full-decoration (ref &optional git-log-extra-options paths)
  (egg-insert-logs-with-decoration ref 
                                   (append '("--graph" "--topo-order") git-log-extra-options) 
                                   paths
                                   (if paths
                                       (list :line egg-file-log-commit-map
                                             :branch egg-file-log-commit-map
                                             :tag egg-file-log-commit-map
                                             :remote egg-file-log-commit-map
                                             :site egg-file-log-commit-map)
                                     (list :line egg-log-commit-map
                                           :branch egg-log-local-branch-map
                                           :tag egg-log-local-ref-map
                                           :remote egg-log-remote-branch-map
                                           :site egg-log-remote-site-map))
                                   nil))

(defalias 'egg-log-pop-to-file 'egg-buffer-pop-to-file)

(defsubst egg-log-diff-interactive ()
  (list (car (get-text-property (point) :diff))
        (or (get-text-property (point) :commit) 
            (get-text-property (point) :stash))
        current-prefix-arg))

(defsubst egg-log-hunk-interactive ()
  (nconc (list (or (get-text-property (point) :commit) (get-text-property (point) :stash))
               current-prefix-arg)
         (egg-hunk-info-at (point))))

(defun egg-log-diff-cmd-visit-file (file sha1 &optional use-wdir-file)
  "Open revision SHA1's FILE.
With C-u prefix, use the work-tree's version instead."
  (interactive (egg-log-diff-interactive))
  (egg-log-pop-to-file file sha1 nil use-wdir-file))

(defun egg-log-diff-cmd-visit-file-other-window (file sha1 &optional use-wdir-file)
  "Open revision SHA1's FILE in other window.
With C-u prefix, use the work-tree's version instead."
  (interactive (egg-log-diff-interactive))
  (egg-log-pop-to-file file sha1 t use-wdir-file))

(defun egg-log-hunk-cmd-visit-file (sha1 use-wdir-file file hunk-header hunk-beg &rest ignored)
  (interactive (egg-log-hunk-interactive))
  (egg-log-pop-to-file file sha1 nil use-wdir-file 
                       (egg-hunk-compute-line-no hunk-header hunk-beg)))

(defun egg-log-hunk-cmd-visit-file-other-window (sha1 use-wdir-file file hunk-header hunk-beg &rest ignored)
  (interactive (egg-log-hunk-interactive))
  (egg-log-pop-to-file file sha1 t use-wdir-file (egg-hunk-compute-line-no hunk-header hunk-beg)))

(defun egg-log-buffer-get-rev-at (pos &rest options)
  (let* ((commit (egg-commit-at-point pos))
         (refs (egg-references-at-point pos))
         (first-ref (if (stringp refs) refs (car (last refs))))
         (ref-at-point (egg-ref-at-point pos))
         (current-branch (egg-get-symbolic-HEAD))
         (head-sha1 (egg-get-current-sha1)))
    
    (when (stringp commit)
      (cond ((memq :sha1 options) (if (memq :short options)
                                      (substring commit 0 8)
                                    commit))
            ((stringp ref-at-point) ref-at-point)
            ((and (equal commit head-sha1) (stringp current-branch)) current-branch)
            ((and (equal commit head-sha1) (not (memq :no-HEAD options))) "HEAD")
            ((stringp first-ref) first-ref)
            ((memq :symbolic options) (egg-describe-rev commit))
            ((memq :short options)(substring commit 0 8))
            (t commit)))))

(defun egg-log-buffer-do-remove-mark (mark-char)
  (let ((pos (point-min))
        (inhibit-read-only t))
    (while (setq pos (next-single-property-change (1+ pos) :mark))
      (when (= (get-text-property pos :mark) mark-char)
        (remove-text-properties pos (1+ pos)
                                (list :mark nil 'display nil))))))

(defun egg-log-buffer-find-first-mark (mark-char)
  (let ((pos (point-min)))
    (while (and (setq pos (next-single-property-change (1+ pos) :mark))
                (/= (get-text-property pos :mark) mark-char)))
    pos))

(defun egg-log-buffer-do-mark (pos char &optional unmark remove-first &rest extra-properties)
  (let ((commit (get-text-property pos :commit))
        (inhibit-read-only t)
        (col (- egg-log-buffer-comment-column 10))
        (step (if unmark -1 (if remove-first 0 1)))
        leader follower-of-leader)
    (when commit
      (when remove-first
        (egg-log-buffer-do-remove-mark char))
      (goto-char pos)
      (move-to-column col)
      (setq leader (get-text-property (point) :append-to))
      (funcall (if unmark
                   #'remove-text-properties
                 #'add-text-properties)
               (point) (1+ (point))
               (nconc (list :mark char
                            'display
                            (and char
                                 (egg-text (char-to-string char)
                                           'egg-log-buffer-mark)))
                      extra-properties))
      (when leader
        (save-excursion
          (goto-char (egg-log-buffer-get-commit-pos leader))
          (move-to-column col)
          (setq follower-of-leader (get-text-property (point) :followed-by))
          (when (equal follower-of-leader commit)
            (put-text-property (point) (1+ (point)) :followed-by nil))))
      (forward-line step)
      (while (not (or (get-text-property (point) :commit)
                      (eobp) (bobp)))
        (forward-line step))
      (move-to-column col))))

(defun egg-log-buffer-mark (pos)
  "Mark commit at POS as the BASE commit."
  (interactive "d")
  (egg-log-buffer-do-mark pos (egg-log-buffer-base-mark) nil t))

(defun egg-log-buffer-do-mark-append (pos mark prompt-fmt error-fmt &optional exclusive)
  (let* ((commit (egg-commit-at-point pos))
         (pretty (egg-pretty-short-rev commit))
         (parent (car (egg-commit-parents commit)))
         leader pretty-leader other leader-pos 
         leader-mark must-mark-leader leader-leader)
    (unless (setq leader (egg-completing-read-sha1 
                          commit (format prompt-fmt pretty) parent))
      (error error-fmt pretty))
    (setq pretty-leader (egg-pretty-short-rev leader))
    (unless (setq leader-pos (egg-log-buffer-get-commit-pos leader))
      (error "Can't find %s in buffer, please configure egg to display more commits"
             leader))
    (when (functionp mark)
      (setq mark (funcall mark commit leader)))
    (setq leader-pos (+ leader-pos egg-log-buffer-comment-column -10))
    (setq leader-mark (get-text-property leader-pos :mark))
    (unless leader-mark
      (when (y-or-n-p (format "should %s be picked as well? " pretty-leader))
        (setq must-mark-leader t
              leader-mark (egg-log-buffer-pick-mark))))
    (setq other (get-text-property leader-pos :followed-by))
    (setq leader-leader (get-text-property leader-pos :append-to))
    (when exclusive
      (if (and other
               (not (y-or-n-p 
                     (format "%s is already exclusively followed by %s! replace it with %s? "
                             pretty-leader other pretty))))
          (setq exclusive nil)
        (setq must-mark-leader t
              leader-mark (egg-log-buffer-pick-mark))))
    (when must-mark-leader
      (egg-log-buffer-do-mark leader-pos leader-mark nil nil
                              :followed-by (and exclusive commit)
                              :append-to leader-leader))
    (egg-log-buffer-do-mark pos mark nil nil :append-to leader)))


(defun egg-log-buffer-mark-pick (pos &optional append-to) 
  "Mark commit at POS to be picked in the upcoming interactive rebase.
With C-u prefix, prompt for reordering."
  (interactive "d\nP")
  (if append-to
      (egg-log-buffer-do-mark-append pos (egg-log-buffer-pick-mark)
                                     "reorder %s to follow: "
                                     "Need a commit for %s to follow!" t)
    (egg-log-buffer-do-mark pos (egg-log-buffer-pick-mark))))

(defun egg-log-buffer-mark-squash (pos &optional append-to)
  "Mark commit at POS to be squashed in the upcoming interactive rebase.
With C-u prefix, prompt for reordering."
  (interactive "d\nP")
  (if append-to
      (egg-log-buffer-do-mark-append 
       pos (lambda (commit leader)
             (if (y-or-n-p (format "keep %s's message (merge into %s's message)? "
                                   (egg-pretty-short-rev commit)
                                   (egg-pretty-short-rev leader)))
                 (egg-log-buffer-squash-mark)
               (egg-log-buffer-fixup-mark)))
       "squash %s into: "
       "Need a commit to squash %s into!")
    (egg-log-buffer-do-mark pos (egg-log-buffer-squash-mark))))

(defun egg-log-buffer-mark-edit (pos &optional append-to)
  "Mark commit at POS to be edited in the upcoming interactive rebase.
With C-u prefix, prompt for reordering."
  (interactive "d\nP")
  (if append-to
      (egg-log-buffer-do-mark-append pos (egg-log-buffer-edit-mark)
                                     "reorder %s to follow: "
                                     "Need a commit for %s to follow!" t)
    (egg-log-buffer-do-mark pos (egg-log-buffer-edit-mark))))

(defun egg-log-buffer-do-unmark-all ()
  "Unmark all commits."
  (interactive)
  (let ((pos (point-min))
        (inhibit-read-only t))
    (while (setq pos (next-single-property-change (1+ pos) :mark))
      (remove-text-properties pos (1+ pos)
                              (list :mark nil 'display nil 
                                    :append-to nil :followed-by nil)))
    (egg-refresh-buffer (current-buffer))))

(defun egg-log-buffer-unmark (pos &optional all)
  "Unmark commit at POS.
With C-u prefix, unmark all."
  (interactive "d\nP")
  (if all
      (egg-log-buffer-do-unmark-all)
    (egg-log-buffer-do-mark pos nil t)))

(defun egg-log-buffer-get-marked-alist (&rest types)
  (let ((pos (point-min))
        marker subject alist)
    (save-excursion
      (while (and (< pos (point-max))
                  (setq pos (next-single-property-change (1+ pos) :mark)))
        (when (or (null types) (memq (get-text-property pos :mark) types))
          (goto-char pos)
          (setq marker (point-marker))
          (move-to-column egg-log-buffer-comment-column)
          (setq subject (buffer-substring-no-properties
                         (point) (line-end-position)))
          (setq alist (cons (list (get-text-property pos :commit)
                                  (get-text-property pos :mark)
                                  subject marker
                                  (get-text-property pos :append-to)
                                  (get-text-property pos :followed-by))
                            alist)))))
    alist))

(defsubst egg-marked-commit-sha1 (commit) (nth 0 commit))
(defsubst egg-marked-commit-mark (commit) (nth 1 commit))
(defsubst egg-marked-commit-subject (commit) (nth 2 commit))
(defsubst egg-marked-commit-marker (commit) (nth 3 commit))
(defsubst egg-marked-commit-leader (commit) (nth 4 commit))
(defsubst egg-marked-commit-follower (commit) (nth 5 commit))

(defun egg-log-buffer-get-rebase-marked-alist ()
  (let ((tbd (egg-log-buffer-get-marked-alist (egg-log-buffer-pick-mark) 
                                              (egg-log-buffer-squash-mark)
                                              (egg-log-buffer-edit-mark)
                                              (egg-log-buffer-fixup-mark)))
        add-some-func add-one-func done)
    (setq add-some-func
          (lambda ()
            (let (commit)
              ;; find 1st commit without leader
              (setq commit
                    ;; (dolist-done (c tbd found)
                    ;;   (unless (egg-marked-commit-leader c)
                    ;; 	(setq found c)))
                    (egg--find-not tbd #'egg-marked-commit-leader)
                    )
              (when commit
                (setq tbd (delq commit tbd))
                ;; add commit to done list
                (funcall add-one-func commit)))))
    (setq add-one-func
          (lambda (commit)
            (let (sha1 second-sha1 second followers)
              ;; actually add to the done list
              (push commit done)
              (setq sha1 (egg-marked-commit-sha1 commit))
              ;; find commit's second-in-command 
              (setq second-sha1 (egg-marked-commit-follower commit))
              (when second-sha1
                (setq second (dolist-done (c tbd found)
                               (when (equal (egg-marked-commit-sha1 c) second-sha1)
                                 (setq found c))))
                (setq tbd (remq second tbd)))
              ;; find commits' followers
              (dolist (c tbd)
                (when (equal (egg-marked-commit-leader c) sha1)
                  (setq tbd (remq c tbd))
                  (push c followers)))

              ;; add followers one-by-one to done list
              (dolist (c followers)
                (funcall add-one-func c))

              ;; add second-in-command to done list
              (when second
                (funcall add-one-func second))
              ;; add the remaining unrelated to commits
              (when tbd
                (funcall add-some-func)))))
    (funcall add-some-func)
    (nreverse done)))

(defun egg-setup-rebase-interactive (rebase-dir upstream onto repo-state commit-alist)
  (let ((process-environment (copy-sequence process-environment))
        (repo-state (or repo-state (egg-repo-state :staged :unstaged)))
        (orig-buffer (current-buffer))
        orig-head-sha1 tmp)
    (setq orig-head-sha1 (plist-get repo-state :sha1))
    (unless (egg-repo-clean repo-state) (error "Repo not clean"))
    (unless onto (setq onto upstream))

    (with-temp-buffer
      (make-directory rebase-dir t)

      (write-region (point-min) (point-min)
                    (concat rebase-dir "interactive"))
      (write-region (point-min) (point-min) (concat rebase-dir "verbose"))
      (insert (plist-get repo-state :head) "\n")
      (write-region (point-min) (point-max) (concat rebase-dir "head-name"))
      (erase-buffer)
      (insert (plist-get repo-state :sha1) "\n")
      (write-region (point-min) (point-max) (concat rebase-dir "orig-head"))
      (erase-buffer)
      (insert upstream "\n")
      (write-region (point-min) (point-max) (concat rebase-dir "upstream"))
      (erase-buffer)
      (insert onto "\n")
      (write-region (point-min) (point-max) (concat rebase-dir "onto"))
      (erase-buffer)
      (insert "\n")
      (write-region (point-min) (point-max) (concat rebase-dir "quiet"))

      (save-match-data
        (let* ((split-string-default-separators "=")
               (strategy-alist (mapcar 'split-string egg-git-merge-strategy-options))
               (strategy (cadr (assoc "--strategy" strategy-alist)))
               (strategy-opts 
                (delq nil 
                      (mapcar (lambda (opt-key-val)
                                (when (equal (car opt-key-val) "--strategy-option")
                                  (cadr opt-key-val)))
                              strategy-alist))))
          (when strategy 
            (erase-buffer)
            (insert strategy "\n")
            (write-region (point-min) (point-max) (concat rebase-dir "strategy")))
          (when strategy-opts
            (erase-buffer)
            (dolist (option strategy-opts)
              (insert "  '--" option "'"))
            (write-region (point-min) (point-max) (concat rebase-dir "strategy_opts")))))
      
      (erase-buffer)
      (insert onto "\n")
      (write-region (point-min) (point-max)
                    (concat rebase-dir "stopped-sha"))
      (erase-buffer)
      (insert "# Rebase " upstream ".." orig-head-sha1 " onto " onto "\n")
      (dolist (rev-info commit-alist)
        (insert (cond ((eq (nth 1 rev-info) (egg-log-buffer-pick-mark)) "pick")
                      ((eq (nth 1 rev-info) (egg-log-buffer-squash-mark)) "squash")
                      ((eq (nth 1 rev-info) (egg-log-buffer-fixup-mark)) "fixup")
                      ((eq (nth 1 rev-info) (egg-log-buffer-edit-mark)) "edit"))
                " " (nth 0 rev-info) " " (nth 2 rev-info) "\n"))
      (write-region (point-min) (point-max)
                    (concat rebase-dir "git-rebase-todo"))
      (write-region (point-min) (point-max)
                    (concat rebase-dir "git-rebase-todo.backup"))
      (setq tmp (buffer-string)))

    (setenv "GIT_REFLOG_ACTION" (format "rebase -i (%s)" onto))
    (with-egg-debug-buffer
      (erase-buffer)
      ;; debug
      (insert "upstream: " upstream "\n")
      (insert "onto: " onto "\n")
      (insert "orig-head: " orig-head-sha1 "\n")
      (insert (plist-get repo-state :head) "\n")
      (insert "TODO START:\n" tmp "TODO END:\n")
      
      (egg--git nil "update-ref" "ORIG_HEAD" orig-head-sha1)
      (egg--git nil "checkout" onto)

      (egg-do-async-rebase-continue #'egg-handle-rebase-interactive-exit
                                    orig-head-sha1))))

(defun egg-sentinel-commit-n-continue-rebase (prefix gpg-uid text-beg text-end next-beg
                                                     rebase-dir orig-buffer orig-sha1 commit-func)
  (let ((process-environment (copy-sequence process-environment)))
    (mapc (lambda (env-lst)
            (setenv (car env-lst) (cadr env-lst)))
          (egg-rebase-author-info rebase-dir))
    (apply commit-func prefix gpg-uid text-beg text-end next-beg nil))
  (with-current-buffer orig-buffer
    (egg-do-async-rebase-continue
     #'egg-handle-rebase-interactive-exit
     orig-sha1)))


(defun egg-search-for-regexps (re-value-alist)
  (save-match-data
    (let (re line)
      (dolist-done (item re-value-alist value)
        (setq re (car item))
        (goto-char (point-min))
        (when (re-search-forward re nil t)
          (setq line (buffer-substring-no-properties (line-beginning-position)
                                                     (line-end-position)))
          (setq value (cons (cdr item) line)))))))


(defun egg-handle-rebase-interactive-exit (&optional orig-sha1)
  (let ((exit-msg egg-async-exit-msg)
        (debug-rebase-msg (buffer-string))
        (proc egg-async-process)
        (case-fold-search nil)
        (output-buffer (current-buffer))
        state buffer res msg rebase-dir match-code-line)

    (setq match-code-line
          (egg-search-for-regexps
           '(("error: could not apply" .			:rebase-conflict)
             ("When you have resolved this problem" .		:rebase-conflict)
             ("Automatic cherry-pick failed" .			:rebase-conflict)
             ("Successfully rebased and updated" .		:rebase-done)
             ("You can amend the commit now" .			:rebase-edit)
             ("nothing added to commit" .			:rebase-empty)
             ("nothing to commit (working directory clean)" .	:rebase-empty)
             ("If you wish to commit it anyway" .		:rebase-empty)
             ("Could not commit staged changes" .		:rebase-resolved)
             ("You have uncommitted changes" .			:rebase-commit)
             ("You have staged changes in your working tree" .	:rebase-commit)
             ("Could not apply" .				:rebase-squash)
             ("please commit in egg" .				:rebase-commit)
             (": needs merge" .					:rebase-unmerged-file)
             ("You must edit all merge conflicts" .		:rebase-unresolved)
             ("\\(?:Cannot\\|Could not\\)" .			:rebase-fail)
             )))

    (setq res (car match-code-line) msg (cdr match-code-line))
    (setq buffer (process-get proc :orig-buffer))
    
    (with-egg-debug-buffer
      (egg-run-buffers-update-hook)
      (egg-revert-all-visited-files) ;; too heavy ???
      (setq state (egg-repo-state :force))
      (setq rebase-dir (plist-get state :rebase-dir))

      ;; debug
      (goto-char (point-max))
      (insert "ASYNC-REBASE-MSG-BEGIN (" (symbol-name res) "):\n" 
              debug-rebase-msg
              "ASYNC-REBASE-MSG-END:\n")

      (when (eq res :rebase-resolved)
        (setq res (if (file-exists-p (concat (egg-git-rebase-dir) "amend"))
                      :rebase-amend :rebase-commit)))

      (cond ((eq res :rebase-done)
             (message "GIT-REBASE-INTERACTIVE> %s" msg)
             (with-current-buffer (egg-get-log-buffer)
               (egg-log-buffer-do-unmark-all)))

            ((null res)
             (message "EGG got confused by rebase's output")
             (pop-to-buffer output-buffer))

            ((eq res :rebase-unresolved)
             (message "GIT-REBASE-INTERACTIVE: merge conflict(s) needs to be resolved an staged!"))
            ((eq res :rebase-unmerged-file)
             (let (file)
               (save-match-data
                 (string-match "\\`\\([^:]+\\): needs merge" msg)
                 (setq file (match-string 1 msg)))
               (message "GIT-REBASE-INTERACTIVE> merge %s before continue with rebase" file)))

            ((memq res '(:rebase-commit :rebase-amend))
             (egg-commit-log-edit
              (let* ((cherry (plist-get state :rebase-cherry))
                     (cherry-op (save-match-data
                                  (car (split-string cherry)))))
                (concat
                 (egg-text "Rebasing " 'egg-text-3)
                 (egg-text (plist-get state :rebase-head) 'egg-branch)
                 ": "
                 (egg-text (concat (if (eq res :rebase-commit) "Commit " "Amend ")
                                   cherry-op "ed cherry")
                           'egg-text-3)))
              (egg-log-msg-mk-closure-input #'egg-sentinel-commit-n-continue-rebase
                                            rebase-dir buffer orig-sha1
                                            (if (eq res :rebase-commit) 
                                                #'egg-log-msg-commit
                                              #'egg-log-msg-amend-commit))
              (egg-file-as-string (concat rebase-dir "message")))

             (message "please commit the changes to continue with rebase."))

            ((eq res :rebase-squash)
             (egg-commit-log-edit
              (let* ((cherry (plist-get state :rebase-cherry))
                     (cherry-op (save-match-data (car (split-string cherry)))))
                (concat 
                 (egg-text "Rebasing " 'egg-text-3)
                 (egg-text (plist-get state :rebase-head) 'egg-branch) ": "
                 (egg-text (concat "Merge " cherry-op "ed cherry into last commit")
                           'egg-text-3)))
              (egg-log-msg-mk-closure-input #'egg-sentinel-commit-n-continue-rebase
                                            rebase-dir buffer orig-sha1 
                                            #'egg-log-msg-amend-commit)
              (egg-file-as-string (concat rebase-dir "message")))
             (message "please edit the combined message and commit the changes to continue with rebase."))


            ((eq res :rebase-edit)
             (egg-commit-log-edit
              (concat (egg-text "Rebasing " 'egg-text-3)
                      (egg-text (plist-get state :rebase-head)
                                'egg-branch) ": "
                                (egg-text "Re-edit cherry's commit log"
                                          'egg-text-3))
              (egg-log-msg-mk-closure-input #'egg-sentinel-commit-n-continue-rebase
                                            rebase-dir buffer orig-sha1 #'egg-log-msg-amend-commit)
              (egg-commit-message "HEAD"))
             (message "please re-edit the message and commit the changes to continue with rebase."))

            ((eq res :rebase-conflict)
             (egg-status nil t :sentinel)
             (ding)
             (message "automatic rebase stopped! please resolve conflict(s)"))
            ((eq res :rebase-empty)
             (egg-status nil t :sentinel)
             (ding)
             (message "automatic rebase stopped! this empty commit should be skipped!"))
            ((eq res :rebase-fail)
             (egg-status nil t :sentinel)
             (ding)
             (message "Automatic rebase failed!"))))))

(defun egg-log-buffer-merge (pos &optional level)
  "Merge to HEAD the path starting from commit at POS.
With C-u prefix, do not auto commit the merge result.
With C-u C-u prefix, prompt the user for the type of merge to perform."
  (interactive "d\np")
  (let ((rev (egg-log-buffer-get-rev-at pos :no-HEAD :short))
        (merge-options-alist '((?c "(c)ommit" "" "--commit")
                               (?n "(n)o-commit" " (without merge commit)" "--no-commit")
                               (?s "(s)quash" " (without merge data)" "--squash")
                               (?f "(f)f-only" " (fast-forward only)" "--ff-only")))
        res option key)
    (unless (egg-repo-clean)
      (egg-status nil nil)
      (error "Repo is not clean!"))

    (setq option
          (cond ((> level 15)
                 (or (assq (setq key
                                 (string-to-char
                                  (read-key-sequence
                                   (format "merge option - %s: "
                                           (mapconcat 'identity 
                                                      (mapcar 'cadr 
                                                              merge-options-alist)
                                                      " ")))))
                           merge-options-alist)
                     (error "Invalid choice:%c (must be one of: c,n,s,f)" key)))
                ((> level 3) (nth 1 merge-options-alist))
                (t (car merge-options-alist))))

    (if  (null (y-or-n-p (format "merge %s to HEAD%s? " rev (nth 2 option))))
        (message "cancel merge from %s to HEAD%s!" rev (nth 2 option))
      (egg-log-buffer-do-merge-to-head rev (nth 3 option)))))

(defun egg-log-buffer-ff-pull (pos)
  (interactive "d")
  (unless (egg-repo-clean)
    (egg-status nil nil)
    (error "Repo is not clean!"))
  (egg-log-buffer-do-merge-to-head (egg-log-buffer-get-rev-at pos :short :no-HEAD)
                                   "--ff-only"))

(defun egg-log-buffer-merge-n-squash (pos)
  (interactive "d")
  (unless (egg-repo-clean)
    (egg-status nil nil)
    (error "Repo is not clean!"))
  (egg-log-buffer-do-merge-to-head (egg-log-buffer-get-rev-at pos :short :no-HEAD) "--squash"))

(defun egg-log-buffer-rebase (pos)
  "Rebase HEAD using commit at POS as upstream.
If there was a commit marked as BASE, then rebase HEAD onto the commit under the
cursor using the BASE commit as upstream."
  (interactive "d")
  (let* ((mark (egg-log-buffer-find-first-mark (egg-log-buffer-base-mark)))
         (upstream (if mark (egg-log-buffer-get-rev-at mark :short)))
         (onto (egg-log-buffer-get-rev-at pos :short :no-HEAD))
         (head-name (egg-branch-or-HEAD))
         res modified-files buf)

    (unless upstream
      (setq upstream onto)
      (setq onto nil))

    (unless upstream (error "No upstream to rebase on!"))

    (if (null (y-or-n-p (if onto 
                            (format "rebase %s..%s onto %s? " upstream head-name onto)
                          (format "rebase %s on %s? " head-name upstream))))
        (message (if onto
                     (format "cancelled rebasing %s..%s onto %s!" upstream head-name onto)
                   (format "cancelled rebasing %s on %s!" head-name upstream)) ))
    (egg-buffer-do-rebase upstream onto 'log)))

(defun egg-log-buffer-rebase-interactive (pos)
  "Start an interactive session to rebase the marked commits onto commit at POS."
  (interactive "d")
  (let* ((state (egg-repo-state :staged :unstaged))
         (rebase-dir (concat (plist-get state :gitdir) "/"
                             egg-git-rebase-subdir "/"))
         (todo-alist (egg-log-buffer-get-rebase-marked-alist))
         (commits (mapcar 'car todo-alist))
         (r-commits (reverse commits))
         (upstream (egg-commit-at pos))
         (all (egg-git-to-lines "rev-list" "--reverse" "--cherry-pick"
                                (concat upstream "..HEAD"))))

    (unless (consp commits)
      (error "No commit selected! must select atleast one commit to rebase!"))

    (unless (egg-repo-clean state)
      (error "repo %s is not clean" (plist-get state :gitdir)))
    (mapc (lambda (commit)
            (unless (member commit all)
              (error "commit %s is not between HEAD and upstream %s"
                     commit upstream)))
          commits)

    (egg-setup-rebase-interactive rebase-dir upstream nil state todo-alist)
    (egg-status nil t)))

(defun egg-log-buffer-checkout-commit (pos &optional force)
  "Checkout ref or commit at POS.
With C-u prefix, force the checkout even if the index was different
from the new commit."
  (interactive "d\nP")
  (let ((ref (egg-read-rev "checkout: "
                           (egg-log-buffer-get-rev-at pos :short :no-HEAD))))
    (if force 
        (egg-log-buffer-do-co-rev ref "-f")
      (egg-log-buffer-do-co-rev ref))))

(defun egg-log-buffer-tag-commit (pos &optional force)
  "Tag commit at POS.
With C-u prefix, force the creation of the tag
even if it replace an existing one with the same name."
  (interactive "d\nP")
  (let* ((rev (egg-log-buffer-get-rev-at pos :short))
         (name (read-string (format "tag %s with name: " rev)))
         (egg--do-no-output-message 
          (format "new lightweight tag '%s' at %s" name rev)))
    (egg-log-buffer-do-tag-commit name rev force)))

(defun egg-log-buffer-atag-commit (pos &optional sign-tag)
  "Start composing the message to create an annotated tag on commit at POS.
With C-u prefix, the tag will be gpg-signed."
  (interactive "d\np")
  (let* ((commit (get-text-property pos :commit))
         (name (read-string (format "create annotated tag on %s with name: "
                                    (egg-pretty-short-rev commit))))
         (gpg-uid (cond ((> sign-tag 15) t) ;; use default gpg uid
                        ((> sign-tag 3)	    ;; sign the tag
                         (read-string (format "sign tag '%s' with gpg key uid: " name)
                                      (egg-user-name)))
                        (t nil)))
         (gpg-agent-info 
          (egg-gpg-agent-info "set GPG_AGENT_INFO environment to `%s' ")))
    (when (and gpg-uid (not gpg-agent-info))
      (error "gpg-agent's info is unavailable! please set GPG_AGENT_INFO environment!"))
    (egg-create-annotated-tag name commit gpg-uid)))

(defun egg-log-buffer-create-new-branch (pos &optional force)
  "Create a new branch pointing to commit at POS, without checking it out.
With C-u prefix, force the branch creation by deleting the old one with the same name."
  (interactive "d\nP")
  (let ((rev (egg-log-buffer-get-rev-at pos :short))
        (upstream (egg-head-at pos)))
    (egg-buffer-do-create-branch 
     (read-string (format "create new branch at %s with name: " rev))
     rev force upstream 'log)))

(defun egg-log-buffer-start-new-branch (pos &optional force)
  "Create a new branch pointing to commit at POS, and make it the new HEAD.
With C-u prefix, force the creation by deleting the old branch with the same name."
  (interactive "d\nP")
  (let ((rev (egg-log-buffer-get-rev-at pos :short :no-HEAD))
        (upstream (egg-head-at pos))
        (force (if force "-B" "-b"))
        name track)
    
    (setq name (read-string (format "start new branch from %s with name: " rev)))
    (setq track (if (and upstream
                         (y-or-n-p (format "should the branch '%s' track '%s'"
                                           name upstream)))
                    "--track"
                  "--no-track"))
    (egg-log-buffer-handle-result
     (egg--git-co-rev-cmd t rev force name track))))

(defun egg-log-buffer-anchor-head (pos &optional strict-level)
  "Move the current branch or the detached HEAD to commit at POS.
The index will be reset and files will in worktree updated. If a file that is
different between the original commit and the new commit, the git command will
abort. This is basically git reset --keep.
With C-u prefix, HEAD will be moved, index will be reset and the work tree updated
by throwing away all local modifications (this is basically git reset --hard).
With C-u C-u prefix, prompt for the git reset mode to perform."
  (interactive "d\np")
  (let* ((rev (egg-log-buffer-get-rev-at pos :short :no-HEAD))
         (commit (egg-commit-at-point pos))
         (branch (egg-current-branch))
         (hard (> strict-level 3))
         (ask (> strict-level 15))
         (key-mode-alist '((?s . "--soft")
                           (?h . "--hard")
                           (?x . "--mixed")
                           (?k . "--keep")
                           (?m . "--merge")))
         (reset-mode "--keep")
         prompt mode-key)
    
    (setq prompt (format "%s to %s%s? "
                         (if branch
                             (concat "move " branch)
                           "attach HEAD")
                         (if branch (substring commit 0 8) rev)
                         (cond (ask (setq reset-mode "--bad") " (will prompt for advanced mode)")
                               (hard (setq reset-mode "--hard") " (throw away all un-committed changes)")
                               (t (setq reset-mode "--keep") " (but keep current changes)"))))
    (when (y-or-n-p prompt)
      (when ask
        (setq mode-key (read-key-sequence "git-reset: (s)oft (h)ard mi(x)ed (k)eep (m)erge? "))
        (setq mode-key (string-to-char mode-key))
        (setq reset-mode (cdr (assq mode-key key-mode-alist)))
        (unless (stringp reset-mode)
          (error "Invalid choice: %c (must be one of s,h,x,k,m)" mode-key)))
      (egg-log-buffer-do-move-head reset-mode rev))))


(defun egg-log-buffer-rm-ref (pos &optional force)
  "Remove the ref at POS."
  (interactive "d\nP")
  (let ((victim (get-text-property pos :full-name))
        (remote-info (get-text-property pos :x-info))
        (delete-on-remote-func (get-text-property pos :x-delete))
        parts delete-on-remote remote-site name-at-remote
        remote-ok pretty)

    (when (stringp victim)
      (setq pretty (propertize victim 'face 'bold)))

    (cond ((null victim)
           (message "No ref to remove here!"))
          ((not (y-or-n-p (format "remove ref %s? " pretty)))
           (message "Canceled removal of %s" pretty))
          ((null (egg-git-to-string "show-ref" victim))
           (message "Ref %s vanished!" pretty))
          (t
           (setq parts (save-match-data (split-string victim "/" t)))
           (setq remote-site (and (equal (nth 1 parts) "remotes") (nth 2 parts)))
           (setq name-at-remote (and remote-site (mapconcat 'identity (nthcdr 3 parts) "/")))
           (setq delete-on-remote (and remote-site
                                       (y-or-n-p (format "delete %s on %s too? "
                                                         (propertize name-at-remote 'face 'bold) 
                                                         (propertize remote-site 'face 'bold)))))
           (setq remote-ok
                 (if delete-on-remote
                     (egg--buffer-handle-result
                      (if (and delete-on-remote-func remote-info)
                          (funcall delete-on-remote-func (current-buffer) remote-info name-at-remote)
                        (egg--git-push-cmd (current-buffer) "--delete" remote-site name-at-remote)))
                   t))

           (when remote-ok
             (egg-log-buffer-handle-result
              (egg--git-push-cmd (current-buffer) "--delete" "." victim)))))))

(defun egg-log-buffer-do-pick-partial-cherry (rev head-name files &optional 
                                                  revert prompt cancel-msg)
  (if (not (y-or-n-p (or prompt (format "pick selected files from %s and put i on %s"
                                        rev head-name))))
      (message (or cancel-msg (format "Nah! that cherry (%s) looks rotten!!!" rev)))
    (let ((dir (egg-work-tree-dir))
          (args (list "--3way"))
          patch)
      (with-temp-buffer
        (setq default-directory dir)
        (unless (apply 'egg--git t "--no-pager" "show" "--no-color" rev "--" files)
          (error "Error retrieving rev %s" rev))
        (setq patch (buffer-string)))
      (when revert (setq args (cons "--reverse" args)))
      (egg--git-apply-cmd t patch args))))

(defun egg-log-buffer-do-pick-1cherry (rev head-name edit-commit-msg)
  (if (not (y-or-n-p (format "pick %s and put it on %s%s? " rev head-name
                             (if edit-commit-msg " (with new commit message)" ""))))
      (message "Nah! that cherry (%s) looks rotten!!!" rev)
    (egg--git-cherry-pick-cmd t rev (if edit-commit-msg "--no-commit" "--ff"))))

(defun egg-log-buffer-pick-1cherry (pos &optional edit-commit-msg)
  "Pick commit at POS and put on HEAD.
With C-u prefix, will not auto-commit but let the user re-compose the message."
  (interactive "d\nP")
  
  (let ((rev (egg-log-buffer-get-rev-at pos :short :no-HEAD))
        (selection (cdr (get-text-property pos :selection)))
        (head-name (egg-branch-or-HEAD))
        res modified-files old-msg)
    (unless (and rev (stringp rev))
      (error "No cherry here for picking! must be a bad season!" ))
    (when (string-equal rev "HEAD")
      (error "Cannot pick your own HEAD!"))

    (setq res (if (null selection)
                  (egg-log-buffer-do-pick-1cherry rev head-name edit-commit-msg)
                (setq edit-commit-msg t)
                (egg-log-buffer-do-pick-partial-cherry rev head-name selection)))

    (setq old-msg (egg-commit-message rev))
    (egg--buffer-handle-result-with-commit
     res (list (concat (egg-text "Newly Picked Cherry:  " 'egg-text-3)
                       (egg-text rev 'egg-branch))
               (egg-log-msg-mk-closure-input #'egg-log-msg-commit)
               old-msg)
     t 'log)))

(defsubst egg-log-buffer-do-revert-rev (rev use-default-commit-msg)
  (if (not (y-or-n-p (format "undo changes introduced by %s%s? " rev
                             (if use-default-commit-msg
                                 " (with git's default commit message)" ""))))
      (message "Nah! that lump (%s) looks benign!!!" (egg-commit-subject rev))
    (egg--git-revert-cmd t rev use-default-commit-msg)))

(defsubst egg-log-buffer-do-selective-revert-rev (rev files)
  (egg-log-buffer-do-pick-partial-cherry 
   rev nil files t
   (format "undo changes introduced by selected files in %s? " rev)
   (format "Nah! that lump (%s) looks benign!!!" (egg-commit-subject rev))))

(defun egg-log-buffer-revert-rev (pos &optional use-default-commit-msg)
  (interactive "d\nP")
  (let ((sha1 (egg-log-buffer-get-rev-at pos :sha1))
        (rev (egg-log-buffer-get-rev-at pos :symbolic))
        (selection (cdr (get-text-property pos :selection)))
        res)
    (unless (and rev (stringp rev))
      (error "No tumour to remove here! very healthy body!" ))
    (when (and (string-equal rev "HEAD") (null selection))
      (error "Just chop your own HEAD (use anchor a.k.a git-reset)! no need to revert HEAD"))
    
    (setq res (if selection
                  (egg-log-buffer-do-selective-revert-rev rev selection)
                (egg-log-buffer-do-revert-rev rev use-default-commit-msg)))
    (egg--buffer-handle-result-with-commit
     res (list (concat
                (egg-text "Undo Changes Introduced by:  " 'egg-text-3)
                (egg-text rev 'egg-branch)) 
               (egg-log-msg-mk-closure-input #'egg-log-msg-commit)
               (format "Revert \"%s\"\n\nThis reverts commit %s\n" (egg-commit-subject sha1) sha1))
     t 'log)))

(defun egg-log-buffer-fetch-remote-ref (pos)
  "Download and update the remote tracking branch at POS."
  (interactive "d")
  (let* ((ref-at-point (get-text-property pos :ref))
         (ref (car ref-at-point))
         (type (cdr ref-at-point))
         (remote-info (get-text-property pos :x-info))
         (fetch-function (get-text-property pos :x-fetch))
         (full-name (get-text-property pos :full-name))
         name remote)
    (unless (eq type :remote)
      (error "Nothing to fetch from here!"))
    (setq name (file-name-nondirectory ref)
          remote (egg-rbranch-to-remote ref))
    (when (and remote name)
      (message "GIT> fetching %s from %s..." ref remote)
      (if (functionp fetch-function)
          (funcall fetch-function (current-buffer) remote-info full-name)
        (egg-buffer-async-do nil "fetch" remote
                             (format "refs/heads/%s:refs/remotes/%s"
                                     name ref))))))

(defun egg-log-buffer-do-fetch-from-site (remote-name remote-info fetch-function tag-or-branch)
  (let* ((pretty-remote (propertize remote-name 'face 'bold))
         (fetch-tag (cond ((eq tag-or-branch 'ask)
                           (y-or-n-p (format "Fetch a tag instead of branch from %s? " pretty-remote)))
                          (t tag-or-branch)))
         (ref (read-string (format "%s to fetch from %s (default all refs): " 
                                   (if fetch-tag "tag" "branch") pretty-remote)
                           nil nil "--all"))
         (pretty-ref (propertize ref 'face 'bold)))
    
    (if (equal ref "--all")
        (progn
          (message "GIT> fetching everything from %s..." pretty-remote)
          (if (functionp fetch-function)
              (funcall fetch-function (current-buffer) remote-info "--all")
            (if fetch-tag
                (egg-buffer-async-do nil "fetch" "--tags" remote-name)
              (egg-buffer-async-do nil "fetch" remote-name))))
      (message "GIT> fetching %s from %s..." pretty-ref pretty-remote)
      (if (functionp fetch-function)
          (funcall fetch-function (current-buffer) remote-info ref)
        (if fetch-tag
            (egg-buffer-async-do nil "fetch" remote-name "tag" ref)
          (egg-buffer-async-do nil "fetch" remote-name
                               (format "%s:refs/remotes/%s/%s" ref remote-name ref)))))))

(defun egg-log-buffer-fetch-site (pos)
  "Fetch some refs from remote at POS."
  (interactive "d")
  (let* ((ref-at-point (get-text-property pos :ref))
         (ref (car ref-at-point))
         (type (cdr ref-at-point))
         (remote-info (get-text-property pos :x-info))
         (fetch-function (get-text-property pos :x-fetch))
         remote)
    (unless (eq type :remote)
      (error "No site here to fetch from!"))
    (setq remote (egg-rbranch-to-remote ref))
    (when remote
      (egg-log-buffer-do-fetch-from-site remote remote-info fetch-function 'ask))))

(defun egg-log-buffer-fetch ()
  "Fetch something from a remote"
  (interactive)
  (let* ((remote (egg-read-remote "Fetch from remote: "))
         (remote-info (get-text-property 0 :x-info remote))
         (fetch-function (get-text-property 0 :x-fetch remote)))
    (if (or (null remote) (equal "" remote))
        (error "Invalid remote: %s" remote)
      (egg-log-buffer-do-fetch-from-site remote remote-info fetch-function 'ask))))

(defun egg-log-buffer-push-to-local (pos &optional level)
  "Push commit at POS onto HEAD.
With C-u prefix, instead of HEAD, prompt for another ref as destination.
With C-u C-u prefix, will force the push evel if it would be non-ff.
When the destination of the push is HEAD, the underlying git command
would be a pull (by default --ff-only)."
  (interactive "d\np")
  (let ((src (or (egg-ref-at-point pos)
                 (egg-log-buffer-get-rev-at pos :short :no-HEAD)))
        (prompt-dst (> level 3))
        (non-ff (> level 15))
        (head-name (egg-branch-or-HEAD))
        dst mark base)
    
    (setq mark (egg-log-buffer-find-first-mark (egg-log-buffer-base-mark)))
    (setq base (if mark (egg-log-buffer-get-rev-at mark :short)))
    (setq dst (or base head-name))

    (unless src
      (error "Nothing to push here!"))
    (if (or prompt-dst (equal dst src))
        (setq dst (egg-read-local-ref (format "use %s to update: " src))))
    (if (y-or-n-p (format "push %s on %s%s? " src dst 
                          (if non-ff " (allowed non-ff move)" "")))
        (if (string-equal dst head-name)
            (if non-ff
                (if (egg-repo-clean)
                    (egg-log-buffer-do-move-head "--hard" src)
                  (error "Can't push on dirty repo"))
              (egg-log-buffer-do-merge-to-head src "--ff-only"))
          (egg--git-push-cmd (current-buffer) (if non-ff "-vf" "-v")
                             "." (concat src ":" dst)))
      (message "local push cancelled!"))))

(defun egg-log-buffer-push-head-to-local (pos &optional non-ff)
  "Push HEAD to the ref at POS."
  (interactive "d\nP")
  (let* ((dst (egg-ref-at-point pos)))
    (unless dst
      (error "Nothing here to push to!"))
    (if (y-or-n-p (format "update %s with HEAD? " dst))
        (egg--git-push-cmd (current-buffer) (if non-ff "-v" "-vf")
                           "." (concat "HEAD:" dst))
      (message "local push cancelled!"))))

(defun egg-log-buffer-push-to-remote (pos &optional non-ff)
  "Push the ref at POS to a remote repository.
If the ref track a remote tracking branch, then the repo to
upload to is the repo of the remote tracking branch. Otherwise,
prompt for a remote repo."
  (interactive "d\nP")
  (let* ((ref-at-point (get-text-property pos :ref))
         (lref (car ref-at-point))
         (type (cdr ref-at-point))
         (commit (egg-commit-at-point pos))
         type-name rref tracking remote spec push-function delete-function remote-info)
    
    (cond ((null commit) 
           (error "Nothing to push here!"))
          ((null type)
           ;; cursor was not on a ref
           ;; push the sha1 to remote
           (setq lref (egg-short-sha1 commit))
           (setq type-name "commit"))
          ((eq type :remote)
           ;; on a remote tracking branch name
           ;; push something to the remote
           ;; blank means delete on remote site
           (setq remote (egg-rbranch-to-remote lref))
           (setq type-name "ref")
           (setq lref nil))
          ((eq type :tag)
           (setq type-name "tag"))
          ((eq type :head)
           (setq type-name "branch")
           (when (consp (setq tracking (egg-tracking-target lref :remote)))
             (setq rref (nth 0 tracking)
                   remote (nth 1 tracking))))
          (t (error "Internal error: type is %s" type)))

    (cond ((and (null lref) (null remote))
           (error "Internal error: lref=%s remote=%s" lref remote))
          ((null lref)
           (setq lref 
                 (egg-read-local-ref 
                  (format "local ref to push to %s (none means deleting the a remote ref):"
                          (propertize remote 'face 'bold)))))
          ((null remote)
           (setq remote
                 (egg-read-remote (format "push %s %s to: " type-name
                                          (propertize lref 'face 'bold))))))

    (unless rref
      (setq rref (if (equal "" lref)
                     (read-string (format "delete %s's ref: " (propertize remote 'face 'bold)))
                   (read-string (format "push %s %s to %s as: " type-name
                                        (propertize lref 'face 'bold)
                                        (propertize remote 'face 'bold)) lref))))

    ;;(egg-add-remote-properties remote remote rref)

    (setq remote-info (egg-get-remote-properties remote rref))
    (setq push-function (plist-get remote-info :x-push))
    (setq delete-function (plist-get remote-info :x-delete))
    (setq remote-info (plist-get remote-info :x-info))


    (if (equal "" lref)
        (if (functionp delete-function)
            (funcall delete-function (current-buffer) remote-info rref)
          (message "EGG> deleting %s on %s..." rref remote)
          (egg-buffer-async-do nil "push" "--delete" remote rref))
      (if (functionp push-function)
          (funcall push-function (current-buffer) remote-info lref rref)
        (message "GIT> pushing %s to %s on %s..." lref rref remote)
        (setq spec (concat lref ":" rref))
        (egg-buffer-async-do nil "push" (if non-ff "-vf" "-v") remote spec)))))

(defun egg-log-buffer-push (pos)
  "Push some refs to the remote at POS"
  (interactive "d")
  (let* ((ref-at-point (get-text-property pos :ref))
         (ref (car ref-at-point))
         (type (cdr ref-at-point))
         site name def remote)
    (unless (eq type :remote)
      (error "No site here to push to!"))
    (setq remote (egg-rbranch-to-remote ref))
    (when remote
      (setq name
            (completing-read (format "push to %s (default all heads): "
                                     remote)
                             (egg-local-refs) nil nil nil nil "--all"))
      (message "GIT> pushing %s to %s..."
               (if (equal name "--all") "everything" name) remote)
      (egg-buffer-async-do nil "push" remote name))))

(defun egg-log-buffer-goto-pos (pos)
  (goto-char pos)
  (goto-char (line-beginning-position))
  (let ((sha1 (get-text-property (point) :commit)))
    (when (stringp sha1)
      (setq sha1 (substring sha1 0 6))
      (save-match-data
        (if (looking-at (concat "^.* \\(" sha1 "\\)"))
            (goto-char (match-beginning 1)))))))

(defun egg-log-buffer-next-ref (pos)
  "Move cursor to the next ref."
  (interactive "d")
  (let ((current-ref (egg-references-at-point pos))
        (n-pos (next-single-property-change pos :references))
        n-ref)
    (when n-pos
      (setq n-ref (egg-references-at-point n-pos))
      (if n-ref
          (egg-log-buffer-goto-pos n-pos)
        (if (setq n-pos (next-single-property-change n-pos :references))
            (egg-log-buffer-goto-pos n-pos))))))

(defun egg-log-buffer-prev-ref (pos)
  "Move cursor to the previous ref."
  (interactive "d")
  (let ((current-ref (egg-references-at-point pos))
        (p-pos (previous-single-property-change pos :references))
        p-ref)
    (when p-pos
      (setq p-pos (1- p-pos))
      (setq p-ref (egg-references-at-point p-pos))
      (if (and p-ref (not (equal p-ref current-ref)))
          (egg-log-buffer-goto-pos p-pos)
        (when (setq p-pos (previous-single-property-change p-pos :references))
          (setq p-pos (1- p-pos))
          (egg-log-buffer-goto-pos p-pos))))))

(defun egg-log-diff-toggle-file-selection (pos)
  "(un)select the file at POS for the next partial cherry-pic/revert operation."
  (interactive "d")
  (let* ((diff (get-text-property pos :diff))
         (diff-beg (and diff (nth 1 diff)))
         (file (and diff (car diff)))
         (selection (get-text-property pos :selection))
         (files (and selection (cdr selection)))
         (inhibit-read-only t))
    (unless (consp selection)
      (error "Cannot select a commit's file at the cursor!"))
    (unless (stringp file)
      (error "Failed to pick a commit's file at the cursor!"))
    (save-excursion
      (goto-char diff-beg)
      (setcdr selection
              (if (member file files)
                  (progn
                    (put-text-property (line-end-position)
                                       (1+ (line-end-position))
                                       'display nil)
                    (delete file files))
                (put-text-property (line-end-position)
                                   (1+ (line-end-position))
                                   'display 
                                   (propertize (string ?  egg-commit-file-select-mark ?\n)
                                               'face 'egg-diff-file-header))
                (cons file files))))))

(defcustom egg-commit-box-chars "-|++"
  "horz line, vert line, up-left corner and low-left corner"
  :group 'egg
  :type '(radio :tag "Commit Box Characters"
                (const :tag "- | + +" "-|++")
                (vector :tag "Pick individual character"
                        (radio :tag "line"
                               (const :tag "■" #x25a0)
                               (const :tag "□" #x25a1)
                               (const :tag "█" #x2588)))))

(defun egg-log-buffer-box-inserted-commit (beg end)
  (save-excursion
    (let ((inhibit-read-only t))
      (goto-char beg)
      (insert (aref egg-commit-box-chars 2)
              (make-string 100 (aref egg-commit-box-chars 0))
              "\n")
      (while (< (point) end)
        (forward-line 1)
        (insert (aref egg-commit-box-chars 1) " "))
      (forward-line 1)
      (insert (aref egg-commit-box-chars 3)
              (make-string 100 (aref egg-commit-box-chars 0))
              "\n"))))

(defun egg-log-buffer-do-insert-commit (pos &optional args highlight-regexp path-args)
  (save-excursion
    (let ((sha1 (get-text-property pos :commit))
          (ref (egg-references-at-point pos))
          (nav (get-text-property pos :navigation))
          (inhibit-read-only t)
          (indent-column egg-log-buffer-comment-column)
          (indent-spaces (make-string egg-log-buffer-comment-column ? ))
          commit-beg beg end diff-beg diff-end is-cc-diff face-end hide-sect-type)
      (goto-char pos)
      (setq commit-beg (line-beginning-position))
      (goto-char (1+ (line-end-position)))
      (setq beg (point))
      (unless (egg--git-args 
               t (nconc (list "show" "--no-color" "--show-signature")
                        (copy-sequence egg-git-diff-options)
                        (copy-sequence args)
                        (list (concat "--pretty=format:"
                                      indent-spaces "%ai%n"
                                      indent-spaces "%an%n"
                                      "%b")
                              sha1)
                        path-args))
        (error "error calling git log %s!" ref))
      (setq end (point-marker))

      ;; car is the sha1 of the commit
      ;; cdr is a list of selected files from the commit.
      ;; use commit-beg to include the commit line as well
      (put-text-property commit-beg end :selection (list sha1))

      (save-excursion
        (save-match-data
          (goto-char beg)
          (while (re-search-forward "^\\(gpg\\|Signed-off-by\\):" end t)
            (save-excursion
              (goto-char (match-beginning 0))
              (insert indent-spaces)))
          (goto-char beg)
          (setq is-cc-diff (re-search-forward "^@@@" end t))))
      (setq diff-end end)
      (egg-delimit-section :commit sha1 beg end (1- beg) nil nav)
      (put-text-property beg end 'keymap egg-section-map)
      (egg-decorate-diff-section :begin beg
                                 :end end
                                 :diff-map egg-log-diff-map
                                 :hunk-map egg-log-hunk-map
                                 :cc-diff-map egg-log-diff-map
                                 :cc-hunk-map egg-log-hunk-map)
      (goto-char beg)
      (setq diff-beg (or (next-single-property-change beg :diff) end))

      (while (< (point) diff-beg)
        (if (equal (buffer-substring-no-properties (line-beginning-position)
                                                   (+ (line-beginning-position)
                                                      indent-column))
                   indent-spaces)
            (progn
              (put-text-property (line-beginning-position) 
                                 (+ (line-beginning-position) indent-column) 
                                 'face 'egg-diff-none)
              (put-text-property (+ (line-beginning-position) indent-column)
                                 (line-end-position) 'face 'egg-text-2))
          (put-text-property (line-beginning-position) (line-end-position) 
                             'face 'egg-text-2))
        (forward-line 1)
        (goto-char (line-end-position)))

      (when (stringp highlight-regexp)
        (egg-buffer-highlight-pickaxe highlight-regexp diff-beg diff-end is-cc-diff))
      (when (setq hide-sect-type (cdr (assq 'egg-log-buffer-mode 
                                            egg-buffer-hide-section-type-on-start)))
        (egg-buffer-hide-section-type hide-sect-type beg end))
      (set-buffer-modified-p nil))))

(defun egg-log-buffer-insert-commit (pos)
  "Load and show the details of commit at POS."
  (interactive "d")
  (let* ((next (next-single-property-change pos :diff))
         (sha1 (and next (get-text-property next :commit)))
         (pickaxe-args (and egg-internal-log-buffer-closure
                            (plist-get egg-internal-log-buffer-closure :pickaxe-args)))
         (pickaxed-paths (and egg-internal-log-buffer-closure
                              (plist-get egg-internal-log-buffer-closure :paths)))
         (highlight (and egg-internal-log-buffer-closure
                         (plist-get egg-internal-log-buffer-closure :highlight))))
    (if (equal (get-text-property pos :commit) sha1)
        (call-interactively #'egg-section-cmd-toggle-hide-show)
      (egg-log-buffer-do-insert-commit pos pickaxe-args highlight pickaxed-paths))))

(defun egg-log-show-marked-commits (marked-list)
  (when marked-list
    (let ((beg (point)) end sha1)
      (mapc (lambda (marked-commit)
              (egg-log-buffer-do-mark (egg-log-buffer-get-commit-pos (egg-marked-commit-sha1 marked-commit))
                                      (egg-marked-commit-mark marked-commit)
                                      nil nil
                                      :followed-by (egg-marked-commit-follower marked-commit)
                                      :append-to (egg-marked-commit-leader marked-commit)))
            marked-list)
      (goto-char beg)
      (insert (egg-text "Commits marked for interactive rebase!\n" 'egg-header))
      (dolist (commit marked-list)
        (setq sha1 (egg-marked-commit-sha1 commit))
        (insert " " 
                (egg-text (string (egg-marked-commit-mark commit)) 'egg-log-buffer-mark)
                " " 
                (egg-text (substring sha1 0 8) 'font-lock-constant-face)
                " "
                (egg-text (egg-marked-commit-subject commit) 'egg-text-2))
        (add-text-properties (line-end-position) (point)
                             (list :commit-sha1 sha1
                                   :commit-pos (egg-marked-commit-marker commit)))
        (insert "\n"))
      (setq end (point))
      (insert "\n"))))

(defun egg-generic-display-logs (data &optional init)
  (buffer-disable-undo)
  (and init (setq buffer-invisibility-spec nil))
  (let ((title (plist-get data :title))
        (subtitle (plist-get data :subtitle))
        (git-dir (egg-git-dir))
        (desc (plist-get egg-internal-log-buffer-closure :description))
        (closure (plist-get egg-internal-log-buffer-closure :closure))
        (help (plist-get egg-internal-log-buffer-closure :help))
        (rebase-commits (plist-get egg-internal-log-buffer-closure :rebase-commits))
        (inhibit-read-only t)
        inv-beg beg pos help-beg marked-alist)
    (setq marked-alist (unless init (egg-log-buffer-get-rebase-marked-alist)))
    (erase-buffer)
    (insert title
            (if subtitle (concat "\n" subtitle "\n") "\n")
            (egg-text "repo: " 'egg-text-2)
            (egg-text (egg-git-dir) 'font-lock-constant-face)
            (if desc (concat "\n" desc "\n") "\n")
            "\n")
    (setq inv-beg (- (point) 2))
    (when (stringp help)
      (setq help-beg (point))
      (insert (egg-text "Help" 'egg-help-header-1) "\n")
      (put-text-property help-beg (point) 'help-echo (egg-tooltip-func))
      (setq inv-beg (1- (point)))
      (insert help)
      (egg-delimit-section :section :help help-beg (point)
                           inv-beg egg-section-map :help)
      (insert "\n")
      (if init (egg-buffer-maybe-hide-help :help)))
    (setq pos (point))
    (setq beg (or (funcall closure) pos))
    (when marked-alist
      (goto-char pos)
      (egg-log-show-marked-commits marked-alist))
    (goto-char beg)))

(defun egg-log-buffer-redisplay (buffer &optional init)
  (with-current-buffer buffer
    (let* ((state (egg-repo-state))
           (sha1 (plist-get state :sha1)))
      (plist-put egg-internal-log-buffer-closure :title
                 (egg-text (egg-pretty-head-string state) 'egg-branch))
      (plist-put egg-internal-log-buffer-closure :subtitle
                 (egg-text sha1 'font-lock-string-face))
      (egg-generic-display-logs egg-internal-log-buffer-closure init))))

(defun egg-async-xfer-pp (status cmd-name remote-re remote-re-no fall-back-remote-name)
  (save-match-data
    (let* ((cmd-name (upcase cmd-name))
           remote-name xfer-msg remote-msg beg)
      
      (when (and remote-re 
                 (goto-char (point-min))
                 (re-search-forward remote-re nil t))
        (setq remote-name (match-string-no-properties 1))
        (forward-line 1)
        (skip-chars-forward " ")
        (setq xfer-msg (buffer-substring-no-properties (point) (line-end-position))))

      (when (progn (goto-char (point-min)) (re-search-forward "^remote: \\(.+\\)$" nil t))
        (setq remote-msg (match-string-no-properties 1)))

      ;;(unless remote-name (setq remote-name fall-back-remote-name))

      (unless (or remote-msg xfer-msg)
        (setq xfer-msg (cond ((and (goto-char (point-min))
                                   (re-search-forward "^error: \\(.+\\)" nil t))
                              (match-string-no-properties 1))
                             ((and (goto-char (point-min))
                                   (re-search-forward "^fatal: \\(.+\\)" nil t))
                              (match-string-no-properties 1))
                             (t
                              (goto-char (point-min))
                              (re-search-forward "EGG-GIT-OUTPUT:\n")
                              (setq beg (point))
                              (goto-char (point-max))
                              (if (re-search-forward "^.+" nil t)
                                  (buffer-substring-no-properties (line-beginning-position)
                                                                  (line-end-position))
                                ;; not a message from remote
                                (setq remote-name nil)
                                (cond ((eq status :finished) "all done")
                                      ((eq status :killed) "dead in action")
                                      ((numberp status) (format "exit with code %d" status))
                                      ((eq status :failed) "fatal failure")
                                      ((eq status :confused) "egg was confused by git")
                                      (t "this message should not be seen (status = %s)" status)))))))

      (if remote-name
          (message "GIT-%s> %s: %s" cmd-name remote-name (if remote-msg remote-msg xfer-msg))
        (message "GIT-%s> %s" cmd-name (if remote-msg remote-msg xfer-msg))))))

(defun egg-async-fetch-pp (status cmd-sexp)
  (egg-async-xfer-pp status (car cmd-sexp) "^From \\(.+\\)$" 1 (nth 1 cmd-sexp)))

(defun egg-async-push-pp (status cmd-sexp)
  (egg-async-xfer-pp status (car cmd-sexp) "^To \\(.+\\)$" 1 (nth 1 cmd-sexp)))

(defun egg-async-generic-pp (status cmd-sexp)
  (egg-async-xfer-pp status (car cmd-sexp) nil nil (nth 1 cmd-sexp)))

(defun egg-async-unimplemented-pp (status cmd-sexp)
  (egg-async-xfer-pp status "internal-error" nil nil nil))


(defun egg-log-buffer-redisplay-from-command (buffer)
  ;; in process buffer
  (when (and (processp egg-async-process)
             (equal (current-buffer) (process-buffer egg-async-process)))
    (save-excursion
      (let ((status egg-async-exit-status)
            cmd-sexp cmd-string pos done)
        (goto-char (point-min))
        (skip-chars-forward "^(")
        (setq cmd-sexp (read (current-buffer)))
        (if (not (consp cmd-sexp))
            (egg-async-unimplemented-pp status nil)
          (setq cmd-string (car cmd-sexp))
          (cond ((string-equal "fetch" cmd-string)
                 (egg-async-fetch-pp status cmd-sexp))
                ((string-equal "push" cmd-string)
                 (egg-async-push-pp status cmd-sexp))
                (t
                 (egg-async-generic-pp status cmd-sexp)))))))
  ;; update log buffer
  (egg-log-buffer-redisplay buffer))

(define-egg-buffer log "*%s-log@%s*"
  "Major mode to display the output of git log.\\<egg-log-buffer-mode-map>
Each line with a shorten sha1 representing a commit in the repo's history.
\\[egg-log-buffer-next-ref] move the cursor to the next commit with a ref
\\[egg-log-buffer-prev-ref] move the cursor to the previous commit line with a ref.
\\[egg-buffer-cmd-refresh] refresh the display of the log buffer
\\[egg-status] shows the repo's current status.

\\{egg-log-buffer-mode-map}

Each line representing a commit has extra keybindings:\\<egg-log-commit-map>
\\[egg-log-buffer-insert-commit] fetch and show the commit's details.
\\[egg-section-cmd-toggle-hide-show] hide/show the current commit's details
\\[egg-section-cmd-toggle-hide-show-children] hide all the sub-blocks of the current commit's details.
\\[egg-log-buffer-create-new-branch] create a new branch starting from the current commit.
\\[egg-log-buffer-start-new-branch] start in a new branch from the current commit.
\\[egg-log-buffer-checkout-commit] checkout the current commit.
\\[egg-log-buffer-tag-commit] create a new lightweight tag pointing at the current commit.
C-u \\[egg-log-buffer-tag-commit] create a new lightweight tag pointing at the current commit,
  replacing the old tag with the same name.
\\[egg-log-buffer-atag-commit] create a new annotated tag pointing at the current commit.
C-u \\[egg-log-buffer-atag-commit] create a new gpg-signed tag pointing at the current commit.
\\[egg-log-buffer-anchor-head] move HEAD (and maybe the current branch tip) as well as
the index to the current commit if it's safe to do so
 (the underlying git command is `reset --keep'.)
C-u \\[egg-log-buffer-anchor-head] move HEAD (and maybe the current branch tip) and
the index to the current commit, the work dir will also be updated,
uncommitted changes will be lost (the underlying git command is `reset --hard').
C-u C-u \\[egg-log-buffer-anchor-head] will let the user specify a mode to run git-reset.
\\[egg-log-buffer-merge] will merge the current commit into HEAD.
C-u \\[egg-log-buffer-merge] will merge the current commit into HEAD but will not
auto-commit if the merge was successful.

\\{egg-log-commit-map}

Each ref on the commit line has extra extra keybindings:\\<egg-log-ref-map>
\\[egg-log-buffer-rm-ref] delete the ref under the cursor.
\\[egg-log-buffer-push-to-local] push the ref to HEAD or BASE.
C-u \\[egg-log-buffer-push-to-local] push the ref to a local ref.
C-u C-u \\[egg-log-buffer-push-to-local] push the ref to a local ref (non-ff allowed).

Each local ref on the commit line has extra extra extra keybindings:\\<egg-log-local-ref-map>
\\[egg-log-buffer-push-to-remote] upload to a remote the ref under the cursor.
  for a remote-tracking local branch this would updating the tracking target.
  for other local refs this  means uploading (or deleting) the local value
   of the ref to the remote repository.
\\[egg-log-buffer-push-head-to-local] update the local ref under the cursor with the current HEAD.

Each remote ref on the commit line has extra extra extra keybindings:\\<egg-log-remote-branch-map>
\\[egg-log-buffer-fetch-remote-ref] download the new value of the ref from the remote repo.
."
  (kill-all-local-variables)
  (setq buffer-read-only t)
  (setq major-mode 'egg-log-buffer-mode
        mode-name  "Egg-Log"
        mode-line-process ""
        truncate-lines t)
  (use-local-map egg-log-buffer-mode-map)
  (set (make-local-variable 'egg-buffer-refresh-func)
       'egg-log-buffer-redisplay)
  (set (make-local-variable 'egg-buffer-async-cmd-refresh-func)
       'egg-log-buffer-redisplay-from-command)
  (set (make-local-variable 'egg-log-buffer-comment-column) 0)
  (setq buffer-invisibility-spec nil)
  (run-mode-hooks 'egg-log-buffer-mode-hook))

(defun egg-log-commit-line-menu-attach-head-ignore-changes (pos)
  (interactive "d")
  (egg-log-buffer-anchor-head pos 4))

(defun egg-log-make-commit-line-menu (&optional heading)
  (let ((map (make-sparse-keymap heading)))
    (define-key map [load] (list 'menu-item "(Re)Load Commit Details"
                                 'egg-log-buffer-insert-commit
                                 :visible '(egg-commit-at-point)))
    (define-key map [diff] (list 'menu-item "Compare against HEAD (or BASE)"
                                 'egg-log-buffer-diff-revs
                                 :visible '(egg-commit-at-point)))
    (define-key map [prev] (list 'menu-item "Goto Prev Ref"
                                 'egg-log-buffer-prev-ref
                                 :visible '(egg-navigation-at-point)))
    (define-key map [next] (list 'menu-item "Goto Next Ref"
                                 'egg-log-buffer-next-ref
                                 :visible '(egg-navigation-at-point)))
    (define-key map [hs] (list 'menu-item "Hide/Show Details"
                               'egg-section-cmd-toggle-hide-show
                               :visible '(egg-navigation-at-point)))
    (define-key map [hs-sub] (list 'menu-item "Hide/Show Details of Subsections"
                                   'egg-section-cmd-toggle-hide-show-children
                                   :visible '(egg-navigation-at-point)))
    (define-key map [sp9] '("--"))
    (define-key map [rpush] (list 'menu-item "Fetch Refs from Remote"
                                  'egg-log-buffer-fetch-site
                                  :visible '(egg-remote-at-point)))
    (define-key map [rfetch] (list 'menu-item "Push Refs to Remote"
                                   'egg-log-buffer-push
                                   :visible '(egg-remote-at-point)))
    (define-key map [rdown] (list 'menu-item "Fetch Remote Ref"
                                  'egg-log-buffer-fetch-remote-ref
                                  :visible '(egg-ref-at-point)
                                  :enable '(egg-remote-at-point)))
    (define-key map [ldown] (list 'menu-item "Push HEAD To Ref"
                                  'egg-log-buffer-push-head-to-local
                                  :visible '(egg-ref-at-point)
                                  :enable '(not (egg-remote-at-point))))
    (define-key map [upload] (list 'menu-item "Push Ref to Remote"
                                   'egg-log-buffer-push-to-remote
                                   :visible '(egg-ref-at-point)
                                   :enable '(not (egg-remote-at-point))))
    (define-key map [update] (list 'menu-item "Push to HEAD or Another Local Branch"
                                   'egg-log-buffer-push-to-local
                                   :visible '(egg-ref-at-point)))
    (define-key map [sp5] '("--"))
    (define-key map [irebase] (list 'menu-item "Rebase HEAD interratively"
                                    'egg-log-buffer-rebase
                                    :visible '(egg-commit-at-point)
                                    :enable '(egg-log-buffer-get-marked-alist)))
    (define-key map [unmark] (list 'menu-item "Unmark for interactive Rebase "
                                   'egg-log-buffer-unmark
                                   :visible '(egg-commit-at-point)))
    (define-key map [edit] (list 'menu-item "Mark for Editing in upcoming interactive Rebase "
                                 'egg-log-buffer-mark-edit
                                 :visible '(egg-commit-at-point)))
    (define-key map [squash] (list 'menu-item "Mark to be Squashed in upcoming interactive Rebase "
                                   'egg-log-buffer-mark-squash
                                   :visible '(egg-commit-at-point)))
    (define-key map [pick] (list 'menu-item "Mark to be Picked in upcoming interactive Rebase "
                                 'egg-log-buffer-mark-pick
                                 :visible '(egg-commit-at-point)))
    (define-key map [base] (list 'menu-item "Mark as Base Commit "
                                 'egg-log-buffer-mark
                                 :visible '(egg-commit-at-point)))
    (define-key map [sp4] '("--"))
    (define-key map [rebase] (list 'menu-item "Rebase HEAD"
                                   'egg-log-buffer-rebase
                                   :visible '(egg-commit-at-point)))
    (define-key map [merge] (list 'menu-item "Merge to HEAD"
                                  'egg-log-buffer-merge
                                  :visible '(egg-commit-at-point)))
    (define-key map [sp3] '("--"))
    (define-key map [rh-4] (list 'menu-item "Anchor HEAD (ignore changes)"
                                 'egg-log-commit-line-menu-attach-head-ignore-changes
                                 :visible '(egg-commit-at-point)))
    (define-key map [rh-0] (list 'menu-item "Anchor HEAD"
                                 'egg-log-buffer-anchor-head
                                 :visible '(egg-commit-at-point)))
    (define-key map [sp2] '("--"))
    (define-key map [reflog] (list 'menu-item "Show Ref History (Reflog)"
                                   'egg-log-buffer-reflog-ref
                                   :visible '(egg-ref-at-point)))
    (define-key map [rm-ref] (list 'menu-item "Remove Ref "
                                   'egg-log-buffer-rm-ref
                                   :visible '(egg-ref-at-point)))
    (define-key map [cb] (list 'menu-item "Create New Branch"
                               'egg-log-buffer-create-new-branch
                               :visible '(egg-commit-at-point)))
    (define-key map [co-dh] (list 'menu-item "Detach HEAD and Checkout"
                                  'egg-log-buffer-checkout-commit
                                  :enable ' (not (egg-head-at-point))
                                  :visible '(egg-commit-at-point)))
    (define-key map [sp1] '("--"))
    (define-key map [sb] (list 'menu-item "Start New Branch"
                               'egg-log-buffer-start-new-branch
                               :visible '(egg-commit-at-point)))
    (define-key map [co] (list 'menu-item "Checkout Branch"
                               'egg-log-buffer-checkout-commit
                               :visible '(egg-head-at-point)))
    (define-key map [tag] (list 'menu-item "Tag (Lightweight)"
                                'egg-log-buffer-tag-commit
                                :visible '(egg-commit-at-point)))
    (define-key map [atag] (list 'menu-item "Tag (Annotated)"
                                 'egg-log-buffer-atag-commit
                                 :visible '(egg-commit-at-point)))
    map))

(defconst egg-log-buffer-commit-line-menu (egg-log-make-commit-line-menu))
(defconst egg-log-buffer-local-ref-menu (egg-log-make-commit-line-menu))
(defconst egg-log-buffer-remote-ref-menu (egg-log-make-commit-line-menu))
(defconst egg-log-buffer-remote-site-menu (egg-log-make-commit-line-menu))
(defconst egg-log-buffer-mode-commit-menu (egg-log-make-commit-line-menu))

(defun egg-log-commit-line-menu-heading (pos &optional prefix)
  (let ((ref (get-text-property pos :ref))
        (references (egg-references-at-point pos))
        (commit (get-text-property pos :commit))
        (prefix (or prefix "(Git/Egg)")))
    (cond ((consp ref)
           (format "%s %s: %s" prefix
                   (cond ((eq (cdr ref) :head) "Branch")
                         ((eq (cdr ref) :remote) "Remote")
                         ((eq (cdr ref) :tag) "Tag"))
                   (car ref)))
          ((consp references)
           (concat "Ref: " prefix (car (last references))))
          ((stringp commit)
           (concat prefix " Commit: "
                   (file-name-nondirectory
                    (egg-pretty-short-rev commit))))
          (t "No Commit Here"))))

(defun egg-log-commit-mouse-menu-heading (&optional prefix)
  (let* ((event last-command-event)
         (window (posn-window (event-end event)))
         (buffer (and window (window-buffer window)))
         (pos (posn-point (event-end event))))
    (egg-log-commit-line-menu-heading pos prefix)))

(defun egg-log-popup-commit-line-menu-1 (event generic-menu)
  (let* ((window (posn-window (event-end event)))
         (buffer (and window (window-buffer window)))
         (pos (posn-point (event-end event)))
         menu keys cmd)
    (when (bufferp buffer)
      (save-excursion
        (with-current-buffer buffer
          (goto-char pos)
          (setq menu
                (nconc (list 'keymap
                             (egg-log-commit-line-menu-heading pos))
                       (cdr generic-menu)))
          (setq keys (progn
                       (force-mode-line-update)
                       (x-popup-menu event menu)))
          (setq cmd (and keys (lookup-key menu (apply 'vector keys))))
          (when (and cmd (commandp cmd))
            (call-interactively cmd)))))))

(defun egg-log-popup-local-ref-menu (event)
  (interactive "e")
  (egg-log-popup-commit-line-menu-1 event egg-log-buffer-local-ref-menu))

(defun egg-log-popup-remote-ref-menu (event)
  (interactive "e")
  (egg-log-popup-commit-line-menu-1 event egg-log-buffer-remote-ref-menu))

(defun egg-log-popup-remote-site-menu (event)
  (interactive "e")
  (egg-log-popup-commit-line-menu-1 event egg-log-buffer-remote-site-menu))

(defun egg-log-popup-commit-line-menu (event)
  (interactive "e")
  (egg-log-popup-commit-line-menu-1 event egg-log-buffer-commit-line-menu))

;; (define-key egg-log-local-ref-map [C-down-mouse-2] 'egg-popup-log-local-ref-menu)
;; (define-key egg-log-local-ref-map [C-mouse-2] 'egg-popup-log-local-ref-menu)

(defconst egg-log-buffer-menu (make-sparse-keymap "Egg (Git)"))

(define-key egg-log-buffer-mode-map
  [menu-bar egg-log-buffer-mode] (cons "Egg (Git)" egg-log-buffer-menu))

(let ((menu egg-log-buffer-menu))
  (define-key menu [quit] '(menu-item "Close History View" egg-quit-buffer))
  (define-key menu [refresh] '(menu-item "Refresh History View" egg-buffer-cmd-refresh))
  (define-key menu [pickaxe] '(menu-item "Search History for Changes"
                                         egg-search-changes))
  (define-key menu [goto] '(menu-item "Locate Line in File"
                                      egg-log-hunk-cmd-visit-file-other-window
                                      :enable (egg-hunk-at-point)))
  (define-key menu [sp3] '("--"))
  (define-key menu [commit] (list 'menu-item
                                  '(egg-log-commit-mouse-menu-heading "Operations on ")
                                  egg-log-buffer-mode-commit-menu
                                  :visible '(egg-commit-at-point)))
  (define-key menu [sp1] '("--"))
  (define-key menu [hs] '(menu-item "Hide/Show Details"
                                    egg-section-cmd-toggle-hide-show
                                    :enable (egg-navigation-at-point)))
  (define-key menu [hs-sub] '(menu-item "Hide/Show Details of Subsections"
                                        egg-section-cmd-toggle-hide-show-children
                                        :enable (egg-navigation-at-point)))
  (define-key menu [prev] '(menu-item "Goto Previous Ref" egg-log-buffer-prev-ref))
  (define-key menu [next] '(menu-item "Goto Next Ref" egg-log-buffer-next-ref))
  (define-key menu [Push] '(menu-item "Push To The Upstream" egg-push-upstream))
  (define-key menu [Pull] '(menu-item "Pull From The Upstream" egg-pull-upstream)))

(defconst egg-log-buffer-help-text
  (concat
   (egg-text "Common Key Bindings:" 'egg-help-header-2)
   "\n"
   (egg-pretty-help-text
    "\\<egg-log-buffer-mode-map>"
    "\\[egg-log-buffer-next-ref]:next thing  "
    "\\[egg-log-buffer-prev-ref]:previous thing  "
    "\\[egg-search-changes]:search history  "
    "\\[egg-push-upstream]:push to the upstream  "
    "\\[egg-pull-upstream]:pull from the upstream  "
    "\\[egg-status]:show repo's status  "
    "\\[egg-buffer-cmd-refresh]:redisplay  "
    "\\[egg-quit-buffer]:quit\n")
   (egg-text "Extra Key Bindings for a Commit line:" 'egg-help-header-2)
   "\n"
   (egg-pretty-help-text
    "\\<egg-log-commit-map>"
    "\\[egg-log-buffer-insert-commit]:load details  "
    "\\[egg-section-cmd-toggle-hide-show]:hide/show details "
    "\\[egg-section-cmd-toggle-hide-show-children]:hide sub-blocks  "
    "\\[egg-log-buffer-checkout-commit]:checkout  "
    "\\[egg-log-buffer-start-new-branch]:start new branch\n"
    "\\[egg-log-buffer-anchor-head]:anchor HEAD  "
    "\\[egg-log-buffer-tag-commit]:new tag  "
    "\\[egg-log-buffer-atag-commit]:new annotated tag  "
    "\\[egg-log-buffer-create-new-branch]:create branch  "
    "\\[egg-log-buffer-diff-revs]:diff vs HEAD (or BASE)\n"
    "\\[egg-log-buffer-merge]:merge to HEAD  "
    "\\[egg-log-buffer-rebase]:rebase HEAD  "
    "\\[egg-log-buffer-rebase-interactive]:rebase marked commits interactively"
    "\n"
    )
   (egg-text "Extra Key Bindings to prepare a (interactive) rebase:" 'egg-help-header-2)
   "\n"
   (egg-pretty-help-text
    "\\<egg-log-commit-map>"
    "\\[egg-log-buffer-mark]:mark as BASE "
    "\\[egg-log-buffer-mark-pick]:mark as picked  "
    "\\[egg-log-buffer-mark-squash]:mark as squashed  "
    "\\[egg-log-buffer-mark-edit]:mark as edited  "
    "\\[egg-log-buffer-unmark]:unmark\n")
   (egg-text "Extra Extra Key Bindings for a Ref:" 'egg-help-header-2)
   "\n"
   (egg-pretty-help-text
    "\\<egg-log-local-ref-map>"
    "\\[egg-log-buffer-rm-ref]:delete ref  "
    "\\[egg-log-buffer-push-to-local]:push ref to HEAD (or a local ref)  "
    "\\[egg-log-buffer-push-head-to-local]:push HEAD to ref\n"
    "\\[egg-log-buffer-push-to-remote]:push to remote  "
    "\\<egg-log-remote-branch-map>"
    "\\[egg-log-buffer-fetch-remote-ref]:fetch from remote\n")
   (egg-text "Extra Key Bindings for a Diff Block:" 'egg-help-header-2)
   "\n"
   (egg-pretty-help-text
    "\\<egg-log-diff-map>"
    "\\[egg-log-diff-cmd-visit-file-other-window]:visit version/line\n")
   (egg-text "References:" 'egg-help-header-2) "\n"
   (egg-text "local-branch" 'egg-branch-mono) " "
   (egg-text "lightweight-tag" 'egg-tag-mono) " "
   (egg-text "annotated-tag" 'egg-an-tag-mono) " "
   (egg-text "remote/" 'egg-remote-mono)
   (egg-text "branch" 'egg-branch-mono) " "
   (egg-text "  HEAD  " 'egg-log-HEAD-name) " "
   "\n"))


(defun egg-log-buffer-diff-revs (pos &optional do-pickaxe pickaxe)
  "Compare HEAD against commit at POS.
With C-u prefix, prompt for a string and restrict to diffs introducing/removing it.
With C-u C-u prefix, prompt for a regexp and restrict to diffs introducing/removing it.
With C-u C-u C-u prefix, prompt for a pickaxe mode.
A ready made PICKAXE info can be provided by the caller when called non-interactively."
  (interactive "d\np")
  (let* ((rev (egg-log-buffer-get-rev-at pos :symbolic))
         (mark (egg-log-buffer-find-first-mark (egg-log-buffer-base-mark)))
         (head-name (egg-branch-or-HEAD))
         (base (if mark (egg-log-buffer-get-rev-at mark :short) head-name))
         (pickaxe pickaxe)
         buf diff-info)
    (unless (and rev (stringp rev))
      (error "No commit here to compare against %s!" base))
    (when (string-equal rev base)
      (error "It's pointless to compare %s vs %s!" rev base))
    (unless pickaxe
      (setq pickaxe 
            (egg-buffer-prompt-pickaxe "restrict diffs" :string (egg-string-at-point)
                                       (> do-pickaxe 63)
                                       (> do-pickaxe 15)
                                       (> do-pickaxe 3))))
    (setq diff-info (egg-build-diff-info rev base nil pickaxe))
    (plist-put diff-info :command 
               (lambda (prefix)
                 (interactive "p")
                 (egg-re-do-diff nil
                                 (egg-buffer-prompt-pickaxe "restrict diffs" :string
                                                            (egg-string-at-point)
                                                            (> prefix 63)
                                                            (> prefix 15)
                                                            (> prefix 3))
                                 nil)))
    (setq buf (egg-do-diff diff-info))
    (pop-to-buffer buf)))

(defun egg-log-buffer-diff-upstream (pos &optional do-pickaxe)
  "Compare commit at POS against its upstream."
  (interactive "d\np")
  (let* ((ref (egg-ref-at-point pos :head))
         (mark (egg-log-buffer-find-first-mark (egg-log-buffer-base-mark)))
         (upstream (if mark (egg-log-buffer-get-rev-at mark :symbolic)))
         pickaxe buf diff-info)
    (unless (and ref (stringp ref))
      (error "No ref here to compare"))
    (when (equal ref upstream)
      (error "It's pointless to compare %s vs %s!" ref upstream))
    (unless (stringp upstream)
      (setq upstream (egg-read-ref (format "upstream of %s: " ref)
                                   (egg-upstream ref))))
    (setq pickaxe
          (egg-buffer-prompt-pickaxe "restrict diffs" :string (egg-string-at-point)
                                     (> do-pickaxe 63)
                                     (> do-pickaxe 15)
                                     (> do-pickaxe 3)))
    (setq diff-info (egg-build-diff-info upstream ref nil pickaxe t))
    (plist-put diff-info :command 
               (lambda (prefix)
                 (interactive "p")
                 (egg-re-do-diff nil
                                 (egg-buffer-prompt-pickaxe "restrict diffs" :string
                                                            (egg-string-at-point)
                                                            (> prefix 63)
                                                            (> prefix 15)
                                                            (> prefix 3))
                                 t)))
    (setq buf (egg-do-diff diff-info))
    (pop-to-buffer buf)))


(defun egg-insert-yggdrasil-with-decoration (ref &optional git-log-extra-options ignored)
  (egg-do-insert-n-decorate-yggdrasil ref git-log-extra-options))

(defun egg-do-insert-n-decorate-yggdrasil (refs &optional git-log-extra-options)
  (let* ((ref (cond ((stringp refs) 
                     (setq refs (list refs))
                     (car refs))
                    ((consp refs)
                     (car refs))))
         (mappings 
          (cdr (egg-git-to-lines 
                "--no-pager" "log" "-g" "--pretty=%H~%gd%n" 
                (format "--max-count=%d" (1+ egg-max-reflogs))
                (concat ref "@{now}"))))
         (beg (point)) 
         (head-name (egg-branch-or-HEAD))
         sha1-list sha1-reflog-alist sha1 reflog-time time reflog dup pair
         tmp)
    (setq tmp (save-match-data (mapcar (lambda (line) 
                                         (split-string line "~" t)) 
                                       mappings)))
    (setq mappings nil)
    (dolist (pair tmp)
      (when (and (stringp (nth 0 pair)) (stringp (nth 1 pair)))
        (push pair mappings)))
    (setq mappings (nreverse mappings))
    (save-match-data
      (dotimes (i (length mappings))
        (setq pair (pop mappings))
        (setq sha1 (car pair))
        (setq reflog-time (cadr pair))
        (setq reflog (format "%s@{%d}" ref (1+ i)))
        (string-match "{\\(.+\\)}\\'" reflog-time)
        (setq time (match-string-no-properties 1 reflog-time))
        (put-text-property 0 (length reflog) :reflog (substring-no-properties reflog) reflog)
        (put-text-property 0 (length reflog) 'face 'egg-reflog-mono reflog)
        (put-text-property 0 (length reflog) :time time reflog)
        (setq dup (assoc sha1 sha1-reflog-alist))
        (if dup
            (setcdr dup (cons reflog (cdr dup)))
          (add-to-list 'sha1-list sha1)
          (add-to-list 'sha1-reflog-alist (list sha1 reflog)))))

    (egg-run-git-log (nconc refs sha1-list) 
                     (append '("--graph" "--topo-order") git-log-extra-options))

    (goto-char beg)
    (egg-decorate-log egg-log-commit-map
                      egg-log-local-branch-map
                      egg-log-local-ref-map
                      egg-log-remote-branch-map
                      egg-log-remote-site-map
                      sha1-reflog-alist)))


(defun egg-build-log-closure (refs file-name buf help &optional single-mom &rest closure-items)
  "Show the commit DAG of REF-NAME.
if SINGLE-MOM is non-nil, only show the first parent.
if FILE-NAME is non-nil, restrict the logs to the commits modifying FILE-NAME."
  (let* ((ref-name (cond ((stringp refs) (setq refs (list refs)) (car refs))
                         ((consp refs) (car refs))))
         (egg-internal-current-state
          (egg-repo-state (if (invoked-interactively-p) :error-if-not-git)))
         (default-directory (egg-work-tree-dir 
                             (egg-git-dir (invoked-interactively-p))))
         (description (concat (egg-text "history scope: " 'egg-text-2)
                              (if ref-name 
                                  (egg-text ref-name 'egg-term)
                                (egg-text "all refs" 'egg-term))))
         paths decorating-func)
    (with-current-buffer buf
      (when single-mom
        (setq single-mom (list "--first-parent")))
      (when file-name
        (setq paths (list file-name)))
      (setq decorating-func
            (if (and (null file-name) ref-name)
                #'egg-insert-yggdrasil-with-decoration
              #'egg-insert-logs-with-full-decoration))
      (set
       (make-local-variable 'egg-internal-log-buffer-closure)
       (append (list :description description
                     :closure
                     `(lambda ()
                        (,decorating-func (list ,@refs) (list ,@single-mom) (list ,@paths))))
               closure-items))
      (when (and (memq :log egg-show-key-help-in-buffers) help)
        (plist-put egg-internal-log-buffer-closure :help help))
      egg-internal-log-buffer-closure)))

(defun egg-log-interactive ()
  (let ((level (prefix-numeric-value current-prefix-arg))
        (head-name (egg-branch-or-HEAD))
        (pickup (egg-string-at-point))
        ref)
    (cond ((> level 15) ;; ask
           (setq ref (egg-read-ref "show history of: " (or pickup head-name) t))
           (if (equal ref "") (setq ref nil))
           (list (if (and (not (equal head-name ref))
                          (y-or-n-p (format "combine history with %s? " head-name)))
                     (list ref head-name)
                   ref)
                 (y-or-n-p "only show 1st parent? ")))
          ((> level 3) ;; all refs
           (list nil))
          (t ;; default head
           (list head-name)))))

(defun egg-log (ref-name &optional single-mom)
  "Show the commit DAG of REF-NAME."
  (interactive (egg-log-interactive))
  (let* ((egg-internal-current-state
          (egg-repo-state (if (invoked-interactively-p) :error-if-not-git)))
         (default-directory (egg-work-tree-dir 
                             (egg-git-dir (invoked-interactively-p))))
         (buf (egg-get-log-buffer 'create)))
    (egg-build-log-closure ref-name nil buf egg-log-buffer-help-text single-mom
                           :command 'egg-log)
    (egg-log-buffer-redisplay buf 'init)
    (cond (egg-switch-to-buffer (switch-to-buffer buf))
          (t (pop-to-buffer buf)))))


;;;========================================================
;;; file history
;;;========================================================
(define-egg-buffer file-log "*%s-file-log@%s*"
  (egg-log-style-buffer-mode 'egg-file-log-buffer-mode
                             "Egg-FileHistory"
                             egg-log-buffer-mode-map
                             'egg-file-log-buffer-mode-hook))


(defvar egg-rev-file-buffer-closure nil)

(defun egg-grok-n-map-single-hunk-buffer (header-end prefix-len prefix-mapping)
  (let* ((inhibit-read-only t)
         (prefix (make-string prefix-len ? )) ;; start with no-change
         (range (list :type (cdr (assoc prefix prefix-mapping)) :beg nil :end nil))
         ranges-list line-start)
    (delete-region (point-min) header-end)
    (goto-char (point-min))
    (plist-put range :beg (point))
    (while (not (eobp))
      (setq line-start (buffer-substring-no-properties (point) (+ (point) prefix-len)))
      (delete-region (point) (+ (point) prefix-len))
      (unless (equal line-start prefix) ;; keep going if it's same prefix
        (plist-put range :end (point))
        (setq ranges-list (cons range ranges-list))
        (setq prefix line-start)
        (setq range (list :type (cdr (assoc prefix prefix-mapping))
                          :beg (point) :end nil)))
      (forward-line 1)
      (goto-char (line-beginning-position)))
    ranges-list))

(defun egg-decorate-single-hunk-buffer (ranges-list mode)
  (funcall mode)
  (dolist (range ranges-list)
    (let* ((beg (plist-get range :beg))
           (end (plist-get range :end))
           (type (plist-get range :type))
           (ov (make-overlay beg end)))
      (overlay-put ov 'evaporate t)
      (overlay-put ov 'face (cdr (assq type '((add . egg-add-bg)
                                              (del . egg-del-bg))))))))

(defun egg-file-log-walk-show-buffer ()
  (let ((pos (point))
        (log-buffer (current-buffer))
        (dir (egg-work-tree-dir))
        (repo (egg-repo-name))
        (git-name (car (plist-get egg-internal-log-buffer-closure :paths)))
        (rev-file-buffer (plist-get egg-internal-log-buffer-closure :rev-file-buffer))
        (inhibit-read-only inhibit-read-only)
        sha1 short-sha1 mode cc-diff ranges-list)
    (setq sha1 (egg-commit-at-point))
    (setq short-sha1 (and sha1 (egg-short-sha1 sha1)))
    (setq mode (assoc-default git-name auto-mode-alist 'string-match))
    (unless (and (bufferp rev-file-buffer) (buffer-live-p rev-file-buffer))
      (setq rev-file-buffer (get-buffer-create (concat "*egg@" git-name "*")))
      (plist-put egg-internal-log-buffer-closure :rev-file-buffer rev-file-buffer))
    (with-current-buffer rev-file-buffer
      (setq default-directory dir)
      (setq inhibit-read-only t)
      (erase-buffer)
      (egg-git-show-file t git-name sha1 "-U1000000000")
      ;; (egg-git-ok t "--no-pager" "show" "--patience" "-U1000000000" sha1 "--" git-name)
      (rename-buffer (concat "*" repo ":" short-sha1 "@" git-name "*"))
      (set (make-local-variable 'egg-rev-file-buffer-closure)
           (list :sha1 sha1 :path git-name :work-tree dir))
      (goto-char (point-min))
      (save-match-data
        (re-search-forward "^@@\\(@\\)?.+@@\\(@\\)?\n")
        (setq cc-diff (and (match-beginning 1) (match-beginning 2))) ;; the delta is a cc diff
        (setq ranges-list 
              (egg-grok-n-map-single-hunk-buffer
               (match-end 0) (if cc-diff 2 1)
               (if cc-diff '(("  " . keep)
                             ("++" . add)
                             ("+ " . add)
                             (" +" . add)
                             ("--" . del)
                             ("- " . del)
                             (" -" . del)
                             ("+-" . bad)
                             ("-+" . bad))
                 '((" " . keep)
                   ("+" . add)
                   ("-" . del))))))
      (egg-decorate-single-hunk-buffer ranges-list mode)
      (set-buffer-modified-p nil)
      (setq buffer-read-only t)
      (put-text-property (point-min) (point-max) :commit sha1))
    (display-buffer rev-file-buffer t)))

(defun egg-file-log-walk-rev-next ()
  (interactive)
  (egg-buffer-cmd-next-block :commit)
  (egg-file-log-walk-show-buffer))

(defun egg-file-log-walk-rev-prev ()
  (interactive)
  (egg-buffer-cmd-prev-block :commit)
  (egg-file-log-walk-show-buffer))

(defun egg-file-log-walk-current-rev ()
  (interactive)
  (when (egg-commit-at-point)
    (egg-file-log-walk-show-buffer)))

(defun egg-log-buffer-simple-redisplay (buffer &optional init)
  (with-current-buffer buffer
    (egg-generic-display-logs egg-internal-log-buffer-closure init)))

(defconst egg-file-log-help-text
  (concat
   (egg-text "Common Key Bindings:" 'egg-help-header-2) "\n"
   (egg-pretty-help-text
    "\\<egg-log-buffer-mode-map>"
    "\\[egg-log-buffer-next-ref]:next thing  "
    "\\[egg-log-buffer-prev-ref]:previous thing  "
    "\\[egg-status]:show repo's status  "
    "\\[egg-buffer-cmd-refresh]:redisplay  "
    "\\[egg-quit-buffer]:quit\n" )
   (egg-text "Extra Key Bindings for a Commit line:" 'egg-help-header-2) "\n"
   (egg-pretty-help-text
    "\\<egg-secondary-log-commit-map>"
    "\\[egg-log-locate-commit]:locate commit in history  "
    "\\[egg-log-buffer-insert-commit]:load details  "
    "\\[egg-section-cmd-toggle-hide-show]:hide/show details  "
    "\\[egg-section-cmd-toggle-hide-show-children]:hide sub-blocks\n"
    "\\[egg-log-buffer-anchor-head]:anchor HEAD  "
    "\\[egg-log-buffer-checkout-commit]:checkout  "
    "\\[egg-log-buffer-start-new-branch]:start new branch  "
    "\\[egg-log-buffer-create-new-branch]:create branch\n"
    "\\[egg-log-buffer-tag-commit]:new tag  "
    "\\[egg-log-buffer-atag-commit]:new annotated tag\n"
    )
   (egg-text "Extra Key Bindings for a Diff Block:" 'egg-help-header-2) "\n"
   (egg-pretty-help-text
    "\\<egg-log-diff-map>"
    "\\[egg-log-diff-cmd-visit-file-other-window]:visit version/line\n")
   ))

(defun egg-file-log (file-name &optional all)
  "Show the commits in the current branch's DAG that modified FILE-NAME.
if ALL is not-nil, then do not restrict the commits to the current branch's DAG."
  (interactive (list (buffer-file-name) current-prefix-arg))
  (unless (and file-name (file-exists-p file-name))
    (error "File does not exist: %s" file-name))
  (let ((egg-internal-current-state
         (egg-repo-state (if (invoked-interactively-p) :error-if-not-git)))
        (default-directory (egg-work-tree-dir 
                            (egg-git-dir (invoked-interactively-p))))
        (buffer (egg-get-file-log-buffer 'create))
        (head-name (egg-branch-or-HEAD))
        (title (concat (egg-text "history of " 'egg-text-2) (egg-text file-name 'egg-term)))
        ref help single-mom)
    (egg-build-log-closure (if all nil head-name) 
                           file-name buffer egg-file-log-help-text single-mom
                           :title title
                           :paths (list (egg-file-git-name file-name))
                           :command `(lambda (&optional all)
                                       (interactive "P")
                                       (egg-file-log ,file-name all)))
    (egg-log-buffer-simple-redisplay buffer 'init)
    (cond (egg-switch-to-buffer (switch-to-buffer buffer))
          (t (pop-to-buffer buffer)))))

;;;========================================================
;;; commit search
;;;========================================================
(defconst egg-query:commit-commit-map
  (let ((map (make-sparse-keymap "Egg:LogQueryCommit")))
    (set-keymap-parent map egg-secondary-log-commit-map)
    (define-key map (kbd "=") 'egg-query:commit-buffer-diff-revs)
    ;;
    map))



(defun egg-query:commit-buffer-diff-revs (pos prefix)
  (interactive "d\np")
  (let* ((rev (egg-log-buffer-get-rev-at pos :short))
         (mark (egg-log-buffer-find-first-mark (egg-log-buffer-base-mark)))
         (head-name (egg-branch-or-HEAD))
         (base (if mark (egg-log-buffer-get-rev-at mark :short) head-name))
         (pickaxe (plist-get egg-internal-log-buffer-closure :pickaxe))
         (file (nth 1 (plist-get egg-internal-log-buffer-closure :paths)))
         buf diff-info)
    (unless (and rev (stringp rev))
      (error "No commit here to compare against %s!" base))
    (when (string-equal rev base)
      (error "It's pointless to compare %s vs %s!" rev base))
    (setq diff-info (egg-build-diff-info rev base file pickaxe nil))
    (plist-put diff-info :command
               (if file `(lambda () (egg-re-do-diff ,file nil nil))
                 (lambda (prefix)
                   (interactive "p")
                   (egg-re-do-diff nil (egg-buffer-prompt-pickaxe "restrict diffs" :string
                                                                  (egg-string-at-point)
                                                                  (> prefix 15)
                                                                  (> prefix 3)
                                                                  t)
                                   nil))))
    (pop-to-buffer (egg-do-diff diff-info))))

(defun egg-do-locate-commit (sha1)
  (let ((buf (egg-get-log-buffer 'create))
        (head-name (egg-branch-or-HEAD))
        (short-sha1 (egg-short-sha1 sha1))
        pos)
    (setq short-sha1 (egg-short-sha1 sha1))
    (with-current-buffer buf
      (set (make-local-variable 'egg-internal-log-buffer-closure)
           (list :description
                 (concat (egg-text "history scope: " 'egg-text-2)
                         (egg-text head-name 'egg-term)
                         (egg-text " and " 'egg-text-2)
                         (egg-text short-sha1 'egg-term))
                 :closure
                 `(lambda ()
                    (egg-insert-logs-with-full-decoration (list :locate ,head-name ,sha1)))))
      (egg-log-buffer-redisplay buf)
      (setq pos (point-min))
      (while (and pos
                  (not (equal (get-text-property pos :commit) sha1)))
        (setq pos (next-single-property-change pos :commit))))
    (pop-to-buffer buf)
    (egg-log-buffer-goto-pos pos)
    (recenter)))

(defun egg-log-locate-commit (pos)
  "Relocate the commit at POS back to the full history in the log buffer."
  (interactive "d")
  (egg-do-locate-commit (get-text-property pos :commit)))

(defun egg-query:commit-buffer-rerun (buffer &optional init)
  (interactive (list (current-buffer)))
  (with-current-buffer buffer
    (plist-put egg-internal-log-buffer-closure :title
               (egg-text "History Search" 'egg-branch))
    (egg-generic-display-logs egg-internal-log-buffer-closure init)))

(define-egg-buffer query:commit "*%s-query:commit@%s*"
  (egg-log-style-buffer-mode 'egg-query:commit-buffer-mode
                             "Egg-Query:Commit")
  (setq egg-buffer-refresh-func #'egg-query:commit-buffer-rerun)
  (run-mode-hooks 'egg-query:commit-buffer-mode-hook))

(defun egg-async-mark-log-buffer-commits (args log-buffer closure)
  "Run pickaxe as specified in ARGS asynchronously then mark the commits in LOG-BUFFER.
CLOSURE specifies how the commits will be marked."
  (egg-async-0-args
   (list (lambda (log-buffer closure)
           (let ((all-commits (plist-get closure :commits))
                 (matched-mark (plist-get closure :matched-mark))
                 (unmatched-mark (plist-get closure :unmatched-mark))
                 (commits (save-match-data 
                            (goto-char (point-min))
                            (re-search-forward "EGG-GIT-OUTPUT:\n")
                            (split-string (buffer-substring-no-properties 
                                           (match-end 0)
                                           (point-max))
                                          "\n" t)))
                 pos wins)
             (with-current-buffer log-buffer
               (dolist (commit all-commits)
                 (egg-buffer-goto-section commit)
                 (egg-log-buffer-do-mark (point) (if (member commit commits) 
                                                     matched-mark
                                                   unmatched-mark)))
               (setq pos (point)))
             (setq wins (get-buffer-window-list log-buffer))
             (when (consp wins)
               (dolist (win wins)
                 (set-window-point win pos)))))
         log-buffer closure)
   (nconc (list "--no-pager" "log" "--pretty=%H" "--no-color")
          args)))

(defun egg-log-buffer-mark-commits-matching (level &optional default-search-term)
  "Mark commits between HEAD and the commit under POINT for rebase.
Prompt user for a search term and the type of match (string, regex or line).
For each commits between the commit under POINT and HEAD, if the commit introduced
or removed the term, then mark the commit as EDIT for the up-comming interactive
rebase. Otherwise mark the commit as PICK."
  (interactive (list (prefix-numeric-value current-prefix-arg)
                     (egg-string-at-point)))
  (let* ((end-rev (egg-branch-or-HEAD))
         (start-rev (egg-commit-at-point))
         (revs (concat start-rev ".." end-rev))
         (all-commits (egg-git-to-lines "--no-pager" "log" "--pretty=%H" revs))
         (pickaxe-term (egg-buffer-prompt-pickaxe "mark commits" :string default-search-term
                                                  (> level 15) (> level 3) t))
         (args (cond ((stringp pickaxe-term) (list "-S" pickaxe-term))
                     ((and (consp pickaxe-term) (memq :regexp pickaxe-term))
                      (list  "--pickaxe-regex" "-S" (car pickaxe-term)))
                     ((and (consp pickaxe-term) (memq :line pickaxe-term))
                      (list "-G" (car pickaxe-term))))))
    (setq args (nconc args (list revs)))
    (egg-async-mark-log-buffer-commits args (current-buffer)
                                       (list :matched-mark (egg-log-buffer-edit-mark)
                                             :unmatched-mark (egg-log-buffer-pick-mark)
                                             :commits all-commits))))

(defun egg-async-insert-n-decorate-query-logs (args)
  (let* ((closure egg-internal-log-buffer-closure)
         (fetched-data (and closure (plist-get closure :fetched-data)))
         (beg (point)))
    (cond ((null fetched-data)
           (insert "\t" (egg-text "Please be patient! Searching in background..." 'egg-text-2))
           (egg-async-0-args 
            (list (lambda (log-buffer closure) 
                    (let ((output (save-match-data 
                                    (goto-char (point-min))
                                    (re-search-forward "EGG-GIT-OUTPUT:\n")
                                    (split-string (buffer-substring-no-properties 
                                                   (match-end 0)
                                                   (point-max))
                                                  "\n" t))))
                      (plist-put closure :fetched-data
                                 (if output output "Nothing found!!!"))
                      (egg-refresh-buffer log-buffer)))
                  (current-buffer) closure)
            (nconc (list "--no-pager" "log" "--pretty=oneline" "--decorate=full" "--no-color")
                   args)))

          ((stringp fetched-data)
           (insert fetched-data "\n"))

          ((consp fetched-data)
           (dolist (line fetched-data)
             (insert line "\n"))
           (goto-char beg)
           (egg-decorate-log egg-query:commit-commit-map
                             egg-query:commit-commit-map
                             egg-query:commit-commit-map
                             egg-query:commit-commit-map))
          (t (error "fetched-data is: %s" fetched-data)))
    beg))

(defun egg-do-search-file-changes (prefix default-term file-name search-action-format
                                          &optional do-all)
  (let* ((head-name (egg-branch-or-HEAD))
         (file-name (or file-name (buffer-file-name)))
         (short-name (file-name-nondirectory file-name))
         (search-action (format search-action-format short-name head-name))
         (pickaxe (egg-buffer-prompt-pickaxe search-action :string default-term
                                             (> prefix 15) (> prefix 3) t))
         (closure (egg-do-search-changes pickaxe file-name (and do-all (list "--all"))))) 
    (plist-put closure :command
               `(lambda (prefix default-term)
                  (interactive (list (prefix-numeric-value current-prefix-arg)
                                     (egg-string-at-point)))
                  (egg-do-search-file-changes prefix default-term 
                                              ,file-name
                                              ,search-action-format
                                              ,do-all)))
    closure))


(defun egg-search-file-changes (prefix &optional default-term file-name)
  "Search current file's history for changes introducing or removing a string
term, default to DEFAUL-TERM. The search is restricted to the current branch's history.
With C-u prefix, search for a regexp instead of a string.
With C-u C-u prefix, prompt the user for advanced search mode."
  (interactive (list (prefix-numeric-value current-prefix-arg)
                     (egg-string-at-point)))
  (egg-do-search-file-changes prefix default-term file-name "search %s's history in %s"))

(defun egg-search-file-changes-all (prefix &optional default-term file-name)
  "Search current file's history for changes introducing or removing a string
term, default to DEFAUL-TERM. The search is done on the full history.
With C-u prefix, search for a regexp instead of a string.
With C-u C-u prefix, prompt the user for advanced search mode."
  (interactive (list (prefix-numeric-value current-prefix-arg)
                     (egg-string-at-point)))
  (egg-do-search-file-changes prefix default-term file-name "search %s's full history"
                              'all))

(defun egg-search-changes (prefix default-term)
  "Search the current branch's history for changes introducing/removing a term.
DEFAULT-TERM is the default search term."
  (interactive (list (prefix-numeric-value current-prefix-arg)
                     (egg-string-at-point)))
  (let* ((mark (egg-log-buffer-find-first-mark (egg-log-buffer-base-mark)))
         (head-name (egg-branch-or-HEAD))
         (start-rev (if mark (egg-log-buffer-get-rev-at mark :short)))
         (revs (and start-rev (list (concat start-rev "^.." head-name))))
         (pickaxe (egg-buffer-prompt-pickaxe 
                   (if revs (concat "search " (car revs))
                     (format "search %s's history" head-name))
                   :string default-term 
                   (> prefix 15) (> prefix 3) t))
         closure)
    (setq closure (egg-do-search-changes pickaxe nil revs))
    (plist-put closure :command
               (lambda (prefix default-term)
                 (interactive (list (prefix-numeric-value current-prefix-arg)
                                    (egg-string-at-point)))
                 (egg-search-changes prefix default-term)))
    closure))



(defun egg-search-changes-all (prefix default-term)
  "Search entire history for changes introducing/removing a term.
DEFAULT-TERM is the default search term.
If called non-interactively, the caller can provide ready-made PICKAXE info
and a FILE-NAME. If FILE-NAME is non-nil then restrict the search to FILE-NAME's
history."
  (interactive (list (prefix-numeric-value current-prefix-arg)
                     (egg-string-at-point)))
  (let* ((pickaxe (egg-buffer-prompt-pickaxe "search entire history"
                                             :string default-term 
                                             (> prefix 15) (> prefix 3) t))
         closure)
    (setq closure (egg-do-search-changes pickaxe nil (list "--all")))
    (plist-put closure :command
               (lambda (prefix default-term)
                 (interactive (list (prefix-numeric-value current-prefix-arg)
                                    (egg-string-at-point)))
                 (egg-search-changes-all prefix default-term)))
    closure))

(defun egg-do-search-changes (pickaxe file-name &optional extras)
  "Pickaxe history for TERM.
TERM is specified by PICKAXE-TYPE to be either a string, a regexp or a line-matching regexp.
If CASE-INSENSITIVE is non nil, then regexp matching will ignore case.
If FILE-NAME is non nil then only search the file history instead of the repo's history.
EXTRAS is what ever arguments should be added to the git log command."
  (let* ((default-directory (egg-work-tree-dir (egg-git-dir t)))
         (git-file-name (if file-name (file-relative-name file-name)))
         (label-prefix (if git-file-name
                           (concat git-file-name "'s commits")
                         "Commits "))
         (buf (egg-get-query:commit-buffer 'create))
         (term (egg-pickaxe-term pickaxe))
         (highlight (egg-pickaxe-highlight pickaxe))
         (pickaxe-args (egg-pickaxe-to-args pickaxe))
         (label (egg-pickaxe-pick-item pickaxe
                                       (concat label-prefix " containing: ")
                                       (concat label-prefix " containing regexp: ")
                                       (concat label-prefix " with lines matching: ")))
         args desc func help closure)

    (setq args (append pickaxe-args extras (if git-file-name (list "--" git-file-name))))
    (setq desc (concat (egg-text label 'egg-text-2) (egg-text term 'egg-term)))
    (setq func `(lambda ()
                  (egg-async-insert-n-decorate-query-logs (list ,@args))
                  ))

    (with-current-buffer buf
      (set (make-local-variable 'egg-internal-log-buffer-closure)
           (list :description desc :closure func
                 :highlight highlight
                 :pickaxe pickaxe
                 :pickaxe-args pickaxe-args
                 :paths (when git-file-name (list "--" git-file-name))))
      (when (memq :query egg-show-key-help-in-buffers)
        (setq help egg-log-style-help-text))
      (if help (plist-put egg-internal-log-buffer-closure :help help))
      (setq closure egg-internal-log-buffer-closure)
      (egg-query:commit-buffer-rerun buf 'init))
    (pop-to-buffer buf)
    closure))

(defun egg-do-grep-commit (grep-info revs)
  "Grep commit's for words.
REVS are revision to search for or '--all'.
GREP-INFO is plist with
:regexp posix regular-expression to search for.
:author regular-expression to match the author's name.
:committer regular-expression to match the commiter's name.
:match-all if non-nil, then limits the commits to the ones which match all regexps instead
of at least one."
  (let* ((default-directory (egg-work-tree-dir (egg-git-dir t)))
         (buf (egg-get-query:commit-buffer 'create))
         (desc "")
         (op-name "or")
         (first-criterion t)
         regex args func help closure)
    
    (when (plist-get grep-info :match-all)
      (add-to-list 'args "--all-match")
      (setq op-name "and"))
    (when (setq regex (plist-get grep-info :author))
      (add-to-list 'args (concat "--author=" regex))
      (setq desc (concat desc (if first-criterion
                                  (egg-text "Commits" 'egg-text-2) 
                                (egg-text op-name 'egg-text-2))			 
                         (egg-text " with author: " 'egg-text-2)
                         (egg-text regex 'egg-term) "\n"))
      (setq first-criterion nil))
    (when (setq regex (plist-get grep-info :committer))
      (add-to-list 'args (concat "--committer=" regex))
      (setq desc (concat desc (if first-criterion
                                  (egg-text "Commits" 'egg-text-2) 
                                (egg-text op-name 'egg-text-2))			 
                         (egg-text " with commiter: " 'egg-text-2)
                         (egg-text regex 'egg-term) "\n"))
      (setq first-criterion nil))
    (when (setq regex (plist-get grep-info :regexp))
      (add-to-list 'args (concat "--grep=" regex))
      (setq desc (concat desc (if first-criterion
                                  (egg-text "Commits" 'egg-text-2) 
                                (egg-text op-name 'egg-text-2))			 
                         (egg-text " with message matching: " 'egg-text-2)
                         (egg-text regex 'egg-term) "\n"))
      (setq first-criterion nil))
    
    (setq args (nconc args revs))
    (setq func `(lambda ()
                  (egg-async-insert-n-decorate-query-logs (list ,@args))
                  ))

    (with-current-buffer buf
      (set (make-local-variable 'egg-internal-log-buffer-closure)
           (list :description desc :closure func
                 :grep-args args))
      (when (memq :query egg-show-key-help-in-buffers)
        (setq help egg-log-style-help-text))
      (if help (plist-put egg-internal-log-buffer-closure :help help))
      (setq closure egg-internal-log-buffer-closure)
      (egg-query:commit-buffer-rerun buf 'init))
    (pop-to-buffer buf)
    closure))

(defun egg-grep-commit (prefix term)
  "Grep files tracked by git."
  (interactive (list (prefix-numeric-value current-prefix-arg)
                     (egg-string-at-point)))
  (let (info)
    (setq info (list :regexp
                     (read-string "Search for commits with message matching: " term)))
    (when (> prefix 3)
      (plist-put info :author
                 (read-string "Search for commits with author: ")))
    (when (> prefix 15)
      (plist-put info :committer
                 (read-string "Search for commits with commiter: ")))
    (when (> (length info) 2)
      (if (y-or-n-p "limits commits to those matching ALL criteria? ")
          (plist-put info :match-all t)))
    (egg-do-grep-commit info nil)))

;;;========================================================
;;; reflog
;;;========================================================

(defun egg-reflog (ref &optional prefix)
  "Show commit DAG of BRANCH and its reflogs.
This is just an alternative way to launch `egg-log'"
  (interactive (list (egg-branch-or-HEAD) (prefix-numeric-value current-prefix-arg)))
  (let ((head-name (egg-branch-or-HEAD)))
    (egg-log 
     (delq nil
           (cond ((> prefix 15) 
                  (setq ref (egg-read-ref "show history of ref: " ref))
                  (list ref
                        (unless (equal head-name ref)
                          (when (and (y-or-n-p 
                                      (format "combine %s's history with %s? " 
                                              ref head-name)))
                            head-name))))
                 ((> prefix 3) 
                  (setq ref (egg-read-ref "show history of ref: " ref))
                  (list ref (unless (equal head-name ref) head-name)))
                 (t (list ref)))))))

(defun egg-log-buffer-reflog-ref (pos &optional prefix)
  "Show reflogs for the ref at POS"
  (interactive "d\np")
  (egg-reflog (egg-ref-at-point) prefix))

;;;========================================================
;;; stash
;;;========================================================
(defun egg-buffer-do-insert-stash (pos)
  (save-excursion
    (let ((stash (get-text-property pos :stash))
          (nav (get-text-property pos :navigation))
          (inhibit-read-only t)
          beg end)
      (goto-char pos)
      (goto-char (1+ (line-end-position)))
      (setq beg (point))
      (unless (egg--git-args t
                             (append '("stash" "show" "-p")
                                     egg-git-diff-options
                                     (list "--src-prefix=BASE:/" "--dst-prefix=WIP:/"
                                           stash)))
        (error "error calling git stash show %s!" stash))
      (setq end (point))
      (egg-delimit-section :stash stash beg end (1- beg) nil nav)
      (put-text-property beg end 'keymap egg-section-map)
      (egg-decorate-diff-section :begin beg
                                 :end end
                                 :src-prefix "BASE:/"
                                 :dst-prefix "WIP:/"
                                 :diff-map egg-log-diff-map
                                 :hunk-map egg-log-hunk-map)
      (goto-char beg)
      (setq end (next-single-property-change beg :diff))
;;;       (put-text-property beg (+ indent-column beg) 'face 'egg-diff-none)
;;;       (put-text-property (+  indent-column beg) (line-end-position)
;;; 			 'face 'egg-text-2)
      (forward-line 1)
      (set-buffer-modified-p nil))))

(defun egg-sb-buffer-do-unstash (cmd &rest args)
  (let ((default-directory (egg-work-tree-dir))
        (cmd (or cmd "pop")))
    (unless (egg-has-stashed-wip)
      (error "No WIP was stashed!"))
    (unless (egg-repo-clean)
      (unless (y-or-n-p (format "repo is NOT clean, still want to apply stash? "))
        (error "stash %s cancelled!" cmd)))
    (egg-status-buffer-handle-result (egg--git-stash-unstash-cmd t cmd args))))

(defun egg-sb-buffer-apply-stash (pos &optional prefix)
  "Apply the stash at POS."
  (interactive "d\np")
  (let* ((stash (get-text-property pos :stash))
         (args (list "--index" stash))
         (do-it t))
    (when (stringp stash)
      (cond ((and (> prefix 15)
                  (not (y-or-n-p (format "apply WIP %s with index? " stash))))
             (setq args (list stash)))
            ((< prefix 4)
             (setq do-it (y-or-n-p (format "apply WIP %s to repo? " stash)))))
      (when do-it
        (apply #'egg-sb-buffer-do-unstash "apply" args)))))

(defun egg-sb-buffer-pop-stash (&optional no-confirm)
  "Pop and apply the stash at POS."
  (interactive "P")
  (when (or no-confirm
            (y-or-n-p "pop and apply last WIP to repo? "))
    (egg-sb-buffer-do-unstash "pop" "--index")))

(defun egg-sb-buffer-drop-stash (pos &optional all)
  "Drop the stash at POS."
  (interactive "d\nP")
  (let ((stash (get-text-property pos :stash)))
    (unless stash
      (error "No stash here!!!"))
    (if all
        (error "Drop all stash not supported yet!")
      (when (y-or-n-p (format "delete %s? " stash)) 
        (egg-status-buffer-handle-result (egg--git-stash-drop-cmd (current-buffer) stash))))))

(defun egg-status-buffer-stash-wip (msg &optional include-untracked)
  "Stash current work-in-progress in workdir and the index.
MSG is the is the description for the WIP. Also stash untracked/unignored files
if INCLUDE-UNTRACKED is non-nil."
  (interactive "sshort description of this work-in-progress: \nP")
  (let ((default-directory (egg-work-tree-dir))
        (include-untracked (and include-untracked
                                (y-or-n-p "stash untracked files too? ")))
        res files action)
    (if (egg-repo-clean)
        (error "No WIP to stash")
      (setq res (if include-untracked
                    (egg--git-stash-save-cmd t "-u" msg)
                  (egg--git-stash-save-cmd t msg)))
      (when (egg-status-buffer-handle-result res)
        (egg-buffer-goto-section "stash-stash@{0}")))))


;;;========================================================
;;; annotated tag
;;;========================================================

;; (setenv "GPG_AGENT_INFO" "/tmp/gpg-peL1m4/S.gpg-agent:16429:1")
;; (getenv "GPG_AGENT_INFO")

(defun egg-tag-msg-create-tag (prefix gpg-uid text-beg text-end ignored name commit)
  (if gpg-uid				;; sign the tag
      (let ((egg--do-no-output-message (format "signed %s with tag '%s'" commit name))
            (gpg-agent-info (egg-gpg-agent-info 'set))
            (force (> prefix 3)))

        (unless gpg-agent-info
          (error "gpg-agent's info is unavailable! please set GPG_AGENT_INFO environment!"))

        (egg--async-create-signed-tag-cmd (egg-get-log-buffer)
                                          (buffer-substring-no-properties text-beg text-end)
                                          name commit gpg-uid force))
    (let ((egg--do-no-output-message (format "annotated %s with tag '%s'" commit name))
          (force (> prefix 3)))
      (egg-edit-buffer-do-create-tag name commit text-beg text-end force))))

(define-egg-buffer tag:msg "*%s-tag:msg@%s*"
  (egg-log-msg-mode)
  (setq major-mode 'egg-tag:msg-buffer-mode
        mode-name "Egg-Tag:Msg"
        mode-line-process "")
  (setq buffer-invisibility-spec nil)
  (run-mode-hooks 'egg-tag:msg-mode-hook))

(defun egg-create-annotated-tag (name commit-1 &optional gpg-uid)
  (let* ((git-dir (egg-git-dir))
         (default-directory (egg-work-tree-dir git-dir))
         (buf (egg-get-tag:msg-buffer 'create))
         (commit (egg-git-to-string "rev-parse" "--verify" commit-1))
         (pretty (egg-pretty-short-rev commit))
         (inhibit-read-only inhibit-read-only)
         text-beg text-end)
    (or commit (error "Bad commit: %s" commit-1))
    (pop-to-buffer buf)
    (setq inhibit-read-only t)
    (erase-buffer)
    
    (insert (egg-text "Create Annotated Tag" 'egg-text-2) "  "
            (egg-text name 'egg-branch) "\n"
            (egg-text "on commit:" 'egg-text-1) " "
            (egg-text commit 'font-lock-constant-face) "\n"
            (egg-text "a.k.a.:" 'egg-text-1) " "
            (egg-text pretty 'font-lock-string-face) "\n"
            (egg-text "GPG-Signed by: " 'egg-text-1)
            (if gpg-uid (egg-text gpg-uid 'egg-text-2)
              (egg-text "None" 'egg-text-2)) "\n"
              (egg-text "Repository: " 'egg-text-1)
              (egg-text git-dir 'font-lock-constant-face) "\n"
              (egg-text "----------------- Tag Message (type C-c C-c when done) ---------------"
                        'font-lock-comment-face))
    (put-text-property (point-min) (point) 'read-only t)
    (put-text-property (point-min) (point) 'rear-sticky nil)
    ;;    (put-text-property (point-min) (point) 'keymap egg-tag-buffer-heading-map)
    (insert "\n")
    (setq text-beg (point-marker))
    (set-marker-insertion-type text-beg nil)
    (setq text-end (point-marker))
    (set-marker-insertion-type text-end t)

    (set (make-local-variable 'egg-log-msg-closure)
         (egg-log-msg-mk-closure-from-input
          (egg-log-msg-mk-closure-input #'egg-tag-msg-create-tag name commit-1)
          nil gpg-uid text-beg text-end nil))
    nil))
;;;========================================================
;;; minor-mode
;;;========================================================
(defun egg-file-toggle-blame-mode (save)
  "Toggle blame mode for the current-file.
With C-u prefix, do not ask for confirmaton before saving the buffer."
  (interactive "P")
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (when (and (buffer-modified-p)
             (or save
                 (y-or-n-p (format "save %s first? " (buffer-file-name)))))
    (save-buffer))
  (let (blame-was-on buffer-was-readonly)
    (mapc (lambda (ov)
            (when (overlay-get ov :blame)
              (setq buffer-was-readonly (plist-get (overlay-get ov :blame)
                                                   :buffer-read-only))
              (setq blame-was-on t)))
          (overlays-at (point)))
    (if blame-was-on
        (progn (egg-file-buffer-blame-off (current-buffer))
               (set-buffer-modified-p nil)
               (setq buffer-read-only buffer-was-readonly))
      (egg-file-buffer-blame-on (current-buffer)
                                :buffer-read-only buffer-read-only)
      (set-buffer-modified-p nil)
      (setq buffer-read-only t))))

(defun egg-file-diff (&optional ask)
  "Diff the current file in another window."
  (interactive "P")
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (let ((git-file (egg-buf-git-name))
        (src-rev (and ask (egg-read-rev "diff against: " (egg-branch-or-HEAD))))
        buf)
    (setq buf (egg-do-diff (egg-build-diff-info src-rev nil git-file)))
    (pop-to-buffer buf)))

(defun egg-file-checkout-other-version (&optional no-confirm)
  "Checkout HEAD's version of the current file.
With C-u prefix, ask for confirmation if the current file contains unstaged changes.
That's the NO-CONFIRM parameter in non-interactive use."
  (interactive "P")
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (let* ((file (file-name-nondirectory (buffer-file-name)))
         (file-modified (not (egg-file-committed (buffer-file-name))))
         (egg--do-no-output-message egg--do-no-output-message)
         (head-name (egg-branch-or-HEAD))
         rev)
    (when file-modified
      (unless (y-or-n-p (format "ignored uncommitted changes in %s? " file))
        (error "File %s contains uncommitted changes!" file)))
    (setq rev (egg-read-rev (format "checkout %s version: " file) head-name))
    (setq egg--do-no-output-message (format "checked out %s's contents from %s" file rev))
    (egg-file-buffer-handle-result
     (egg--git-co-files-cmd (egg-get-status-buffer) file rev))))

(defun egg-file-cancel-modifications (&optional no-confirm)
  "Checkout INDEX's version of the current file.
With C-u prefix, then ask for confirmation if the current file contains unstaged changes.
That's the CONFIRM-P paramter in non-interactive use."
  (interactive "P")
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (let* ((file (file-name-nondirectory (buffer-file-name)))
         (git-file (egg-buf-git-name))
         (file-modified (not (egg-file-updated (buffer-file-name))))
         (egg--do-no-output-message egg--do-no-output-message)
         rev)
    (unless git-file
      (error "%s doesn't seem to be tracked by git!" file))
    (when (and file-modified (not no-confirm))
      (unless (y-or-n-p (format "ignored unstaged changes in %s? " file))
        (error "File %s contains unstaged changes!" file)))
    (setq egg--do-no-output-message (format "checked out %s's contents from index" file))
    (egg-file-buffer-handle-result
     (egg--git-co-files-cmd (egg-get-status-buffer) file))))

(defun egg-start-new-branch (&optional force)
  "Start a new branch from HEAD."
  (interactive "P")
  (let* ((upstream (egg-current-branch))
         (rev (or (egg-get-symbolic-HEAD) (egg-HEAD)))
         (force (if force "-B" "-b"))
         name track)
    (setq name (read-string (format "start new branch from %s with name: " rev)))
    (setq track (if (and upstream
                         (y-or-n-p (format "should the branch '%s' track '%s'"
                                           name upstream)))
                    "--track"
                  "--no-track"))
    (egg-status-buffer-handle-result
     (egg--git-co-rev-cmd t rev force name track))))

(defvar egg-git-name nil)
(defvar egg-git-revision nil)
(make-variable-buffer-local 'egg-git-name)
(make-variable-buffer-local 'egg-git-revision)

(defun egg-file-get-other-version (file &optional rev prompt same-mode name)
  (let* ((mode (assoc-default file auto-mode-alist 'string-match))
         (git-dir (egg-git-dir))
         (dir (egg-work-tree-dir))
         (lbranch (egg-current-branch))
         (rbranch (and git-dir (or (egg-tracking-target lbranch)
                                   rev ":0")))
         (prompt (or prompt (format "%s's version: " file)))
         (rev (or rev (egg-read-rev prompt rbranch)))
         (canon-name (egg-file-git-name file))
         (git-name (concat rev ":" canon-name))
         (buf (get-buffer-create (concat "*" (if name (concat name ":" canon-name) git-name) "*"))))
    (with-current-buffer buf
      (setq default-directory dir)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (unless (egg-git-ok t "show" git-name)
          (error "Failed to get %s's version: %s" file rev))
        (when (and (functionp mode) same-mode)
          (funcall mode))
        (setq egg-git-name (egg-file-git-name file))
        (setq egg-git-revision rev)
        (put-text-property (point-min) (point-max) 'keymap
                           egg-file-index-map)
        (egg-set-global-mode "Egg")
        (set-buffer-modified-p nil)
        (setq buffer-read-only t)))
    buf))

(defun egg-file-version-other-window (&optional ask)
  "Show other version of the current file in another window."
  (interactive "P")
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (let ((buf (egg-file-get-other-version
              (buffer-file-name) (if ask nil ":0")
              (format "show %s's version:" (buffer-file-name))
              t)))
    (unless (bufferp buf)
      (error "Oops! can't get %s older version" (buffer-file-name)))
    (pop-to-buffer buf)))

(add-hook 'ediff-quit-hook 'egg--kill-ediffing-temp-buffers)

(defun egg-file-ediff (&optional ask-for-dst)
  "Compare, using ediff, the current file's contents in work-dir with vs a rev.
If ASK-FOR-DST is non-nil, then compare the file's contents in 2 different revs."
  (interactive "P")
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (let* ((file buffer-file-name)
         (short-file (file-name-nondirectory file))
         (dst (if ask-for-dst (egg-read-rev (format "(ediff) %s's newer version: "
                                                    short-file)
                                            (egg-branch-or-HEAD))))
         (src (egg-read-rev (if dst (format "(ediff) %s's %s vs older version: "
                                            short-file  dst)
                              (format "(ediff) %s vs version: " short-file)))))
    (egg--ediff-file-revs file dst nil src nil)))


(defun egg-resolve-merge-with-ediff (file)
  "Launch a 3-way ediff session to resolve the merge conflicts in FILE."
  (interactive "P")
  (let* ((short-file (file-name-nondirectory file))
         (ours ":2")
         (pretty-ours "ours")
         (theirs ":3")
         (pretty-theirs "theirs"))
    (if (egg-rebase-in-progress)
        (egg--ediff-file-revs file nil nil theirs pretty-theirs ours pretty-ours)
      (egg--ediff-file-revs file nil nil ours pretty-ours theirs pretty-theirs))))

(defun egg--ediff-file-revs (file-name new-rev new-rev-pretty parent-1 parent-1-pretty
                                       &optional parent-2 parent-2-pretty)
  (let* ((default-directory (egg-work-tree-dir))
         (git-file-name (egg-file-git-name file-name))
         (short-file (file-name-nondirectory file-name))
         (buffer-3 (if new-rev
                       (egg-file-get-other-version git-file-name new-rev nil t new-rev-pretty)
                     (find-file-noselect file-name)))
         (buffer-1 (egg-file-get-other-version git-file-name parent-1 nil t parent-1-pretty))
         (buffer-2 (and parent-2 
                        (egg-file-get-other-version git-file-name parent-2 nil t parent-2-pretty))))
    (when new-rev (egg--add-ediffing-temp-buffers buffer-3))
    (when parent-1 (egg--add-ediffing-temp-buffers buffer-1))
    (when parent-2 (egg--add-ediffing-temp-buffers buffer-2))

    (add-hook 'ediff-before-setup-hook #'egg--ediff-save-windows-config-hook)
    (add-hook 'ediff-quit-hook #'egg--ediff-restore-windows-config-hook)

    (cond ((and (bufferp buffer-1) (bufferp buffer-2) (bufferp buffer-3))
           (ediff-buffers3 buffer-2 buffer-1 buffer-3))
          ((and (bufferp buffer-1) (bufferp buffer-3))
           (ediff-buffers buffer-1 buffer-3) )
          (t (error "internal error: something wrong")))))

(defun egg--commit-do-ediff-file-revs (commit file)
  (let ((parents (egg-commit-parents commit)))
    (egg--ediff-file-revs file commit nil (car parents) nil (cadr parents) nil))
  ;; (let* ((default-directory (egg-work-tree-dir))
  ;; 	 parents)
  ;;   (with-temp-buffer
  ;;     (egg-git-ok t "--no-pager" "cat-file" "-p" commit)
  ;;     (goto-char (point-min))
  ;;     (while (re-search-forward (rx line-start 
  ;; 				    "parent " (group (= 40 hex-digit)) 
  ;; 				    (0+ space)
  ;; 				    line-end) nil t)
  ;; 	(add-to-list 'parents (match-string-no-properties 1)))
  ;;     (setq parents (mapcar (lambda (long)
  ;; 			      (substring-no-properties long 0 8))
  ;; 			    (nreverse parents)))
  ;;     (egg--ediff-file-revs file commit nil (car parents) nil (cadr parents) nil)))
  )

(defun egg--diff-do-ediff-file-revs (diff-info file)
  (let ((default-directory (egg-work-tree-dir))
        (src (plist-get diff-info :src-revision))
        (src-pretty (plist-get diff-info :src))
        (dst (plist-get diff-info :dst-revision))
        (dst-pretty (plist-get diff-info :dst)))
    (setq src (cond ((consp src) (egg-git-to-string "merge-base" (car src) (cdr src)))
                    ((stringp src) src)
                    ((null src)
                     (setq src-pretty (concat "INDEX:" file))
                     ":0")))
    (egg--ediff-file-revs file dst dst-pretty src src-pretty nil nil)))

(defconst egg-key-action-alist
  '((?m :merge-file "[m]erge current file" "Resolve merge conflict(s) in current file.")
    (?f :stage-file "stage current [f]ile" "Stage current file's changes")
    (?s :status "show repo's [s]tatus" "Browse the current status of the repo" )
    (?a :stage-all "stage [a]ll files" "Stage all current changes inside this repo.")
    (?r :rebase-continue "continue [r]rebase" "Continue with the current rebase session.")
    (?d :diff-file "[d]iff current file" "Compare the current file against the staged snapshot.")
    (?c :commit "[c]ommit staged changes" "Proceed to commit current staged changes onto HEAD.")
    (?y :sync "s[y]nc" "Synchronize branches and repos (push/fetch).")
    (?? :more-options "[?] more options" nil)
    (?b :new-branch "start new [b]ranch" "Create and switch to a new branch starting from HEAD.")
    (?q :quit "[q] quit" nil)))

(defconst egg-action-function-alist
  '((:merge-file	. egg-resolve-merge-with-ediff)
    (:stage-file	. egg-file-stage-current-file)
    (:status		. egg-status)
    (:stage-all		. egg-stage-all-files)
    (:rebase-continue	. egg-buffer-rebase-continue)
    (:diff-file		. egg-file-diff)
    (:commit		. egg-commit-log-edit)
    (:sync		. egg-log)
    (:new-branch	. egg-start-new-branch)
    (:quit		. (lambda () (interactive) (message "do nothing now! later.") (ding) nil))))

(defconst egg-action-menu-name-alist
  '((:merge-file	. "Resolve File's Merge Conflicts using Ediff")
    (:stage-file	. "Stage File's Modifications")
    (:status		. "View Project Status")
    (:stage-all		. "Stage All Project's Modifications")
    (:rebase-continue	. "Continue Rebase Session")
    (:diff-file		. "Show File's Modifications (Diff)")
    (:commit		. "Commit Staged Changes")
    (:sync		. "Show Project History")
    (:new-branch	. "Start a New Branch")))

(defconst egg-electrict-select-action-buffer
  (get-buffer-create "*Egg:Select Action*"))

(defun egg-select-action-run ()
  (interactive)
  (let (action)
    (save-excursion
      (with-current-buffer egg-electrict-select-action-buffer
        (beginning-of-line)
        (when (boundp 'egg-electric-in-progress-p)
          (setq action (get-text-property (point) :action))
          (if action
              (throw 'egg-select-action action)
            (ding)))))))

(defun egg-select-action-quit ()
  (interactive)
  (let (action)
    (save-excursion
      (with-current-buffer egg-electrict-select-action-buffer
        (beginning-of-line)
        (when (boundp 'egg-electric-in-progress-p)
          (throw 'egg-select-action nil))))))

(defconst egg-electric-select-action-map
  (let ((map (make-sparse-keymap "Egg:SelectAction")))
    (define-key map "q" 'egg-select-action-quit)
    (define-key map (kbd "RET") 'egg-select-action-run)
    (define-key map (kbd "SPC") 'egg-select-action-run)
    (define-key map (kbd "C-l") 'recenter)
    map))

(defun egg-electric-select-action (default banner &optional alternatives)
  (let ((egg-electric-in-progress-p t)
        (old-buffer (current-buffer))
        (buf egg-electrict-select-action-buffer)
        (action-alist
         (delq nil (mapcar (lambda (entry)
                             (if (and (cadddr entry)
                                      (or (null alternatives)
                                          (memq (cadr entry) alternatives)))
                                 (cons (cadr entry)
                                       (cadddr entry))))
                           egg-key-action-alist)))
        action default-entry beg)
    (setq default-entry (assq default action-alist))
    (setq action-alist
          (cons default-entry (remq default-entry action-alist)))
    (unwind-protect
        (setq action
              (catch 'egg-select-action
                (save-window-excursion
                  (with-current-buffer buf
                    (let ((inhibit-read-only t))
                      (erase-buffer)
                      (insert (egg-text "Select Action\n"
                                        'egg-section-title))
                      (insert (egg-text banner 'egg-text-1) "\n\n")
                      (insert (egg-text "select an action:" 'egg-text-1)
                              "\n\n")
                      (put-text-property (point-min) (point)
                                         'intangible t)
                      (setq beg (point))
                      (insert
                       (mapconcat
                        (lambda (entry)
                          (egg-prop (concat "- " (cdr entry))
                                    :action (car entry)
                                    'face 'egg-electrict-choice))
                        action-alist
                        "\n")
                       "\n")
                      (goto-char beg)
                      (set-buffer-modified-p nil)
                      (setq buffer-read-only t))
                    (setq major-mode 'egg-select-action)
                    (setq mode-name "Egg-Select")
                    (use-local-map egg-electric-select-action-map))
                  (Electric-pop-up-window egg-electrict-select-action-buffer)
                  (goto-char beg)
                  (Electric-command-loop 'egg-select-action
                                         "select next action> "))))
      (bury-buffer buf))
    (when (and action (symbolp action))
      action)))

(defsubst egg-guess-next-action (desc)
  (cond ((memq :file-has-merged-conflict desc) :merge-file)
        ((memq :file-is-modified desc) 	       :stage-file)
        ((memq :file-is-unmerged desc) 	       :stage-file)
        ((memq :wdir-has-merged-conflict desc) :status)
        ((memq :wdir-has-unmerged-files  desc) :stage-all)
        ((memq :wdir-is-modified desc)	       :stage-all)
        ((memq :rebase-in-progress desc)       :rebase-continue)
        ((memq :has-staged-changes desc)       :commit)
        (t     	    			       :sync)))

(defun egg-limit-alternative-actions (desc)
  (let ((alternatives (mapcar 'car egg-action-function-alist)))
    (unless (memq :file-has-merged-conflict desc)
      (setq alternatives (delq :merge-file alternatives)))
    (unless (memq :file-is-modified desc)
      (setq alternatives (delq :diff-file (delq :stage-file alternatives))))
    (when (or (not (memq :wdir-is-modified desc))
              (memq :wdir-has-merged-conflict desc))
      (setq alternatives (delq :stage-all alternatives)))
    (when (or (not (memq :rebase-in-progress desc))
              (memq :wdir-is-modified desc))
      (setq alternatives (delq :rebase-continue alternatives)))
    (when (or (memq :wdir-is-modified desc)
              (memq :rebase-in-progress desc)
              (not (memq :has-staged-changes desc)))
      (setq alternatives (delq :commit alternatives)))
    (when (or (memq :wdir-has-merged-conflict desc)
              (memq :rebase-in-progress desc))
      (setq alternatives (delq :new-branch alternatives)))
    (when (or (memq :wdir-is-modified desc)
              (memq :has-staged-changes desc)
              (memq :rebase-in-progress desc))
      (setq alternatives (delq :sync alternatives)))
    alternatives))



(defun egg-describe-state (state)
  (let* ((git-dir (plist-get state :gitdir))
         (current-file (buffer-file-name))
         (default-directory (egg-work-tree-dir git-dir))
         (file-git-name (and current-file (egg-file-git-name current-file)))
         (unstaged-files (plist-get state :unstaged))
         (staged-files (plist-get state :staged))
         (unmerged-files (plist-get state :unmerged))
         desc dummy)
    (when unstaged-files
      (setq desc (cons :wdir-is-modified desc)))

    (when staged-files
      (setq desc (cons :has-staged-changes desc)))

    (when unmerged-files
      (setq desc (cons :wdir-has-unmerged-files desc)))

    (when (plist-get state :rebase-step)
      (setq desc (cons :rebase-in-progress desc)))

    (when unstaged-files
      (with-temp-buffer
        (egg-git-ok t "diff")
        (setq dummy (buffer-string))
        (save-match-data
          (goto-char (point-min))
          (if (search-forward "\n++<<<<<<<" nil t)
              (setq desc (cons :wdir-has-merged-conflict desc)))))

      (when (and file-git-name (member file-git-name unstaged-files))
        (setq desc (cons :file-is-modified desc))
        (with-temp-buffer
          (egg-git-ok t "diff" file-git-name)
          (setq dummy (buffer-string))
          (save-match-data
            (goto-char (point-min))
            (if (search-forward "\n++<<<<<<<" nil t)
                (setq desc (cons :file-has-merged-conflict desc)))))
        (when (member file-git-name unmerged-files)
          (setq desc (cons :file-is-unmerged desc)))))
    desc))

(defsubst egg-build-key-prompt (prefix default alternatives)
  (let ((action-desc-alist (mapcar 'cdr egg-key-action-alist)))
    (concat prefix " default: "
            (nth 1 (assq default action-desc-alist))
            ". alternatives:  "
            (mapconcat 'identity
                       (mapcar (lambda (action)
                                 (nth 1 (assq action action-desc-alist)))
                               (remq default alternatives)) ", "))))

(defun egg-prompt-next-action (described-state)
  (let ((default (egg-guess-next-action described-state))
        (limited-alternatives (egg-limit-alternative-actions described-state))
        banner key action alternatives)
    (setq alternatives (list default :status :more-options))
    (while (null action)
      (setq key (read-key-sequence
                 (egg-build-key-prompt "next action?"
                                       default alternatives)))
      (setq key (string-to-char key))
      (setq action
            (if  (memq key '(?\r ?\n ?\ ))
                default
              (cadr (assq key egg-key-action-alist))))
      (when (eq action :more-options)
        (setq banner
              (format "%s %s\n%s %s\nINDEX %s"
                      (buffer-file-name)
                      (cond ((memq :file-has-merged-conflict described-state)
                             "contains conflicting merge-changes")
                            ((memq :file-is-modified described-state)
                             "contains unstaged changes")
                            (t "is not modified"))
                      (egg-work-tree-dir)
                      (cond ((memq :wdir-has-merged-conflict described-state)
                             "has files with conflicting merge changes")
                            ((memq :wdir-is-modified described-state)
                             "has files with unstaged changes")
                            (t "is clean"))
                      (cond ((memq :rebase-in-progress described-state)
                             "has unfinished rebase session")
                            ((memq :has-staged-changes described-state)
                             "contains staged changes ready to commit")
                            (t "is empty"))))
        (setq action (egg-electric-select-action default banner limited-alternatives)))
      (when (null action)
        (ding)))
    action))

(defun egg-next-action (&optional ask)
  "Guess and perform the next logical action.
With C-u prefix, ask for confirmation before executing the next-action."
  (interactive "P")
  (save-some-buffers nil 'egg-is-in-git)
  (let* ((state (egg-repo-state :unstaged :staged :error-if-not-git))
         (desc (egg-describe-state state))
         (current-prefix-arg nil)
         action default)
    (setq action (if (or ask egg-confirm-next-action)
                     (egg-prompt-next-action desc)
                   (egg-guess-next-action desc)))

    (call-interactively (cdr (assq action egg-action-function-alist)))))

(defun egg-file-next-action-menu-name ()
  (let* ((state (egg-repo-state :unstaged :staged :error-if-not-git))
         (desc (egg-describe-state state))
         (action (egg-guess-next-action desc)))
    (concat "Next Action: "
            (cdr (assq action egg-action-menu-name-alist)))))

(defun egg-file-next-action-menu-binding (&optional ignored)
  (let* ((state (egg-repo-state :unstaged :staged :error-if-not-git))
         (desc (egg-describe-state state))
         (action (egg-guess-next-action desc)))
    (cdr (assq action egg-action-function-alist))))

(defvar egg-minor-mode nil)
(defvar egg-minor-mode-map (make-sparse-keymap "Egg"))
(defvar egg-file-cmd-map (make-sparse-keymap "Egg:File"))

(defun egg-mode-key-prefix-set (var val)
  (define-key egg-minor-mode-map (read-kbd-macro val) egg-file-cmd-map)
  (custom-set-default var val))

(let ((map egg-file-cmd-map))
  (define-key map (kbd "a") 'egg-file-toggle-blame-mode)
  (define-key map (kbd "b") 'egg-start-new-branch)
  (define-key map (kbd "c") 'egg-commit-log-edit)
  (define-key map (kbd "e") 'egg-file-ediff)
  (define-key map (kbd "f") 'egg-find-tracked-file)
  (define-key map (kbd "g") 'egg-grep)
  (define-key map (kbd "i") 'egg-file-stage-current-file)
  (define-key map (kbd "l") 'egg-log)
  (define-key map (kbd "L") 'egg-reflog)
  (define-key map (kbd "h") 'egg-file-log)
  (define-key map (kbd "o") 'egg-file-checkout-other-version)
  (define-key map (kbd "s") 'egg-status)
  (define-key map (kbd "u") 'egg-file-cancel-modifications)
  (define-key map (kbd "v") 'egg-next-action)
  (define-key map (kbd "w") 'egg-commit-log-edit)
  (define-key map (kbd "/") 'egg-search-file-changes)
  (define-key map (kbd "?") 'egg-search-changes)
  (define-key map (kbd "=") 'egg-file-diff)
  (define-key map (kbd "~") 'egg-file-version-other-window)
  (define-key map (kbd "P") 'egg-push-upstream)
  (define-key map (kbd "j") 'egg-pull-upstream)
  )

(defconst egg-minor-mode-menu (make-sparse-keymap "Egg (Git)"))
(define-key egg-minor-mode-map [menu-bar egg-minor-mode-menu]
  (cons "Egg (Git)" egg-minor-mode-menu))

(let ((menu egg-minor-mode-menu))
  (define-key menu [Pull] '(menu-item "Pull From The Upstream" egg-pull-upstream))
  (define-key menu [push] '(menu-item "Push To The Upstream" egg-push-upstream))
  (define-key menu [reflog] '(menu-item "View RefLog" egg-reflog))
  (define-key menu [log] '(menu-item "View Project History" egg-log))
  (define-key menu [status] '(menu-item "View Project Status" egg-status))
  (define-key menu [blame] '(menu-item "Toggle Blame Mode" egg-file-toggle-blame-mode))
  (define-key menu [sp3] '("--"))
  (define-key menu [grep] '(menu-item "Search Project's Other Versions (grep)" egg-grep))
  (define-key menu [pickaxe] '(menu-item "Search File History" egg-file-log-pickaxe))
  (define-key menu [vother] '(menu-item "View File Other Version" egg-file-version-other-window))
  (define-key menu [filelog] '(menu-item "View File History" egg-file-log))
  (define-key menu [sp2] '("--"))
  (define-key menu [cother] '(menu-item "Checkout File's Other Version" egg-file-checkout-other-version))
  (define-key menu [ediff]
    '(menu-item "EDiff File (vs INDEX)" egg-file-ediff
                :enable (not (egg-file-updated (buffer-file-name)))))
  (define-key menu [diff]
    '(menu-item "Diff File (vs INDEX)" egg-file-diff
                :enable (not (egg-file-updated (buffer-file-name)))))
  (define-key menu [sp1] '("--"))
  (define-key menu [undo]
    '(menu-item "Cancel Modifications (revert to INDEX)" egg-file-cancel-modifications
                :enable (not (egg-file-updated (buffer-file-name)))))
  (define-key menu [commit]
    '(menu-item "Commit Staged Changes" egg-commit-log-edit
                :enable (not (egg-file-index-empty (buffer-file-name)))))
  (define-key menu [stage]
    '(menu-item "Stage File's Modifications" egg-file-stage-current-file
                :enable (not (egg-file-updated (buffer-file-name)))))
  (define-key menu [sp0] '("--"))
  (define-key menu [next]
    '(menu-item (egg-file-next-action-menu-name) egg-next-action
                :keys "\\[egg-next-action]"
                :filter egg-file-next-action-menu-binding)))

(defcustom egg-mode-key-prefix "C-x v"
  "Prefix keystrokes for egg minor-mode commands."
  :group 'egg
  :type 'string
  :set 'egg-mode-key-prefix-set)


(defvar egg-minor-mode-name " Git")

;;;###autoload
(defun egg-minor-mode (&optional arg)
  "Turn-on egg-minor-mode which would enable key bindings for
egg in current buffer.\\<egg-minor-mode-map>
\\[egg-start-new-branch] start a new branch from the current HEAD.
\\[egg-status] shows the repo's current status
\\[egg-commit-log-edit] start editing the commit message for the current staged changes.
\\[egg-file-stage-current-file] stage new changes of the current file
\\[egg-log] shows repo's history
\\[egg-file-checkout-other-version] checkout another version of the current file
\\[egg-file-cancel-modifications] delete unstaged modifications in the current file
\\[egg-next-action] perform the next logical action
\\[egg-file-diff] compare file with index or other commits
\\[egg-file-version-other-window] show other version of the current file.

\\{egg-minor-mode-map}
"
  (interactive "p")
  (setq egg-minor-mode (if (null arg)
                           (not egg-minor-mode)
                         (> arg 0)))
  (when egg-minor-mode
    (if (boundp 'vc-mode)
        (set 'vc-mode nil))
    (make-local-variable 'egg-minor-mode-name)
    (setq egg-minor-mode-name
          (intern (concat "egg-" (egg-git-dir) "-HEAD")))))

;;;###autoload
(defun egg-minor-mode-find-file-hook ()
  (when (egg-is-in-git)
    (save-match-data
      (if (not (string-match "\\`git version \\(1.[7-9]\\|2.[0-9]+\\)."
                             (shell-command-to-string
                              (concat egg-git-command " --version"))))
          (progn
            (message "can't find supported git")
            (remove-hook 'find-file-hook #'egg-minor-mode-find-file-hook)
            (message "disabled egg-minor-mode!"))
        (or (assq 'egg-minor-mode minor-mode-alist)
            (setq minor-mode-alist
                  (cons '(egg-minor-mode egg-minor-mode-name) minor-mode-alist)))
        (setcdr (or (assq 'egg-minor-mode minor-mode-map-alist)
                    (car (setq minor-mode-map-alist
                               (cons (list 'egg-minor-mode)
                                     minor-mode-map-alist))))
                egg-minor-mode-map)
        (make-local-variable 'egg-minor-mode)
        (egg-minor-mode 1)))))

;;;###autoload
(add-hook 'find-file-hook 'egg-git-dir)
;;;###autoload
(add-hook 'find-file-hook 'egg-minor-mode-find-file-hook)

;;;========================================================
;;; tool-tip
;;;========================================================


(defun egg-section-at (pos &optional object)
  (let* ((sect-prop (get-text-property pos :sect-type object))
         (sect (and sect-prop (get-text-property pos sect-prop object))))
    (unless sect
      (setq sect (egg-commit-at pos object)))
    (if (consp sect)
        (car sect)
      sect)))

(defun egg-file-name-at (pos &optional buffer)
  (when (bufferp buffer)
    (save-excursion
      (with-current-buffer buffer
        (goto-char pos)
        (ffap-file-at-point)))))

(defconst egg-cmd-help-text-fmt-alist
  '((egg-log-buffer-push-to-local egg-ref-or-commit-at "update another branch with %s")
    (egg-log-buffer-ff-pull egg-ref-or-commit-at "update HEAD with %s")
    (egg-log-buffer-push egg-rsite-at "push branches to remote %s")
    (egg-log-buffer-fetch-site egg-ref-at "(re)-fetch %s")
    (egg-log-buffer-rm-ref egg-ref-at "remove %s")
    (egg-log-buffer-reflog-ref egg-ref-at "show history (reflog) of %s")
    (egg-log-buffer-unmark egg-commit-at "unmark %s for upcoming rebase")
    (egg-log-buffer-mark-edit egg-commit-at "mark %s to be edited in upcoming rebase")
    (egg-log-buffer-mark-squash egg-commit-at "mark %s to be squashed in upcoming rebase")
    (egg-log-buffer-mark-pick egg-commit-at "mark %s to be picked in upcoming rebase")
    (egg-log-buffer-mark egg-commit-at "mark %s as BASE")
    (egg-log-buffer-rebase egg-commit-at "rebase HEAD to %s")
    (egg-log-buffer-anchor-head egg-ref-or-commit-at "anchor HEAD at %s")
    (egg-log-buffer-atag-commit egg-commit-at "create new annotated-tag at %s")
    (egg-log-buffer-tag-commit egg-commit-at "create new tag at %s")
    (egg-log-buffer-checkout-commit egg-ref-or-commit-at "checkout %s")
    (egg-log-buffer-start-new-branch egg-commit-at "start a new branch at %s")
    (egg-log-buffer-create-new-branch egg-commit-at "create a new branch at %s")
    (egg-log-buffer-insert-commit egg-commit-at "load %s's details")
    (egg-section-cmd-toggle-hide-show-children egg-section-at "hide/show %s's children's details")
    (egg-section-cmd-toggle-hide-show egg-section-at "hide/show %s's details")
    (egg-log-buffer-merge egg-ref-or-commit-at "merge %s to HEAD")
    (egg-buffer-cmd-navigate-next nil "next block")
    (egg-buffer-cmd-navigate-prev nil "prev block")
    (egg-diff-section-cmd-visit-file-other-window egg-section-at "open %s in other window")
    (egg-diff-section-cmd-visit-file egg-section-at "open %s")
    (egg-diff-section-cmd-ediff nil "view this delta in ediff")
    (egg-staged-section-cmd-ediff3 egg-section-at "view %s changes in ediff3")
    (egg-diff-section-cmd-unstage egg-section-at "unstage %s")
    (egg-diff-section-cmd-undo egg-section-at "delete theses changes from %s")
    (egg-unstaged-section-cmd-ediff egg-section-at "view this delta in ediff")
    (egg-diff-section-cmd-stage egg-section-at "stage %s")
    (egg-unmerged-section-cmd-ediff3 nil "view this conflict in ediff3")
    (egg-find-file-at-point egg-file-name-at "open %s")
    (egg-ignore-pattern-from-string-at-point egg-file-name-at "add a pattern matching %s to .gitignore file")
    (egg-status-buffer-stage-untracked-file egg-file-name-at "add %s to this repo")
    (egg-mouse-hide-show-cmd egg-section-at "hide/show %s's details")
    (egg-status-popup-staged-diff-menu egg-section-at "popup menu for %s")
    (egg-status-popup-unstaged-diff-menu egg-section-at "popup menu for %s")
    (egg-buffer-rebase-abort nil "abort rebase session")
    (egg-buffer-selective-rebase-skip nil "skip rebase session's current commit")
    (egg-buffer-selective-rebase-continue nil "continue rebase session")
    (egg-log-buffer-diff-revs egg-ref-or-commit-at "diff %s vs HEAD")
    ))

(defun egg-buffer-help-echo (window buffer pos)
  (if (and (bufferp buffer) (number-or-marker-p pos))
      (let ((keymap (get-text-property pos 'keymap buffer))
            seen-list func-name-alist)
        (when (keymapp keymap)
          (mapconcat
           (lambda (mapping)
             (if (consp mapping)
                 (let* ((key (car mapping))
                        (cmd (cdr mapping))
                        (howto (assq cmd egg-cmd-help-text-fmt-alist))
                        (func (nth 1 howto))
                        (fmt (nth 2 howto))
                        (key-str (format-kbd-macro (vector key)))
                        (name (or (cdr (assq func func-name-alist))
                                  (when (functionp func)
                                    (cdar (setq func-name-alist
                                                (cons (cons func
                                                            (funcall func pos buffer))
                                                      func-name-alist)))))))
                   (when (and (not (memq key seen-list)) (stringp fmt))
                     (if (and (stringp name) (= (length name) 40))
                         (setq name (substring name 0 8)))
                     (add-to-list 'seen-list key)
                     (format "%s - %s\n" key-str (format fmt name))))
               ""))
           keymap "")))))

(defun egg-push-upstream (called-interactively select &optional caller)
  "Push local branch to the upstream"
  (interactive "p\nP")
  (progn
    (message "GIT> pushing...")
    (egg--git-push-cmd (current-buffer))))

(defun egg-pull-upstream (called-interactively select &optional caller)
  "Pull remote branch to the local"
  (interactive "p\nP")
  (progn
    (message "GIT> pulling...")
    (egg-buffer-async-do nil "pull")))


;;;========================================================
;;; auto-update
;;;========================================================

(defvar egg-auto-update nil)

(defun egg-maybe-update-status ()
  "Pull up the status buffer for the current buffer if there is one."
  (let ((bufname (egg-buf-git-name)))
    (when (and egg-auto-update bufname)
      (egg-status nil nil)
      (egg-goto-block-filename bufname))))

(add-hook 'after-save-hook 'egg-maybe-update-status)

(defun egg-goto-block-filename (filename)
  (interactive "sFilename: ")
  (egg-goto-block-regexp (concat "\\(un\\)?staged-" filename)))


(defun egg-goto-block-regexp (nav-regexp)
  "Takes `nav-regexp' as regexp and moves cursor there."
  (let (nav-point)
    (goto-char (point-min))
    (let (prev-point)
      (while (not (eql prev-point (point)))
        (setq prev-point (point))
        (egg-buffer-cmd-navigate-next)
        (let ((prop-name (symbol-name (egg-navigation-at-point))))
          (if (string-match nav-regexp prop-name)
              (setq nav-point (point)
                    prev-point (point))))))
    nav-point))

(run-hooks 'egg-load-hook)
(provide 'egg)

;;; egg.el ends here
