;;; egg-grep.el -- Emacs Got Git's compile-mode which can grep files in non-checkout git revisions
;; 
;; A magit fork
;; 
;; Copyright (C) 2008  Linh Dang
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
(require 'egg)
(require 'compile)
(require 'grep)
(require 'cl)

(defvar egg-grep-saved-find-file-func nil)

(defun egg-grep-find-file (marker rev:name dir formats)
  (save-match-data
    (let* ((rev-name-lst (split-string rev:name ":" t))
	   (rev (car rev-name-lst))
	   (file (cadr rev-name-lst)))
      (unless file 
	(setq file rev)
	(setq rev nil))
      (if rev
	  (egg-file-get-other-version file rev nil t)
	(apply egg-grep-saved-find-file-func marker file dir formats)))))

(defun egg-grep-next-error-function (n &optional reset)
  (interactive "P")
  (let ((egg-grep-saved-find-file-func
	 (symbol-function 'compilation-find-file)))
    (flet ((compilation-find-file (marker file-name dir &rest formats)
				  (egg-grep-find-file marker 
						      file-name
						      dir formats)))
      (compilation-next-error-function n reset))))

;;;###autoload
(defun egg-grep-process-setup ()
  "Setup compilation variables and buffer for `egg-grep'.
Set up `compilation-exit-message-function' and run `egg-grep-setup-hook'."
  (set (make-local-variable 'compilation-exit-message-function)
       (lambda (status code msg)
	 (if (eq status 'exit)
	     (cond ((zerop code)
		    '("finished (matches found)\n" . "matched"))
		   ((= code 1)
		    '("finished with no matches found\n" . "no match"))
		   (t
		    (cons msg code)))
	   (cons msg code)))) 
  
  (run-hooks 'egg-grep-setup-hook))



(defvar egg-grep-mode-map
  (let ((map (make-sparse-keymap "Egg:Grep")))
    (set-keymap-parent map compilation-minor-mode-map)
    (define-key map (kbd "SPC") 'scroll-up)
    (define-key map (kbd "DEL") 'scroll-down)

    (define-key map (kbd "RET") 'compile-goto-error)
    (define-key map "n" 'next-error-no-select)
    (define-key map "p" 'previous-error-no-select)
    (define-key map "{" 'compilation-previous-file)
    (define-key map "}" 'compilation-next-file)
    (define-key map (kbd "TAB") 'compilation-next-error)
    map)
  "Keymap for git-grep buffers.
`compilation-minor-mode-map' is the parent keymap.")

;;;###autoload
(define-compilation-mode egg-grep-mode "Git-Grep"
  "Sets `compilation-last-buffer' and `compilation-window-height'."
  (setq compilation-last-buffer (current-buffer))
  (set (make-local-variable 'compilation-error-face)
       grep-hit-face)
  (set (make-local-variable 'compilation-error-regexp-alist)
       grep-regexp-alist)
  (set (make-local-variable 'compilation-process-setup-function)
       'egg-grep-process-setup)
  (set (make-local-variable 'compilation-disable-input) t)
  (set (make-local-variable 'next-error-function) 
       'egg-grep-next-error-function))

;;;###autoload
(defun egg-grep (level)
  (interactive "p")
  (let ((git-dir (or (egg-git-dir) 
		     (error "Dir NOT in a git repo: %s" 
			    default-directory)))
	(cmd "git --no-pager grep -n ")
	rev term)

    (when (> level 15)
      (setq rev (egg-read-rev "grep in revision: " "HEAD"))
      (when (= (aref rev 0) ?:)
	(setq cmd (concat cmd "--cached "))
	(setq rev nil)))

    (when (and (> level 3) (setq term (symbol-at-point)))
      (when term
	(setq term (symbol-name term))
	(setq cmd (concat cmd term " "))))
    
    (when rev
      (setq cmd (concat cmd " " rev)))

    (setq cmd 
	  (read-string "run git grep (like this) : " cmd))

    (compilation-start cmd 'egg-grep-mode
		       `(lambda (name) 
			  (format "*git-grep@%s*" ,git-dir)))))

;;; egg-grep.el ends here
