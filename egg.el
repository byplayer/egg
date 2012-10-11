;;; egg.el --- Emacs Got Git - Emacs interface to Git

;; Copyright (C) 2008  Linh Dang
;; Copyright (C) 2008  Marius Vollmer
;; Copyright (C) 2009  Tim Moore
;; Copyright (C) 2010  Alexander Prusov
;; Copyright (C) 2011-12 byplayer
;;
;; Author: Bogolisk <bogolisk@gmail.com>
;; Created: 19 Aug 2008
;; Version: 1.0.2
;; Keywords: git, version control, release management
;;
;; Special Thanks to
;;   Antoine Levitt, Bogolisk,
;;   Christian Köstlin
;;   Max Mikhanosha
;;   Aleksandar Simic
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

(require 'cl)
(require 'electric)
(require 'ediff)
(require 'ffap)
(require 'diff-mode)

(defconst egg-version "1.0.2")

(defgroup egg nil
  "Controlling Git from Emacs."
  :prefix "egg-"
  :group 'tools)

(defgroup egg-faces nil
  "Colourful Faces for Egg."
  :group 'egg)

(defface egg-header
  '((t :weight bold :inherit variable-pitch :height 1.1))
  "Face for generic headers.

Many Egg faces inherit from this one by default."
  :group 'egg-faces)

(defface egg-text-base
  '((((class color) (background light))
     :foreground "navy" :inherit variable-pitch)
    (((class color) (background dark))
     :foreground "SteelBlue" :inherit variable-pitch)
    (t))
  "Face for description text."
  :group 'egg-faces)

(defface egg-text-1
  '((t :inherit egg-text-base))
  "Face for description text."
  :group 'egg-faces)

(defface egg-text-help
  '((t :inherit egg-text-base :height 0.8))
  "Face for help text."
  :group 'egg-faces)

(defface egg-help-header-1
  '((t :inherit egg-text-base :weight bold))
  "Face for help text."
  :group 'egg-faces)

(defface egg-help-header-2
  '((((class color) (background light))
     :foreground "Black" :inherit egg-text-1 :height 0.9)
    (((class color) (background dark))
     :foreground "LightSteelBlue" :inherit egg-text-1 :height 0.9)
    (t :inherit egg-text-1))
  "Face for help text."
  :group 'egg-faces)

(defface egg-text-2
  '((t :inherit egg-text-base :height 1.1))
  "Face for description text."
  :group 'egg-faces)

(defface egg-text-3
  '((t :inherit egg-text-base :height 1.2))
  "Face for description text."
  :group 'egg-faces)

(defface egg-text-4
  '((t :inherit egg-text-base :height 1.4))
  "Face for description text."
  :group 'egg-faces)

(defface egg-electrict-choice
  '((((class color) (background light))
     :foreground "Blue" :inherit egg-text-1 :weight bold)
    (((class color) (background dark))
     :foreground "Cyan" :inherit egg-text-1 :weight bold)
    (t))
  "Face for description text."
  :group 'egg-faces)

(defface egg-section-title
  '((((class color) (background light))
     :foreground "DarkGoldenrod" :inherit egg-header :height 1.1)
    (((class color) (background dark))
     :foreground "PaleGreen" :inherit egg-header :height 1.1)
    (t :weight bold))
  "Face for generic header lines.

Many Egg faces inherit from this one by default."
  :group 'egg-faces)

(defface egg-branch
  '((((class color) (background light))
     :foreground "SkyBlue" :inherit egg-header :height 1.1)
    (((class color) (background dark))
     :foreground "Yellow" :inherit egg-header :height 1.1)
    (t :weight bold))
  "Face for the current branch."
  :group 'egg-faces)

(defface egg-log-buffer-mark
  '((((class color) (background light))
     :foreground "black" :inherit bold)
    (((class color) (background dark))
     :foreground "orchid1" :inherit bold)
    (t :weight bold))
  "Face to mark commit line in log-buffer."
  :group 'egg-faces)

(defface egg-branch-mono
  '((((class color) (background light))
     :foreground "SkyBlue" :inherit bold)
    (((class color) (background dark))
     :foreground "Yellow" :inherit bold)
    (t :weight bold))
  "Face for a branch."
  :group 'egg-faces)

(defface egg-tag-mono
  '((((class color) (background light))
     :foreground "GoldenRod" :inherit bold)
    (((class color) (background dark))
     :foreground "SkyBlue" :inherit bold)
    (t :weight bold))
  "Face for a tag."
  :group 'egg-faces)

(defface egg-an-tag-mono
  '((((class color) (background light))
     :foreground "DarkGoldenRod" :inherit bold)
    (((class color) (background dark))
     :foreground "LightGreen" :inherit bold)
    (t :weight bold))
  "Face for an annotated branch."
  :group 'egg-faces)

(defface egg-stash-mono
  '((((class color) (background light))
     :foreground "DarkGoldenRod" :inherit bold)
    (((class color) (background dark))
     :foreground "LightGreen" :inherit bold)
    (t :weight bold))
  "Face for a stash identifier."
  :group 'egg-faces)

(defface egg-reflog-mono
  '((((class color) (background light))
     :foreground "gray70" :inherit egg-stash-mono)
    (((class color) (background dark))
     :foreground "gray30" :inherit egg-stash-mono)
    (t :weight bold))
  "Face for a reflog identifier."
  :group 'egg-faces)

(defface egg-remote-mono
  '((((class color) (background light))
     :foreground "Orchid" :inherit bold)
    (((class color) (background dark))
     :foreground "DarkSalmon" :inherit bold)
    (t :weight bold))
  "Face for a remote."
  :group 'egg-faces)

(defface egg-term
  '((((class color) (background light))
     :foreground "SkyBlue" :inherit bold)
    (((class color) (background dark))
     :foreground "Yellow" :inherit bold)
    (t :weight bold))
  "Face for an important term."
  :group 'egg-faces)

(defface egg-help-key
  '((t :inherit egg-term :height 0.9))
  "Hilight Face in help text."
  :group 'egg-faces)

(defface egg-warning
  '((((class color) (background light))
     :foreground "Red" :inherit bold)
    (((class color) (background dark))
     :foreground "Orange" :inherit bold)
    (t :weight bold))
  "Face for a warning."
  :group 'egg-faces)

(defface egg-diff-file-header
  '((((class color) (background light))
     :foreground "SlateBlue" :inherit egg-header)
    (((class color) (background dark))
     :foreground "LightSlateBlue" :inherit egg-header)
    (t :weight bold))
  "Face for diff file headers."
  :group 'egg-faces)

(defface egg-unmerged-diff-file-header
  '((((class color) (background light))
     :foreground "Red" :inherit egg-diff-file-header)
    (((class color) (background dark))
     :foreground "Orange" :inherit egg-diff-file-header)
    (t :weight bold))
  "Face for unmerged diff file headers."
  :group 'egg-faces)

(defface egg-diff-hunk-header
  '((((class color) (background light))
     :background "grey85")
    (((class color) (background dark))
     :background "grey45"))
  "Face for diff hunk headers."
  :group 'egg-faces)

(defface egg-diff-add
  '((((class color) (background light))
     :foreground "blue1")
    (((class color) (background dark))
     :foreground "ForestGreen"))
  "Face for lines in a diff that have been added."
  :group 'egg-faces)

(defface egg-add-bg
  '((((class color) (background light))
     :background "medium sea green")
    (((class color) (background dark))
     :background "#375243"))
  "Background Face for lines in a diff that have been added."
  :group 'egg-faces)

(defface egg-del-bg
  '((((class color) (background light))
     :background "indian red")
    (((class color) (background dark))
     :background "IndianRed4"))
  "Background Face for lines in a diff that have been deleted."
  :group 'egg-faces)



(defface egg-diff-none
  '((((class color) (background light))
     :foreground "grey50")
    (((class color) (background dark))
     :foreground "grey70"))
  "Face for lines in a diff that are unchanged."
  :group 'egg-faces)

(defface egg-diff-del
  '((((class color) (background light))
     :foreground "red")
    (((class color) (background dark))
     :foreground "OrangeRed"))
  "Face for lines in a diff that have been deleted."
  :group 'egg-faces)

(defface egg-diff-conflict
  '((((class color) (background light))
     :foreground "Blue")
    (((class color) (background dark))
     :foreground "Orange"))
  "Face for lines in a diff that have been deleted."
  :group 'egg-faces)

(defface egg-graph
  '((((class color) (background light))
     :foreground "grey90")
    (((class color) (background dark))
     :foreground "grey30"))
  "Face for graph."
  :group 'egg-faces)

(defface egg-blame
  '((((class color) (background light))
     :background: "grey85" :foreground "black")
    (((class color) (background dark))
     :background "grey15" :foreground "white")
    (t :inherit region))
  "Face for blame header."
  :group 'egg-faces)

(defface egg-blame-culprit
  '((((class color) (background light))
     :inherit egg-text-2 :background "grey85" :foreground "grey35")
    (((class color) (background dark))
     :inherit egg-text-2 :background "grey15" :foreground "grey60")
    (t :inherit egg-blame))
  "Face for blame culprit."
  :group 'egg-faces)

(defface egg-blame-subject
  '((((class color) (background light))
     :inherit egg-blame-culprit :foreground "black")
    (((class color) (background dark))
     :inherit egg-blame-culprit :foreground "white")
    (t :inherit egg-blame))
  "Face for blame tag line."
  :group 'egg-faces)

;; (defface egg-log-HEAD
;;   '((t (:inherit region)))
;;   "Face to highlight HEAD in the log buffer."
;;   :group 'egg-faces)

(defface egg-log-HEAD-name
  '((((class color) (background light))
     (:box (:line-width 1 :color "black" :style nil)
	   :inherit egg-branch-mono))
    (((class color) (background dark))
     (:box (:line-width 1 :color "white" :style nil)
	   :inherit egg-branch-mono))
    (t (:box (:line-width 1 :color "yellow" :style nil)
	:inherit egg-branch-mono)))
  "Face to highlight HEAD in the log buffer."
  :group 'egg-faces)

(defcustom egg-buffer-hide-sub-blocks-on-start nil
  "Initially hide all sub-blocks."
  :group 'egg
  :type '(set (const :tag "Status Buffer"   egg-status-buffer-mode)
              (const :tag "Log Buffer"      egg-log-buffer-mode)
              (const :tag "File Log Buffer" egg-file-log-buffer-mode)
              (const :tag "Diff Buffer"     egg-diff-buffer-mode)
              (const :tag "Commit Buffer"   egg-commit-buffer-mode)))

(defcustom egg-buffer-hide-section-type-on-start nil
  "Initially hide sections of the selected type."
  :group 'egg
  :type '(set (cons :tag "Status Buffer"
                    (const :tag "Hide Blocks of type"
                           egg-status-buffer-mode)
                    (radio (const :tag "Section" :section)
                           (const :tag "File" :diff)
                           (const :tag "Hunk" :hunk)))
              (cons :tag "Commit Log Buffer"
                    (const :tag "Hide Blocks of type"
                           egg-commit-buffer-mode)
                    (radio (const :tag "Section" :section)
                           (const :tag "File" :diff)
                           (const :tag "Hunk" :hunk)))
              (cons :tag "Diff Buffer"
                    (const :tag "Hide Blocks of type"
                           egg-diff-buffer-mode)
                    (radio (const :tag "File" :diff)
                           (const :tag "Hunk" :hunk)))))

(defcustom egg-buffer-hide-help-on-start nil
  "Initially hide keybindings help."
  :group 'egg
  :type '(set (const :tag "Status Buffer"   egg-status-buffer-mode)
              (const :tag "Log Buffer"      egg-log-buffer-mode)
              (const :tag "File Log Buffer" egg-file-log-buffer-mode)
              (const :tag "Diff Buffer"     egg-diff-buffer-mode)
              (const :tag "Commit Buffer"   egg-commit-buffer-mode)))

(defcustom egg-log-HEAD-max-len 1000
  "Maximum number of entries when showing the history of HEAD."
  :group 'egg
  :type 'integer)

(defcustom egg-log-all-max-len 10000
  "Maximum number of entries when showing the history of HEAD."
  :group 'egg
  :type 'integer)

(defcustom egg-max-reflogs 10
  "Maximum number of reflogs displayed in the log buffer."
  :group 'egg
  :type 'integer)

(defcustom egg-confirm-next-action t
  "Always prompt for confirmation while guessing the next logical action ."
  :group 'egg
  :type 'boolean)

(defcustom egg-confirm-undo t
  "Always prompt for confirmation before removing delta from workdir."
  :group 'egg
  :type 'boolean)

(defcustom egg-status-buffer-sections '(repo unstaged staged untracked stash)
  "Sections to be listed in the status buffer and their order."
  :group 'egg
  :type '(repeat (choice (const :tag "Repository Info" repo)
                         (const :tag "Unstaged Changes Section" unstaged)
                         (const :tag "Staged Changes Section" staged)
                         (const :tag "Untracked/Unignored Files" untracked)
			 (const :tag "Stashed Work-in-Progess" stash))))


(defcustom egg-commit-buffer-sections '(staged unstaged untracked)
  "Sections to be listed in the status buffer and their order."
  :group 'egg
  :type '(repeat (choice (const :tag "Unstaged Changes Section" unstaged)
                         (const :tag "Staged Changes Section" staged)
                         (const :tag "Untracked/Unignored Files" untracked))))


(defcustom egg-refresh-index-in-backround nil
  "Whether to refresh the index in the background when emacs is idle."
  :group 'egg
  :type 'boolean)

(defcustom egg-enable-tooltip nil
  "Whether to activate useful tooltips, showing the local keymap at the point."
  :group 'egg
  :type 'boolean)

(defcustom egg-git-rebase-subdir "rebase-merge"
  "Name of the rebase's workdir.
Different versions of git have different names for this subdir."
  :group 'egg
  :type '(choice (const ".dotest-merge")
                 (const "rebase-merge")
                 string))

(defcustom egg-show-key-help-in-buffers
  '(:log :status :diff :file-log :query :stash)
  "Display keybinding help in egg special buffers."
  :group 'egg
  :type '(set (const :tag "Status Buffer"   :status)
              (const :tag "Log Buffer"      :log)
              (const :tag "File Log Buffer" :file-log)
              (const :tag "Diff Buffer"     :diff)
              (const :tag "Commit Buffer"   :commit)
	      (const :tag "Search Buffer"   :query)
              (const :tag "Stash Buffer"    :stash)))

(define-widget 'egg-quit-window-actions-set 'lazy
  "Custom Type for quit-window actions."
  :offset 4
  :format "%v"
  :type '(set :tag "Actions"
              (const :tag "Kill Buffer" kill)
              (const :tag "Restore Windows" restore-windows)))

(defcustom egg-quit-window-actions nil
  "Actions to perform upon quitting an egg special buffer."
  :group 'egg
  :type '(set (cons :format "%v" (const :tag "Status Buffer" egg-status-buffer-mode)
                    egg-quit-window-actions-set)
              (cons :format "%v"  (const :tag "Log (History) Buffer" egg-log-buffer-mode)
                    egg-quit-window-actions-set)
              (cons :format "%v"  (const :tag "Commit Log Buffer" egg-commit-buffer-mode)
                    egg-quit-window-actions-set)
              (cons :format "%v"  (const :tag "Diff Buffer" egg-diff-buffer-mode)
                    egg-quit-window-actions-set)
              (cons :format "%v"  (const :tag "File Log (History) Buffer" egg-file-log-buffer-mode)
                    egg-quit-window-actions-set)))


(defcustom egg-git-command "git"
  "Name or full-path to the git command.
Set this to the appropriate string in the case where `git' is not the
desirable way to invoke GIT."
  :group 'egg
  :type 'string)

(defcustom egg-cmd-select-special-buffer nil
  "If true, then select the special window invoked by the command.
Instead of just displaying it. Commands like egg-status, unless prefixed
with C-u, only display the special buffer but not selecting it. When
this option is true, invert the meaning of the prefix. I.e. the command
will select the window unless prefixed with C-u."
  :group 'egg
  :type 'boolean)

(defcustom egg-git-diff-options
  '("--patience" "--ignore-space-at-eol")
  "Extra options for git diff."
  :group 'egg
  :type '(set :tag "Extra Diff Options"
	      (radio :tag "Algorithm"
		     (const :tag "Patience" "--patience")
		     (const :tag "Historgram" "--histogram")
		     (const :tag "Minimal" "--minimal"))
	      (radio :tag "White Space"
		      (const :tag "Ignore Space at End-of-Line" 
			     "--ignore-space-at-eol")
		      (const :tag "Ignore Space Changes"
			     "--ignore-space-change")
		      (const :tag "Ignore All Space"
			     "--ignore-all-space"))))

(defcustom egg-git-diff-file-options-alist 
  '((c-mode "--patience" "--ignore-all-space")
    (emacs-lisp-mode "--patience" "--ignore-all-space")
    (text-mode "--histogram")
    (makefile-mode "--patience" "--ignore-space-at-eol"))
  "Extra options for when show diff of a file matching a major mode."
  :group 'egg
  :type '(repeat (cons :tag "File Diff"
		       (choice :tag "Mode"
			       (const :tag "C" c-mode)
			       (const :tag "C++" c++-mode)
			       (const :tag "Java" java-mode)
			       (const :tag "Text" text-mode)
			       (const :tag "ELisp" emacs-lisp-mode)
			       (const :tag "Lisp" lisp-mode)
			       (const :tag "Makefile" makefile-mode)
			       (const :tag "Python" python-mode)
			       (const :tag "Perl" perl-mode)
			       (symbol :tag "Other"))
		       (set :tag "Extra Options"
			    (radio :tag "Algorithm"
				    (const :tag "Patience" "--patience")
				    (const :tag "Historgram" "--histogram")
				    (const :tag "Minimal" "--minimal"))
			    (radio :tag "White Space"
				    (const :tag "Ignore Space at End-of-Line" 
					   "--ignore-space-at-eol")
				    (const :tag "Ignore Space Changes"
					   "--ignore-space-change")
				    (const :tag "Ignore All Space"
					   "--ignore-all-space"))))
		 ))

(defcustom egg-dummy-option nil
  "Foo bar"
  :group 'egg
  :type '(set (const :bold) (const :italic)))

(defvar egg-gpg-agent-info nil)
(defun egg-gpg-agent-info (&optional action-if-not-set)
  (or egg-gpg-agent-info
      (setq egg-gpg-agent-info
	    (let* ((file (and (file-readable-p "~/.gpg-agent-info")
			      (expand-file-name "~/.gpg-agent-info")))
		   (info (and file (egg-pick-file-contents 
				    file "^GPG_AGENT_INFO=\\(.+\\)$" 1)))
		   (env (getenv "GPG_AGENT_INFO"))
		   (info-list (and (stringp info) (save-match-data 
						    (split-string info ":" t))))
		   (socket (and info-list (car info-list)))
		   (agent-pid (and info-list (string-to-number (nth 1 info-list))))
		   (agent-attr (and agent-pid (process-attributes agent-pid)))
		   (agent-cmdline (and agent-attr (cdr (assq 'args agent-attr))))
		   agent-info)
	      (setq agent-info
		    (if (stringp env)
			env ;; trust the environment
		      (when (and info 
				 (file-exists-p socket)
				 (= (aref (nth 8 (file-attributes socket)) 0) ?s)
				 agent-attr
				 (save-match-data
				   (string-match "gpg-agent" agent-cmdline)))
			info)))
	      (when (and (not env) agent-info)
		(cond ((eq action-if-not-set 'set)
		       (setenv "GPG_AGENT_INFO" agent-info))
		      ((stringp action-if-not-set)
		       (if (y-or-n-p (format action-if-not-set agent-info))
			   (setenv "GPG_AGENT_INFO" agent-info)
			 (setq agent-info nil)))
		      ((null action-if-not-set)
		       ;; cancel everything!!!
		       (setq agent-info nil))
		      (t (error "What happened? (action-if-not-set = %s)"
				action-if-not-set))))
	      agent-info))))

;;;========================================================
;;; simple routines
;;;========================================================

(defsubst egg-unquote-posix-regexp (string)
  (while (string-match "\\\\[\\|()]" string)
    (setq string (concat (substring string 0 (match-beginning 0))
			 (substring string (1+ (match-beginning 0))))))
  string)


(defmacro invoked-interactively-p ()
  "wrapper for checking if the function was invoked interactively,
works around the deprecation of 'interactive-p' after Emacs 23.2"
  (if (> emacs-major-version 23)
      '(called-interactively-p 'interactive)
    (if (> emacs-minor-version 2)
	'(called-interactively-p 'interactive)
      '(interactive-p))))

(defmacro with-egg-debug-buffer (&rest body)
  "Evaluate BODY there like `progn' in the egg's debug buffer.
See also `with-temp-file' and `with-output-to-string'."
  (declare (indent 0) (debug t))
  (let ((egg-debug-buffer (make-symbol "egg-debug-buffer"))
	(egg-debug-dir (make-symbol "egg-debug-dir")))
    `(let ((,egg-debug-dir (egg-work-tree-dir))
	   (,egg-debug-buffer (get-buffer-create (concat "*egg-debug:" (egg-git-dir) "*"))))
       (with-current-buffer ,egg-debug-buffer
	 (setq default-directory ,egg-debug-dir)
         (unwind-protect
	     (progn ,@body)
           )))))

(defmacro with-egg-async-buffer (&rest body)
  "Evaluate BODY there like `progn' in the egg's async buffer.
See also `with-temp-file' and `with-output-to-string'."
  (declare (indent 0) (debug t))
  (let ((egg-async-buffer (make-symbol "egg-async-buffer"))
	(egg-async-dir (make-symbol "egg-async-dir")))
    `(let ((,egg-async-dir (egg-work-tree-dir))
	   (,egg-async-buffer (get-buffer-create (concat "*egg-async:" (egg-git-dir) "*"))))
       ;; FIXME: kill-buffer can change current-buffer in some odd cases.
       (with-current-buffer ,egg-async-buffer
	 (setq default-directory ,egg-async-dir)
         (unwind-protect
	     (progn ,@body)
           )))))

;; (cl-macroexpand '(with-egg-debug-buffer (do-something)))
;; (let* ((egg-debug-dir (egg-work-tree-dir))
;;        (egg-debug-buffer (get-buffer-create (concat "*egg-debug:" (egg-git-dir) "*"))))
;;   (with-current-buffer egg-debug-buffer 
;;     (setq default-directory egg-debug-dir)
;;     (unwind-protect 
;; 	(progn (do-something))
;;       (and (buffer-name egg-debug-buffer) 
;; 	   (kill-buffer egg-debug-buffer)))))


(defmacro egg-text (text face)
  "Format TEXT with face FACE at compile-time or run-time."
  (cond ((stringp text)
         (propertize text 'face (if (symbolp face) face
                                  (nth 1 face))))
        ((null text)
         `(propertize "<internal-bug>" 'face ,face))
        (t `(propertize ,text 'face ,face))))

;;(cl-macroexpand '(egg-text blah 'egg-text-3))

(defmacro egg-prop (text &rest prop)
  "Propertize TEXT with properties list PROP at compile-time or run-time."
  (if (stringp text)
      (apply 'propertize text
             (mapcar (lambda (sym)
                       (if (consp sym)
                           (nth 1 sym)
                         sym))
                     prop))
    `(propertize ,text ,@prop)))

(defsubst egg-string-at-point () (current-word t))

;;(defalias 'egg-string-at-point 'ffap-string-at-point)
(defalias 'egg-find-file-at-point 'find-file-at-point)

(defsubst egg-goto-line (line)
  (goto-char (point-min))
  (forward-line (1- line)))

(defsubst egg-prepend (str prefix &rest other-properties)
  "Make STR appear to have prefix PREFIX.
If OTHER-PROPERTIES was non-nil, apply it to STR."
  (setq prefix (concat prefix (substring str 0 1)))
  (setq str (apply 'propertize str other-properties))
  (put-text-property 0 1 'display prefix str)
  str)

(defsubst egg-commit-contents (rev)
  "Retrieve the raw-contents of the commit REV."
  (with-temp-buffer
    (call-process egg-git-command nil t nil "cat-file" "commit" rev)
    (buffer-string)))

(defsubst egg-commit-message (rev)
  "Retrieve the commit message of REV."
  (save-match-data
    (with-temp-buffer
      (call-process egg-git-command nil t nil "cat-file" "commit" rev)
      (goto-char (point-min))
      (re-search-forward "^\n")
      (buffer-substring-no-properties (match-end 0) (point-max)))))

(defun egg-commit-subject (rev)
  "Retrieve the commit subject of REV."
  (save-match-data
    (with-temp-buffer
      (call-process egg-git-command nil t nil "cat-file" "commit" rev)
      (goto-char (point-min))
      (re-search-forward "^\n")
      (buffer-substring-no-properties (match-end 0)
				      (if (or (re-search-forward "\n\n" nil t)
					      (re-search-forward "\n" nil t))
					  (match-beginning 0)
					(point-max))))))

(defsubst egg-cmd-to-string-1 (program args)
  "Execute PROGRAM and return its output as a string.
ARGS is a list of arguments to pass to PROGRAM."
  (with-temp-buffer
    (if (= (apply 'call-process program nil t nil args) 0)
        (buffer-substring-no-properties
         (point-min) (if (> (point-max) (point-min))
                         (1- (point-max)) (point-max))))))

(defsubst egg-cmd-to-string (program &rest args)
  "Execute PROGRAM and return its output as a string.
ARGS is a list of arguments to pass to PROGRAM."
  (egg-cmd-to-string-1 program args))


(defsubst egg-git-to-string (&rest args)
  "run GIT wih ARGS and return the output as a string."
  (egg-cmd-to-string-1 egg-git-command args))

(defsubst egg-cmd-ok (program buffer &rest args)
  "run PROGRAM with ARGS and insert output into BUFFER at point.
return the t if the exit-code was 0. if BUFFER was t then
current-buffer would be used."
  (= (apply 'call-process program nil buffer nil args) 0))

(defsubst egg-git-ok (buffer &rest args)
  "run GIT with ARGS and insert output into BUFFER at point.
return the t if the exit-code was 0. if BUFFER was t then
current-buffer would be used."
  (= (apply 'call-process egg-git-command nil buffer nil args) 0))

(defsubst egg-git-ok-args (buffer args)
  "run GIT with ARGS and insert output into BUFFER at point.
return the t if the exit-code was 0. if BUFFER was t then
current-buffer would be used."
  (= (apply 'call-process egg-git-command nil buffer nil args) 0))

(defun egg-git-show-file-args (buffer file rev args)
  (let* ((mode (assoc-default file auto-mode-alist 'string-match))
	 (extras (and mode (assoc-default mode egg-git-diff-file-options-alist 'eq))))
    (egg-git-ok-args buffer (append (list "--no-pager" "show")
				    extras
				    args
				    (list rev "--" file)))))

(defsubst egg-git-show-file (buffer file rev &rest args)
  (egg-git-show-file-args buffer file rev args))

(defsubst egg-git-region-ok (start end &rest args)
  "run GIT with ARGS and insert output into current buffer at point.
return the t if the exit-code was 0. The text between START and END
is used as input to GIT."
  (= (apply 'call-process-region start end egg-git-command t t nil args) 0))

(defsubst egg-wdir-clean () (egg-git-ok nil "diff" "--quiet"))
(defsubst egg-file-updated (file)
  (egg-git-ok nil "diff" "--quiet" "--" file))
(defsubst egg-file-committed (file)
  (egg-git-ok nil "diff" "--quiet" "HEAD" "--" file))
(defsubst egg-file-index-empty (file)
  (egg-git-ok nil "diff" "--quiet" "--cached" "--" file))
(defsubst egg-index-empty () (egg-git-ok nil "diff" "--cached" "--quiet"))

(defsubst egg-has-stashed-wip ()
  (egg-git-ok nil "rev-parse" "--verify" "-q" "stash@{0}"))


(defsubst egg-git-to-lines (&rest args)
  "run GIT with ARGS.
Return the output lines as a list of strings."
  (save-match-data
    (split-string (or (egg-cmd-to-string-1 egg-git-command args) "")
                  "[\n]+" t)))

(defsubst egg-git-to-string-list (&rest args)
  "run GIT with ARGS.
Return the output lines as a list of strings."
  (save-match-data
    (split-string (or (egg-cmd-to-string-1 egg-git-command args) "")
                  "[\n\t ]+" t)))

(defun egg-git-lines-matching (re idx &rest args)
  "run GIT with ARGS.
Return the output lines as a list of strings."
  (with-temp-buffer
    (when (= (apply 'call-process egg-git-command nil t nil args) 0)
      (let (lines)
        (save-match-data
          (goto-char (point-min))
          (while (re-search-forward re nil t)
            (setq lines (cons (match-string-no-properties idx) lines)))
          lines)))))

(defun egg-git-lines-matching-stdin (stdin re idx &rest args)
  "run GIT with ARGS.
Return the output lines as a list of strings."
  (with-temp-buffer
    (let (lines pos)
      (insert stdin)
      (setq pos (point-max))
      (when (= (apply 'call-process-region (point-min) (point-max)
		      egg-git-command nil t nil args) 0)
        (save-match-data
          (goto-char pos)
          (while (re-search-forward re nil t)
            (setq lines (cons (match-string-no-properties idx) lines)))
          lines)))))

(defun egg-git-lines-matching-multi (re indices &rest args)
  "run GIT with ARGS.
Return the output lines as a list of strings."
  (with-temp-buffer
    (when (= (apply 'call-process egg-git-command nil t nil args) 0)
      (let (lines matches)
        (save-match-data
          (goto-char (point-min))
          (while (re-search-forward re nil t)
            (setq matches nil)
            (dolist (idx indices)
              (when (match-beginning idx)
                (setq matches
                      (cons (cons idx (match-string-no-properties idx))
                            matches))))
            (setq lines (cons matches lines)))
          lines)))))

(defsubst egg-file-git-name (file)
  "return the repo-relative name of FILE."
  (car (egg-git-to-lines "ls-files" "--full-name" "--" file)))

(defsubst egg-buf-git-name (&optional buf)
  "return the repo-relative name of the file visited by BUF.
if BUF was nil then use current-buffer"
  (egg-file-git-name (file-truename (buffer-file-name buf))))

(defsubst egg-files-git-name (files)
  "return the repo-relative name for each file in the list of files FILES."
  (delete-dups
   (apply 'egg-git-to-lines "ls-files" "--full-name" "--" files)))

(defsubst egg-unmerged-files ()
  "return a list of repo-relative names for each unmerged files."
  (save-match-data
    (delete-dups
     (mapcar 'car
             (mapcar 'last
                     (mapcar
                      'split-string
                      (egg-git-to-lines "ls-files" "--full-name" "-u")))))))

(defsubst egg-local-branches ()
  "Get a list of local branches. E.g. (\"master\", \"wip1\")."
  (egg-git-to-lines "rev-parse" "--symbolic" "--branches"))

(defsubst egg-local-refs ()
  "Get a list of local refs. E.g. (\"master\", \"wip1\")."
  (egg-git-to-lines "rev-parse" "--symbolic" "--branches" "--tags"))

(defun egg-remote-branches (&optional raw)
  "Get a list of remote branches. E.g. (\"origin/master\", \"joe/fork1\")."
  (let ((lst (egg-git-to-lines "rev-parse" "--symbolic" "--remotes")))
    (if raw lst
      (mapcar (lambda (full-name)
                (let ((tmp (save-match-data (split-string full-name "/"))))
                  (cons (cadr tmp) (car tmp))))
              lst))))

(defun egg-upstream (branch)
  (and (egg-git-ok nil "config" (concat "branch." branch ".merge"))
       (let ((upstream (egg-git-to-string "name-rev" "--name-only" 
					  (concat branch "@{upstream}"))))
	 (if (and (> (length upstream) 8)
		  (string-equal (substring upstream 0 8) "remotes/"))
	     (substring upstream 8)
	   upstream))))

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
      (unless (egg-git-ok t "show" "-s" tag)
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
	    (egg-git-ok t "tag" "-v" tag)
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

(defsubst egg-rbranch-to-remote (rbranch)
  "Return the remote name in the remote-branch RBRANCH.
E.g: `foo' in `foo/bar'"
  (and (stringp rbranch)
       (> (length rbranch) 0)
       (directory-file-name (file-name-directory rbranch))))

(defsubst egg-rbranch-name (rbranch)
  "Return the ref name in the remote-branch RBRANCH.
E.g: `bar' in `foo/bar'"
  (and (stringp rbranch)
       (> (length rbranch) 0)
       (file-name-nondirectory rbranch)))

(defsubst egg-short-ref (full-ref)
  "Return the short ref name of the full ref name FULL-REF.
like `my_tag' in `refs/tags/my_tag'."
  (and (stringp full-ref)
       (> (length full-ref) 0)
       (file-name-nondirectory full-ref)))

(defsubst egg-file-as-string-raw (file-name)
  (with-temp-buffer
    (insert-file-contents-literally file-name)
    (buffer-string)))

(defsubst egg-file-as-string (file-name)
  "return the contents of file FILE-NAME as a string."
  (with-temp-buffer
    (insert-file-contents-literally file-name)
    (buffer-substring-no-properties
     (point-min) (if (> (point-max) (point-min))
                     (1- (point-max)) (point-max)))))


(defun egg-pick-file-contents (file-name regexp &rest indices)
  "Pick a string out of the contents of the file FILE-NAME.
This function searches for and return the 1st match of REGEXP on the
contents of the file. If indices was not nil, then return the first
successful submatch in the order in INDICES."
  (with-temp-buffer
    (insert-file-contents-literally file-name)
    (goto-char (point-min))
    (when (re-search-forward regexp nil t)
      (if (null indices)
          (match-string-no-properties 0)
        (dolist (idx indices)
          (if (match-beginning idx)
              (return (match-string-no-properties idx))))))))

(defun egg-pick-file-records (file-name start-re end-re)
  "Return a list of strings from the contents of the file FILE-NAME.
START-RE is the regexp to match the beginning of a record.
END-RE is the regexp to match the end of a record."
  (with-temp-buffer
    (insert-file-contents-literally file-name)
    (goto-char (point-min))
    (let ((beg (point-min))
          (end (point-max))
          lst)
      (save-match-data
        (while (and (> end beg)
                    (not (eobp))
                    (re-search-forward start-re nil t))
          (setq beg (match-beginning 0))
          (when (re-search-forward end-re nil t)
            (setq end (match-beginning 0))
            (if (> end beg)
                (setq lst (cons (buffer-substring-no-properties
                                 beg (match-beginning 0))
                                lst)))
            (goto-char end))))
      lst)))

(defsubst egg-is-in-git ()
  "is the default-directory in a git repo."
  (= (call-process egg-git-command nil nil nil "rev-parse" "--git-dir") 0))

(defsubst egg-is-dir-in-git (dir)
  "is DIR in a git repo."
  (let ((default-directory dir)) (egg-is-in-git)))

(defsubst egg-name-rev (rev)
  "get the symbolic name of REV."
  (egg-git-to-string "name-rev" "--always" "--name-only" rev))

(defsubst egg-describe-rev (rev)
  "get the long symbolic name of REV."
  (egg-git-to-string "describe" "--always" "--tags" rev))

(defsubst egg-sha1 (rev)
  "get the SHA1 of REV."
  (egg-git-to-string "rev-parse" (concat rev "~0")))

(defun egg-read-git-dir ()
  "call GIT to read the git directory of default-directory."
  (let* ((dotgit-parent (locate-dominating-file default-directory ".git"))
	 (dotgit (and dotgit-parent (concat dotgit-parent "/.git")))
         (dir (or (and dotgit (file-directory-p dotgit) dotgit)
		  (egg-git-to-string "rev-parse" "--git-dir")))
	 (work-tree dotgit-parent))
    (when (stringp dir)
      (setq dir (expand-file-name dir))
      (when (stringp work-tree) 
	(setq work-tree (expand-file-name work-tree))
	(put-text-property 0 (length dir) :work-tree work-tree dir))
      dir)))

(defvar egg-git-dir nil)
(defun egg-git-dir (&optional error-if-not-git)
  "return the (pre-read) git-dir of default-directory"
  (if (and (local-variable-p 'egg-git-dir) egg-git-dir)
      egg-git-dir
    (set (make-local-variable 'egg-git-dir)
         (or (egg-read-git-dir)
             (and error-if-not-git
                  (or (kill-local-variable 'egg-git-dir) t)
                  (error "Not in a git repository: %s" default-directory))))
    ;; first time, no status yet.
    ;; this directory's specific var will be updated by
    ;; egg-set-mode-info
    (set (intern (concat "egg-" egg-git-dir "-HEAD")) " Egg")
    egg-git-dir))

(defsubst egg-work-tree-dir (&optional git-dir)
  (unless git-dir (setq git-dir (egg-git-dir)))
  (or (get-text-property 0 :work-tree git-dir)
      (file-name-directory git-dir)))

(defsubst egg-repo-name (&optional git-dir)
  (let* ((dir (or git-dir (egg-git-dir)))
	 (work-tree-dir (egg-work-tree-dir dir)))
    (when (stringp work-tree-dir)
      (file-name-nondirectory (directory-file-name work-tree-dir)))))

(defsubst egg-buf-git-dir (buffer)
  "return the (pre-read) git-dir of BUFFER."
  (with-current-buffer buffer
    (egg-git-dir)))

(defun egg-HEAD ()
  "return HEAD. Either a symbolic ref or a sha1."
  (let* ((git-dir (egg-git-dir)))
    (if git-dir
        (egg-pick-file-contents (concat git-dir "/HEAD")
                                "^ref: refs/heads/\\(.+\\)\\|^\\([0-9a-f]+\\)" 1 2))))

(defsubst egg-get-symbolic-HEAD (&optional file)
  ;; get the symbolic name of HEAD
  (setq file (or file (concat (egg-git-dir) "/HEAD")))
  (egg-pick-file-contents file
                          "^ref: refs/heads/\\(.+\\)"
                          1))

(defsubst egg-get-full-symbolic-HEAD (&optional file)
  ;; get the symbolic full name of HEAD
  (setq file (or file (concat (egg-git-dir) "/HEAD")))
  (egg-pick-file-contents file
                          "^ref: \\(refs/heads/.+\\)"
                          1))

(defsubst egg-get-current-sha1 ()
  (or (egg-git-to-string "rev-parse" "--verify" "-q" "HEAD")
      "0000000000000000000000000000000000000000"))

(defun egg-commit-at-point (&optional pos object)
  (interactive "d")
  (get-text-property (or pos (point)) :commit object))

(defun egg-ref-at-point (&optional pos type object)
  (interactive "d")
  (let ((ref (get-text-property (or pos (point)) :ref object)))
    (when ref
      (if type
	  (and (if (consp type)
		   (memq (cdr ref) type)
		 (eq (cdr ref) type)) 
	       (car ref))
	(car ref)))))

(defsubst egg-ref-at (pos &optional object)
  (egg-ref-at-point pos nil object))

(defsubst egg-head-at-point (&optional pos object)
  (interactive "d")
  (egg-ref-at-point pos :head object))

(defsubst egg-head-at (pos)
  (egg-ref-at-point pos '(:remote :head)))

(defsubst egg-tag-at-point (&optional pos object)
  (interactive "d")
  (egg-ref-at-point pos :tag object))

(defsubst egg-remote-at-point (&optional pos object)
  (interactive "d")
  (egg-ref-at-point pos :remote object))

(defsubst egg-references-at-point (&optional pos object)
  (interactive "d")
  (get-text-property (or pos (point)) :references object))

(defsubst egg-ref-or-commit-at (pos &optional object)
  (or (egg-ref-at-point pos object) (egg-commit-at-point pos object)))

(defsubst egg-commit-at (pos &optional object)
  (egg-commit-at-point pos object))

(defsubst egg-rsite-at (pos &optional object)
  (egg-rbranch-to-remote (egg-remote-at-point pos object)))

(defsubst egg-delta-file-at (pos &optional object)
  (car (get-text-property pos :diff object)))

(defsubst egg-delta-hunk-at (pos &optional object)
  (car (get-text-property pos :hunk object)))

(defsubst egg-set-mode-info (state)
  "Set the mode-line string for buffers visiting files in the current repo.
The string is built based on the current state STATE."
  (set (intern (concat "egg-" egg-git-dir "-HEAD"))
       (format " Git:%s" (cond ((plist-get state :rebase-dir)
                                "(rebasing)")
                               ((plist-get state :merge-heads)
                                "(merging)")
                               ((plist-get state :branch)
                                (plist-get state :branch))
                               (t "(detached)")))))


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


(defun egg-all-refs ()
  "Get a list of all refs."
  (append (egg-git-to-lines "rev-parse" "--symbolic"
                            "--branches" "--tags" "--remotes")
          (delq nil
                (mapcar
                 (lambda (head)
                   (if (file-exists-p (concat (egg-git-dir) "/" head))
                       head))
                 '("HEAD" "ORIG_HEAD")))))

(defun egg-ref-type-alist ()
  "Build an alist of (REF-NAME . :type) cells."
  (mapcar (lambda (ref-desc)
            (cons (cdr (assq 5 ref-desc))
                  (cond ((assq 2 ref-desc) :head)
                        ((assq 3 ref-desc) :tag)
                        ((assq 4 ref-desc) :remote))))
          (egg-git-lines-matching-multi
           "^.+ \\(refs/\\(?:\\(heads\\)\\|\\(tags\\)\\|\\(remotes\\)\\)/\\(\\([^/\n]+/\\)?[^/\n]+\\)\\)$"
           ;; 1: full-name
           ;; 2: head
           ;; 3: tag
           ;; 4: remote
           ;; 5: name
           ;; 6: remote-host
           '(1 2 3 4 5 6) "show-ref")))

(defsubst egg-tooltip-func ()
  (if egg-enable-tooltip 'egg-buffer-help-echo))

(defun egg-full-ref-decorated-alist (head-properties
                                     tag-properties
                                     atag-properties
                                     remote-ref-properties
                                     remote-site-properties
				     &optional head-properties-HEAD)
  "Build an alist of (ref . :type) cells.
A ref string of a head will be decorated with HEAD-PROPERTIES.  A
ref string of a tag will be decorated with TAG-PROPERTIES or
ATAG-PROPERTIES.  A ref string of a remote will be formatted with
REMOTE-REF-PROPERTIES and REMOTE-SITE-PROPERTIES."
  (let ((refs-desc-list
         (egg-git-lines-matching-multi
          "^.+ \\(refs/\\(?:\\(heads\\)\\|\\(tags\\)\\|\\(remotes\\)\\)/\\(\\([^/\n]+/\\)?[^/\n{}]+\\)\\)\\(\\^{}\\)?$"
          ;; 1: full-name
          ;; 2: head
          ;; 3: tag
          ;; 4: remote
          ;; 5: name
          ;; 6: remote-host
          ;; 7: is annotated tag
          '(1 2 3 4 5 6 7) "show-ref" "-d"))
	(symbolic-HEAD (egg-get-symbolic-HEAD))
        annotated-tags refs)
    ;; remove the annotated tags from the list
    (setq refs-desc-list
          (delq nil
                (mapcar (lambda (desc)
                          (if (not (assq 7 desc))
                              ;; not an annotated tag
                              desc
                            (setq annotated-tags
                                  (cons (cdr (assq 1 desc))
                                        annotated-tags))
                            nil))
                        refs-desc-list)))
    ;; decorate the ref alist
    (setq refs
	  (mapcar (lambda (desc)
		    (let ((full-name (cdr (assq 1 desc)))
			  (name (cdr (assq 5 desc)))
			  (remote (cdr (assq 6 desc))))
		      (cond ((assq 2 desc)
			     ;; head
			     (cons full-name
				   (apply 'propertize name
					  :full-name full-name
					  :ref (cons name :head)
					  (if (and head-properties-HEAD
						   (string-equal name symbolic-HEAD))
					      head-properties-HEAD
					    head-properties))))
			    ((assq 3 desc)
			     ;; tag
			     (cons full-name
                             (apply 'propertize name
				    :full-name full-name
                                    :ref (cons name :tag)
                                    (if (member full-name annotated-tags)
                                        atag-properties
                                      tag-properties))))
                      ((assq 4 desc)
                       ;; remote
                       (cons full-name
                             (concat
                              (if (stringp remote)
                                  (apply 'propertize remote
                                         :ref (cons name :remote)
                                         remote-site-properties)
                                ;; svn has no remote name
                                "")
                              (apply 'propertize (substring name (length remote))
				     :full-name full-name
                                     :ref (cons name :remote)
                                     remote-ref-properties)))))))
            refs-desc-list))
    (unless symbolic-HEAD
      (setq refs (cons (cons "HEAD" (propertize "HEAD" 'face 'egg-log-HEAD-name)) refs)))
    refs))

(defun egg-get-all-refs (prefix)
  (egg-git-to-lines "for-each-ref" "--format=%(refname:short)" 
		    (format "refs/heads/%s*" prefix)
		    (format "refs/tags/%s*" prefix)
		    (format "refs/remotes/%s*/*" prefix)
		    (format "refs/remotes/%s*" prefix)))

(defun egg-get-local-refs (prefix)
  (egg-git-to-lines "for-each-ref" "--format=%(refname:short)" 
		    (format "refs/heads/%s*" prefix)
		    (format "refs/tags/%s*" prefix)))

(defun egg-complete-get-all-refs (prefix &optional matches)
  (if matches
      (try-completion prefix matches)
    (egg-get-all-refs prefix)))

(defun egg-complete-get-local-refs (prefix &optional matches)
  (if matches
      (try-completion prefix matches)
    (egg-get-local-refs prefix)))

(defun egg-get-match-files-substring (sub &optional matches)
  (if matches
      (try-completion sub (mapcar #'file-name-nondirectory matches))
    (let ((default-directory (egg-work-tree-dir))
	  files name-matched-files full-match)
      (setq files (egg-git-to-lines "--no-pager" "ls-files" 
				    (concat sub "*")
				    (concat "*/" sub "*")))
      (dolist (file files)
	(if (string-equal file sub)
	    (setq full-match file))
	(if (string-equal (file-name-nondirectory file) sub)
	    (add-to-list 'name-matched-files file)))
      (or (and full-match (list full-match))
	  name-matched-files
	  files))))

(defun egg-do-completion (string &optional func all)
  "Do ref name completion"
  (let* ((matches (funcall func string))
	 (single (= (length matches) 1))
	 (perfect (and single (equal (car matches) string)))
	 prefix)

    (if all matches
      (when matches
	(setq prefix (funcall func string matches)))
      (cond ((null matches) nil)
	    (perfect t)
	    (single (car matches))
	    ((stringp prefix) prefix)
	    ((null prefix) nil)
	    (t string)))))

(defsubst egg-read-ref (prompt &optional default no-match-ok)
  (completing-read prompt #'egg-do-completion #'egg-complete-get-all-refs (not no-match-ok) default))

(defsubst egg-read-local-ref (prompt &optional default no-match-ok)
  (completing-read prompt #'egg-do-completion #'egg-complete-get-local-refs (not no-match-ok) default))

(defun egg-read-tracked-filename (prompt &optional default no-match-ok)
  (concat (egg-work-tree-dir)
	  (completing-read prompt #'egg-do-completion
			   #'egg-get-match-files-substring
			   (not no-match-ok) default)))

(defun egg-find-tracked-file (file-name)
  (interactive (list (egg-read-tracked-filename "Find tracked file: ")))
  (switch-to-buffer (find-file-noselect file-name)))

(defun egg-complete-rev (string &optional ignored all)
  "Do revision completion"
  (save-match-data
    (cond ((string-match "\\`:[0-3]*" string) ;; stages
           (funcall (if all 'all-completions 'try-completion)
                    string '(":0" ":1" ":2" ":3")))

          ;; rev^, rev~10 etc.
          ((string-match "[\\^~][\\^~0-9]*\\'" string)
           ;; check with rev-parse
           (if (egg-git-ok nil "rev-parse" string)
               ;; rev-parse ok
               (if all
                   ;; fixme: how to do a full expansion?
                   (list string)
                 ;; match
                 string)))

          ;; normal rev name
          (t (let ((matches
                    ;; match all types of refs
                    (egg-git-to-lines "for-each-ref" "--format=%(refname)"
                                      (concat "refs/*/" string "*")
                                      (concat "refs/*/" string "*/*")))
                   prefix)
               ;; get the short name
               ;; with 1.6.x: for-each-ref" "--format=%(refname=short)
               (setq matches
                     (mapcar (lambda (long)
                               (string-match
                                "\\`refs/\\(?:heads\\|tags\\|remotes\\)/\\(.+\\)\\'"
                                long)
                               (match-string-no-properties 1 long))
                             matches))
               ;; do the completion
               (setq prefix
                     (funcall (if all 'all-completions 'try-completion)
                              string
                              (nconc (directory-files (egg-git-dir)
                                                      nil "HEAD")
                                     matches)))
               (cond (all prefix)
                     ((stringp prefix) prefix)
                     ((null prefix) nil)
                     (t string)))))))

(defsubst egg-get-rebase-apply-state (rebase-dir)
  "Build a plist of rebase info of REBASE-DIR.
this is for rebase -m variant."
  (let ((patch-files (directory-files rebase-dir nil "\\`[0-9]+\\'")))
    (list :rebase-dir rebase-dir
        :rebase-head (egg-name-rev (egg-file-as-string (concat rebase-dir "head-name")))
        :rebase-upstream
        (egg-describe-rev (egg-file-as-string (concat rebase-dir "onto")))
        :rebase-step (string-to-number (car patch-files))
        :rebase-num (string-to-number (car (nreverse patch-files))))))

(defsubst egg-get-rebase-merge-state (rebase-dir)
  "Build a plist of rebase info of REBASE-DIR.
this is for rebase -m variant."
  (list :rebase-dir rebase-dir
        :rebase-head
        (egg-name-rev (egg-file-as-string (concat rebase-dir "head-name")))
        :rebase-upstream
        (egg-describe-rev (egg-file-as-string (concat rebase-dir "onto_name")))
        :rebase-step			;; string-to-number?
        (egg-file-as-string (concat rebase-dir "msgnum"))
        :rebase-num			;; string-to-number?
        (egg-file-as-string (concat rebase-dir "end"))))

(defsubst egg-get-rebase-interactive-state (rebase-dir)
  "Build a plist of rebase info of REBASE-DIR.
this is for rebase -i variant."
  (list :rebase-dir rebase-dir
        :rebase-head
        (egg-name-rev (egg-file-as-string (concat rebase-dir "head-name")))
        :rebase-upstream
        (egg-describe-rev (egg-file-as-string (concat rebase-dir "onto")))
        :rebase-num
        (length
         (egg-pick-file-records (concat rebase-dir "git-rebase-todo.backup")
                                "^[pes]" "$"))
        :rebase-step
        (if (file-exists-p (concat rebase-dir "done"))
            (length (egg-pick-file-records (concat rebase-dir "done")
                                           "^[pes]" "$"))
          0)
	:rebase-stopped
	(if (file-exists-p (concat rebase-dir "stopped-sha"))
	    (egg-pick-file-contents (concat rebase-dir "stopped-sha") "^[0-9a-f]+$"))
        :rebase-cherry
        (if (file-exists-p (concat rebase-dir "done"))
            (car (egg-pick-file-records
                  (concat rebase-dir "done")
                  "^[pes]" "$")))))

(defsubst egg-git-rebase-dir (&optional git-dir)
  (concat (or git-dir (egg-git-dir)) "/" egg-git-rebase-subdir "/"))

(defsubst egg-rebase-author-info (rebase-dir)
  "Retrieve an alist of commit environment variables of the current
cherry in REBASE-DIR."
  (mapcar (lambda (lst)
            ;; chop the ' '
            (setcar (cdr lst) (substring (cadr lst) 1 -1))
            lst)
          (mapcar (lambda (line)
                    ;; name-value split
                    (save-match-data (split-string line "=" t)))
                  ;; grab the GIT_xxx=yyy
                  (egg-pick-file-records (concat rebase-dir "author-script")
                                         "^GIT_\\(.+\\)" "$"))))

(defsubst egg-interactive-rebase-in-progress ()
  "Is an interactive rebase in progress in the current repo?"
  (file-exists-p (concat (egg-git-dir) "/" egg-git-rebase-subdir
                         "/interactive") ))

(defvar egg-internal-current-state nil)
(defun egg-get-repo-state (&optional extras)
  "Retrieve current repo's state as a plist.
The properties:
:gitdir :head :branch :sha1 :merge-heads :rebase-dir :rebase-head
:rebase-upstream :rebase-step :rebase-num :rebase-cherry

EXTRAS contains the extra properties to retrieve: :staged :unstaged

if EXTRAS contains :error-if-not-git then error-out if not a git repo.
"
  (let* ((git-dir (egg-git-dir (memq :error-if-not-git extras)))
         (head-file (concat git-dir "/HEAD"))
         (merge-file (concat git-dir "/MERGE_HEAD"))
         (branch (egg-get-symbolic-HEAD head-file))
         (branch-full-name (egg-get-full-symbolic-HEAD head-file))
         (sha1 (egg-get-current-sha1))
         (merge-heads
          (mapcar 'egg-name-rev
                  (if (file-readable-p merge-file)
                      (egg-pick-file-records merge-file "^" "$"))))
	 (rebase-apply (if (file-directory-p (concat git-dir "/rebase-apply"))
			   (concat git-dir "/rebase-apply/")))
         (rebase-dir
	  (or rebase-apply
	      (if (file-directory-p (concat git-dir "/" egg-git-rebase-subdir))
		  (concat git-dir "/" egg-git-rebase-subdir "/"))))
         (is-rebase-interactive 
	  (and (not rebase-apply)
	       (file-exists-p (concat rebase-dir "interactive"))))
         (rebase-state
          (if rebase-apply
	      (egg-get-rebase-apply-state rebase-dir)
	      (when rebase-dir
		(if is-rebase-interactive
		    (egg-get-rebase-interactive-state rebase-dir)
		  (egg-get-rebase-merge-state rebase-dir)))))
         (state (nconc (list :gitdir git-dir
                             :head branch-full-name
                             :branch branch
                             :sha1 sha1
                             :merge-heads merge-heads)
                       rebase-state))
         files)
    (dolist (req extras)
      (cond ((eq req :unstaged)
             (setq files (egg-git-to-lines "diff" "--name-only"))
             (setq state (nconc (list :unstaged files) state))
             (when (and files (stringp (car files)))
               (setq state (nconc (list :unmerged (egg-unmerged-files))
                                  state))))
            ((eq req :staged)
             (setq state
                   (nconc (list :staged (egg-git-to-lines "diff" "--cached" "--name-only"))
                          state)))
	    
	    ((eq req :name)
             (setq state
                   (nconc (list :name (egg-git-to-string "config" "user.name")) state)))
	    ((eq req :email)
             (setq state
                   (nconc (list :email (egg-git-to-string "config" "user.email")) state)))))
    ;; update mode-line
    (egg-set-mode-info state)
    state))

(defun egg-repo-state (&rest args)
  "return the cached repo state or re-read it.
if ARGS contained :force then ignore the cached state."
  (if (or (null egg-internal-current-state) ;; not cached
	  (memq :force args)		    ;; forced
	  (memq nil ;; cached copy has no extra reqs
		(mapcar (lambda (req)
			  (memq req egg-internal-current-state))
			args)))
      (egg-get-repo-state args)
    egg-internal-current-state))

(defsubst egg-repo-clean (&optional state)
  "Whether the current repos is clean base on the current repo state.
use STATE as repo state if it was not nil. Otherwise re-read the repo state."
  (unless state
    (setq state (egg-repo-state :staged :unstaged)))
  (and
   (null (plist-get state :rebase-num))
   (null (plist-get state :merge-heads))
   (not (if (memq :unstaged state)
            (plist-get state :unstaged)
          (egg-wdir-clean)))
   (not (if (memq :staged state)
            (plist-get state :staged)
          (egg-index-empty)))))

(defun egg-wdir-dirty () (plist-get (egg-repo-state :unstaged) :unstaged))
(defun egg-staged-changes () (plist-get (egg-repo-state :staged) :staged))

(defsubst egg-current-branch (&optional state)
  "The current symbolic value of HEAD. i.e. name of a branch. if STATE
was not nil then use it as repo state instead of re-read from disc."
  (plist-get (or state (egg-repo-state)) :branch))

(defsubst egg-short-sha1 (&optional sha1)
  (egg-git-to-string "rev-parse" "--short" (or sha1 (egg-current-sha1))))

(defsubst egg-current-sha1 (&optional state)
  "The immutable sha1 of HEAD.  if STATE was not nil then use it
as repo state instead of re-read from disc."
  (plist-get (or state (egg-repo-state)) :sha1))

(defsubst egg-user-name (&optional state)
  "The configured user name."
  (plist-get (or state (egg-repo-state :name)) :name))

(defsubst egg-user-email (&optional state)
  "The configured email."
  (plist-get (or state (egg-repo-state :email)) :email))

(defsubst egg-head (&optional state)
  "a cons cell (branch . sha1) of HEAD.  if STATE was not nil then use it
as repo state instead of re-read from disc."
  (if (egg-git-dir)
      (let ((state (or state (egg-repo-state))))
        (cons (egg-current-sha1 state)
              (egg-current-branch state)))))

(defun egg-pretty-head-string (&optional state)
  "Pretty description of HEAD.  if STATE was not nil then use it
as repo state instead of re-read from disc."
  (let* ((state (or state (egg-repo-state)))
         (branch (plist-get state :branch))
         (merge-heads (plist-get state :merge-heads))
         (rebase-head (plist-get state :rebase-head))
         (rebase-upstream (plist-get state :rebase-upstream))
         (sha1 (plist-get state :sha1)))
    (cond ((and branch merge-heads)
           (concat "Merging to " branch " from: "
                   (mapconcat 'identity merge-heads ",")))
          (merge-heads
           (concat "Merging to " (egg-name-rev sha1) " from: "
                   (mapconcat 'identity merge-heads ",")))
          ((and rebase-head rebase-upstream)
           (format "Rebasing %s onto %s" rebase-head rebase-upstream))
          (branch branch)
          (t (concat "Detached HEAD: " (egg-describe-rev sha1))))))

(defsubst egg-pretty-head-name (&optional state)
  "Pretty name for HEAD.  if STATE was not nil then use it
as repo state instead of re-read from disc."
  (let* ((state (or state (egg-repo-state)))
         (branch (plist-get state :branch)))
    (or branch (egg-describe-rev (plist-get state :sha1)))))

(defsubst egg-branch-or-HEAD () (or (egg-get-symbolic-HEAD) "HEAD"))


(defsubst egg-config-section-raw (type &optional name)
  (egg-pick-file-contents (concat (egg-git-dir) "/config")
                          (concat "^"
                                  (if name
                                      (format "\\[%s \"%s\"\\]" type name)
                                    (format "\\[%s\\]" type))
                                  "\n"
                                  "\\(\\(?:\t.+\n\\)+\\)")
                          1))

(defsubst egg-config-section (type &optional name)
  (save-match-data
    (mapcar
     (lambda (line)
       (split-string line "[ =]+" t))
     (split-string (or (egg-config-section-raw type name) "")
                   "[\t\n]+" t))))

(defun egg-config-get-all (called-interactively file type)
  (interactive "p\nfFilename: \nsType: ")
  (let (res)
    (setq res
	  (save-match-data
	    (mapcar (lambda (rec)
		      (let ((key (car rec))
			    (infos (cdr rec)))
			(cons (progn (string-match "\"\\(.+\\)\"" key)
				     (match-string-no-properties 1 key))
			      (mapcar (lambda (attr)
					(split-string attr "[ =]+" t))
				      infos))))
		    (mapcar (lambda (str)
			      (split-string str "[\t\n]+" t))
			    (egg-pick-file-records file
						   (concat "^\\[" type " \"")
						   "^\\[\\|\\'")))))
    (if called-interactively
	(message "%S" res))
    res))

(defsubst egg-config-get-all-branches ()
  (egg-config-get-all nil (concat (egg-git-dir) "/config") "branch"))

(defsubst egg-config-get-all-remotes ()
  (egg-config-get-all nil (concat (egg-git-dir) "/config") "remote"))

(defsubst egg-config-get-all-remote-names ()
  (mapcar 'car (egg-config-get-all-remotes)))

(defsubst egg-config-get (type attr &optional name)
  (and (egg-git-dir)
       (cadr (assoc attr (egg-config-section type name)))))

(defun egg-tracking-target (branch &optional mode)
  (let ((remote (egg-config-get "branch" "remote" branch))
        (rbranch (egg-config-get "branch" "merge" branch)))
    (when (stringp rbranch)
      (setq rbranch (egg-rbranch-name rbranch))
      (cond ((null mode) (concat remote "/" rbranch))
            ((eq :name-only mode) rbranch)
            (t (cons rbranch remote))))))


(defsubst egg-read-rev (prompt &optional default)
  "Query user for a revision using PROMPT. DEFAULT is the default value."
  (completing-read prompt 'egg-complete-rev nil nil default))

(defsubst egg-read-remote (prompt &optional default)
  "Query user for a remote using PROMPT. DEFAULT is the default value."
  (completing-read prompt (egg-config-get-all-remote-names) nil t default))

;;;========================================================
;;; Async Git process
;;;========================================================

(defsubst egg-async-process ()
  (with-egg-async-buffer
   (let ((proc (get-buffer-process (current-buffer))))
     (if (and (processp proc) 		;; is a process
	      (not (eq (process-status proc) 'exit)) ;; not finised
	      (= (process-exit-status proc) 0))      ;; still running
	 proc))))

(defun egg-async-do (exit-code func-args args)
  "Run GIT asynchronously with ARGS.
if EXIT code is an exit-code from GIT other than zero but considered
success."
  (let ((inhibit-read-only inhibit-read-only)
        (accepted-msg (and (integerp exit-code)
                           (format "exited abnormally with code %d"
                                   exit-code)))
        proc)
    
    (with-egg-async-buffer
      (setq proc (get-buffer-process (current-buffer)))
      (when (and (processp proc)		       ;; is a process
		 (not (eq (process-status proc) 'exit)) ;; not finised
		 (= (process-exit-status proc) 0)) ;; still running
	(error "EGG: %s is already running!" (process-command proc)))
      (setq inhibit-read-only t)
      (erase-buffer)
      (widen)
      (goto-char (point-max))
      (insert "EGG-GIT-CMD:\n")
      (insert (format "%S\n" args))
      (insert "EGG-GIT-OUTPUT:\n")
      (setq proc (apply 'start-process "egg-git" (current-buffer) egg-git-command args))
      (setq mode-line-process " git")
      (when (and (consp func-args) (functionp (car func-args)))
	(process-put proc :callback-func (car func-args))
	(process-put proc :callback-args (cdr func-args)))
      (when (stringp accepted-msg)
	(process-put proc :accepted-msg accepted-msg)
	(process-put proc :accepted-code exit-code))
      (process-put proc :cmds (cons egg-git-command args))
      (set-process-sentinel proc #'egg-process-sentinel))
    proc))

(defsubst egg-async-0 (func-args &rest args)
  (egg-async-do nil func-args args))

(defsubst egg-async-1 (func-args &rest args)
  (egg-async-do 1 func-args args))

(defsubst egg-async-0-args (func-args args)
  (egg-async-do 0 func-args args))

(defsubst egg-async-1-args (func-args args)
  (egg-async-do 1 func-args args))

(defvar egg-async-process nil)
(defvar egg-async-cmds nil)
(defvar egg-async-exit-msg nil)

(defun egg-process-sentinel (proc msg)
  (let ((exit-code (process-get proc :accepted-code))
        (accepted-msg (process-get proc :accepted-msg))
        (callback-func (process-get proc :callback-func))
        (callback-args (process-get proc :callback-args))
        (cmds (process-get proc :cmds)))
    (cond ((string= msg "finished\n")
           (message "EGG: git finished."))
          ((string= msg "killed\n")
           (message "EGG: git was killed."))
          ((and accepted-msg (string-match accepted-msg msg))
           (message "EGG: git exited with code: %d." exit-code))
          ((string-match "exited abnormally" msg)
           (message "EGG: git failed."))
          (t (message "EGG: git is weird!")))
    (with-current-buffer (process-buffer proc)
      (setq mode-line-process nil)
      (widen)
      (egg-cmd-log-whole-buffer (current-buffer))
      (goto-char (point-max))
      (re-search-backward "^EGG-GIT-CMD:" nil t)
      ;; Narrow to the last command
      (narrow-to-region (point) (point-max))
      (if (functionp callback-func)
          (let ((egg-async-process proc)
                (egg-async-cmds cmds)
                (egg-async-exit-msg msg))
            (apply callback-func callback-args))))))


;;;========================================================
;;; New: internal command
;;;========================================================

(defvar egg--ediffing-temp-buffers nil)
(defun egg--add-ediffing-temp-buffers (&rest buffers)
  (dolist (buf buffers)
    (when (buffer-live-p buf)
      (add-to-list 'egg--ediffing-temp-buffers buf))))

(defun egg--kill-ediffing-temp-buffers ()
  (let ((lst egg--ediffing-temp-buffers))
    (setq egg--ediffing-temp-buffers nil)
    (message "kill ediffing buffers: job-name=%s buffers=%S" ediff-job-name lst)
    (dolist (buf lst)
      (when (buffer-live-p buf)
	(message "egg killing buffer: %s" (if (bufferp buf) (buffer-name buf) buf))
	(bury-buffer buf)
	(kill-buffer buf)))))

(defsubst egg--do-output (&optional erase)
  "Get the output buffer for synchronous commands.
erase the buffer's contents if ERASE was non-nil."
  (let ((buffer (get-buffer-create (concat " *egg-output:" (egg-git-dir) "*")))
	(default-directory default-directory))
    (with-current-buffer buffer
      (setq default-directory (egg-work-tree-dir))
      (widen)
      (if erase (erase-buffer)))
    buffer))

(defmacro with-egg--do-buffer (&rest body)
  "Evaluate BODY there like `progn' in the egg--do-output buffer.
See also `with-temp-file' and `with-output-to-string'."
  (declare (indent 0) (debug t))  
  `(with-current-buffer (egg--do-output)
     (setq default-directory (egg-work-tree-dir))
     (unwind-protect
	 (progn ,@body)
       )))

(defmacro with-clean-egg--do-buffer (&rest body)
  "Evaluate BODY there like `progn' in the egg--do-output buffer.
See also `with-temp-file' and `with-output-to-string'."
  (declare (indent 0) (debug t))  
  `(with-current-buffer (egg--do-output t)
     (setq default-directory (egg-work-tree-dir))
     (unwind-protect
	 (progn ,@body)
       )))

(defun egg--do (stdin program args)
  "Run PROGRAM with ARGS synchronously using STDIN as starndard input.
ARGS should be a list of arguments for PROGRAM."
  (let ((buf (current-buffer)) ret)
    (egg-cmd-log "RUN:" program " " (mapconcat 'identity args " ")
		 (if stdin " <REGION\n" "\n"))
    (with-clean-egg--do-buffer
      (cond ((stringp stdin)
	     (insert stdin))
	    ((consp stdin)
	     (insert-buffer-substring buf (car stdin) (cdr stdin)))
	    (t nil))

      (setq ret (if stdin
		    (apply 'call-process-region (point-min) (point-max)
			   program t t nil args)
		  (apply 'call-process program nil t nil args)))
      (egg-cmd-log-whole-buffer (current-buffer))
      (egg-cmd-log (format "RET:%d\n" ret))
      (cons ret (current-buffer)))))

(defun egg--do-git (stdin cmd args)
  "Run git command CMD with ARGS synchronously, using STDIN as starndard input.
ARGS should be a list of arguments for the git command CMD."
  (egg--do stdin "git" (cons cmd args)))

(defun egg--do-handle-exit (exit-info post-proc-func &optional buffer-to-update)
  "Handle the exit code and the output of a synchronous action.
EXIT-INFO is the results of the action in form of a pair (return-code . output-buffer).
POST-PROC-FUNC shall be a function which will be call with 1 argument: the return-code
of the action. It shall be called in the output buffer of the action.
This function returns the returned value of POST-PROC-FUNC.
EXIT-INFO should be the return value of `egg--do-git' or `egg--do'."
  (let ((ret (car exit-info))
	(buf (cdr exit-info))
	beg end pp-results)
    (with-current-buffer buf
      (setq beg (point-min))
      (setq end (point-max))
      ;; even if the buffer is empty, post-proc-func must
      ;; still be done to process the ret-code
      (setq pp-results
	    (cond ((functionp post-proc-func)
		   (goto-char (point-min))
		   (funcall post-proc-func ret))
		  ((and (consp post-proc-func)
			(functionp (car post-proc-func))
			(functionp (cdr post-proc-func)))
		   (funcall (cdr post-proc-func) (funcall (car post-proc-func) ret))))))
    (cond ((bufferp buffer-to-update)
	   (egg-refresh-buffer buffer-to-update))
	  ((memq buffer-to-update '(t all))
	   (egg-run-buffers-update-hook))
	  (t nil))
    (if (memq :success pp-results)
	pp-results
      (nconc (list :success (= ret 0)) pp-results)		;; default result
      )))

(defvar egg--do-git-quiet nil)		;; don't show git's output
(defvar egg--do-no-output-message nil)

(defun egg--do-show-output (cmd-name output-info)
  "Show the output of a synchronous git command as feed-back for the emacs command.
CMD-NAME is the name of the git command such as: merge or checkout. OUTPUT-INFO is
generally the returned value of `egg--do-handle-exit'. OUTPUT-INFO will also be
used as the returned value of this function."
  (let ((ok (plist-get output-info :success))
	(line (plist-get output-info :line))
	(no-output-message (or egg--do-no-output-message "*no output*"))
	prefix)
    (setq prefix (concat (if (stringp cmd-name) cmd-name "GIT")
			 (if ok "> " ":ERROR> ")))
    (unless (and egg--do-git-quiet ok)
      (message (if (stringp line) 
		   (concat prefix line)
		 (concat "EGG: " no-output-message))))
    (unless ok (ding))
    output-info))

(defun egg--do-git-action (cmd buffer-to-update post-proc-func args)
  "Run git command CMD with arguments list ARGS.
Show the output of CMD as feedback of the emacs command.
Update the buffer BUFFER-TO-UPDATE and use POST-PROC-FUNC as the
output processing function for `egg--do-handle-exit'."
  (egg--do-show-output (concat "GIT-" (upcase cmd))
		       (egg--do-handle-exit (egg--do-git nil cmd args)
					    post-proc-func buffer-to-update)))

(defun egg--do-git-action-stdin (cmd stdin buffer-to-update post-proc-func args)
  "Run git command CMD with arguments list ARGS and STDIN as standard input.
Show the output of CMD as feedback of the emacs command.
Update the buffer BUFFER-TO-UPDATE and use POST-PROC-FUNC as the
output processing function for `egg--do-handle-exit'."
  (egg--do-show-output (concat "GIT-" (upcase cmd))
		       (egg--do-handle-exit (egg--do-git stdin cmd args)
					    post-proc-func buffer-to-update)))



(defconst egg--bad-git-output-regex
  (concat (regexp-opt '("Cannot" "cannot" "Couldn't" "couldn't" "Could not" "could not" 
			"Failed" "failed" "incompatible" "Incompatible" "invalid" "Invalid"
			"not allowed" "rejected" "Unable" "unable" "internal error" 
			"mutually exclusive" "does not" "do not" "did not" "is not" "needs a"
			"No such" "no such" "No changes" "Too many" "too many"
			"Nothing" "nothing" "Abort" "abort" "Malformed" "malformed"
			"unresolved" "Unresolved" "Corrupt" "corrupt" "empty" 
			"does not make sense" "only with" "only one" "only allowed"
			"skipped" "Skipped" "bad" "Bad" "doesn't"
			"too big" "Too big" "too many" "Too many"
			"not a valid" "Not a valid" "already exist" "ignored by" "is beyond"

			"Not"
			) t)
	  "\\|\\(?:No.+found\\)\\|\\(?:[On]nly.+can be used\\)"))

(defconst egg--fatal-git-output-regex "^fatal")

(defun egg--git-pp-grab-line-no (line-no &rest extras)
  "Grab the line LINE-NO in the current buffer.
Return it in a form usable for `egg--do-show-output'."
  (let* ((lines (delete "" (save-match-data
			     (split-string (buffer-string) "\n"))))
	 (line (cond ((< line-no 0) (nth (- -1 line-no) (nreverse lines)))
		     ((> line-no 0) (nth (1- line-no) lines))
		     (t nil))))
    (when (stringp line)
      (nconc (list :line line) extras))))

(defun egg--git-pp-grab-line-matching (regex &optional replacement &rest extras)
  "If REGEX matched a line in the current buffer, return it in a form suitable
for `egg--do-show-output'. If REPLACEMENT was provided, use it in the returned
structure instead of the matching line."
  (let ((matched-line 
	 (when (stringp regex)
	   (save-match-data
	     (goto-char (point-min))
	     (when (re-search-forward regex nil t)
	       (goto-char (match-beginning 0))
	       (buffer-substring-no-properties 
		(line-beginning-position)
		(line-end-position)))))))
    (when (stringp matched-line)
      (nconc (list :line (if (stringp replacement) replacement matched-line))
	     extras))))

(defsubst egg--git-pp-grab-1st-line-matching (regex-list &optional replacement &rest extras)
  "Try maching the lines in the current buffer against each regex in REGEX-LIST
until one matched. Return the line in a form suitable for `egg--do-show-output'.
If REPLACEMENT was provided, use it in the returned structure instead of
the matching line."
  (let ((r-list regex-list)
	re found)
    (while (and (not found) r-list)
      (setq re (car r-list)
	    r-list (cdr r-list))
      (setq found (apply 'egg--git-pp-grab-line-matching re replacement extras)))
    found))

(defun egg--git-pp-fatal-output (&optional pre-regexes post-regexes)
  (or
   (egg--git-pp-grab-1st-line-matching
    (nconc (if (stringp pre-regexes) (list pre-regexes) pre-regexes)
	   (list egg--bad-git-output-regex egg--fatal-git-output-regex)
	   (if (stringp post-regexes) (list post-regexes) post-regexes)))
   (egg--git-pp-grab-line-no -1)))

(defsubst egg--git-pp-fatal-result (&optional pre-regexes post-regexes)
  (nconc (list :success nil)
	 (egg--git-pp-fatal-output pre-regexes post-regexes)))

(defun egg--git-pp-generic (ret-code accepted-codes ok-regex bad-regex
				     &optional line-no)
  "Simple post-processing function for synchronous git actions.
return a suitable structure for `egg--do-show-output'. if RET-CODE was 0
then the action is considered a success. The line matching OK-REGEX would
be also return in the structure. OK-REGEX can also be a list of regexes.
If no line matched OK-REGEX and LINE-NO was provided, then return the line
LINE-NO in the result structure. If RET-CODE wasn't 0, then use BAD-REGEX
instead of OK-REGEX.

This simple function might be use as the POST-PROC-FUNC argument of the
`egg--do-handle-exit' function."
  (if (memq ret-code accepted-codes)
      (if (consp ok-regex)
	  (egg--git-pp-grab-1st-line-matching ok-regex nil :success t)
	(egg--git-pp-grab-line-matching ok-regex nil :success t))
    (or (if (consp bad-regex)
	    (egg--git-pp-grab-1st-line-matching bad-regex)
	  (egg--git-pp-grab-line-matching bad-regex))
	(egg--git-pp-grab-line-no (or line-no -1)))))

(defconst egg--git-action-cmd-doc nil
  "The `egg--git-xxxxx-cmd' functions perform git command synchronously.
The returned value is a plist where the results of the action are indexed
by the :aaaaa symbols

:success (t or nil) the success of the action from egg's p-o-v.
:line the selected line from the git command's output to display
      to the user as the feedback of the emacs command. Sometimes
      egg fabricates this line.
:files the files in the worktree which might be changed by the
       git command and their buffers should be reverted.
:next-action (a symbol) the next logical action for egg to do.")

(defun egg--git-push-cmd (buffer-to-update &rest args)
  "Peform a synchronous action using the git push command using ARGS as arguments.
Update BUFFER-TO-UPDATE if needed.

See documentation of `egg--git-action-cmd-doc' for the return structure."
  (egg--do-git-action 
   "push" buffer-to-update
   (lambda (ret-code)
     (egg--git-pp-generic ret-code '(0) " -> \\|Everything up-to-date\\|deleted"
			  '("rejected" "\\<not\\>")))
   args))

(defun egg--git-push-cmd-test (from to repo)
  (interactive "sPush: \nsOnTo: \nsAt:")
  (egg--git-push-cmd nil repo (concat from ":" to)))

(defun egg--git-pp-reset-output (ret-code reset-mode)
  "Post-processing function for the output the git reset command in the current buffer.
RET-CODE is the return code of the git process and RESET-MODE would be one
of: --hard, --keep, --soft, --mixed. --merge is currently not supported.
Return a structure suitable for `egg--do-show-output'."
  (if (/= ret-code 0)
      (egg--git-pp-fatal-output "Entry.not uptodate")
    (cond ((string-equal "--hard" reset-mode)
	   (egg--git-pp-grab-line-matching "^HEAD is now at" nil
					   :next-action 'log :success t))
	  ((string-equal "--keep" reset-mode)
	   (egg--git-pp-grab-line-no -1 :next-action 'status :success t))
	  ((string-equal "--soft" reset-mode)
	   (egg--git-pp-grab-line-no -1 :next-action 'status :success t))
	  ((string-equal "--mixed" reset-mode)
	   (egg--git-pp-grab-line-matching "Unstaged changes after reset"
					   "there are unstaged changes after reset"
					   :next-action 'status :success t)))))

(defun egg--git-reset-cmd (buffer-to-update reset-mode rev)
  "Peform a synchronous action using the git reset command.
Update BUFFER-TO-UPDATE if needed. RESET mode is a one of: --hard, --keep, --mixed
and --soft (--merge is currently unsupported.). HEAD will be resetted to REV.
The relevent line from the output of the underlying git command will be display
as feedback of emacs command.

See documentation of `egg--git-action-cmd-doc' for the return structure."
  (let ((pre-reset (egg-get-current-sha1))
	;; will be changed, if "--keep"
	(rev-vs-head (egg-git-to-lines "diff" "--name-only" "HEAD" rev))
	;; will be changed, if "--hard"
	(rev-vs-wdir (egg-git-to-lines "diff" "--name-only" rev))
	files res)
    (setq res (egg--do-git-action
	       "reset" buffer-to-update
	       `(lambda (ret-code)
		  (egg--git-pp-reset-output ret-code ,reset-mode))
	       (list reset-mode rev)))
    (if (plist-get res :success)
	(cond ((equal reset-mode "--hard")
	       (nconc res (list :files rev-vs-wdir)))
	      ((member reset-mode '("--keep" "--merge"))
	       (nconc res (list :files rev-vs-head)))
	      (t res))
      res)))

(defun egg--git-reset-cmd-test (mode rev)
  (interactive "sreset mode:\nsrev:")
  (egg--git-reset-cmd t mode rev))

(defun egg--git-reset-files-cmd (buffer-to-update rev &rest files)
  "Peform a synchronous action using the git reset command on paths FILES.
Update BUFFER-TO-UPDATE if needed. FILES will be resetted to REV in the index.
The relevent line from the output of the underlying git command will be displayed
as feedback of emacs command.

See documentation of `egg--git-action-cmd-doc' for the return structure."
  (egg--do-git-action
   "reset" buffer-to-update
   (lambda (ret-code)
     (cond ((= ret-code 0) (list :success t :next-action 'status))
	   ((= ret-code 1)
	    (egg--git-pp-grab-line-matching "Unstaged changes after reset:"
					    "there are unstaged changes after reset"
					    :next-action 'status :success t))
	   ((> ret-code 1) (egg--git-pp-fatal-result))))
   (nconc (list (or rev "HEAD") "--") files)))


(defun egg--git-co-files-cmd (buffer-to-update file-or-files &rest args)
  "Peform a synchronous action using the git checkout command on FILE-OR-FILES.
Update BUFFER-TO-UPDATE if needed. ARGS will be passed to the git command as
arguments. FILE-OR-FILES will be updated to REV in the index as well as the work
tree. The relevent line from the output of the underlying git command will be
displayed as feedback of emacs command.

See documentation of `egg--git-action-cmd-doc' for the return structure."
  (let* ((files (if (consp file-or-files) file-or-files (list file-or-files)))
	 (args (append args (cons "--" files)))
	 (res (egg--do-git-action
	       "checkout" buffer-to-update
	       (lambda (ret-code)
		 (if (= ret-code 0)
		     (list :success t :next-action 'status)
		   (egg--git-pp-fatal-result "yet to be born")))
	       args)))
    (if (plist-get res :success)
	(nconc res (list :files files))
      res)))

(defun egg--git-co-rev-cmd-args (buffer-to-update rev args)
  "Peform a synchronous action using git to checkout REV to the worktree.
ARGS will be used as arguments. Update BUFFER-TO-UPDATE if
needed. The relevent line from the output of the underlying git
command will be displayed as feedback of emacs command."
  (let (files cmd res)
    (if (eq :0 rev)
	(setq files ;; index vs wdir
	      (egg-git-to-lines "diff" "--name-only")
	      cmd "checkout-index")
      ;; will change if switch rev
      (setq files (egg-git-to-lines "diff" "--name-only" rev "HEAD")
	    cmd "checkout"
	    args (append args (list rev))))
    (setq res 
	  (egg--do-git-action 
	   cmd buffer-to-update 
	   (lambda (ret-code)
	     (if (= ret-code 0)
		 (or (egg--git-pp-grab-line-matching 
		      (regexp-opt '("Already on" "HEAD is now at"
				    "Switched to branch" "Switched to a new branch"
				    "Reset branch")) nil
		      :next-action 'status :success t)
		     (egg--git-pp-grab-line-no -1 :next-action 'status :success t))
	       (or
		(egg--git-pp-grab-line-matching "untracked working tree files would be overwritten"
						"untracked file(s) would be overwritten"
						:next-action 'status)
		(egg--git-pp-fatal-result "Please, commit your changes"))))
	   args))
    
    (if (plist-get res :success)
	(nconc res (list :files files))
      res)))

(defsubst egg--git-co-rev-cmd (buffer-to-update rev &rest args)
  "Peform a synchronous action using git to checkout REV to the worktree.
ARGS will be used as arguments. Update BUFFER-TO-UPDATE if
needed. The relevent line from the output of the underlying git
command will be displayed as feedback of emacs command.

See documentation of `egg--git-action-cmd-doc' for the return structure."
  (egg--git-co-rev-cmd-args buffer-to-update rev args))

(defun egg--git-merge-pp-func (ret-code)
  (cond ((= ret-code 0)
	 (or (egg--git-pp-grab-line-matching "stopped before committing as requested"
					     nil :next-action 'commit :success t)
	     (egg--git-pp-grab-line-matching
	      (regexp-opt '("merge went well" "Already up-to-date" 
			    "file changed" "files changed"
			    "insertions" "deletions"))
	      nil :success t :next-action 'log)
	     (egg--git-pp-grab-line-no -1 :success t :next-action 'status)))
	((= ret-code 1)
	 (or (egg--git-pp-grab-line-matching "fix conflicts and then commit"
					     nil :next-action 'status :success t)
	     (egg--git-pp-grab-line-matching
	      "untracked working tree files would be overwritten by merge"
	      "untracked files would be overwritten, please rename them before merging"
	      :next-action 'status)
	     (egg--git-pp-grab-line-matching
	      "commit your changes or stash them before you can merge"
	      nil :next-action 'status)
	     (egg--git-pp-grab-line-no -1)))
	(t (egg--git-pp-fatal-result))))

(defun egg--git-merge-cmd (buffer-to-update pp-func &rest args)
  "Peform the git merge command synchronously with ARGS as arguments.
Update BUFFER-TO-UPDATE if needed. The relevant line from the
output of the underlying git command will be displayed as
feedback of emacs command.

See documentation of `egg--git-action-cmd-doc' for the return structure."
  (egg--do-git-action 
   "merge" buffer-to-update
   (if (functionp pp-func)
       (cons #'egg--git-merge-pp-func pp-func)
     #'egg--git-merge-pp-func)
   args))

(defun egg--git-merge-cmd-test (ff-only from)
  (interactive "P\nsMerge: ")
  (if ff-only
      (egg--git-merge-cmd t "-v" "--ff-only" from)
    (egg--git-merge-cmd t "-v" from)))

(defun egg--git-add-cmd (buffer-to-update &rest args)
  "Run git add command synchronously with ARGS as arguments.
Update BUFFER-TO-UPDATE as needed.

See documentation of `egg--git-action-cmd-doc' for the return structure."
  (egg--do-git-action
   "add" buffer-to-update
   (lambda (ret-code)
     (if (= ret-code 0)
	 (or (egg--git-pp-grab-line-matching "nothing added" nil :success t)
	     (egg--git-pp-grab-line-matching "^add " "index updated" 
					     :next-action 'status :success t)
	     (egg--git-pp-grab-line-no -1 :success t))
       (egg--git-pp-fatal-result)))
   args))

(defun egg--git-rm-cmd (buffer-to-update &rest args)
  "Run the git rm command synchronously with ARGS as arguments.
Update BUFFER-TO-UPDATE as needed.

See documentation of `egg--git-action-cmd-doc' for the return structure."
  (egg--do-git-action
   "rm" buffer-to-update
   (lambda (ret-code)
     (if (= ret-code 0)
	 (nconc (list :success t)
		(let (files)
		  (goto-char (point-min))
		  (while (re-search-forward "^rm '\\(.+\\)'$" nil t)
		    (add-to-list 'files (match-string-no-properties 1)))
		  (when (consp files)
		    (list :files files :next-action 'status))))
       (egg--git-pp-fatal-result "has staged content different from both"
				 (regexp-opt '("did not match" "not removing")))))
   args))


(defun egg--git-branch-cmd (buffer-to-update args)
  "Run the git branch command synchronously with ARGS as arguments.
Update BUFFER-TO-UPDATE as needed.

See documentation of `egg--git-action-cmd-doc' for the return structure."  (egg--do-git-action
   "branch" buffer-to-update
   (lambda (ret-code)
     (if (= ret-code 0)
	  (egg--git-pp-grab-line-no -1 :success t)
       (egg--git-pp-fatal-result (regexp-opt '("No commit" "no commit" 
					       "No such" "no such" "is not fully")))))
   args))

(defconst egg--git-stash-error-regex
  "unimplemented\\|\\([dD]o \\|[Cc]ould \\|[Cc]an\\)not\\|No \\(changes\\|stash found\\)\\|Too many\\|is not\\|unable\\|Conflicts in index\\|No branch name\\|^fatal")

(defun egg--git-stash-save-cmd (buffer-to-update &rest args)
  "Run the git stash save command synchronously with ARGS as arguments.
Update BUFFER-TO-UPDATE as needed.

See documentation of `egg--git-action-cmd-doc' for the return structure."
  (let ((files (egg-git-to-lines "diff" "--name-only" "HEAD"))
	res)
    (setq res
	  (egg--do-git-action
	   "stash" buffer-to-update
	   (lambda (ret-code)
	     (if (= ret-code 0)
		 (or (egg--git-pp-grab-1st-line-matching
		      '("Saved working directory" "HEAD is now at") nil
		      :next-action 'stash :success t)
		     (egg--git-pp-grab-line-no -1 :next-action 'stash :success t))
	       (egg--git-pp-fatal-result)))
	   (cons "save" args)))
    (when (plist-get res :success)
      (setq res (nconc res (list :files files))))
    res))

(defun egg--git-stash-drop-cmd (buffer-to-update &rest args)
  "Run the git stash save command synchronously with ARGS as arguments.
Update BUFFER-TO-UPDATE as needed.

See documentation of `egg--git-action-cmd-doc' for the return structure."
  (egg--do-git-action
   "stash" buffer-to-update
   (lambda (ret-code)
     (if (= ret-code 0)
	 (or (egg--git-pp-grab-line-matching "^Dropped stash" nil :next-action 'stash :success t)
	     (egg--git-pp-grab-line-no -1 :next-action 'stash :success t))
       (or (egg--git-pp-grab-line-matching "only has" nil :next-action 'stash)
	   (egg--git-pp-fatal-result))))
   (cons "drop" args)))

(defun egg--git-stash-unstash-cmd (buffer-to-update cmd &optional args)
  "Run a git stash CMD command synchronously with ARGS as arguments.
CMD should be pop, apply or branch.
 See documentation of `egg--git-action-cmd-doc' for the return structure."
  (unless (egg-has-stashed-wip)
    (error "no WIP was stashed!"))
  (let ((files (egg-git-to-lines "diff" "--name-only" "stash@{0}"))
	(cmd (or cmd "pop"))
	res)
    (setq res
	  (egg--do-git-action
	   "stash" buffer-to-update
	   (lambda (ret-code)
	     (if (= ret-code 0)
		 (or (egg--git-pp-grab-line-matching "Dropped refs/stash" nil
						     :next-action 'status :success t)
		     (egg--git-pp-grab-line-no -1 :next-action 'status :success t))
	       (or (egg--git-pp-grab-line-matching "^CONFLICT" nil 
						   :next-action 'status :success t)
		   (egg--git-pp-grab-line-matching 
		    "following files would be overwritten"
		    "stashed wip conflicts with local modifications, please commit first"
		    :next-action 'status)
		   (egg--git-pp-fatal-result))))
	   (cons cmd args)))
    (when (plist-get res :success)
      (setq res (nconc res (list :files files))))
    res))

(defun egg--git-cherry-pick-pp (ret-code rev not-commit-yet)
  (cond ((= ret-code 0)
	 (or (egg--git-pp-grab-line-matching
	      (regexp-opt '("file changed" "files changed"
			    "insertions" "deletions"))
	      nil :success t :next-action (if not-commit-yet 'commit 'log))
	     (if not-commit-yet
		(if (egg-git-ok nil "diff" "--quiet" "--cached")
		    ;; cherry pick produced empty index
		    (list :success t
			  :line (or (egg--git-pp-grab-line-no -1)
				    (format "cherry '%s' evaporated!!!" (egg-sha1 rev))))
		  (list :success t :next-action 'commit
			:line (or (egg--git-pp-grab-line-no -1)
				  (format "cherry '%s' picked, ready to be committed"
					  (egg-sha1 rev)))))
	       (list :success t :next-action 'log
		     :line (or (egg--git-pp-grab-line-no -1)
			       (format "'%s' applied cleanly" (egg-sha1 rev)))))))
	((= ret-code 1)
	 (or
	  (egg--git-pp-grab-line-matching 
	   (regexp-opt '("cherry-pick is now empty" "nothing to commit"))
	   nil :success t)
	  (egg--git-pp-grab-line-matching "after resolving the conflicts"
					  "please resolve conflicts"
					  :next-action 'status :success t)
	  (egg--git-pp-grab-line-matching "error: could not apply" nil
					  :next-action 'status)
	  (egg--git-pp-grab-line-no -1)))
	(t (egg--git-pp-fatal-result))))

(defun egg--git-cherry-pick-cmd (buffer-to-update rev &rest args)
  "Run the git cherry-pick command synchronously with ARGS as arguments.
REV is the commit to be picked.

See documentation of `egg--git-action-cmd-doc' for the return structure."
  (let ((files (egg-git-to-lines "diff" "--name-only" rev))
	(no-commit (and (member "--no-commit" args) t))
	res)
    (setq res 
	  (egg--do-git-action
	   "cherry-pick"
	   buffer-to-update
	   `(lambda (ret-code)
	      (egg--git-cherry-pick-pp ret-code ,rev ,no-commit))
	   (nconc args (list rev))))
    (when (plist-get res :success)
      (nconc res (list :files files)))
    res))

(defun egg--git-cherry-pick-cmd-test (rev option)
  (interactive
   (list (egg-read-rev "cherry pick rev: " 
		       (or (egg-ref-at-point) (egg-commit-at-point) (egg-string-at-point)))
	 (read-string "cherry pick option: " "--no-commit")))
  (egg--buffer-handle-result (egg--git-cherry-pick-cmd t rev option) t))

(defun egg--git-apply-cmd (buffer-to-update patch &optional args)
  "Run the git apply command with PATCH as input and ARGS as arguments.
Update BUFFER-TO-UPDATE as needed.

See documentation of `egg--git-action-cmd-doc' for the return structure."
  (let ((files (egg-git-lines-matching-stdin patch "^[0-9]+\t[0-9]+\t\\(.+\\)$" 1
					     "apply" "--numstat" "-"))
	res)
    (setq res 
	  (egg--do-git-action-stdin
	   "apply" patch
	   buffer-to-update
	   (lambda (ret-code)
	     (cond ((= ret-code 0)
		    (or (egg--git-pp-grab-line-matching "Applied patch.+cleanly" 
							"patch applied cleanly"
							:success t :next-action 'commit)
			(egg--git-pp-grab-line-no -1 :success t :next-action 'status)))
		   ((= ret-code 1) 
		    (or (egg--git-pp-grab-line-matching "Fall back to three-way merge"
							"Patch produced conflicts"
							:success t :next-action 'status)
			(egg--git-pp-grab-1st-line-matching 
			 '("Apply patch to.+with conflicts"
			   "error:.+patch does not apply"
			   "patch failed:"))
			(egg--git-pp-grab-line-no -1)))
		   (t (egg--git-pp-fatal-result))))
	   (append args (list "-v" "-"))))
    (when (plist-get res :success)
      (nconc res (list :files files)))
    res))

(defun egg--git-apply-cmd-test (file)
  (interactive "fpatch file: ")
  (with-temp-buffer
    (insert-file-contents-literally file)
    (egg--git-apply-cmd nil (buffer-string) '("-3"))
    (egg-status nil nil)))

(defun egg--git-pp-commit-output (ret-code)
  (cond ((= ret-code 0)
	 (or (egg--git-pp-grab-line-matching "files? changed" nil
					     :success t :next-action 'status)
	     (egg--git-pp-grab-line-no -1 :success t :next-action 'status)))
	((= ret-code 1)
	 (or (egg--git-pp-grab-1st-line-matching '("^nothing" "^Abort") nil
						 :success t)
	     (egg--git-pp-grab-line-no -1)))
	(t (egg--git-pp-fatal-result (regexp-opt '("empty message" "nothing to amend"))
				     "[Oo]nly one.+ can be used"))))

(defun egg--git-commit-with-region-cmd (buffer-to-update beg end gpg-uid &rest args)
  (egg--do-git-action-stdin "commit"
			    (cons beg end) buffer-to-update
			    #'egg--git-pp-commit-output
			    (append args (cond ((eq gpg-uid t) (list "-v" "-S" "-F" "-"))
					       ((stringp gpg-uid) (list "-v" 
									(concat "--gpg-sign=" gpg-uid)
									"-F" "-"))
					       (t (list "-v" "-F" "-"))))))

(defun egg--async-create-signed-commit-handler (buffer-to-update)
  (goto-char (point-min))
  (re-search-forward "EGG-GIT-OUTPUT:\n" nil t)
  (if (not (match-end 0))
      (message "something wrong with git-commit's output!")
    (let* ((proc egg-async-process)
	   (ret-code (process-exit-status proc))
	   res)
      (goto-char (match-end 0)) commit
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

(defun egg--async-create-signed-commit-cmd (buffer-to-update beg end gpg-uid &rest extras)
  (let ((args (list "-v" (if (stringp gpg-uid)
			     (concat "--gpg-sign=" gpg-uid)
			   "-S") 
		    "-m" (buffer-substring-no-properties beg end))))
    (setq args (nconc args extras))
    (egg-async-1-args (list #'egg--async-create-signed-commit-handler buffer-to-update)
		      (cons "commit" args))))

(defsubst egg-do-commit-with-region (beg end gpg-uid)
  (funcall (if gpg-uid
	       #'egg--async-create-signed-commit-cmd
	     #'egg--git-commit-with-region-cmd)
	   t beg end gpg-uid))

(defsubst egg-do-amend-with-region (beg end gpg-uid)
  (funcall (if gpg-uid
	       #'egg--async-create-signed-commit-cmd
	     #'egg--git-commit-with-region-cmd)
	   t beg end gpg-uid "--amend"))

(defun egg--git-amend-no-edit-cmd (buffer-to-update &rest args)
  (egg--do-git-action
   "commit" buffer-to-update #'egg--git-pp-commit-output
   (nconc (list "--amend" "--no-edit") args)))

(defsubst egg-buffer-do-amend-no-edit (&rest args)
  (egg--buffer-handle-result (egg--git-amend-no-edit-cmd t) t))


(defun egg--git-revert-pp (ret-code rev not-commit-yet)
  (cond ((= ret-code 0)
	 (or (egg--git-pp-grab-line-matching
	      (regexp-opt '("file changed" "files changed"
			    "insertions" "deletions"))
	      nil :success t :next-action (if not-commit-yet 'commit 'log))
	     (if not-commit-yet
		(if (egg-git-ok nil "diff" "--quiet" "--cached")
		    ;; revert produced empty index
		    (list :success t
			  :line (or (egg--git-pp-grab-line-no -1)
				    (format "successfully reverted '%s', but resulted in no changes"
					    (egg-sha1 rev))))
		  (list :success t :next-action 'commit
			:line (or (egg--git-pp-grab-line-no -1)
				  (format "reverted '%s', ready to commit"
					  (egg-sha1 rev)))))
	       (list :success t :next-action 'log
		     :line (or (egg--git-pp-grab-line-no -1)
			       (format "rev '%s' reverted" (egg-sha1 rev)))))))
	((= ret-code 1)
	 (or
	  (egg--git-pp-grab-line-matching "after resolving the conflicts"
					  "revert produced conflicts, please resolve"
					  :next-action 'status :success t)
	  (egg--git-pp-grab-line-matching "error: could not revert" nil
					  :next-action 'status)
	  (egg--git-pp-grab-line-no -1)))
	(t (egg--git-pp-fatal-result))))

(defun egg--git-revert-cmd (buffer-to-update rev use-default-msg)
  "Run the git revert command synchronously with ARGS as arguments.
REV is the commit to be picked.

See documentation of `egg--git-action-cmd-doc' for the return structure."
  (let ((files (egg-git-to-lines "diff" "--name-only" rev))
	(not-commit-yet (null use-default-msg))
	res)
    (setq res 
	  (egg--do-git-action
	   "revert"
	   buffer-to-update
	   `(lambda (ret-code)
	      (egg--git-revert-pp ret-code ,rev ,not-commit-yet))
	   (list (if use-default-msg "--no-edit" "--no-commit") rev)))
    (when (plist-get res :success)
      (nconc res (list :files files)))
    res))

(defun egg--git-tag-cmd-pp (ret-code)
  (cond ((= ret-code 0)
	 (or (egg--git-pp-grab-1st-line-matching 
	      '("Deleted tag" "Updated tag" "Good signature from"
		"^user: ") nil :next-action 'log :success t)
	     (egg--git-pp-grab-line-no -1 :next-action 'log :success t)))
	((= ret-code 1)
	 (or (egg--git-pp-grab-1st-line-matching '("no signature found" "^error:"))
	     (egg--git-pp-grab-line-no -1)))
	(t ;; 128
	 (egg--git-pp-fatal-result 
	  "gpg: skipped\\|^gpg: \\|empty.+object\\|bad object\\|[Nn]o tag"))))

(defun egg--git-tag-cmd (buffer-to-update stdin &optional args)
  (if stdin
      (egg--do-git-action-stdin "tag" stdin buffer-to-update #'egg--git-tag-cmd-pp args)
    (egg--do-git-action "tag" buffer-to-update #'egg--git-tag-cmd-pp args)))

(defun egg--git-tag-check-name (name &optional force ambiguity-ok)
  (let ((check-name (egg-git-to-string "name-rev" name)))
    (setq check-name (save-match-data (split-string check-name " " t)))
    (cond ((and (equal (nth 0 check-name) "Could")
		(equal (nth 1 check-name) "not"))
	   nil) ;; ok, no collision
	  ((and (equal (nth 0 check-name) name)
		(not (equal (nth 1 check-name) name))
		;; collision with existing tag
		(or force
		    (y-or-n-p (format "a tag %s already exists, force move? " name)))))
	  ((and (equal (nth 0 check-name) name)
		(equal (nth 1 check-name) name)
		;; collison with heads
		(unless ambiguity-ok
		  (error "Refuse to introduce ambiguity: a branch head %s alread exist! bailed out!"
			 name))
		nil)))))

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
        (while (re-search-forward "^\\([0-9a-f]\\{40\\}\\) \\([0-9]+\\) \\([0-9]+\\) \\([0-9]+\\)$" nil t)
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
          (when (egg-git-ok t "blame" "-w" "-M" "-C" "--porcelain" "--"
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

(defconst egg-hide-show-map
  (let ((map (make-sparse-keymap "Egg:HideShow")))
    (define-key map (kbd "h") 'egg-section-cmd-toggle-hide-show)
    (define-key map (kbd "H") 'egg-section-cmd-toggle-hide-show-children)
    (define-key map [mouse-2] 'egg-mouse-hide-show-cmd)
    map)
  "Keymap for a section than can be hidden/shown.\\{egg-hide-show-map}")

(defconst egg-section-map
  (let ((map (make-sparse-keymap "Egg:Section")))
    (set-keymap-parent map egg-hide-show-map)
    (define-key map (kbd "n") 'egg-buffer-cmd-navigate-next)
    (define-key map (kbd "p") 'egg-buffer-cmd-navigate-prev)
    map)
  "Keymap for a section in sequence that can be navigated back and forth.
\\{egg-section-map}")

(defconst egg-diff-section-map
  (let ((map (make-sparse-keymap "Egg:Diff")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "RET") 'egg-diff-section-cmd-visit-file-other-window)
    (define-key map (kbd "f") 'egg-diff-section-cmd-visit-file)
    (define-key map (kbd "=") 'egg-diff-section-cmd-ediff)
    map)
  "Keymap for a diff section in sequence of deltas.
\\{egg-diff-section-map}")

(defconst egg-staged-diff-section-map
  (let ((map (make-sparse-keymap "Egg:StagedDiff")))
    (set-keymap-parent map egg-diff-section-map)
    (define-key map (kbd "=") 'egg-staged-section-cmd-ediff3)
    (define-key map (kbd "s") 'egg-diff-section-cmd-unstage)
    (define-key map (kbd "DEL") 'egg-diff-section-cmd-revert-to-head)
    (define-key map [C-down-mouse-2] 'egg-status-popup-staged-diff-menu)
    (define-key map [C-mouse-2] 'egg-status-popup-staged-diff-menu)

    map)
  "Keymap for a diff section in sequence of staged deltas.
\\{egg-staged-diff-section-map}")

(defconst egg-wdir-diff-section-map
  (let ((map (make-sparse-keymap "Egg:WdirDiff")))
    (set-keymap-parent map egg-diff-section-map)
    (define-key map (kbd "u") 'egg-diff-section-cmd-undo)
    map)
  "Keymap for a diff section in sequence of deltas between the workdir and
the index. \\{egg-wdir-diff-section-map}")

(defconst egg-unstaged-diff-section-map
  (let ((map (make-sparse-keymap "Egg:UnstagedDiff")))
    (set-keymap-parent map egg-wdir-diff-section-map)
    (define-key map (kbd "=") 'egg-unstaged-section-cmd-ediff)
    (define-key map (kbd "s") 'egg-diff-section-cmd-stage)
    (define-key map (kbd "DEL") 'egg-diff-section-cmd-revert-to-head)

    (define-key map [C-down-mouse-2] 'egg-status-popup-unstaged-diff-menu)
    (define-key map [C-mouse-2] 'egg-status-popup-unstaged-diff-menu)

    map)
  "Keymap for a diff section in sequence of unstaged deltas.
\\{egg-unstaged-diff-section-map}")

(defconst egg-unmerged-diff-section-map
  (let ((map (make-sparse-keymap "Egg:UnmergedDiff")))
    (set-keymap-parent map egg-unstaged-diff-section-map)
    (define-key map (kbd "=") 'egg-unmerged-section-cmd-ediff3)
    map)
  "Keymap for a diff section in sequence of unmerged deltas.
\\{egg-unmerged-diff-section-map}")

(defconst egg-hunk-section-map
  (let ((map (make-sparse-keymap "Egg:Hunk")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "RET") 'egg-hunk-section-cmd-visit-file-other-window)
    (define-key map (kbd "=") 'egg-diff-section-cmd-ediff)
    (define-key map (kbd "f") 'egg-hunk-section-cmd-visit-file)
    map)
  "Keymap for a hunk in a diff section. \\{egg-hunk-section-map}")

(defconst egg-staged-hunk-section-map
  (let ((map (make-sparse-keymap "Egg:StagedHunk")))
    (set-keymap-parent map egg-hunk-section-map)
    (define-key map (kbd "=") 'egg-staged-section-cmd-ediff3)
    (define-key map (kbd "s") 'egg-hunk-section-cmd-unstage)

    (define-key map [C-down-mouse-2] 'egg-status-popup-staged-hunk-menu)
    (define-key map [C-mouse-2] 'egg-status-popup-staged-hunk-menu)

    map)
  "Keymap for a hunk in a staged diff section.
\\{egg-staged-hunk-section-map}")

(defconst egg-wdir-hunk-section-map
  (let ((map (make-sparse-keymap "Egg:WdirHunk")))
    (set-keymap-parent map egg-hunk-section-map)
    (define-key map (kbd "u") 'egg-hunk-section-cmd-undo)
    map)
  "Keymap for a hunk in a diff section between the workdir and the index.
\\{egg-wdir-hunk-section-map}")

(defconst egg-unstaged-hunk-section-map
  (let ((map (make-sparse-keymap "Egg:UnstagedHunk")))
    (set-keymap-parent map egg-wdir-hunk-section-map)
    (define-key map (kbd "=") 'egg-unstaged-section-cmd-ediff)
    (define-key map (kbd "s") 'egg-hunk-section-cmd-stage)

    (define-key map [C-down-mouse-2] 'egg-status-popup-unstaged-hunk-menu)
    (define-key map [C-mouse-2] 'egg-status-popup-unstaged-hunk-menu)

    map)
  "Keymap for a hunk in a unstaged diff section.
\\{egg-unstaged-hunk-section-map}")

(defconst egg-unmerged-hunk-section-map
  (let ((map (make-sparse-keymap "Egg:UnmergedHunk")))
    ;; no hunking staging in unmerged file
    (set-keymap-parent map egg-wdir-hunk-section-map)
    (define-key map (kbd "=") 'egg-unmerged-section-cmd-ediff3)
    map)
  "Keymap for a hunk in a unmerged diff section.
\\{egg-unmerged-hunk-section-map}")

(defun list-tp ()
  (interactive)
  (message "tp: %S" (text-properties-at (point))))

(defun list-nav ()
  (interactive)
  (message "nav: %c:%s-%c:%s"
           (preceding-char)
           (get-text-property (1- (point)) :navigation)
           (following-char)
           (get-text-property (point) :navigation)))

(defsubst egg-navigation-at-point ()
  (get-text-property (point) :navigation))

(defsubst egg-invisible-spec-at-point ()
  (get-text-property (point) 'invisible))

(defsubst egg-hunk-at-point ()
  (get-text-property (point) :hunk))

(defsubst egg-diff-at-point ()
  (get-text-property (point) :diff))

(defsubst egg-point-in-section (section-id)
  (eq (get-text-property (point) :section) section-id))

(defsubst egg-safe-search (re limit &optional no)
  (save-excursion
    (save-match-data
      (and (re-search-forward re limit t)
           (match-beginning (or no 0))))))

(defsubst egg-safe-search-pickup (re &optional limit no)
  (save-excursion
    (save-match-data
      (and (re-search-forward re limit t)
           (match-string-no-properties (or no 0))))))

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
  (put-text-property (1- line-beg) beg 'display "    -- ")
  (put-text-property beg end 'face 'egg-diff-none))

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
                  "\\+\\+<<<<<<< \\(.+\\)\\(?::.+\\)\\|";8 conflict start
                  "\\(\\+\\+=======\\)\\|"		;9 conflict div
                  "\\+\\+>>>>>>> \\(.+\\)\\(?::.+\\)\\|";10 conflict end
                  "\\( -.*\\)\\|"			;11 cc-del
                  "\\( \\+.*\\)\\|"			;12 cc-add
                  "\\(-.*\\)\\|"			;13 del
                  "\\(\\+.*\\)\\|"			;14 add
                  "\\( .*\\)"				;15 none
                  "\\)$"))

         ;; where the hunk end?
         (hunk-end-re "^\\(?:diff\\|@@\\)")
         ;; where the diff end?
         (diff-end-re "^diff ")

         sub-beg sub-end head-end m-b-0 m-e-0 m-b-x m-e-x
         last-diff last-cc current-delta-is)

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
                       m-e-x (match-end conf-beg-no))
                 (put-text-property m-b-0 m-b-x 'face 'egg-diff-conflict)
                 (put-text-property m-b-x m-e-x 'face 'egg-branch-mono)
                 (put-text-property m-e-x m-e-0 'face 'egg-diff-none)
                 ;; mark the whole conflict section
                 (setq sub-end (egg-safe-search "^++>>>>>>>.+$" end))
                 (put-text-property m-b-0 sub-end 'keymap
                                    conflict-map))

                ((match-beginning conf-end-no)
                 (setq m-b-x (match-beginning conf-end-no)
                       m-e-x (match-end conf-end-no))
                 ;; just decorate, no mark.
                 ;; the section was already mark when the conf-beg-no
                 ;; matched.
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
                       head-end (or (egg-safe-search "^@@" end) end))
                 ;; decorate the header
                 (egg-decorate-diff-header m-b-x m-e-x m-b-0 m-e-0)
                 ;; mark the whole diff
                 (egg-delimit-section
                  :diff (setq last-diff
                              (egg-make-diff-info
                               (match-string-no-properties diff-no)
                               sub-beg sub-end head-end))
                  sub-beg sub-end m-e-0 diff-map 'egg-compute-navigation)
		 
		 (setq current-delta-is 'diff))

                ((match-beginning cc-diff-no) ;; cc-diff
                 (setq m-b-x (match-beginning cc-diff-no)
                       m-e-x (match-end cc-diff-no)
                       sub-end (or (egg-safe-search diff-end-re end) end)
                       ;; find the end of the header
                       head-end (or (egg-safe-search "^@@@" end) end))
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

		 (setq current-delta-is 'cc-diff))

                ((match-beginning index-no) ;; index
                 (setq m-b-x (match-beginning index-no)
                       m-e-x (match-end index-no))
                 (egg-decorate-diff-index-line m-b-x m-e-x m-b-0 m-b-0))
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

(defun egg-diff-section-cmd-visit-file (file)
  "Visit file FILE."
  (interactive (list (car (get-text-property (point) :diff))))
  (find-file file))

(defun egg-diff-section-cmd-visit-file-other-window (file)
  "Visit file FILE in other window."
  (interactive (list (car (get-text-property (point) :diff))))
  (find-file-other-window file))

(defun egg-unmerged-section-cmd-ediff3 (file)
  "Run ediff3 to resolve merge conflicts in FILE."
  (interactive (list (car (get-text-property (point) :diff))))
  (find-file file)
  (egg-resolve-merge-with-ediff))

(defun egg-unstaged-section-cmd-ediff (file)
  "Compare FILE and its staged copy using ediff."
  (interactive (list (car (get-text-property (point) :diff))))
  (find-file file)
  (egg-file-do-ediff ":0" "INDEX"))

(defun egg-staged-section-cmd-ediff3 (file)
  "Compare the staged copy of FILE and the version in HEAD using ediff."
  (interactive (list (car (get-text-property (point) :diff))))
  (find-file file)
  (egg-file-do-ediff ":0" "INDEX" "HEAD"))

(defvar egg-diff-buffer-info nil
  "Data for the diff buffer.
This is built by `egg-build-diff-info'")

(defun egg-diff-section-cmd-ediff (file pos)
  "Ediff src and dest versions of FILE based on the diff at POS."
  (interactive (list (car (get-text-property (point) :diff))
                     (point)))
  (let ((commit (get-text-property pos :commit))
        (diff-info egg-diff-buffer-info)
        src src-name dst)
    (find-file file)
    (cond (commit
           (setq src (egg-describe-rev (concat commit "^"))
                 dst (egg-describe-rev commit)))
          ((setq src (plist-get diff-info :src-revision))
	   (when (consp src)
	     (setq src (egg-git-to-string "merge-base" (car src) (cdr src))))
           (setq src (egg-describe-rev src)))
          ((setq src (and diff-info ":0"))
           (setq src-name "INDEX")))
    (unless src (error "Ooops!"))
    (egg-file-do-ediff src src-name dst nil 'ediff2)))

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
      (if (< (point) limit)
          (while (re-search-forward "^\\(?:\\+\\| \\).*" limit t)
            (setq adjust (1+ adjust)))))
    (+ line adjust)))

(defsubst egg-hunk-info-at (pos)
  "Rebuild the hunk info at POS.
Hunk info are relative offsets. This function compute the
physical offsets. The hunk-line may be NIL if this is not status
or commit buffer and `egg-calculate-hunk-ranges' was
not called"
  (let* ((diff-info (get-text-property pos :diff))
         (head-beg (nth 1 diff-info))
         (hunk-info (get-text-property pos :hunk))
         (hunk-beg (+ (nth 1 hunk-info) head-beg))
         (hunk-end (+ (nth 2 hunk-info) head-beg))
         (hunk-ranges (nth 3 hunk-info)))
    (list (car diff-info) (car hunk-info) hunk-beg hunk-end hunk-ranges)))

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

(defun egg-section-cmd-toggle-hide-show (nav)
  "Toggle the hidden state of the current navigation section of type NAV."
  (interactive (list (get-text-property (point) :navigation)))

  ;; emacs's bug? caused by tooltip
  (if (eq buffer-invisibility-spec t)
      (setq buffer-invisibility-spec nil))

  (if (assoc nav buffer-invisibility-spec)
      (remove-from-invisibility-spec (cons nav t))
    (add-to-invisibility-spec (cons nav t)))
  (force-window-update (current-buffer)))

(defun egg-section-cmd-toggle-hide-show-children (pos sect-type)
  "Toggle the hidden state of the subsections of the current navigation section at POS."
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

(defun egg-use-region-p ()
  (if (fboundp 'use-region-p)
      (use-region-p)
    (and transient-mark-mode mark-active)))

(defun egg-insert-current-line-buffer (buf)
  (egg-insert-string-buffer (egg-current-line-string) buf))

(defun egg-current-line-string ()
  (buffer-substring-no-properties
   (line-beginning-position) (line-beginning-position 2)))

(defun egg-insert-string-buffer (string buf)
  (with-current-buffer buf
     (insert string)))

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
(defvar egg-buffer-refresh-func nil)
(defvar egg-buffer-async-cmd-refresh-func nil)
(defvar egg-internal-update-index-timer nil)

(defsubst egg-buffer-async-do (accepted-code &rest args)
  "Run git asynchronously and refresh the current buffer on exit.
exit code ACCEPTED-CODE is considered a success."
  (egg-async-do accepted-code
                (cons (or egg-buffer-async-cmd-refresh-func
                          egg-buffer-refresh-func)
                      (list (current-buffer)))
                args))

(defsubst egg-run-buffers-update-hook (&optional newly-read-state)
  "Update all egg special buffers."
  (let ((egg-internal-current-state
         (or newly-read-state (egg-get-repo-state))))
    (run-hooks 'egg-buffers-refresh-hook)))

(defun egg-refresh-buffer (buffer)
  (when (and (bufferp buffer) (buffer-live-p buffer))
    (with-current-buffer buffer
	(when (and (egg-git-dir)
		   (functionp egg-buffer-refresh-func))
	  (let ((line (count-lines (point-min) (point)))
		(column (current-column))
		(anchor (get-text-property (point) :navigation))
		(offset (egg-section-relative-pos (point)))
		(win-anchor-off-line-col-alist
		 (mapcar (lambda (win)
			   (let* ((win-pos (window-point win))
				  (win-anchor (get-text-property win-pos :navigation))
				  (win-off (egg-section-relative-pos win-pos))
				  (win-line (count-lines (point-min) win-pos))
				  (win-col (save-excursion
					     (goto-char win-pos)
					     (current-column))))
			     (list win win-anchor win-off win-line win-col)))
			 (get-buffer-window-list))))
	    (funcall egg-buffer-refresh-func (current-buffer))
	    (if anchor
		(egg-buffer-goto-section anchor)
	      (egg-goto-line line)
	      (goto-char (+ (line-beginning-position) column)))
	    (dolist (win-anchor-off-line-col win-anchor-off-line-col-alist)
	      (let ((win (nth 0 win-anchor-off-line-col))
		    (anchor (nth 1 win-anchor-off-line-col))
		    (offset (nth 2 win-anchor-off-line-col))
		    (line (nth 3 win-anchor-off-line-col))
		    (col (nth 4 win-anchor-off-line-col)))
		(with-selected-window win
		  (if anchor
		      (egg-buffer-goto-section anchor offset)
		    (egg-goto-line line)
		    (goto-char (+ (line-beginning-position) column)))))))))))

(defun egg-buffer-cmd-refresh ()
  "Refresh the current egg special buffer."
  (interactive)
  (when (and (egg-git-dir)
             (functionp egg-buffer-refresh-func))
    (funcall egg-buffer-refresh-func (current-buffer))))

(defun egg-buffer-cmd-next-block (nav-prop)
  "Move to the next block indentified by text property NAV-PROP."
  (goto-char (or (next-single-property-change (point) nav-prop)
                 (point))))

(defun egg-buffer-cmd-prev-block (nav-prop)
  "Move to the previous block indentified by text property NAV-PROP."
  (goto-char (previous-single-property-change (point) nav-prop
                                              nil (point-min))))

(defun egg-buffer-cmd-navigate-next (&optional at-level)
  "Move to the next section."
  (interactive "P")
  (egg-buffer-cmd-next-block
   (if (not at-level) :navigation
     (or (get-text-property (point) :sect-type) :navigation))))

(defun egg-buffer-cmd-navigate-prev (&optional at-level)
  "Move to the previous section."
  (interactive "P")
  (egg-buffer-cmd-prev-block 
   (if (not at-level) :navigation
     (or (get-text-property (point) :sect-type) :navigation))))

(defconst egg-buffer-mode-map
  (let ((map (make-sparse-keymap "Egg:Buffer")))
    (define-key map (kbd "q") 'egg-quit-buffer)
    (define-key map (kbd "G") 'egg-buffer-cmd-refresh)
    (define-key map (kbd "g") 'egg-buffer-cmd-refresh)
    (define-key map (kbd "n") 'egg-buffer-cmd-navigate-next)
    (define-key map (kbd "p") 'egg-buffer-cmd-navigate-prev)
    (define-key map (kbd "C-c C-h") 'egg-buffer-hide-all)
    map)
  "Common map for an egg special buffer.\\{egg-buffer-mode-map}" )

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
(defconst egg-status-buffer-mode-map
  (let ((map (make-sparse-keymap "Egg:StatusBuffer")))
    (set-keymap-parent map egg-buffer-mode-map)
    (define-key map (kbd "c") 'egg-commit-log-edit)
    (define-key map (kbd "o") 'egg-status-buffer-checkout-ref)
    (define-key map (kbd "l") 'egg-log)
    (define-key map (kbd "w") 'egg-status-buffer-stash-wip)
    (define-key map (kbd "W") 'egg-stash)
    (define-key map (kbd "L") 'egg-reflog)
    (define-key map (kbd "S") 'egg-stage-all-files)
    (define-key map (kbd "U") 'egg-unstage-all-files)
    (define-key map (kbd "X") 'egg-status-buffer-undo-wdir)
    (define-key map (kbd "d") 'egg-diff-ref)
    map)
  "Keymap for the status buffer.\\{egg-status-buffer-mode-map}")

(defconst egg-status-buffer-rebase-map
  (let ((map (make-sparse-keymap "Egg:StatusBufferRebase")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "x") 'egg-buffer-rebase-abort)
    (define-key map (kbd "u") 'egg-buffer-selective-rebase-skip)
    (define-key map (kbd "RET") 'egg-buffer-selective-rebase-continue)
    map)
  "Context keymap for the repo section of the status buffer when
  rebase is in progress.\\{egg-status-buffer-rebase-map}")

(defun egg-buffer-do-rebase (upstream-or-action &optional onto)
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
    (setq res (egg-do-rebase-head upstream-or-action onto))
    (egg-revert-visited-files (plist-get res :files))
    (message "GIT-REBASE> %s" (plist-get res :message))
    (plist-get res :success)))

(defun egg-buffer-rebase-continue ()
  "Continue the current rebase session."
  (interactive)
  (message "continue with current rebase")
  (unless (egg-buffer-do-rebase :continue)
    (egg-status nil t)))

(defsubst egg-do-async-rebase-continue (callback closure &optional
                                                 action
                                                 exit-code)
  "Continue the current rebase session asynchronously."
  (let ((process-environment process-environment)
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
      (unless (egg-buffer-do-rebase action)
        (egg-status nil t))
    (setq action (cdr (assq action '((:skip . "--skip")
                                     (:continue . "--continue")
                                     (:abort . "--abort")))))
    (egg-do-async-rebase-continue
     #'egg-handle-rebase-interactive-exit
     (egg-pick-file-contents (concat (egg-git-rebase-dir) "head") "^.+$")
     action)))

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
  (egg-buffer-do-rebase :abort)
  (egg-status nil t))

(defun egg-rebase-in-progress ()
  (plist-get (egg-repo-state) :rebase-step))

(defsubst egg-pretty-help-text (&rest strings)
  "Perform key bindings substitutions and highlighting in STRINGS."
  (let* ((map (current-local-map)) last-found)
    (with-temp-buffer
      (use-local-map map)
      (save-match-data
        ;; key substitutions
        (insert (substitute-command-keys
                 (mapconcat 'identity strings "")))
        (goto-char (point-min))
        ;; key highlighting
        (while (re-search-forward "\\(\\<[^\n \t:]+\\|[/+.~*=-]\\):" nil t)
          (put-text-property (match-beginning 1) (match-end 1)'face 'egg-help-key)
          (if last-found
              (put-text-property last-found (1- (match-beginning 0))
                                 'face 'egg-text-help))
          (setq last-found (point)))
        (if last-found
            (put-text-property last-found (line-end-position) 'face 'egg-text-help))
        ;; return the total
        (buffer-string)))))

(defconst egg-status-buffer-common-help-text
  (concat
   (egg-text "Common Key Bindings:" 'egg-help-header-2)
   (egg-pretty-help-text
    "\\<egg-status-buffer-mode-map>\n"
    "\\[egg-buffer-cmd-navigate-prev]:previous block  "
    "\\[egg-buffer-cmd-navigate-next]:next block  "
    "\\[egg-commit-log-edit]:commit staged modifications  "
    "\\[egg-log]:show repo's history\n"
    "\\[egg-stage-all-files]:stage all modifications  "
    "\\[egg-unstage-all-files]:unstage all modifications  "
    "\\[egg-diff-ref]:diff other revision\n"
    "\\[egg-status-buffer-undo-wdir]: throw away ALL modifications  "
    "\\<egg-unstaged-diff-section-map>"
    "\\[egg-diff-section-cmd-revert-to-head]:throw away file's modifications\n"
    "\\<egg-hide-show-map>"
    "\\[egg-section-cmd-toggle-hide-show]:hide/show block  "
    "\\[egg-section-cmd-toggle-hide-show-children]:hide sub-blocks  "
    "\\<egg-buffer-mode-map>"
    "\\[egg-buffer-cmd-refresh]:redisplay  "
    "\\[egg-quit-buffer]:quit\n")))

(defconst egg-status-buffer-rebase-help-text
  (concat
   (egg-text "Key Bindings for Rebase Operations:" 'egg-help-header-2)
   (egg-pretty-help-text
    "\\<egg-status-buffer-rebase-map>\n"
    "\\[egg-buffer-selective-rebase-continue]:resume rebase  "
    "\\[egg-buffer-selective-rebase-skip]:skip this rebase step  "
    "\\[egg-buffer-rebase-abort]:abort current rebase session\n")))

(defconst egg-status-buffer-diff-help-text
  (concat
   (egg-text "Extra Key Bindings for the Diff Sections:"
             'egg-help-header-2)
   (egg-pretty-help-text
    "\\<egg-unstaged-diff-section-map>\n"
    "\\[egg-diff-section-cmd-visit-file-other-window]:visit file/line  "
    "\\[egg-diff-section-cmd-stage]:stage/unstage file/hunk/selected area  "
    "\\[egg-diff-section-cmd-undo]:undo file/hunk's modifications\n")))

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

(defconst egg-untracked-file-map
  (let ((map (make-sparse-keymap "Egg:UntrackedFile")))
    (define-key map (kbd "RET") 'egg-find-file-at-point)
    (define-key map (kbd "DEL") 'egg-ignore-pattern-from-string-at-point)
    (define-key map "s" 'egg-status-buffer-stage-untracked-file)
    (define-key map "i" 'egg-status-buffer-stage-untracked-file)
    map)
  "Keymap for a section of untracked file.
\\{egg-untracked-file-map}")

(defun egg-sb-insert-untracked-section ()
  "Insert the untracked files section into the status buffer."
  (let ((beg (point)) inv-beg end)
    (insert (egg-prepend "Untracked Files:" "\n\n"
                         'face 'egg-section-title
                         'help-echo (egg-tooltip-func))
            "\n")
    (setq inv-beg (1- (point)))
    (call-process egg-git-command nil t nil "ls-files" "--others"
                  "--exclude-standard")
    (setq end (point))
    (egg-delimit-section :section 'untracked beg end
                         inv-beg egg-section-map 'untracked)
    (put-text-property inv-beg end 'keymap egg-untracked-file-map)
    (put-text-property (1+ inv-beg) end 'help-echo (egg-tooltip-func))))

(defsubst egg-list-stash (&optional ignored)
  (egg-git-ok t "stash" "list"))

(defun egg-sb-buffer-show-stash (pos)
  (interactive "d")
  (let* ((next (next-single-property-change pos :diff))
         (stash (and next (get-text-property next :stash))))
    (unless (equal (get-text-property pos :stash) stash)
      (egg-buffer-do-insert-stash pos))))

(defconst egg-stash-map
  (let ((map (make-sparse-keymap "Egg:Stash")))
    (set-keymap-parent map egg-hide-show-map)
    (define-key map (kbd "SPC") 'egg-sb-buffer-show-stash)
    (define-key map (kbd "RET") 'egg-sb-buffer-apply-stash)
    (define-key map "a" 'egg-sb-buffer-apply-stash)
    (define-key map (kbd "DEL") 'egg-sb-buffer-drop-stash)
    (define-key map "o" 'egg-sb-buffer-pop-stash)
    map))

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
    ;;(put-text-property (1+ inv-beg) end 'help-echo (egg-tooltip-func))
    ))

(defun egg-sb-insert-unstaged-section (title &rest extra-diff-options)
  "Insert the unstaged changes section into the status buffer."
  (let ((beg (point)) inv-beg diff-beg)
    (insert (egg-prepend title "\n\n" 'face 'egg-section-title
                         'help-echo (egg-tooltip-func))
            "\n")
    (setq diff-beg (point))
    (setq inv-beg (1- (point)))
    (apply 'call-process egg-git-command nil t nil "diff" "--no-color"
           "-M" "-p" "--src-prefix=INDEX:/" "--dst-prefix=WORKDIR:/"
           (append egg-git-diff-options extra-diff-options))
    (egg-delimit-section :section 'unstaged beg (point)
                         inv-beg egg-section-map 'unstaged)
    ;; this section might contains merge conflicts, thus cc-diff
    (egg-decorate-diff-section :begin diff-beg
                               :end (point)
                               :src-prefix "INDEX:/"
                               :dst-prefix "WORKDIR:/"
                               :diff-map egg-unstaged-diff-section-map
                               :hunk-map egg-unstaged-hunk-section-map
                               :cc-diff-map egg-unmerged-diff-section-map
                               :cc-hunk-map egg-unmerged-hunk-section-map
                               :conflict-map egg-unmerged-hunk-section-map)))

(defun egg-sb-insert-staged-section (title &rest extra-diff-options)
  "Insert the staged changes section into the status buffer."
  (let ((beg (point)) inv-beg diff-beg)
    (insert (egg-prepend title "\n\n"
                         'face 'egg-section-title
                         'help-echo (egg-tooltip-func))
            "\n")
    (setq diff-beg (point)
          inv-beg (1- diff-beg))
    (apply 'call-process egg-git-command nil t nil "diff" "--no-color"
           "--cached" "-M" "-p" "--src-prefix=HEAD:/" "--dst-prefix=INDEX:/"
           (append egg-git-diff-options extra-diff-options))
    (egg-delimit-section :section 'staged beg (point)
                         inv-beg egg-section-map 'staged)
    ;; this section never contains merge conflicts, thus no cc-diff
    (egg-decorate-diff-section :begin diff-beg
                               :end (point)
                               :src-prefix "HEAD:/"
                               :dst-prefix "INDEX:/"
                               :diff-map egg-staged-diff-section-map
                               :hunk-map egg-staged-hunk-section-map)))

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
                                     (copy-list range)
                                     (copy-list range)))
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
                          (find-if
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



(defsubst egg-buffer-hide-section-type (sect-type)
  "Hide sections of SECT-TYPE in current special egg buffer."
  (let ((pos (point-min)) nav)
    (while (setq pos (next-single-property-change (1+ pos) sect-type))
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
          (win (get-buffer-window buf)))
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
                ((eq sect 'unstaged) (egg-sb-insert-unstaged-section "Unstaged Changes:"))
                ((eq sect 'staged) (egg-sb-insert-staged-section "Staged Changes:"))
                ((eq sect 'untracked) (egg-sb-insert-untracked-section))
		((eq sect 'stash) (egg-sb-insert-stash-section))))
        (egg-calculate-hunk-ranges)
        (if init (egg-buffer-maybe-hide-all))
        (if init (egg-buffer-maybe-hide-help "help" 'repo))
        (egg-restore-section-visibility)
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

(defun egg-status-buffer-background-job ()
  (when egg-refresh-index-in-backround
    (mapcar #'egg-internal-background-refresh-index
            egg-internal-status-buffer-names-list)))

(defsubst egg-internal-background-jobs-restart ()
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
  :set 'egg-set-background-idle-period
  :type 'integer)

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

(defun egg-cmd-log-buffer ()
  (or (get-buffer (concat " *egg-cmd-logs@" (egg-git-dir) "*"))
      (let ((git-dir (egg-git-dir))
            (default-directory default-directory)
            dir)
        (unless git-dir
          (error "Can't find git dir in %s" default-directory))
        (setq dir (egg-work-tree-dir git-dir))
        (setq default-directory dir)
        (get-buffer-create (concat " *egg-cmd-logs@" git-dir "*")))))

(defun egg-cmd-log (&rest strings)
  (with-current-buffer (egg-cmd-log-buffer)
    (goto-char (point-max))
    (cons (current-buffer)
          (prog1 (point)
            (apply 'insert-before-markers "LOG/" strings)
	    (goto-char (point-max))))))

(defun egg-cmd-log-whole-buffer (buffer)
  (with-current-buffer (egg-cmd-log-buffer)
    (goto-char (point-max))
    (cons (current-buffer)
          (prog1 (point)
	    (insert-buffer-substring buffer)
	    (goto-char (point-max))))))

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

(defun egg-hunk-section-cmd-stage (pos)
  "Add the hunk enclosing POS to the index."
  (interactive "d")
  (egg-hunk-section-apply-cmd pos "--cached"))

(defun egg-hunk-section-cmd-unstage (pos)
  "Remove the hunk enclosing POS from the index."
  (interactive "d")
  (egg-hunk-section-apply-cmd pos "--cached" "--reverse"))

(defun egg-hunk-section-cmd-undo (pos)
  "Remove the file's modification described by the hunk enclosing POS."
  (interactive "d")
  (unless (or (not egg-confirm-undo)
              (y-or-n-p "irreversibly remove the hunk under cursor? "))
    (error "Too chicken to proceed with undo operation!"))
  (egg-hunk-section-apply-cmd pos "-p1" "--reverse"))

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
	   (egg--git-add-cmd t "-v" file))
	  (t ;; file is deleted, update the index
	   (egg--git-rm-cmd t file)))))

(defun egg-diff-section-cmd-unstage (pos)
  "For the file at POS, revert its stage in the index to original.
If the file was a newly created file, it will be removed from the index.
If the file was added after a merge resolution, it will reverted back to
conflicted state. Otherwise, its stage will be reset to HEAD."
  (interactive "d")
  (let ((is-merging (or (plist-get (egg-repo-state) :merge-heads)
			(plist-get (egg-repo-state) :rebase-dir)))
	(diff-info (get-text-property pos :diff))
	file newfile)
    (setq newfile (memq 'newfile diff-info)
	  file (car diff-info))
    (cond (newfile (egg--git-rm-cmd t "--cached" file))
	  (is-merging (egg--git-co-files-cmd t file "-m"))
	  (t (egg--git-reset-files-cmd t nil file)))))

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
        merge-cmd-ok res modified-files 
	need-commit force-commit-to-status line fix-line-func)
    
    (setq modified-files (egg-git-to-lines "diff" "--name-only" rev))
    (cond ((equal merge-mode-flag "--commit")
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
			   (plist-put merge-res :line line))))))))
	  ((member merge-mode-flag '("--no-commit" "--squash"))
	   (setq force-commit-to-status t)))

    (setq res (nconc (egg--git-merge-cmd 'all fix-line-func merge-mode-flag "--log" rev)
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

(defun egg-do-rebase-head (upstream-or-action &optional onto)
  "Rebase HEAD based on UPSTREAM-OR-ACTION.
If UPSTREAM-OR-ACTION is a string then it used as upstream for the rebase operation.
If ONTO is non-nil, then rebase HEAD onto ONTO using UPSTREAM-OR-ACTION as upstream.
If UPSTREAM-OR-ACTION is one of: :abort, :skip and :continue then
perform the indicated rebase action."
  (let ((pre-merge (egg-get-current-sha1))
        cmd-res modified-files feed-back old-choices)
    (with-egg-debug-buffer
      (erase-buffer)
      ;; (when (and (stringp upstream-or-action) ;; start a rebase
      ;;            (eq old-base t))	      ;; ask for old-base
      ;;   (unless (egg-git-ok (current-buffer) "rev-list"
      ;;                       "--topo-order" "--reverse"
      ;;                       (concat upstream-or-action "..HEAD^"))
      ;;     (error "Failed to find rev between %s and HEAD^: %s"
      ;;            upstream-or-action (buffer-string)))
      ;;   (unless (egg-git-region-ok (point-min) (point-max)
      ;;                              "name-rev" "--stdin")
      ;;     (error "Failed to translate revisions: %s" (buffer-string)))
      ;;   (save-match-data
      ;;     (goto-char (point-min))
      ;;     (while (re-search-forward "^.+(\\(.+\\))$" nil t)
      ;;       (setq old-choices (cons (match-string-no-properties 1)
      ;;                               old-choices))))
      ;;   (setq old-base
      ;;         (completing-read (or prompt "old base: ") old-choices))
      ;;   (erase-buffer))
      
      (setq cmd-res
            (cond ((and (stringp onto) (stringp upstream-or-action))
                   (egg-git-ok (current-buffer) "rebase" "-m" "--onto" onto upstream-or-action))
                  ((eq upstream-or-action :abort)
                   (egg-git-ok (current-buffer) "rebase" "--abort"))
                  ((eq upstream-or-action :skip)
                   (egg-git-ok (current-buffer) "rebase" "--skip"))
                  ((eq upstream-or-action :continue)
                   (egg-git-ok (current-buffer) "rebase" "--continue"))
                  ((stringp upstream-or-action)
                   (egg-git-ok (current-buffer) "rebase" "-m" upstream-or-action))))
      (goto-char (point-min))
      (setq feed-back
            (egg-safe-search-pickup
             "^\\(?:CONFLICT\\|All done\\|HEAD is now at\\|Fast-forwarded\\|You must edit all merge conflicts\\).+$"))
      (setq modified-files
            (egg-git-to-lines "diff" "--name-only" pre-merge))
      (egg-run-buffers-update-hook)
      (list :success cmd-res
            :message feed-back
            :files modified-files))))

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
  (egg-do-commit-with-region text-beg text-end gpg-uid))

(defsubst egg-log-msg-amend-commit (prefix gpg-uid text-beg text-end &rest ignored)
  "Amend the last commit with the index using the text between TEXT-BEG and TEXT-END
as message. PREFIX and IGNORED are ignored."
  (egg-do-amend-with-region text-beg text-end gpg-uid))

(defun egg-log-msg-buffer-toggle-signed ()
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
	 (closure egg-log-msg-closure)
	 (text-beg (nth 2 closure))
	 (text-end (nth 3 closure)))
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
        mode-line-process "")
  (set (make-local-variable 'egg-buffer-refresh-func)
       'egg-commit-log-buffer-show-diffs)
  (setq buffer-invisibility-spec nil)
  (run-mode-hooks 'egg-commit-buffer-mode-hook))

(defun egg-commit-log-edit (title-function
                            action-closure
                            insert-init-text-function &optional amend-no-msg)
  "Open the commit buffer for composing a message (if AMEND-NO-MSG is nil).
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
          pos beg end inv-beg help-beg help-end help-inv-beg err-code)

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
      (setq err-code (apply 'call-process egg-git-command nil t nil "diff" args))
      (egg-cmd-log (format "RET:%d\n" err-code))
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

(defconst egg-diff-buffer-common-help-text
  (concat
   (egg-text "Common Key Bindings:" 'egg-help-header-2)
   (egg-pretty-help-text
    "\\<egg-buffer-mode-map>\n"
    "\\[egg-buffer-cmd-navigate-prev]:previous block  "
    "\\[egg-buffer-cmd-navigate-next]:next block  "
    "\\[egg-buffer-cmd-refresh]:redisplay  "
    "\\[egg-quit-buffer]:quit\n")))

(defconst egg-diff-buffer-diff-help-heading
  (egg-text "Extra Bindings for Diff blocks:" 'egg-help-header-2))

(defconst egg-unstaged-diff-help-text
  (egg-pretty-help-text
   "\\<egg-unstaged-diff-section-map>\n"
   "\\[egg-diff-section-cmd-stage]:stage file/hunk  "
   "\\[egg-diff-section-cmd-undo]:undo file/hunk  "
   "\\[egg-diff-section-cmd-visit-file-other-window]:visit file/line\n"))

(defconst egg-staged-diff-help-text
  (egg-pretty-help-text
   "\\<egg-staged-diff-section-map>\n"
   "\\[egg-diff-section-cmd-stage]:unstage file/hunk  "
   "\\[egg-diff-section-cmd-visit-file-other-window]:visit file/line\n"))

(defconst egg-plain-diff-help-text
  (egg-pretty-help-text
   "\\<egg-diff-section-map>\n"
   "\\[egg-diff-section-cmd-visit-file-other-window]:visit file/line\n"))

(defconst egg-wdir-diff-help-text
  (egg-pretty-help-text
   "\\<egg-wdir-diff-section-map>\n"
   "\\[egg-diff-section-cmd-undo]:undo file/hunk  "
   "\\[egg-diff-section-cmd-visit-file-other-window]:visit file/line\n"))

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
        (setq file (list file))
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
	     (egg-file-get-other-version file (egg-short-sha1 sha1) nil t)))
  (when (numberp line)
    (goto-char (point-min))
    (forward-line (1- line))))

;;;========================================================
;;; log browsing
;;;========================================================
(defvar egg-log-buffer-comment-column nil)
(defvar egg-internal-log-buffer-closure nil)

(defun egg-run-git-log-HEAD (&optional refs-only)
  (if refs-only
      (egg-git-ok t "log" (format "--max-count=%d" egg-log-HEAD-max-len)
                  "--graph" "--topo-order" "--simplify-by-decoration"
                  "--pretty=oneline" "--decorate=full" "--no-color")
    (egg-git-ok t "log" (format "--max-count=%d" egg-log-HEAD-max-len)
                "--graph" "--topo-order"
                "--pretty=oneline" "--decorate=full" "--no-color")))

(defun egg-run-git-log-all (&optional refs-only)
  (if refs-only
      (egg-git-ok t "log" (format "--max-count=%d" egg-log-all-max-len)
                  "--graph" "--topo-order" "--simplify-by-decoration"
                  "--pretty=oneline" "--decorate=full" "--all" "--no-color")
    (egg-git-ok t "log" (format "--max-count=%d" egg-log-all-max-len)
                "--graph" "--topo-order"
                "--pretty=oneline" "--decorate=full" "--all" "--no-color")))

(defun egg-run-git-log-pickaxe (string)
  (egg-git-ok t "log" "--pretty=oneline" "--decorate=full" "--no-color"
              (concat "-S" string)))

(defun egg-log-show-ref (pos)
  (interactive "d")
  (let* ((ref-info (get-text-property pos :ref))
	 (reflog (unless ref-info (get-text-property pos :reflog)))
	 (ref-type (and (cdr ref-info)))
	 (reflog-time (and reflog (get-text-property pos :time))))
    (if ref-info
	(cond ((eq ref-type :head) (egg-show-branch (car ref-info)))
	      ((eq ref-type :tag) (egg-show-atag (car ref-info)))
	      ((eq ref-type :remote) (egg-show-remote-branch (car ref-info)))
	      (t nil))
      (when reflog
	(setq reflog (substring-no-properties reflog))
	(setq reflog-time (substring-no-properties reflog-time))
	(put-text-property 0 (length reflog) 'face 'bold reflog)
	(put-text-property 0 (length reflog-time) 'face 'bold reflog-time)
	(message "reflog:%s created:%s" reflog reflog-time)))))

(defconst egg-log-commit-base-map
  (let ((map (make-sparse-keymap "Egg:LogCommitBase")))
    (set-keymap-parent map egg-hide-show-map)
    (define-key map (kbd "SPC") 'egg-log-buffer-insert-commit)
    (define-key map (kbd "B") 'egg-log-buffer-create-new-branch)
    (define-key map (kbd "b") 'egg-log-buffer-start-new-branch)
    (define-key map (kbd "o") 'egg-log-buffer-checkout-commit)
    (define-key map (kbd "t") 'egg-log-buffer-tag-commit)
    (define-key map (kbd "T") 'egg-log-buffer-atag-commit)
    (define-key map (kbd "a") 'egg-log-buffer-anchor-head)
    (define-key map (kbd "m") 'egg-log-buffer-merge)
    (define-key map (kbd "r") 'egg-log-buffer-rebase)
    (define-key map (kbd "c") 'egg-log-buffer-pick-1cherry)
    (define-key map (kbd "i") 'egg-log-show-ref)
    map))

(defconst egg-secondary-log-commit-map
  (let ((map (make-sparse-keymap "Egg:LogCommitSimple")))
    (set-keymap-parent map egg-log-commit-base-map)
    (define-key map (kbd "RET") 'egg-log-locate-commit)
    (define-key map (kbd "C-c C-c") 'egg-log-locate-commit)
    map))

(defconst egg-file-log-commit-map
  (let ((map (make-sparse-keymap "Egg:FileLogCommit")))
    (set-keymap-parent map egg-secondary-log-commit-map)
    (define-key map (kbd "M-SPC") 'egg-file-log-walk-current-rev)
    (define-key map (kbd "M-n") 'egg-file-log-walk-rev-next)
    (define-key map (kbd "M-p") 'egg-file-log-walk-rev-prev)
    map))


(defconst egg-log-commit-map
  (let ((map (make-sparse-keymap "Egg:LogCommit")))
    (set-keymap-parent map egg-log-commit-base-map)
    (define-key map (kbd "R") 'egg-log-buffer-rebase-interactive)
    (define-key map (kbd "+") 'egg-log-buffer-mark-pick)
    (define-key map (kbd ".") 'egg-log-buffer-mark-squash)
    (define-key map (kbd "~") 'egg-log-buffer-mark-edit)
    (define-key map (kbd "-") 'egg-log-buffer-unmark)
    (define-key map (kbd "DEL") 'egg-log-buffer-unmark)

    (define-key map (kbd "*") 'egg-log-buffer-mark)
    (define-key map (kbd "=") 'egg-log-buffer-diff-revs)

    (define-key map (kbd "u") 'egg-log-buffer-push-to-local)
    
    (define-key map [C-down-mouse-2] 'egg-log-popup-commit-line-menu)
    (define-key map [C-mouse-2] 'egg-log-popup-commit-line-menu)

    map)
  "Keymap for a commit line in the log buffer.\\{egg-log-commit-map}}")

(defconst egg-log-ref-map
  (let ((map (make-sparse-keymap "Egg:LogRef")))
    (set-keymap-parent map egg-log-commit-map)
    (define-key map (kbd "L") 'egg-log-buffer-reflog-ref)
    (define-key map (kbd "x") 'egg-log-buffer-rm-ref)
    map))

(defconst egg-secondary-log-ref-map
  (let ((map (make-sparse-keymap "Egg:SecondaryLogRef")))
    (set-keymap-parent map egg-secondary-log-commit-map)
    (define-key map (kbd "L") 'egg-log-buffer-reflog-ref)
    (define-key map (kbd "x") 'egg-log-buffer-rm-ref)
    map))

(defconst egg-log-local-ref-map
  (let ((map (make-sparse-keymap "Egg:LogLocalRef")))
    (set-keymap-parent map egg-log-ref-map)
    (define-key map (kbd "U") 'egg-log-buffer-push-to-remote)
    (define-key map (kbd "d") 'egg-log-buffer-push-head-to-local)

    (define-key map [C-down-mouse-2] 'egg-log-popup-local-ref-menu)
    (define-key map [C-mouse-2] 'egg-log-popup-local-ref-menu)

    map)
  "\\{egg-log-local-ref-map}")

(defconst egg-log-local-branch-map
  (let ((map (make-sparse-keymap "Egg:LogLocalBranch")))
    (set-keymap-parent map egg-log-local-ref-map)
    (define-key map (kbd "C-c C-=") 'egg-log-buffer-diff-upstream)
    map)
  "\\{egg-log-local-branch-map}")

(defconst egg-log-remote-branch-map
  (let ((map (make-sparse-keymap "Egg:LogRemoteRef")))
    (set-keymap-parent map egg-log-ref-map)
    (define-key map (kbd "D") 'egg-log-buffer-fetch-remote-ref)

    (define-key map [C-down-mouse-2] 'egg-log-popup-remote-ref-menu)
    (define-key map [C-mouse-2] 'egg-log-popup-remote-ref-menu)

    map)
  "\\{egg-log-remote-branch-map}")

(defconst egg-log-remote-site-map
  (let ((map (make-sparse-keymap "Egg:LogRef")))
    (set-keymap-parent map egg-log-commit-map)
    (define-key map (kbd "D") 'egg-log-buffer-fetch)
    (define-key map (kbd "U") 'egg-log-buffer-push)

    (define-key map [C-down-mouse-2] 'egg-log-popup-remote-site-menu)
    (define-key map [C-mouse-2] 'egg-log-popup-remote-site-menu)

    map))

(defconst egg-log-diff-map
  (let ((map (make-sparse-keymap "Egg:LogDiff")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "RET") 'egg-log-diff-cmd-visit-file-other-window)
    (define-key map (kbd "f") 'egg-log-diff-cmd-visit-file)
    (define-key map (kbd "=") 'egg-diff-section-cmd-ediff)
    map))

(defconst egg-log-hunk-map
  (let ((map (make-sparse-keymap "Egg:LogHunk")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "RET") 'egg-log-hunk-cmd-visit-file-other-window)
    (define-key map (kbd "f") 'egg-log-hunk-cmd-visit-file)
    (define-key map (kbd "=") 'egg-diff-section-cmd-ediff)
    map))

(defconst egg-log-buffer-base-map
  (let ((map (make-sparse-keymap "Egg:LogBufferBase")))
    (set-keymap-parent map egg-buffer-mode-map)
    (define-key map "G" 'egg-log-buffer-style-command)
    (define-key map "n" 'egg-log-buffer-next-ref)
    (define-key map "s" 'egg-status)
    (define-key map "p" 'egg-log-buffer-prev-ref)
    map))

(defconst egg-log-buffer-mode-map
  (let ((map (make-sparse-keymap "Egg:LogBuffer")))
    (set-keymap-parent map egg-log-buffer-base-map)
    (define-key map "L" 'egg-reflog)
    (define-key map "/" 'egg-search-changes)
    map)  
  "Keymap for the log buffer.\\{egg-log-buffer-mode-map}")

(defconst egg-log-style-buffer-map
  (let ((map (make-sparse-keymap "Egg:LogBuffer")))
    (set-keymap-parent map egg-log-buffer-base-map)
    (define-key map "s" 'egg-status)
    (define-key map "l" 'egg-log)
    map))

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
	(forward-char 2)
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
				   sha1-pseudo-ref-alist)
  "Decorate a log buffer.
LINE-MAP is used as local keymap for a commit line.
HEAD-MAP is used as local keymap for the name of a head.
TAG-MAP is used as local keymap for the name of a tag.
REMOTE-MAP is used as local keymap for the name of a remote head.
REMOTE-SITE-MAP is used as local keymap for the name of a remote site."
  (let ((start (point))
        (head-sha1 (egg-get-current-sha1))
        (ov (make-overlay (point-min) (point-min) nil t))
        (dec-ref-alist
         (egg-full-ref-decorated-alist
          (list 'face 'egg-branch-mono 'keymap head-map 'help-echo (egg-tooltip-func))
          (list 'face 'egg-tag-mono 'keymap tag-map 'help-echo (egg-tooltip-func))
          (list 'face 'egg-an-tag-mono 'keymap tag-map 'help-echo (egg-tooltip-func))
          (list 'face 'egg-branch-mono 'keymap remote-map 'help-echo (egg-tooltip-func))
          (list 'face 'egg-remote-mono 'keymap remote-site-map 'help-echo (egg-tooltip-func))
	  (list 'face 'egg-log-HEAD-name 'keymap head-map 'help-echo (egg-tooltip-func))))
        (ref-string-len 0)
        (dashes-len 0)
        (min-dashes-len 300)
        separator ref-string sha1 pseudo-refs-list
        line-props graph-len beg end sha-beg sha-end subject-beg
        refs-start refs-end
        head-line)
    (save-excursion
      (while (re-search-forward "\\([0-9a-f]\\{40\\}\\) .+$" nil t)
        (setq sha-beg (match-beginning 1)
              sha-end (match-end 1)
              subject-beg (1+ sha-end)
              beg (line-beginning-position)
              end (match-end 0)
              refs-start nil)
        (setq graph-len (if (= beg sha-beg) 0 (- sha-beg beg 1))
              sha1 (buffer-substring-no-properties sha-beg sha-end)
              subject-beg (if (or (/= (char-after subject-beg) ?\()
				  (not (member (buffer-substring-no-properties 
						subject-beg (+ subject-beg 6))
					       '("(refs/" "(tag: " "(HEAD," "(HEAD)"))))
                              subject-beg
                            (setq refs-start (1+ subject-beg))
                            (goto-char subject-beg)
			    (skip-chars-forward "^)")
                            (setq refs-end (point))
                            (+ (point) 2)))
	(setq pseudo-refs-list (assoc-default sha1 sha1-pseudo-ref-alist))
	(dolist (pseudo-ref pseudo-refs-list)
	  (put-text-property 0 (length pseudo-ref) 'keymap line-map pseudo-ref))
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
                                         (make-string dashes-len ?-)
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
          (setq head-line (point-marker)))

        (goto-char (line-end-position)))

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

(defun egg-log-buffer-insert-n-decorate-logs (log-insert-func &optional sha1-name-alist)
  "Use LOG-INSERT-FUNC to insert logs in current buffer then decorate it."
  (let ((beg (point)))
    (funcall log-insert-func)
    (goto-char beg)
    (egg-decorate-log egg-log-commit-map
                      egg-log-local-branch-map
                      egg-log-local-ref-map
                      egg-log-remote-branch-map
                      egg-log-remote-site-map
		      sha1-name-alist)))

(defalias 'egg-log-pop-to-file 'egg-buffer-pop-to-file)

(defun egg-log-diff-cmd-visit-file (file sha1 &optional use-wdir-file)
  (interactive (list (car (get-text-property (point) :diff))
                     (get-text-property (point) :commit)
		     current-prefix-arg))
  (egg-log-pop-to-file file sha1 nil use-wdir-file))

(defun egg-log-diff-cmd-visit-file-other-window (file sha1 &optional use-wdir-file)
  (interactive (list (car (get-text-property (point) :diff))
                     (get-text-property (point) :commit)
		     current-prefix-arg))
  (egg-log-pop-to-file file sha1 t use-wdir-file))

(defun egg-log-hunk-cmd-visit-file (sha1 use-wdir-file file hunk-header hunk-beg &rest ignored)
  (interactive (nconc (list (get-text-property (point) :commit) current-prefix-arg)
		      (egg-hunk-info-at (point))))
  (egg-log-pop-to-file file sha1 nil use-wdir-file 
		       (egg-hunk-compute-line-no hunk-header hunk-beg)))

(defun egg-log-hunk-cmd-visit-file-other-window (sha1 use-wdir-file file hunk-header hunk-beg &rest ignored)
  (interactive (nconc (list (get-text-property (point) :commit) current-prefix-arg)
		      (egg-hunk-info-at (point))))
  (egg-log-pop-to-file file sha1 t use-wdir-file (egg-hunk-compute-line-no hunk-header hunk-beg)))

(defun egg-log-buffer-get-rev-at (pos &rest options)
  (let* ((commit (egg-commit-at-point pos))
         (refs (egg-references-at-point pos))
         (first-head (if (stringp refs) refs (car (last refs))))
         (ref-at-point (egg-ref-at-point pos))
         (head-sha1 (egg-get-current-sha1)))
    
    (when (stringp commit)
      (if (memq :sha1 options)
	  commit
	(if (and (not (memq :no-HEAD options)) (string= head-sha1 commit))
	    "HEAD"
	  (or ref-at-point first-head
	      (if (memq :symbolic options)
		  (egg-describe-rev commit)
		commit)))))))

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

(defun egg-log-buffer-do-mark (pos char &optional unmark remove-first)
  (let ((commit (get-text-property pos :commit))
        (inhibit-read-only t)
        (col (- egg-log-buffer-comment-column 10))
        (step (if unmark -1 (if remove-first 0 1))))
    (when commit
      (when remove-first
        (egg-log-buffer-do-remove-mark char))
      (move-to-column col)
      (funcall (if unmark
                   #'remove-text-properties
                 #'add-text-properties)
               (point) (1+ (point))
               (list :mark char
                     'display
                     (and char
                          (egg-text (char-to-string char)
                                    'egg-log-buffer-mark))))
      (forward-line step)
      (while (not (or (get-text-property (point) :commit)
                      (eobp) (bobp)))
        (forward-line step))
      (move-to-column col))))

(defun egg-log-buffer-mark (pos)
  (interactive "d")
  (egg-log-buffer-do-mark pos ?* nil t))

(defun egg-log-buffer-mark-pick (pos)
  (interactive "d")
  (egg-log-buffer-do-mark pos ?+))

(defun egg-log-buffer-mark-squash (pos)
  (interactive "d")
  (egg-log-buffer-do-mark pos ?.))

(defun egg-log-buffer-mark-edit (pos)
  (interactive "d")
  (egg-log-buffer-do-mark pos ?~))

(defun egg-log-buffer-do-unmark-all ()
  (interactive)
  (let ((pos (point-min))
        (inhibit-read-only t))
    (while (setq pos (next-single-property-change (1+ pos) :mark))
      (remove-text-properties pos (1+ pos)
                              (list :mark nil 'display nil)))))

(defun egg-log-buffer-unmark (pos &optional all)
  (interactive "d\nP")
  (if all
      (egg-log-buffer-do-unmark-all)
    (egg-log-buffer-do-mark pos nil t)))

(defun egg-log-buffer-get-marked-alist (&rest types)
  (let ((pos (point-min))
        marker subject alist)
    (save-excursion
      (while (setq pos (next-single-property-change (1+ pos) :mark))
	(when (or (null types) (memq (get-text-property pos :mark) types))
	  (goto-char pos)
	  (setq marker (point-marker))
	  (move-to-column egg-log-buffer-comment-column)
	  (setq subject (buffer-substring-no-properties
			 (point) (line-end-position)))
	  (setq alist (cons (list (get-text-property pos :commit)
				  (get-text-property pos :mark)
				  subject marker)
			    alist)))))
    alist))


(defun egg-setup-rebase-interactive (rebase-dir upstream onto repo-state commit-alist)
  (let ((process-environment process-environment)
        (repo-state (or repo-state (egg-repo-state :staged :unstaged)))
        (orig-buffer (current-buffer))
        orig-head-sha1)
    (setq orig-head-sha1 (plist-get repo-state :sha1))
    (unless (egg-repo-clean repo-state) (error "Repo not clean"))
    (unless onto (setq onto upstream))

    (with-temp-buffer
      (make-directory rebase-dir t)

      (write-region (point-min) (point-min)
                    (concat rebase-dir "interactive"))
      (write-region (point-min) (point-min)
                    (concat rebase-dir "verbose"))
      (insert (plist-get repo-state :head) "\n")
      (write-region (point-min) (point-max)
                    (concat rebase-dir "head-name"))
      (erase-buffer)
      (insert (plist-get repo-state :sha1) "\n")
      (write-region (point-min) (point-max) ;; no longer needed
                    (concat rebase-dir "head"))
      (write-region (point-min) (point-max)
                    (concat rebase-dir "orig-head"))
      (erase-buffer)
      (insert upstream "\n")
      (write-region (point-min) (point-max)
                    (concat rebase-dir "upstream"))
      (erase-buffer)
      (insert onto "\n")
      (write-region (point-min) (point-max)
                    (concat rebase-dir "onto"))
      (erase-buffer)
      (insert "\n")
      (write-region (point-min) (point-max)
                    (concat rebase-dir "quiet"))
      (erase-buffer)
      (insert onto "\n")
      (write-region (point-min) (point-max)
                    (concat rebase-dir "stopped-sha"))
      (erase-buffer)
      (insert "# Rebase " upstream ".." orig-head-sha1 " onto " onto "\n")
      (dolist (rev-info commit-alist)
        (insert (cond ((eq (nth 1 rev-info) ?+) "pick")
                      ((eq (nth 1 rev-info) ?.) "squash")
                      ((eq (nth 1 rev-info) ?~) "edit"))
                " " (nth 0 rev-info) " " (nth 2 rev-info) "\n"))
      (write-region (point-min) (point-max)
                    (concat rebase-dir "git-rebase-todo"))
      (write-region (point-min) (point-max)
                    (concat rebase-dir "git-rebase-todo.backup")))

    (setenv "GIT_REFLOG_ACTION" (format "rebase -i (%s)" onto))
    (with-egg-debug-buffer
      (erase-buffer)
      (egg-git-ok nil "update-ref" "ORIG_HEAD" orig-head-sha1)
      (egg-git-ok nil "checkout" onto)
      (egg-do-async-rebase-continue #'egg-handle-rebase-interactive-exit
                                    orig-head-sha1))))

(defun egg-sentinel-commit-n-continue-rebase (prefix gpg-uid text-beg text-end next-beg
						     rebase-dir orig-buffer orig-sha1 commit-func)
  (let ((process-environment process-environment))
    (mapc (lambda (env-lst)
	    (setenv (car env-lst) (cadr env-lst)))
	  (egg-rebase-author-info rebase-dir))
    (apply commit-func prefix gpg-uid text-beg text-end next-beg nil))
  (with-current-buffer orig-buffer
    (egg-do-async-rebase-continue
     #'egg-handle-rebase-interactive-exit
     orig-sha1)))

(defun egg-handle-rebase-interactive-exit (&optional orig-sha1)
  (let ((exit-msg egg-async-exit-msg)
        (proc egg-async-process)
	(case-fold-search nil)
        state buffer res msg rebase-dir)
    (goto-char (point-min))
    (save-match-data
      (re-search-forward
       (eval-when-compile
         (concat "\\<\\(?:"
                 "\\(please commit in egg.+$\\)"                             "\\|" ;; 1
                 "\\(Successfully rebased and updated.+$\\)"  		     "\\|" ;; 2
                 "\\(You can amend the commit now\\)" 	     		     "\\|" ;; 3
                 "\\(Automatic cherry-pick failed\\)"	     		     "\\|" ;; 4
                 "\\(nothing added to commit\\)"	             	     "\\|" ;; 5
                 "\\(nothing to commit (working directory clean)\\)"	     "\\|" ;; 6
                 "\\(If you wish to commit it anyway\\)"     		     "\\|" ;; 7
		 "\\(When you have resolved this problem\\)"		     "\\|" ;; 8
                 "\\(\\(?:Cannot\\|Could not\\).+\\)" "\\)")) nil t)
      (setq msg (match-string-no-properties 0))
      (setq res (cond ((match-beginning 1) :rebase-commit)
                      ((match-beginning 2) :rebase-done)
                      ((match-beginning 3) :rebase-edit)
                      ((match-beginning 4) :rebase-conflict)
                      ((match-beginning 5) :rebase-empty)
                      ((match-beginning 6) :rebase-empty)
                      ((match-beginning 7) :rebase-empty)
                      ((match-beginning 8) :rebase-conflict)
                      ((match-beginning 9) :rebase-fail))))
    (setq buffer (process-get proc :orig-buffer))
    (with-current-buffer buffer
      (egg-run-buffers-update-hook)
      (egg-revert-all-visited-files) ;; too heavy ???
      (setq state (egg-repo-state :force))
      (setq rebase-dir (plist-get state :rebase-dir))
      (cond ((eq res :rebase-done)
             (message "GIT-REBASE-INTERACTIVE: %s" msg))

            ((eq res :rebase-commit)
             (egg-commit-log-edit
              (let* ((cherry (plist-get state :rebase-cherry))
                     (cherry-op (save-match-data
                                  (car (split-string cherry)))))
                (concat
                 (egg-text "Rebasing " 'egg-text-3)
                 (egg-text (plist-get state :rebase-head) 'egg-branch)
                 ": "
                 (egg-text (concat "Commit " cherry-op "ed cherry")
                           'egg-text-3)))
              (egg-log-msg-mk-closure-input #'egg-sentinel-commit-n-continue-rebase
					    rebase-dir buffer orig-sha1 #'egg-log-msg-commit)
              (egg-file-as-string (concat rebase-dir "message")))

	     (message "please commit the changes to continue with rebase."))


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
             (message "automatic rebase stopped! this commit should be skipped!"))
            ((eq res :rebase-fail)
             (egg-status nil t :sentinel)
             (ding)
             (message "Automatic rebase failed!"))))))

(defun egg-log-buffer-merge (pos &optional level)
  "Merge to HEAD the path starting from the commit at POS.
With C-u prefix, do not auto commit the merge result.
With C-u C-u prefix, prompt the user for the type of merge to perform."
  (interactive "d\np")
  (let ((rev (egg-log-buffer-get-rev-at pos :symbolic :no-HEAD))
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
  (egg-log-buffer-do-merge-to-head (egg-log-buffer-get-rev-at pos :symbolic :no-HEAD) "--ff-only"))

(defun egg-log-buffer-merge-n-squash (pos)
  (interactive "d")
  (unless (egg-repo-clean)
    (egg-status nil nil)
    (error "Repo is not clean!"))
  (egg-log-buffer-do-merge-to-head (egg-log-buffer-get-rev-at pos :symbolic :no-HEAD) "--squash"))

(defun egg-log-buffer-rebase (pos)
  "Rebase HEAD using the commit under POS as upstream.
If there was a commit marked as BASE, then rebase HEAD onto the commit under the
cursor using the BASE commit as upstream."
  (interactive "d")
  (let* ((mark (egg-log-buffer-find-first-mark ?*))
         (upstream (if mark (egg-log-buffer-get-rev-at mark :symbolic)))
	 (onto (egg-log-buffer-get-rev-at pos :symbolic :no-HEAD))
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
    (unless (egg-buffer-do-rebase upstream onto)
      (egg-status nil t))))

(defun egg-log-buffer-rebase-interactive (pos)
  "Start an interactive rebase session using the marked commits.
The commit at POS is the where the chain of marked commits will rebased onto."
  (interactive "d")
  (let* ((state (egg-repo-state :staged :unstaged))
         (rebase-dir (concat (plist-get state :gitdir) "/"
                             egg-git-rebase-subdir "/"))
         (todo-alist (egg-log-buffer-get-marked-alist ?+ ?. ?~))
         (commits (mapcar 'car todo-alist))
	 (r-commits (reverse commits))
         (upstream (egg-commit-at pos))
         (all (egg-git-to-lines "rev-list" "--reverse" "--cherry-pick"
                                (concat upstream "..HEAD"))))
    (unless (egg-repo-clean state)
      (error "repo %s is not clean" (plist-get state :gitdir)))
    (mapc (lambda (commit)
            (unless (member commit all)
              (error "commit %s is not between HEAD and upstream %s"
                     commit upstream)))
          commits)

;;    (unless (equal sha1 (car r-commits)) (error "HEAD (%s) was not marked!" sha1))

    (setq all (egg-git-to-lines "rev-list" "--reverse" "--cherry-pick" (concat (car commits) "^..HEAD")))

    (mapc (lambda (commit)
            (unless (member commit commits)
              (error "unmarked commit %s between %s and HEAD."
                     commit (car commits))))
          all)
    
    (egg-setup-rebase-interactive rebase-dir upstream nil
                                  state todo-alist)
    (egg-status nil t)))

(defun egg-log-buffer-checkout-commit (pos &optional force)
  "Checkout the commit at POS.
With prefix, force the checkout even if the index was different from the new commit."
  (interactive "d\nP")
  (let ((ref (egg-read-rev "checkout: "
	      (egg-log-buffer-get-rev-at pos :symbolic :no-HEAD))))
    (if force 
	(egg-log-buffer-do-co-rev ref "-f")
      (egg-log-buffer-do-co-rev ref))))

(defun egg-log-buffer-tag-commit (pos &optional force)
  "Tag the commit at POS.
With prefix, force the creation of the tag even if it replace an
existing one with the same name."
  (interactive "d\nP")
  (let* ((rev (egg-log-buffer-get-rev-at pos))
	 (name (read-string (format "tag %s with name: " rev)))
	 (egg--do-no-output-message 
	  (format "new lightweight tag '%s' at %s" name rev)))
    (egg-log-buffer-do-tag-commit name rev force)))

(defun egg-log-buffer-atag-commit (pos &optional sign-tag)
  "Start composing the message for an annotated tag on the commit at POS.
With prefix, the tag will be gpg-signed."
  (interactive "d\np")
  (let* ((commit (get-text-property pos :commit))
	 (name (read-string (format "create annotated tag on %s with name: "
				    (egg-describe-rev commit))))
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
  "Create a new branch, without checking it out."
  (interactive "d\nP")
  (let ((rev (egg-log-buffer-get-rev-at pos))
	(upstream (egg-head-at pos)))
    (egg-buffer-do-create-branch 
     (read-string (format "create new branch at %s with name: " rev))
     rev force upstream 'log)))

(defun egg-log-buffer-start-new-branch (pos &optional force)
  "Create a new branch, and make it a new HEAD"
  (interactive "d\nP")
  (let ((rev (egg-log-buffer-get-rev-at pos :symbolic :no-HEAD))
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
  "Move the current branch or the detached HEAD to the commit at POS.
The index will be reset and files will in worktree updated. If a file that is
different between the original commit and the new commit, the git command will
abort. This is basically git reset --keep. With C-u prefix, HEAD will be moved,
index will be reset and the work tree updated by throwing away all local
modifications (this is basically git reset --hard). With C-u C-u prefix,
the command will prompt for the git reset mode to perform."
  (interactive "d\np")
  (let* ((rev (egg-log-buffer-get-rev-at pos :symbolic :no-HEAD))
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
  (let ((refs (egg-references-at-point pos))
        (candidate (egg-ref-at-point pos))
        victim parts delete-on-remote remote-site name-at-remote
	remote-ok)
    (if (invoked-interactively-p)
	(message "interactive")
      (message "non interactive"))
    (unless candidate (setq candidate (last refs)))
    (setq candidate (completing-read "remove reference: " refs nil nil candidate))
    (setq victim (egg-git-to-string "show-ref" candidate))
    (unless (stringp victim) (error "No such ref: %s!!!" candidate))
    (save-match-data
      (setq victim (nth 1 (split-string victim " " t)))
      (setq parts (and (stringp victim) (split-string victim "/" t))))
    
    (unless (equal (car parts) "refs") (error "Invalid ref: %s" victim))
    
    (setq remote-site (and (equal (nth 1 parts) "remotes") (nth 2 parts)))
    (setq name-at-remote (and remote-site (mapconcat 'identity (nthcdr 3 parts) "/")))
    (setq delete-on-remote (and remote-site
				(y-or-n-p (format "delete %s on %s too? "
						  name-at-remote remote-site))))
    (setq remote-ok 
	  (if delete-on-remote (egg--buffer-handle-result
				(egg--git-push-cmd (current-buffer) "--delete" 
						   remote-site name-at-remote))
	    t))
    (when remote-ok
      (egg-log-buffer-handle-result
       (egg--git-push-cmd (current-buffer) "--delete" "." victim)))))

(defun egg-log-buffer-pick-1cherry (pos &optional edit-commit-msg)
  "Pick one cherry at POS and put on HEAD.
With prefix, will not auto-commit but let the user re-compose the message."
  (interactive "d\nP")
  
  (let ((rev (egg-log-buffer-get-rev-at pos :symbolic))
	(head-name (egg-branch-or-HEAD))
	res modified-files old-msg)
    (unless (and rev (stringp rev))
      (error "No cherry here for picking! must be a bad season!" ))
    (when (string-equal rev "HEAD")
      (error "Cannot pick your own HEAD!"))

    (if (not (y-or-n-p (format "pick %s and put it on %s%s? " rev head-name
			       (if edit-commit-msg " (with new commit message)" ""))))
	(message "Nah! that cherry (%s) looks rotten!!!" rev)
      
      (setq old-msg (egg-commit-message rev))
      (setq res (egg--git-cherry-pick-cmd t rev (if edit-commit-msg "--no-commit" "--ff")))
      (egg--buffer-handle-result-with-commit
       res (list (concat (egg-text "Newly Picked Cherry:  " 'egg-text-3)
			 (egg-text rev 'egg-branch))
		 (egg-log-msg-mk-closure-input #'egg-log-msg-commit)
		 old-msg)
       t 'log))))

(defun egg-log-buffer-revert-rev (pos &optional use-default-commit-msg)
  (interactive "d\nP")
  (let ((sha1 (egg-log-buffer-get-rev-at pos :sha1))
	(rev (egg-log-buffer-get-rev-at pos :symbolic))
	res modified-files old-subject cmd-ok)
    (unless (and rev (stringp rev))
      (error "No tumour to remove here! very healthy body!" ))
    (when (string-equal rev "HEAD")
      (error "Just chop your own HEAD (use anchor a.k.a git-reset)! no need to revert HEAD"))
    
    (setq old-subject (egg-commit-subject rev))

    (if (not (y-or-n-p (format "undo changes introduced by %s%s? " rev
			       (if use-default-commit-msg
				   " (with git's default commit message)" ""))))
	(message "Nah! that lump (%s) looks benign!!!" old-subject)
      
      (setq res (egg--git-revert-cmd t rev use-default-commit-msg))
      (egg--buffer-handle-result-with-commit
       res (list (concat
		  (egg-text "Undo Changes Introduced by:  " 'egg-text-3)
		  (egg-text rev 'egg-branch)) 
		 (egg-log-msg-mk-closure-input #'egg-log-msg-commit)
		 (format "Revert \"%s\"\n\nThis reverts commit %s\n" old-subject sha1))
       t 'log))))

(defun egg-log-buffer-fetch-remote-ref (pos)
  "Download and update the remote tracking branch at POS."
  (interactive "d")
  (let* ((ref-at-point (get-text-property pos :ref))
         (ref (car ref-at-point))
         (type (cdr ref-at-point))
         name remote)
    (unless (eq type :remote)
      (error "Nothing to fetch from here!"))
    (setq name (file-name-nondirectory ref)
          remote (egg-rbranch-to-remote ref))
    (when (and remote name)
      (message "GIT> fetching %s from %s..." ref remote)
      (egg-buffer-async-do nil "fetch" remote
                           (format "refs/heads/%s:refs/remotes/%s"
                                   name ref)))))

(defun egg-log-buffer-fetch (pos)
  (interactive "d")
  (let* ((ref-at-point (get-text-property pos :ref))
         (ref (car ref-at-point))
         (type (cdr ref-at-point))
         site name def remote)
    (unless (eq type :remote)
      (error "No site here to fetch from!"))
    (setq remote (egg-rbranch-to-remote ref))
    (when remote
      (setq name (read-string (format "fetch from %s (default all): "
                                      remote) nil nil "--all"))
      (if (equal name "--all")
          (progn
            (message "GIT> fetching everything from %s..." remote)
            (egg-buffer-async-do nil "fetch" remote))
        (message "GIT> fetching %s from %s..." name remote)
        (egg-buffer-async-do nil "fetch" remote
                             (format "refs/heads/%s:refs/remotes/%s/%s"
                                     name remote name))))))

(defun egg-log-buffer-push-to-local (pos &optional level)
  "Push a ref or a commit at POS onto HEAD.
With C-u, instead of HEAD, prompt for another ref as destination.
With C-u C-u, will force the push evel if it would be non-ff.
When the destination of the push is HEAD, the underlying git command
would be a pull (by default --ff-only)."
  (interactive "d\np")
  (let ((src (or (egg-ref-at-point pos)
		 (egg-log-buffer-get-rev-at pos :symbolic :no-HEAD)))
	(prompt-dst (> level 3))
	(non-ff (> level 15))
	(head-name (egg-branch-or-HEAD))
	dst mark base)
    
    (setq mark (egg-log-buffer-find-first-mark ?*))
    (setq base (if mark (egg-log-buffer-get-rev-at mark :symbolic)))
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
  "WTF."
  (interactive "d\nP")
  (let* ((dst (egg-ref-at-point pos)))
    (unless dst
      (error "Nothing here to push to!"))
    (if (y-or-n-p (format "update %s with HEAD? " dst))
	(egg--git-push-cmd (current-buffer) (if non-ff "-v" "-vf")
			   "." (concat "HEAD:" dst))
      (message "local push cancelled!"))))

(defun egg-log-buffer-push-to-remote (pos &optional non-ff)
  "Upload the ref at POS to a remote repository.
If the ref track a remote tracking branch, then the repo to
upload to is the repo of the remote tracking branch. Otherwise,
prompt for a remote repo."
  (interactive "d\nP")
  (let* ((ref-at-point (get-text-property pos :ref))
         (lref (car ref-at-point))
         (type (cdr ref-at-point))
         rref tracking remote spec)
    (unless ref-at-point
      (error "Nothing to push here!"))
    (cond ((eq type :remote)		;; delete a remote head
           (setq rref (file-name-nondirectory lref))
           (setq remote (directory-file-name
                         (file-name-directory lref)))
           (setq lref ""))
          ((eq type :head)
           (setq tracking (egg-tracking-target lref :remote))
           (if (consp tracking)
               (setq rref (car tracking) remote (cdr tracking))
             (setq remote (egg-read-remote
                           (format "push branch %s to remote: " lref)))
             (setq rref (read-string
                         (format "push branch %s to %s as: " lref remote)
                         lref))))
          ((eq type :tag)
           (setq remote (egg-read-remote "push to remote: "))
           (setq rref (read-string
                       (format "remote tag to push at (on %s): " remote)
                       lref))
           (setq lref (read-string
                       (format "local tag to push at %s/%s (empty mean delete the remote tag) : "
                               remote rref)
                       rref))))
    (unless (> (length lref) 0)
      (unless (y-or-n-p (format "delete %s/%s? " remote rref))
        (message "cancel removal of %s/%s" remote rref)
        (setq remote nil rref nil lref nil)))
    (when (and remote rref lref)
      (setq spec (concat lref ":" rref))
      (message "GIT> pushing %s to %s on %s..." lref rref remote)
      (egg-buffer-async-do nil "push" (if non-ff "-vf" "-v")
                           remote spec))))

(defun egg-log-buffer-push (pos)
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

(defun egg-log-buffer-do-insert-commit (pos &optional args highlight-regexp path-args)
  (save-excursion
    (let ((sha1 (get-text-property pos :commit))
          (ref (egg-references-at-point pos))
          (nav (get-text-property pos :navigation))
          (inhibit-read-only t)
          (indent-column egg-log-buffer-comment-column)
          (indent-spaces (make-string egg-log-buffer-comment-column ? ))
          beg end diff-beg diff-end is-cc-diff face-end)
      (goto-char pos)
      (goto-char (1+ (line-end-position)))
      (setq beg (point))
      (unless (egg-git-ok-args 
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
      (setq end (or (next-single-property-change beg :diff) end)
	    diff-beg end)

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
      ;; (put-text-property beg (+ indent-column beg) 'face 'egg-diff-none)
      ;; (put-text-property (+  indent-column beg) (line-end-position)
      ;;                    'face 'egg-text-2)
      ;; (forward-line 1)
      ;; (put-text-property (point) (+ indent-column (point)) 'face 'egg-diff-none)
      ;; (put-text-property (+ indent-column (point)) end 'face 'egg-text-2)

      (when (stringp highlight-regexp)
	(egg-buffer-highlight-pickaxe highlight-regexp diff-beg diff-end is-cc-diff))
      (set-buffer-modified-p nil))))

(defun egg-log-buffer-insert-commit (pos)
  "Load and show the details of the commit at POS."
  (interactive "d")
  (let* ((next (next-single-property-change pos :diff))
         (sha1 (and next (get-text-property next :commit)))
	 (pickaxe-args (and egg-internal-log-buffer-closure 
			(plist-get egg-internal-log-buffer-closure :pickaxe-args)))
	 (pickaxed-paths (and egg-internal-log-buffer-closure 
			(plist-get egg-internal-log-buffer-closure :paths)))
	 (highlight (and egg-internal-log-buffer-closure 
			 (plist-get egg-internal-log-buffer-closure :highlight))))
    (unless (equal (get-text-property pos :commit) sha1)
      (egg-log-buffer-do-insert-commit pos pickaxe-args highlight pickaxed-paths))))

(defun egg-generic-display-logs (data &optional init)
  (buffer-disable-undo)
  (and init (setq buffer-invisibility-spec nil))
  (let ((title (plist-get data :title))
        (subtitle (plist-get data :subtitle))
        (git-dir (egg-git-dir))
        (desc (plist-get egg-internal-log-buffer-closure :description))
        (closure (plist-get egg-internal-log-buffer-closure :closure))
        (help (plist-get egg-internal-log-buffer-closure :help))
        (inhibit-read-only t)
        inv-beg beg help-beg)
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
      (insert help "\n"))
    (setq beg (point))
    (when help-beg
      (egg-delimit-section :section :help help-beg (point)
                           inv-beg egg-section-map :help))
    (if init (egg-buffer-maybe-hide-help :help))
    (goto-char (or (funcall closure) beg))))

(defun egg-log-buffer-redisplay (buffer &optional init)
  (with-current-buffer buffer
    (let* ((state (egg-repo-state))
           (sha1 (plist-get state :sha1)))
      (plist-put egg-internal-log-buffer-closure :title
                 (egg-text (egg-pretty-head-string state) 'egg-branch))
      (plist-put egg-internal-log-buffer-closure :subtitle
                 (egg-text sha1 'font-lock-string-face))
      (egg-generic-display-logs egg-internal-log-buffer-closure init))))

(defun egg-log-buffer-redisplay-from-command (buffer)
  ;; in process buffer
  (when (and (processp egg-async-process)
             (equal (current-buffer) (process-buffer egg-async-process)))
    (or
     (save-excursion
       (let ((cmd "GIT>") cmd-sexp cmd-string pos done)
         (goto-char (point-min))
         (skip-chars-forward "^(")
         (setq cmd-sexp (read (current-buffer)))
         (when (consp cmd-sexp)
           (setq cmd-string (car cmd-sexp)
                 cmd (cond ((string-equal "fetch" cmd-string) "GIT-FETCH>")
                           ((string-equal "push" cmd-string) "GIT-PUSH>"))))
         (goto-char (point-min))
         (save-match-data
           (cond ((re-search-forward "^\\(?:From\\|To\\) \\(.+\\)\n\\(.+\\)$" nil t)
                  (message "%s %s: %s" cmd
                           (match-string-no-properties 1)
                           (match-string-no-properties 2))
                  (setq done t))))
         (unless done
           (goto-char (point-min))
           (save-match-data
             (cond ((re-search-forward "^fatal: \\(.+\\)$" nil t)
                    (message "%s fatal: %s" cmd
                             (match-string-no-properties 1))
                    (setq done t)))))))))
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
\\[egg-log-buffer-push-to-local] update HEAD or BASE using the ref.
C-u \\[egg-log-buffer-push-to-local] update a local ref using the ref.
C-u C-u \\[egg-log-buffer-push-to-local] update (non-ff allowed) a local ref using the ref.

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
                                  'egg-log-buffer-fetch
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
                    (egg-name-rev commit))))
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
  (define-key menu [next] '(menu-item "Goto Next Ref" egg-log-buffer-next-ref)))

(defconst egg-log-buffer-help-text
  (concat
   (egg-text "Common Key Bindings:" 'egg-help-header-2)
   "\n"
   (egg-pretty-help-text
    "\\<egg-log-buffer-mode-map>"
    "\\[egg-log-buffer-next-ref]:next thing  "
    "\\[egg-log-buffer-prev-ref]:previous thing  "
    "\\[egg-search-changes]:search history  "
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
    "\\[egg-log-buffer-rebase-interactive]:rebase HEAD interactively"
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
    "\\[egg-log-buffer-push-to-local]:update HEAD (or a local ref) with ref  "
    "\\[egg-log-buffer-push-head-to-local]:update this ref with HEAD\n"
    "\\[egg-log-buffer-push-to-remote]:upload to remote  "
    "\\<egg-log-remote-branch-map>"
    "\\[egg-log-buffer-fetch-remote-ref]:download this ref from remote\n")
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
  "Compare HEAD against the rev at POS.
A ready made PICKAXE info can be provided by the caller when called non-interactively."
  (interactive "d\np")
  (let* ((rev (egg-log-buffer-get-rev-at pos :symbolic))
         (mark (egg-log-buffer-find-first-mark ?*))
	 (head-name (egg-branch-or-HEAD))
         (base (if mark (egg-log-buffer-get-rev-at mark :symbolic) head-name))
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
  "Compare REF at POS against its upstream."
  (interactive "d\np")
  (let* ((ref (egg-ref-at-point pos :head))
         (mark (egg-log-buffer-find-first-mark ?*))
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

(defun egg-yggdrasil-insert-logs (ref)
  (let* ((mappings 
	  (cdr (egg-git-to-lines 
		"--no-pager" "log" "-g" "--pretty=%H~%gd%n" 
		(format "--max-count=%d" (1+ egg-max-reflogs))
		(concat ref "@{now}"))))
	 (beg (point)) 
	 (head-name (egg-branch-or-HEAD))
	 sha1-list sha1-reflog-alist sha1 reflog-time time reflog dup pair)
    (setq mappings (save-match-data (mapcar (lambda (line) (split-string line "~" t)) mappings)))
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

    (egg-git-ok-args t (nconc (list "--no-pager" "log"
				    (format "--max-count=%d" egg-log-HEAD-max-len)
				    "--graph" "--topo-order"
				    "--pretty=oneline" "--decorate=full" "--no-color")
			      (if (equal head-name ref)
				  (cons ref sha1-list)
				(nconc (list ref head-name) sha1-list))))
    (goto-char beg)
    (egg-decorate-log egg-log-commit-map
                      egg-log-local-branch-map
                      egg-log-local-ref-map
                      egg-log-remote-branch-map
                      egg-log-remote-site-map
		      sha1-reflog-alist)))

(defun egg-log (ref-name)
  "Show the commit DAG of REF-NAME."
  (interactive (list (let ((level (prefix-numeric-value current-prefix-arg))
			   (head-name (egg-branch-or-HEAD))
			   (pickup (egg-string-at-point)))
		       (cond ((> level 15) ;; ask
			      (egg-read-ref "show history of: " (or pickup head-name)))
			     ((> level 3) ;; all refs
			      'all)
			     (t	;; default head
			      head-name)))))
  (let* ((egg-internal-current-state
          (egg-repo-state (if (invoked-interactively-p) :error-if-not-git)))
         (default-directory (egg-work-tree-dir 
			     (egg-git-dir (invoked-interactively-p))))
         (buf (egg-get-log-buffer 'create))
	 ;; (head-name (egg-branch-or-HEAD))
         help)
    (with-current-buffer buf
      (when (memq :log egg-show-key-help-in-buffers)
        (setq help egg-log-buffer-help-text))
      (set
       (make-local-variable 'egg-internal-log-buffer-closure)
       (if (eq ref-name 'all)
	   (list :description (concat
				  (egg-text "history scope: " 'egg-text-2)
				  (egg-text "all refs" 'egg-term))
		    :closure (lambda ()
			       (egg-log-buffer-insert-n-decorate-logs
				'egg-run-git-log-all)))
	 (list :description (concat
                             (egg-text "history scope: " 'egg-text-2)
                             (egg-text ref-name 'egg-term))
               :closure `(lambda () (egg-yggdrasil-insert-logs ,ref-name)))))
      (if help (plist-put egg-internal-log-buffer-closure :help help))
      (plist-put egg-internal-log-buffer-closure :command 'egg-log)
      (egg-log-buffer-redisplay buf 'init))
    (cond
     (egg-switch-to-buffer (switch-to-buffer buf))
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

(defsubst egg-run-git-file-log-HEAD (file)
  (egg-git-ok t "log" (format "--max-count=%d" egg-log-HEAD-max-len)
              "--graph" "--topo-order" "--no-color"
              "--pretty=oneline" "--decorate=full" "--" file))

(defsubst egg-run-git-file-log-all (file)
  (egg-git-ok t "log" (format "--max-count=%d" egg-log-all-max-len)
              "--graph" "--topo-order" "--no-color"
              "--pretty=oneline" "--decorate=full" "--all" "--" file))


(defun egg-log-buffer-decorate-logs-simple-1 (log-insert-func arg
					   line-map head-map tag-map remote-map)
  (let ((beg (point)))
    (funcall log-insert-func arg)
    (unless (= (char-before (point-max)) ?\n)
      (goto-char (point-max))
      (insert ?\n))
    (goto-char beg)
    (egg-decorate-log line-map head-map tag-map remote-map)))

(defsubst egg-log-buffer-decorate-logs-simple (log-insert-func arg)
  (egg-log-buffer-decorate-logs-simple-1 log-insert-func arg
					 egg-secondary-log-commit-map
					 egg-secondary-log-commit-map
					 egg-secondary-log-commit-map
					 egg-secondary-log-commit-map))

(defsubst egg-file-log-buffer-decorate-logs (log-insert-func arg)
  (egg-log-buffer-decorate-logs-simple-1 log-insert-func arg
					 egg-file-log-commit-map
					 egg-file-log-commit-map
					 egg-file-log-commit-map
					 egg-file-log-commit-map))

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
  (let ((buffer (egg-get-file-log-buffer 'create))
        (title (concat (egg-text "history of " 'egg-text-2)
                       (egg-text file-name 'egg-term)))
	(head-name (egg-branch-or-HEAD))
        help)
    (with-current-buffer buffer
      (set
       (make-local-variable 'egg-internal-log-buffer-closure)
       (if all
           (list :title title
                 :description (concat (egg-text "scope: " 'egg-text-2)
                                      (egg-text "all refs" 'egg-branch-mono))
                 :closure `(lambda ()
                             (egg-file-log-buffer-decorate-logs
                              #'egg-run-git-file-log-all ,file-name))
		 :paths (list (egg-file-git-name file-name)))
         (list :title title
               :description (concat (egg-text "scope: " 'egg-text-2)
                                    (egg-text head-name 'egg-branch-mono))
               :closure `(lambda ()
                           (egg-file-log-buffer-decorate-logs
                            #'egg-run-git-file-log-HEAD ,file-name))
	       :paths (list (egg-file-git-name file-name)))))
      (when (memq :file-log egg-show-key-help-in-buffers)
        (setq help egg-file-log-help-text))
      (if help (plist-put egg-internal-log-buffer-closure :help help))
      (plist-put egg-internal-log-buffer-closure :command
		 `(lambda (&optional all)
		    (interactive "P")
		    (egg-file-log ,file-name all))))
      
    (egg-log-buffer-simple-redisplay buffer 'init)
    (pop-to-buffer buffer)))

;;;========================================================
;;; commit search
;;;========================================================
(defconst egg-query:commit-commit-map
  (let ((map (make-sparse-keymap "Egg:LogQueryCommit")))
    (set-keymap-parent map egg-secondary-log-commit-map)
    (define-key map (kbd "=") 'egg-query:commit-buffer-diff-revs)
    ;;
    map))

(defun egg-section-relative-pos (pos)
  (cond ((equal (point-min) pos) 0)
	((equal (get-text-property (1- pos) :navigation)
		(get-text-property pos :navigation))
	 (- (point)
	    (previous-single-property-change pos :navigation nil (point-min))))
	(t 0)))

(defun egg-buffer-goto-section (section &optional offset)
  (let ((pos (point-min)))
    (while (and pos
		(not (equal (get-text-property pos :navigation) section)))
      (setq pos (next-single-property-change pos :navigation)))
    (when pos (goto-char (if offset (+ offset pos) pos)))))

(defun egg-query:commit-buffer-diff-revs (pos prefix)
  (interactive "d\np")
  (let* ((rev (egg-log-buffer-get-rev-at pos :symbolic))
	 (mark (egg-log-buffer-find-first-mark ?*))
	 (head-name (egg-branch-or-HEAD))
	 (base (if mark (egg-log-buffer-get-rev-at mark :symbolic) head-name))
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
		    (egg-log-buffer-insert-n-decorate-logs
		     (lambda ()
                       (egg-git-ok t "log" "--max-count=10000" "--graph"
                                   "--topo-order" "--pretty=oneline" "--no-color"
                                   "--decorate=full" ,head-name ,sha1))))))
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
				       (list :matched-mark ?~
					     :unmatched-mark ?+
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
	    (nconc (list "--no-pager" "log" "--pretty=oneline" 
			 "--decorate=full" "--no-color")
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


(defun egg-insert-n-decorate-pickaxed-logs (args)
  (let ((beg (point)))
    (egg-git-ok-args t 
		     (nconc (list "log" "--pretty=oneline" "--decorate=full" "--no-color")
			    args))
    (goto-char beg)
    (egg-decorate-log egg-query:commit-commit-map
                      egg-query:commit-commit-map
                      egg-query:commit-commit-map
                      egg-query:commit-commit-map)))

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
  "Search file's history in the current branch for changes introducing or removing a term.
TERM is the default search term."
  (interactive (list (prefix-numeric-value current-prefix-arg)
		     (egg-string-at-point)))
  (egg-do-search-file-changes prefix default-term file-name "search %s's history in %s"))

(defun egg-search-file-changes-all (prefix &optional default-term file-name)
  "Search file's full history for changes introducing or removing a term.
TERM is the default search term."
  (interactive (list (prefix-numeric-value current-prefix-arg)
		     (egg-string-at-point)))
  (egg-do-search-file-changes prefix default-term file-name "search %s's full history"
			      'all))

(defun egg-search-changes (prefix default-term)
  "Search the current branch's history for changes introducing/removing a term.
DEFAULT-TERM is the default search term."
  (interactive (list (prefix-numeric-value current-prefix-arg)
		     (egg-string-at-point)))
  (let* ((mark (egg-log-buffer-find-first-mark ?*))
	 (head-name (egg-branch-or-HEAD))
	 (start-rev (if mark (egg-log-buffer-get-rev-at mark :symbolic)))
	 (revs (and start-rev (list (concat start-rev "^.." head-name))))
	 (pickaxe (egg-buffer-prompt-pickaxe 
		   (if revs (concat "search " (car revs))
		     (format "search %s'shistory" head-name))
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


(defun egg-reflog (branch)
  "Show commit DAG of BRANCH and its reflogs.
This is just an alternative way to launch `egg-log'"
  (interactive (let ((head-name (egg-branch-or-HEAD)))
		 (list (if current-prefix-arg
			   (egg-read-rev "show history of ref: " head-name)
                       head-name))))
  (egg-log branch))

(defun egg-log-buffer-reflog-ref (pos)
  "Show reflogs for the ref at POS"
  (interactive "d")
  (egg-reflog (egg-ref-at-point pos)))

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
      (unless (egg-git-ok-args t
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

(defun egg-sb-buffer-apply-stash (pos &optional no-confirm)
  (interactive "d\nP")
 (let ((stash (get-text-property pos :stash)))
    (when (and stash (stringp stash)
               (or no-confirm
                   (y-or-n-p (format "apply WIP %s to repo? " stash))))
      (egg-sb-buffer-do-unstash "apply" "--index" stash))))

(defun egg-sb-buffer-pop-stash (&optional no-confirm)
  (interactive "P")
  (when (or no-confirm
            (y-or-n-p "pop and apply last WIP to repo? "))
    (egg-sb-buffer-do-unstash "pop" "--index")))

(defun egg-sb-buffer-drop-stash (pos &optional all)
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

(defconst egg-stash-help-text
  (concat
   (egg-text "Extra Key Bindings for a Stash line:" 'egg-help-header-2) "\n"
   (egg-pretty-help-text
    "\\<egg-stash-map>"
    "\\[egg-sb-buffer-show-stash]:load details  "
    ;; "\\[egg-section-cmd-toggle-hide-show]:hide/show details  "
    "\\[egg-sb-buffer-apply-stash]:apply  "
    "\\[egg-sb-buffer-pop-stash]:pop and apply stash "
    "\\[egg-sb-buffer-drop-stash]:delete stash  "
    )
   "\n"
   ))

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
         (pretty (egg-describe-rev commit))
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
if CONFIRM-P was not null, then ask for confirmation if the
current file contains unstaged changes."
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
if CONFIRM-P was not null, then ask for confirmation if the
current file contains unstaged changes."
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
     (egg--git-co-files-cmd (egg-get-status-buffer) git-file))))

(defun egg-start-new-branch (&optional force)
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

(defun egg-file-get-other-version (file &optional rev prompt same-mode name)
  (let* ((mode (assoc-default file auto-mode-alist 'string-match))
         (git-dir (egg-git-dir))
         (lbranch (egg-current-branch))
         (rbranch (and git-dir (or (egg-tracking-target lbranch)
                                   rev ":0")))
         (prompt (or prompt (format "%s's version: " file)))
         (rev (or rev (egg-read-rev prompt rbranch)))
         (canon-name (egg-file-git-name file))
         (git-name (concat rev ":" canon-name))
         (buf (get-buffer-create (concat "*" (or name git-name) "*"))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (unless (= (call-process egg-git-command nil buf nil "show"
                                 git-name)
                   0)
          (error "Failed to get %s's version: %s" file rev))
        (when (and (functionp mode) same-mode)
          (funcall mode))
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
  "Compare, using ediff, the file's contents in work-dir with vs a rev.
If ASK-FOR-DST is non-nil, then compare the file's contents in 2 different revs."
  (interactive "P")
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (let* ((file buffer-file-name)
         (dst-buf (if ask-for-dst
                      (egg-file-get-other-version
                       (buffer-file-name) nil
                       (format "(ediff) %s's newer version: " file)
                       t)
                    (current-buffer)))
         (src-buf (egg-file-get-other-version
                   (buffer-file-name)
                   nil
                   (format "(ediff) %s's older version: " file)
                   t)))
    (unless (and (bufferp src-buf) (bufferp dst-buf))
      (error "Ooops!"))
    (unless (equal (current-buffer) dst-buf)
      (egg--add-ediffing-temp-buffers dst-buf))
    (egg--add-ediffing-temp-buffers src-buf)
    (ediff-buffers dst-buf src-buf)))

(defun egg-resolve-merge-with-ediff (&optional what)
  "Launch a 3-way ediff session to resolve the merge conflicts in the current file.
WHAT is a mistery."
  (interactive "P")
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (let* ((file buffer-file-name)
         (short-file (file-name-nondirectory file))
         (ours (egg-file-get-other-version file ":2" nil t (concat "our:" short-file)))
         (theirs (egg-file-get-other-version file ":3" nil t (concat "their:" short-file))))
    (unless (and (bufferp ours) (bufferp theirs))
      (error "Ooops!"))
    (egg--add-ediffing-temp-buffers ours theirs)
    (if (egg-rebase-in-progress)
	(ediff-buffers3 ours theirs (current-buffer))
      (ediff-buffers3 theirs ours (current-buffer)))))

(defun egg-file-do-ediff (closer-rev closer-rev-name &optional further-rev further-rev-name ediff2)
  "Invoke ediff to compare the contents of the file from FURTHER-REV to CLOSER-REV.
CLOSER-REV-NAME and FURTHER-REV-NAME are pretty display names for the revs.
If EDIFF2 is non-nil, use 2-way ediff session, otherwise use 3-way ediff session
with the current contents in work-dir."
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (let* ((file buffer-file-name)
         (short-file (file-name-nondirectory file))
         (closer-name (concat (or closer-rev-name closer-rev)
                              ":" short-file))
         (this (egg-file-get-other-version file closer-rev nil t closer-name))
         (further-name (and further-rev
                            (concat (or further-rev-name further-rev)
                                    ":" short-file)))
         (that (and further-rev
                    (egg-file-get-other-version file further-rev nil t further-name))))
    (unless (bufferp this) (error "Ooops!"))
    (unless (or (null further-rev) (bufferp that)) (error "Ooops!"))
    (egg--add-ediffing-temp-buffers this that)
    (if (bufferp that)
        (if ediff2
            (ediff-buffers that this)
          (ediff-buffers3 that this (current-buffer)))
      (ediff-buffers this (current-buffer)))))

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
  (define-key map (kbd "d") 'egg-status)
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
  (define-key map (kbd "S") 'egg-stash)
  (define-key map (kbd "u") 'egg-file-cancel-modifications)
  (define-key map (kbd "v") 'egg-next-action)
  (define-key map (kbd "w") 'egg-commit-log-edit)
  (define-key map (kbd "/") 'egg-search-file-changes)
  (define-key map (kbd "?") 'egg-search-changes)
  (define-key map (kbd "=") 'egg-file-diff)
  (define-key map (kbd "~") 'egg-file-version-other-window)
  )

(defconst egg-minor-mode-menu (make-sparse-keymap "Egg (Git)"))
(define-key egg-minor-mode-map [menu-bar egg-minor-mode-menu]
  (cons "Egg (Git)" egg-minor-mode-menu))

(let ((menu egg-minor-mode-menu))
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
    (when (string-match "\\`git version 1.\\(6\\|7\\)."
                        (shell-command-to-string
                         (concat egg-git-command " --version")))
      (or (assq 'egg-minor-mode minor-mode-alist)
          (setq minor-mode-alist
                (cons '(egg-minor-mode egg-minor-mode-name) minor-mode-alist)))
      (setcdr (or (assq 'egg-minor-mode minor-mode-map-alist)
                  (car (setq minor-mode-map-alist
                             (cons (list 'egg-minor-mode)
                                   minor-mode-map-alist))))
              egg-minor-mode-map)
      (make-local-variable 'egg-minor-mode)
      (egg-minor-mode 1))))

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
    (egg-log-buffer-fetch egg-ref-at "(re)-fetch %s")
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

;; misc
(defun egg-insert-texi-for-command ()
  (interactive)
  (let* ((func (symbol-at-point))
	 (name (or (and func (symbol-name func)) (completing-read "function: " obarray 'fboundp t nil nil)))
	 (doc (documentation (or func (intern name)))))
    (forward-line 1)
    (insert "@deffn Command " name "\n"
	    "@anchor{" name "}\n"
	    doc "\n"
	    "@end deffn\n")))

(defun egg-update-texi-command-doc ()
  (interactive)
  (let (fn)
    (save-excursion
      (goto-char (line-beginning-position))
      (when (looking-at "@deffn Command \\(egg-.+\\)\\s-*$")
	(setq fn (match-string-no-properties 1))
	(forward-line 1)
	(unless (looking-at "@anchor{")
	  (insert "@anchor{" fn "}\n"))))))

(defun egg-insert-texi-for-map ()
  (interactive)
  (let* ((map (symbol-at-point))
	 (map-name (or (and map (symbol-name map))
		       (completing-read "map: " obarray 'boundp t nil nil)))
	 (doc (documentation-property (or map (intern map-name))
				      'variable-documentation))
	 key command key-cmd-alist)
    (save-excursion
      (with-temp-buffer
	(insert doc)
	(goto-char (point-min))
	(while (re-search-forward "^\\([^\t\n]+\\)\t+\\(\\S-+\\)$" nil t)
	  (setq key (match-string-no-properties 1)
		command (match-string-no-properties 2))
	  (add-to-list 'key-cmd-alist (cons key command)))))
    (forward-line 1)
    (insert "@table @kbd\n")
    (dolist (pair (nreverse key-cmd-alist))
      (setq key (car pair)
	    command (cdr pair))
      (insert "@item " key "\n" "@ref{" command "}\n"))
    (insert "@end table")))

(run-hooks 'egg-load-hook)
(provide 'egg)

;;; egg.el ends here
