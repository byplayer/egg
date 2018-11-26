;;; egg-base.el --- Emacs Got Git - Emacs interface to Git

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

(require 'egg-custom)
(require 'egg-base)

(defconst egg-buffer-mode-map
  (let ((map (make-sparse-keymap "Egg:Buffer")))
    (define-key map (kbd "q") 'egg-quit-buffer)
    (define-key map (kbd "g") 'egg-buffer-cmd-refresh)
    (define-key map (kbd "G") 'egg-buffer-cmd-refresh)
    (define-key map (kbd "n") 'egg-buffer-cmd-navigate-next)
    (define-key map (kbd "p") 'egg-buffer-cmd-navigate-prev)
    (define-key map (kbd "C-c C-h") 'egg-buffer-hide-all)
    map)
  "Common map for an egg special buffer.\\{egg-buffer-mode-map}" )

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
    (define-key map (kbd "RET") 'egg-staged-diff-section-cmd-visit-index-other-window)
    (define-key map (kbd "f") 'egg-staged-diff-section-cmd-visit-index)
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

(defconst egg-unmerged-wdir-file-map
  (let ((map (make-sparse-keymap "Egg:UnmergedWdirFile")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "DEL") 'egg-unmerged-file-del-action)
    (define-key map (kbd "s") 'egg-unmerged-file-add-action)
    (define-key map (kbd "=") 'egg-unmerged-file-ediff-action)
    (define-key map (kbd "RET") 'egg-unmerged-wdir-file-next-action)
    map)
  "Keymap for unmerged entries in the status buffer. \\{egg-unmerged-wdir-file-map}")

(defconst egg-unmerged-index-file-map
  (let ((map (make-sparse-keymap "Egg:UnmergedIndexFile")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "DEL") 'egg-unmerged-file-del-action)
    (define-key map (kbd "s") 'egg-unmerged-file-checkout-action)
    (define-key map (kbd "=") 'egg-unmerged-file-ediff-action)
    (define-key map (kbd "RET") 'egg-unmerged-index-file-next-action)
    map)
  "Keymap for unmerged entries in the status buffer. \\{egg-unmerged-index-file-map}")

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
    (define-key map (kbd "RET") 'egg-staged-hunk-cmd-visit-index-other-window)
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

(defconst egg-unmerged-conflict-map
  (let ((map (make-sparse-keymap "Egg:Conflict")))
    (set-keymap-parent map egg-wdir-hunk-section-map)
    (define-key map (kbd "m") 'egg-unmerged-conflict-take-side)
    (define-key map (kbd "M") 'egg-unmerged-conflict-checkout-side)
    map)
  "Keymap for a hunk in a unmerged diff section.
\\{egg-unmerged-conflict-map}")

(defconst egg-status-base-map
  (let ((map (make-sparse-keymap "Egg:StatusBase")))
    (set-keymap-parent map egg-buffer-mode-map)
    (define-key map (kbd "c") 'egg-commit-log-edit)
    (define-key map (kbd "d") 'egg-diff-ref)
    (define-key map (kbd "l") 'egg-log)
    (define-key map (kbd "S") 'egg-stage-all-files)
    (define-key map (kbd "U") 'egg-unstage-all-files)
    (define-key map (kbd "SPC") 'egg-section-cmd-toggle-hide-show)
    (define-key map (kbd "P") 'egg-push-upstream)
    (define-key map (kbd "j") 'egg-pull-upstream)
    map)
  "Basic keymap for the status buffer.\\{egg-status-base-map}")

(defconst egg-status-buffer-mode-map
  (let ((map (make-sparse-keymap "Egg:StatusBuffer")))
    (set-keymap-parent map egg-status-base-map)
    (define-key map (kbd "c") 'egg-commit-log-edit)
    (define-key map (kbd "d") 'egg-diff-ref)
    (define-key map (kbd "l") 'egg-log)
    (define-key map (kbd "b") 'egg-start-new-branch)
    (define-key map (kbd "o") 'egg-status-buffer-checkout-ref)
    (define-key map (kbd "w") 'egg-status-buffer-stash-wip)
    (define-key map (kbd "G") 'egg-status)
    (define-key map (kbd "L") 'egg-reflog)
    (define-key map (kbd "S") 'egg-stage-all-files)
    (define-key map (kbd "U") 'egg-unstage-all-files)
    (define-key map (kbd "X") 'egg-status-buffer-undo-wdir)
    map)
  "Keymap for the status buffer.\\{egg-status-buffer-mode-map}")

(defconst egg-status-buffer-istash-map
  (let ((map (make-sparse-keymap "Egg:StatusBufferIStash")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "x") 'egg-sb-istash-abort)
    (define-key map (kbd "C-c C-c") 'egg-sb-istash-go)
    (define-key map (kbd "RET") 'egg-sb-istash-go)
    map)
  "Context keymap for the repo section of the status buffer when
  interactive stash is in progress.\\{egg-status-buffer-istash-map}")

(defconst egg-status-buffer-rebase-map
  (let ((map (make-sparse-keymap "Egg:StatusBufferRebase")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "x") 'egg-buffer-rebase-abort)
    (define-key map (kbd "u") 'egg-buffer-selective-rebase-skip)
    (define-key map (kbd "RET") 'egg-buffer-selective-rebase-continue)
    map)
  "Context keymap for the repo section of the status buffer when
  rebase is in progress.\\{egg-status-buffer-rebase-map}")

(defconst egg-status-buffer-common-help-text
  (concat
   (egg-text "Common Key Bindings:" 'egg-help-header-2)
   (egg-pretty-help-text
    "\\<egg-status-buffer-mode-map>\n"
    "\\[egg-buffer-cmd-navigate-prev]:previous block  "
    "\\[egg-buffer-cmd-navigate-next]:next block  "
    "\\[egg-commit-log-edit]:commit staged modifications  "
    "\\[egg-push-upstream]:push to the upstream  "
    "\\[egg-pull-upstream]:pull from the upstream  "
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

(defconst egg-untracked-file-map
  (let ((map (make-sparse-keymap "Egg:UntrackedFile")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "RET") 'egg-find-file-at-point)
    (define-key map (kbd "DEL") 'egg-ignore-pattern-from-string-at-point)
    (define-key map "s" 'egg-status-buffer-stage-untracked-file)
    (define-key map "i" 'egg-status-buffer-stage-untracked-file)
    map)
  "Keymap for a section of untracked file.
\\{egg-untracked-file-map}")

(defconst egg-stash-map
  (let ((map (make-sparse-keymap "Egg:Stash")))
    (set-keymap-parent map egg-hide-show-map)
    (define-key map (kbd "SPC") 'egg-sb-buffer-show-stash)
    (define-key map (kbd "RET") 'egg-sb-buffer-apply-stash)
    (define-key map "a" 'egg-sb-buffer-apply-stash)
    (define-key map (kbd "DEL") 'egg-sb-buffer-drop-stash)
    (define-key map "o" 'egg-sb-buffer-pop-stash)
    map))


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
    (define-key map (kbd "U") 'egg-log-buffer-push-to-remote)
	
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
  (let ((map (make-sparse-keymap "Egg:LogRemoteSite")))
    (set-keymap-parent map egg-log-commit-map)
    (define-key map (kbd "D") 'egg-log-buffer-fetch-site)
    (define-key map (kbd "U") 'egg-log-buffer-push-to-remote)

    (define-key map [C-down-mouse-2] 'egg-log-popup-remote-site-menu)
    (define-key map [C-mouse-2] 'egg-log-popup-remote-site-menu)

    map))

(defconst egg-log-diff-map
  (let ((map (make-sparse-keymap "Egg:LogDiff")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "RET") 'egg-log-diff-cmd-visit-file-other-window)
    (define-key map (kbd "f") 'egg-log-diff-cmd-visit-file)
    (define-key map (kbd "=") 'egg-diff-section-cmd-ediff)
    (define-key map (kbd "SPC") 'egg-log-diff-toggle-file-selection)
    map))

(defconst egg-log-hunk-map
  (let ((map (make-sparse-keymap "Egg:LogHunk")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "RET") 'egg-log-hunk-cmd-visit-file-other-window)
    (define-key map (kbd "f") 'egg-log-hunk-cmd-visit-file)
    (define-key map (kbd "=") 'egg-diff-section-cmd-ediff)
    (define-key map (kbd "SPC") 'egg-log-diff-toggle-file-selection)
    map))

(defconst egg-log-buffer-base-map
  (let ((map (make-sparse-keymap "Egg:LogBufferBase")))
    (set-keymap-parent map egg-buffer-mode-map)
    (define-key map "G" 'egg-log-buffer-style-command)
    (define-key map "n" 'egg-log-buffer-next-ref)
    (define-key map "s" 'egg-status)
    (define-key map "p" 'egg-log-buffer-prev-ref)
    (define-key map "P" 'egg-push-upstream)
    (define-key map "j" 'egg-pull-upstream)
    map))

(defconst egg-log-buffer-mode-map
  (let ((map (make-sparse-keymap "Egg:LogBuffer")))
    (set-keymap-parent map egg-log-buffer-base-map)
    (define-key map "L" 'egg-log-buffer-reflog-ref)
    (define-key map "/" 'egg-search-changes)
    (define-key map "D" 'egg-log-buffer-fetch)
    map)  
  "Keymap for the log buffer.\\{egg-log-buffer-mode-map}")

(defconst egg-log-style-buffer-map
  (let ((map (make-sparse-keymap "Egg:LogBuffer")))
    (set-keymap-parent map egg-log-buffer-base-map)
    (define-key map "s" 'egg-status)
    (define-key map "l" 'egg-log)
    map))

(provide 'egg-const)
