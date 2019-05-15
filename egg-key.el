;;; egg-key.el --- Emacs Got Git - Emacs interface to Git

;; Copyright (C) 2012  Bogolisk
;;
;; Author: Bogolisk <bogolisk@gmail.com>
;; Created: 26 Oct 2012
;; Version: 1.0.2
;; Keywords: git, version control, release management
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
;;

(require 'egg-const)
(require 'egg-git)
(require 'edmacro)
(require 'rx)
(require 'electric)

(defun egg-key-set-prompt-key (var key)
  (custom-set-default var key)
  (define-key egg-hide-show-map (read-kbd-macro key) 'egg-key-prompt))

(defcustom egg-key-prompt-key "<kp-enter>"
  "Key to launch the (text based) electrict context menu."
  :group 'egg
  :set 'egg-key-set-prompt-key
  :type 'string)

(defcustom egg-key-select-key egg-key-prompt-key
  "Key to select a command in the electrict context menu."
  :group 'egg
  :type 'string)

(defcustom egg-key-quit-key "<kp-delete>"
  "Key to quit th eelectrict context menu."
  :group 'egg
  :type 'string)


(defsubst egg-key-prompt-key () (read-kbd-macro egg-key-prompt-key))
(defsubst egg-key-select-key () (read-kbd-macro egg-key-select-key))
(defsubst egg-key-quit-key () (read-kbd-macro egg-key-quit-key))

(defun egg-key-get-cmd-doc (cmd regex-name-alist &optional sub-no)
  (let ((case-fold-search nil)
        (doc (documentation cmd))
        lines line-1 desc re name re-name
        other-lines ctrl-u-lines)

    (if (stringp doc)
        (save-match-data
          (setq lines (split-string doc "\n"))
          (setq line-1 (car lines))
          (setq other-lines (cdr lines))

          (setq desc (egg-text line-1 'egg-text-1))
          (dolist (line other-lines)
            (when (string-match "\\`With \\(?:C-u \\)+prefix, ?\\(.+\\)\\'" line)
              (push (egg-text (match-string-no-properties 1 line) 'egg-text-1)
                    ctrl-u-lines)))

          (while regex-name-alist
            (setq re-name (car regex-name-alist))
            (setq regex-name-alist (cdr regex-name-alist))
            (setq re (car re-name))
            (setq name (cdr re-name))
            (when (stringp re)
              (when (and (stringp name) (string-match re desc))
                (setq desc (replace-match name t t desc sub-no)))
              (setq ctrl-u-lines
                    (mapcar (lambda (line)
                              (if (string-match re line)
                                  (replace-match name t t line sub-no)
                                line))
                            ctrl-u-lines)))))
      (setq desc "Undocumented"))
    (cons desc (nreverse ctrl-u-lines))))

(defconst egg-key-map-to-heading-alist
  '(("Egg:Section"          . "Operations on Section %s")
    ("Egg:Diff"       . "Operations on Diff %s")
    ("Egg:StagedDiff"      . "Operations on Staged Diff %s")
    ("Egg:WdirDiff"      . "Operations on WDir Diff %s")
    ("Egg:UnmergedWdirFile" . "Operations on UnMerged WDir File %s")
    ("Egg:UnstagedDiff"     . "Operations on UnStaged Diff %s")
    ("Egg:UnmergedDiff"     . "Operations on UnMerge Diff %s")
    ("Egg:Hunk"       . "Operations on Hunk %s")
    ("Egg:StagedHunk"       . "Operations on Staged Hunk %s")
    ("Egg:WdirHunk"       . "Operations on WDir Hunk %s")
    ("Egg:UnstagedHunk"     . "Operations on UnStaged Hunk %s")
    ("Egg:UnmergedHunk"     . "Operations on UnMerged Hunk %s")
    ("Egg:Conflict"         . "Operations on Conflict %s")
    ("Egg:LogCommit"        . "Operations on Commit %s")
    ("Egg:LogLocalBranch"   . "Operations on Local Branch %s")
    ("Egg:Stash"         . "Operations on Stash %s")))


(defun egg-key-get-menu-heading (map-name name &optional func)
  (let ((fmt (assoc-default map-name egg-key-map-to-heading-alist)))
    (when fmt
      (if (functionp func)
          (funcall func fmt name map-name)
        (setq fmt (egg-text fmt 'egg-section-title))
        (format fmt name)))))

;;(egg-key-get-cmd-doc #'egg-log-buffer-push-to-local "testing" "commit at POS")

(defun egg-key-make-alist (name map regex-name-alist &optional sub-no func)
  (let ((excepts (list (egg-key-prompt-key) (egg-key-select-key) (egg-key-quit-key)))
        key cmd desc heading alist)
    (dolist (mapping map)
      (cond ((and (consp mapping)
                  (characterp (setq key (car mapping)))
                  (commandp (setq cmd (cdr mapping)))
                  (not (assoc key alist))
                  (not (member key excepts)))

             ;; just add support for C-c C-c
             (setq desc (egg-key-get-cmd-doc cmd regex-name-alist sub-no))
             (push (nconc (list key cmd) desc) alist))
            ((and (stringp mapping) (null heading))
             (setq heading (egg-key-get-menu-heading mapping name func)))))
    (cons heading (nreverse alist))))

(defun egg-key-make-commit-heading (fmt name map-name)
  (let ((name (propertize name 'face 'egg-branch))
        (fmt (propertize fmt 'face 'egg-section-title)))
    (format fmt name)))

(defun egg-key-make-ref-heading (fmt name map-name short-sha1)
  (let ((name (propertize name 'face 'egg-branch))
        (short-sha1 (propertize short-sha1 'face 'egg-branch))
        (fmt (propertize fmt 'face 'egg-section-title)))
    (format fmt name short-sha1)))

(defun egg-key-make-branch-heading (fmt name map-name short-sha1)
  (egg-key-make-ref-heading
   (egg-text "Operations on Local Branch %s  (%s)" 'egg-section-title)
   name map-name short-sha1))

(defun egg-key-make-tag-heading (fmt name map-name short-sha1)
  (egg-key-make-ref-heading
   (egg-text "Operations on Tag %s  (%s)" 'egg-section-title)
   name map-name short-sha1))

(defun egg-key-make-rbranch-heading (fmt name map-name short-sha1)
  (egg-key-make-ref-heading
   (egg-text "Operations on Remote tracking Branch %s  (%s)" 'egg-section-title)
   name map-name short-sha1))

(defun egg-key-untie-section-fqn (fqn)
  (save-match-data (split-string fqn ":")))

(defun egg-key-make-hunk-heading (fmt parts map-name)
  (save-match-data
    (let ((section (nth 0 parts))
          (file (nth 1 parts))
          (hunk (nth 2 parts)))
      (format (egg-text "%s hunk %s of file %s" egg-section-title)
              section (egg-text hunk 'egg-diff-hunk-header)
              (egg-text file 'egg-diff-file-header)))))

(defun egg-key-make-diff-heading (fmt parts map-name)
  (save-match-data
    (let ((section (nth 0 parts))
          (file (nth 1 parts)))
      (format (egg-text "%s file %s" egg-section-title)
              section (egg-text file 'egg-diff-file-header)))))

;;(where-is-internal #'egg-log-locate-commit egg-secondary-log-commit-map)
;;(lookup-key egg-secondary-log-commit-map [3 3])

;; (egg-key-make-alist "053a3f32" egg-log-commit-map
;;         "\\([Cc]ommit\\|rev\\) at POS\\|the current section")

(defun egg-key-electric-throw-key (&optional prefix)
  (interactive "P")
  (when (boundp 'egg-key-electric-in-progress-p)
    (let ((keys (this-single-command-keys)))
      (throw 'egg-key-selection (cons keys prefix)))))

(defun egg-key-electric-throw-selection (&optional prefix)
  (interactive "P")
  (when (boundp 'egg-key-electric-in-progress-p)
    (let ((keys (get-text-property (point) :selected-key)))
      (unless (or prefix (= (length keys) 1))
        (setq prefix (list (lsh 1 (* (1- (length keys)) 2))))
        (setq keys (vector (aref keys 0))))
      (throw 'egg-key-selection (cons keys prefix)))))

(defun egg-key-electric-quit ()
  (interactive)
  (when (boundp 'egg-key-electric-in-progress-p)
    (throw 'egg-key-selection nil)))

(defun egg-key-make-electric-map (alist select-keys quit-keys)
  (let (map)
    (setq map (cons 'keymap
                    (mapcar (lambda (key)
                              (cons key 'egg-key-electric-throw-key))
                            (mapcar 'car alist))))
    (define-key map select-keys 'egg-key-electric-throw-selection)
    (define-key map quit-keys 'egg-key-electric-quit)
    map))

(defmacro with-egg-key-buffer (&rest body)
  "Evaluate BODY there like `progn' in the egg-key buffer.
See also `with-temp-file' and `with-output-to-string'."
  (declare (indent 0) (debug t))
  (let ((egg-key-buffer (make-symbol "egg-key-buffer"))
        (egg-key-dir (make-symbol "egg-key-dir")))
    `(let ((,egg-key-dir (egg-work-tree-dir))
           (,egg-key-buffer (get-buffer-create (concat "*egg-key:" (egg-git-dir) "*"))))
       (with-current-buffer ,egg-key-buffer
         (setq default-directory ,egg-key-dir)
         (unwind-protect
             (progn ,@body)
           )))))

(defun egg-key-insert-key-line (key desc-list)
  (let ((desc (car desc-list))
        (ctrl-u-lines (cdr desc-list))
        (key-string (propertize (edmacro-format-keys (string key)) 'face 'bold))
        (pos (point))
        (prefix "       ")
        (sep (egg-text "-" 'egg-low-prio-mono-text))
        (ctrl-u (egg-text "C-u " 'egg-low-prio-mono-text))
        (fmt-main " %3s %s %s\n")
        (fmt-ctrl-u "%s%s%s %s %s\n")
        (keys (vector key)))
    (insert (format fmt-main key-string sep desc))
    (put-text-property pos (point) :selected-key keys)
    (dolist (line ctrl-u-lines)
      (setq pos (point))
      (insert (format fmt-ctrl-u prefix ctrl-u key-string sep line))
      (setq keys (vconcat keys (list 21)))  ;; C-u
      (put-text-property pos (point) :selected-key keys)
      (setq prefix (concat prefix ctrl-u)))))

(defun egg-key-electric (heading alist)
  (let ((egg-key-electric-in-progress-p t)
        (old-buffer (current-buffer))
        key cmd desc selection
        beg pos map buf)
    (setq map (egg-key-make-electric-map alist
                                         (egg-key-select-key)
                                         (egg-key-quit-key)))
    (unwind-protect
        (setq selection
              (catch 'egg-key-selection
                (save-window-excursion
                  (with-egg-key-buffer
                   (setq buf (current-buffer))
                   (let ((inhibit-read-only t))
                     (erase-buffer)
                     (insert heading "\n\n")
                     (insert (egg-text "type menu key as shown or select a menu item\n"
                                       'egg-text-help))
                     (insert (egg-text egg-key-select-key 'egg-help-key)
                             (egg-text ": select menu item" 'egg-text-help) "\t"
                             (egg-text egg-key-quit-key 'egg-help-key)
                             (egg-text ": quit menu" 'egg-text-help) "\n\n")
                     (insert (egg-text "Commands:" 'egg-text-2) "\n\n")
                     (put-text-property (point-min) (point) 'intangible t)
                     (setq beg (point))
                     (dolist (mapping alist)
                       (setq key (nth 0 mapping)
                             cmd (nth 1 mapping)
                             desc (nth 2 mapping))
                       (egg-key-insert-key-line key (nthcdr 2 mapping)))
                     ;; (setq pos (point))
                     ;; (insert (format " %3s - %s\n"
                     ;;            (propertize (edmacro-format-keys (string key))
                     ;;            'face 'bold)
                     ;;            desc))
                     ;; (put-text-property pos (point) :selected-key (vector key)))
                     (goto-char beg)
                     (set-buffer-modified-p nil)
                     (setq buffer-read-only t))
                   (setq major-mode 'egg-key)
                   (setq mode-name "Egg-Key")
                   (use-local-map map))
                  (display-buffer buf t)
                  (Electric-pop-up-window buf)
                  (goto-char beg)
                  (Electric-command-loop 'egg-key-selection
                                         "select command> "))))
      (when (bufferp buf)
        (bury-buffer buf)))
    selection))

(defconst egg-subst-ref-in-doc-regex
  (rx (optional "the ")
      (or "ref or commit"
          "ref"
          "branch"
          "tag"
          "remote branch"
          "remote site")
      " at POS"))

(defconst egg-subst-commit-in-doc-regex
  (rx (optional "the ")
      (or (seq (or "ref or commit" "commit" "rev") " at POS")
          "current section")))

(defconst egg-subst-hunk-in-doc-regex
  (rx (optional "the ") (or "current section" "hunk enclosing POS" "hunk")))

(defconst egg-subst-file-in-doc-regex
  (rx (or (seq (optional "file ") "FILE")
          (seq "the file" (optional " at POS"))
          (seq (optional "the ") "current section"))
      word-end))

(defun egg-key-get-section-name (sect-type pos)
  (let ((section (if (symbolp sect-type)
                     (get-text-property pos sect-type)
                   (dolist-done (type sect-type value)
                     (setq value (get-text-property pos type))))))
    (cond ((symbolp section)
           (or (cdr (assq section '((unstaged . "WorkTree")
                                    (staged . "Index")
                                    (untracked . "Untracked Files")
                                    (repo . "Repository")
                                    (stash . "Stashed WIPs")
                                    (help . "Help")
                                    (:help . "Help"))))
               (symbol-name section)))
          ((and (stringp section) (= (length section) 40))
           (substring section 0 8))
          ((eq sect-type :diff)
           (concat (egg-key-get-section-name '(:section :commit :stash) pos)
                   ":"
                   (car section)))
          ((eq sect-type :hunk)
           (concat (egg-key-get-section-name :diff pos)
                   ":"
                   (car section)))
          ((stringp section)
           section)
          (t (error "Unexpected section: %s" section)))))

(defun egg-key-get-section (pos)
  (egg-key-get-section-name (or (get-text-property pos :sect-type)
                                :navigation) pos))

(defun egg-key-prompt (pos)
  (interactive "d")
  (let ((map (get-text-property pos 'keymap))
        (face (get-text-property pos 'face))
        (commit (egg-commit-at-point))
        (branch (egg-head-at-point pos))
        (tag (egg-tag-at-point pos))
        (remote-branch (egg-remote-at-point pos))
        (remote-site (egg-rsite-at pos))
        (sect-type (get-text-property pos :sect-type))
        (stash (get-text-property pos :stash))
        (section (egg-key-get-section pos))
        (line (save-excursion
                (goto-char pos)
                (buffer-substring-no-properties (line-beginning-position)
                                                (line-end-position))))
        (word (current-word))
        heading alist parts
        short name key-info selection)
    (setq short (and commit (substring commit 0 8)))
    (setq key-info
          (cond (branch
                 (egg-key-make-alist branch map
                                     (list (cons egg-subst-ref-in-doc-regex
                                                 (propertize branch 'face 'bold))
                                           (cons egg-subst-commit-in-doc-regex
                                                 (propertize short 'face 'bold)))
                                     nil
                                     `(lambda (fmt name map-name)
                                        (egg-key-make-branch-heading
                                         fmt name map-name ,short))))
                (tag
                 (egg-key-make-alist tag map
                                     (list (cons egg-subst-ref-in-doc-regex
                                                 (propertize tag 'face 'bold))
                                           (cons egg-subst-commit-in-doc-regex
                                                 (propertize tag 'face 'bold)))
                                     nil
                                     `(lambda (fmt name map-name)
                                        (egg-key-make-tag-heading
                                         fmt name map-name ,short))))
                (remote-branch
                 (egg-key-make-alist remote-branch map
                                     (list (cons egg-subst-ref-in-doc-regex
                                                 (propertize remote-branch 'face 'bold))
                                           (cons egg-subst-commit-in-doc-regex
                                                 (propertize remote-branch 'face 'bold))
                                           (cons "\\(the \\)?remote at POS"
                                                 (propertize remote-site 'face 'bold)))
                                     nil
                                     `(lambda (fmt name map-name)
                                        (egg-key-make-rbranch-heading
                                         fmt name map-name ,short))))
                ((and (eq sect-type :hunk) section)
                 (setq parts (egg-key-untie-section-fqn section))
                 (egg-key-make-alist
                  parts map
                  (list (cons egg-subst-hunk-in-doc-regex
                              (propertize (nth 2 parts) 'face 'egg-diff-hunk-header))
                        (cons egg-subst-file-in-doc-regex
                              (propertize (nth 1 parts) 'face 'egg-term)))
                  nil #'egg-key-make-hunk-heading))
                ((and (eq sect-type :diff) section)
                 (setq parts (egg-key-untie-section-fqn section))
                 (egg-key-make-alist
                  parts map
                  (list (cons egg-subst-file-in-doc-regex
                              (propertize (nth 1 parts) 'face 'egg-term))
                        (cons "SHA1" (propertize (nth 0 parts) 'face 'bold)))
                  nil #'egg-key-make-diff-heading))
                (commit
                 (egg-key-make-alist
                  short map (list (cons egg-subst-commit-in-doc-regex
                                        (propertize short 'face 'bold)))
                  nil #'egg-key-make-commit-heading))
                (stash
                 (egg-key-make-alist
                  stash map (list (cons "\\(?:the \\)?\\(stash at POS\\|current section\\)"
                                        (propertize stash 'face 'bold)))))
                ((and (eq sect-type :help) section)
                 (egg-key-make-alist
                  section map
                  (list (cons "\\(:?the \\)?current section"
                              (propertize section 'face 'egg-term)))))
                ((and (eq sect-type :section) section)
                 (egg-key-make-alist
                  section map
                  (list (cons "\\(:?the \\)?current section"
                              (propertize section 'face 'bold))
                        (cons "untracked file(s)\\|FILENAME"
                              (propertize line 'face 'bold))
                        (cons "the string at point"
                              (propertize (concat "\"" word "\"") 'face 'bold)))))
                (t (error "Can't find menu for cursor at %s" (point)))))
    (setq heading (car key-info)
          alist (cdr key-info))
    (setq selection (egg-key-electric heading alist))
    (let (current-prefix-arg cmd key)
      (cond ((consp selection)
             (setq current-prefix-arg (cdr selection))
             (setq key (car selection))
             (setq cmd (lookup-key map key))
             (unless cmd
               (error "can't find mapping for key: %c (%s)"
                      (car selection) (car selection)))
             (message "call %s" cmd)
             (command-execute cmd nil nil t))
            ((null selection)
             (message "later!")
             (ding))
            (t (error "wtf! selection is: %s" selection))))))

(define-key egg-hide-show-map (egg-key-prompt-key) 'egg-key-prompt)


(defconst egg-subst-file-in-doc-re
  (rx (optional "the ") (or "current file" "FILE" "FILE-NAME")))

(defun egg-insert-map-desc ()
  (interactive)
  (let* ((map-name (completing-read "map: " obarray 'boundp t nil nil))
         (map (symbol-value (intern map-name)))
         (alist (cdr (egg-key-make-alist
                      "Don't care" map
                      (list (cons egg-subst-file-in-doc-re
                                  "the current file")
                            (cons "\\(?:at\\|enclosing\\) POS" "under the cursor")))))
         key cmd desc ctl-u)
    (insert "@table @kbd\n" "@anchor{" map-name "}\n")
    (dolist (info (nreverse alist))
      (setq key (nth 0 info))
      (setq cmd (nth 1 info))
      (setq desc (nthcdr 2 info))
      (insert "@item " (string key) "\n")
      (insert (car desc) "\n")
      (insert "@ref{" (symbol-name cmd) "}\n" )
      (setq ctl-u "C-u")
      (dolist (line (cdr desc))
        (aset line 0 (upcase (aref line 0)))
        (insert "@item " ctl-u " " (string key) "\n" line "\n")
        (setq ctl-u (concat ctl-u " C-u"))))
    (insert "@end table")))

(defun egg-insert-cmd-desc ()
  (interactive)
  (let* ((cmd-name (completing-read "cmd: " obarray 'fboundp t nil nil))
         (cmd (symbol-function (intern cmd-name)))
         (desc (egg-key-get-cmd-doc cmd nil))
         (key ??)
         ctl-u)
    (insert "@item " (string key) "\n")
    (insert (car desc) "\n")
    (insert "@ref{" cmd-name "}\n" )
    (setq ctl-u "C-u")
    (dolist (line (cdr desc))
      (aset line 0 (upcase (aref line 0)))
      (insert "@item " ctl-u " " (string key) "\n" line "\n")
      (setq ctl-u (concat ctl-u " C-u")))))


;; (egg-key-get-cmd-doc 'egg-file-checkout-other-version (list (cons egg-subst-file-in-doc-re "the current file")))
