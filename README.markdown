# Egg (Emacs Got Git).

## Intro

Egg is an Emacs interface to git. It's a suite composed of a
minor-mode and various special-buffers presenting different UIs to
help the user performing many git operations.

- egg-minor-mode: providing git-specific vc-look-alike interface
  including similar key-bindings, a minor-mode menu and history
  annotations (blame).
- egg's status-buffer:
  - index manipulation/commit preparation
  - interactive rebase stepping
  - merge conflict resolution
  - stashing work-in-progress
  - adding ignore pattern
  - staging new files
  - ediff or ediff3 launching. (e.g. 3-way ediff of
    work-dir/INDEX/HEAD, 3-way ediff of work-dir/theirs/ours)
- egg's log-buffer
  - browse repo's history and reflogs
  - ref (tag, branch, etc) creation and deletion
  - push and fetch
  - start merge/rebase/interactive-rebase session
  - anchor HEAD (reset)
  - search history (pickaxe), grep commit message.
  - compare revisions
- egg's file-log-buffer: restricted version of the log-buffer, used to
  browse history of a single file.
- egg's query:commit-buffer: restricted variation of the log-buffer,
  used to browse history-search's results (pickaxe or message grep)
- egg-grep: a compile-mode which can grep files in non-checkout git
  revisions.
- egg's commit-log-edit buffer: used to compose the commit-message for
  the upcoming commit. it can do some minor index manipulation. gpg-signature
  can also be enabled.
- egg's tag:msg-buffer: used to compose the message of an annotated tag.
  gpg-signature can also be enabled.
- egg's diff-buffer: used to view the delta between file or repo revisions.

## History

The design of the status-buffer Egg was borrowed/stolen from Magit. Egg,
however has much more functionalities than the status buffer. 

## MAGIT

Magit is an interface to the version control system Git, implemented
by Marius Voller. His code at: http://philjackson.github.com/magit/
