# Egg (Emacs Got Git).

## bogo-1.0.3

### features
- some support for gpg agent. But you should use gpg-2. If you used gpg-1, add "use-agent" in gpg.conf
- added egg-log-HEAD-name for displaying the current branch in the log buffer
- added support for gitdir (when .git is a file)
- added new internal frame work to talk to the git program. should be more robust now.
  the old egg-sync-do framework is too crude and buggy. the cmd logger (egg-cmd-log) is
  now used for just logging command and not involved in any process handing.
- added new refs completion using for-each-ref. much cooler. see egg-read-ref and egg-read-local-ref
- added next and prev navigation binding for blame mode
- in status buffer, x will revert the file's contents to the one in HEAD.
  egg-diff-section-cmd-revert-to-head
- added detection for new file, so a unstaging would turn it back to a untracked file
- in status buffer, X now will revert the worktree back to the contents of the index.
  C-u X will revert the worktree and the index back to the contents of HEAD.
  (egg-status-buffer-undo-wdir)
- in status buffer, W will launch egg-stash
- in status buffer, U will unstage all files. (egg-unstage-all-files)
- improved rebase (please test)
- in status buffer C-u i or C-u s (egg-status-buffer-stage-untracked-file) will
  only add the entry and not the contents of the file to the index.
- improved checkout ref in status buffer (egg-status-buffer-checkout-ref)
- handled different scenarios when unstaging a diff section (new file, resolved merge, etc.)
- rewrote the internal framework of the commit buffer. should be more flexible now.
- with C-u C-u prefix egg-commit-log-edit will just admend the last commit with the existing
  message. No editing.
- in log buffer, = (egg-log-buffer-diff-revs) now supported pickaxing. C-u = will search for
  a string in the diff. C-u C-u = will ask for pickaxing mode (string, regex or line).
- cherry picking support, bound to c in log buffer.
- used DEL to unmark commits in log buffer. the - key caused problem because it all so used
  for prefix. thus C-u - can't be used for unmark all marks.
- keybindings changed for pushing/fetching in the log buffer. U and D is for push/fetch to/from
  remotes. "u" is for local "pushing", "d" is for.. wtf????
- in log buffer, C-u C-u m (egg-log-buffer-merge) will offer several types of merges.
  (no commit, squash, ff-only,...)
- simplified egg-log-buffer-rebase. it no longer takes the C-u prefix. it will simply
  rebase HEAD on the commit under the cursor using the marked commit as upstream.
- in log buffer, C-u o will forcefully checkout the commit or ref, ignoring collisons.
- in log buffer, C-u T now has different meaning (no longer force.) it will create
  a gpg signed tag. C-u C-u T will create a signed tag using default key.
- in log buffer, if there was a ref under a cursor, branch created by B or b will track that ref.
- in log buffer, a, C-u a and C-u C-u a (egg-log-buffer-attach-head, what's a bad name) changed
  their binding. a now will do reset --keep. C-u a will do reset --hard. C-u C-u a will
  prompt the user the type of reset to perform.
- added egg-log-buffer-revert-rev
- in log buffer, u and C-u u (egg-log-buffer-push-to-local) changed their binding. the source
  of the local push will be the commit under the cursor. if a commit   was marked, it will be used
  as target. if no commit was marked, then HEAD will be the target. C-u u will force the ask the
  user for the name of the target. C-u C-u u wil force a non-ff move. if the target was not HEAD,
  the command wil push source on target. if the target was HEAD, and non-ff mode was not forced,
  the command will attempt to do a merge --ff-only from source to HEAD. if non-ff mode was forced,
  the command will do a reset --hard on source, ie. move HEAD the source.
- in the log buffer, C-u / (egg-search-changes) now will do search for posix regexp. C-u C-u /
  will search for a line matching a regexp. commit:querry buffer now correctly display the
  pickaxed commit (restricting them to the diffs introducing or removing the search target.)
  the search target will also be highlighted.
- in log buffer, C-u = will now do a pickaxed diff. it will ask the user for a string to
  search in the diff. C-u C-u = will prompt the user for pickaxe mode (string, regexp or line).
  The displayed diff will be restricted to the diffs introducing or removing the search target.
- pickaxe commands such as egg-search-changes now will run inferior git in async mode because
  pickaxing take a long time on large repo.
- in status buffer, C-u w will ask the user whether untracked files should be stash as well.
- starting the manual

### fixed bugs
- fixed egg-help-key face definition
- replaced delete-duplicates with delete-dups (reduce CL usage)
- fixed invoked-interactively-p (it's now a macro)
- fixed async problem when working with multiple repo (the buffer was wired to the 1st repo).
  add with-egg-debug-buffer and with-egg-async-buffer to make it cleaner
- fixed many missing save-match-data
- improved egg-repo-state handling. added name and email. added egg-user-name and egg-user-email
- fixed decoration for cc diff
- fixed bug in egg-log-locate-commit, it should work correctly now
- fixed bug in egg-stash-buffer-pop and egg-stash-buffer-apply. the index should now be
  correctly restored.
  

### internal changes





## v1.0.3 (not released)
- Persistenk hunk state fixes
- Made the mode compatible with package.el's format
- support emacs 22. use interactive-p wrapper function
- fix not to use goto-char function
- support stage multiple files
  You can select target files and type "s" on status view,
  you will stage selected files.

## v1.0.2
- fixed window kill when finish commit or cancel commit
- fixed don't work when .git directory is symlink

## v1.0.1
- add feature to stage selected area on egg-status Thanks for jedbrown and mooz

## v1.0.0
- add option comment for egg-mode-key-prefix
- update indent .
- add feature for diff other repository .

## v0.96
- fix bug of View File History .

## v 0.95
- change egg-goto-block-filename function to bypte-compile some environments .
  Thanks for Antoine Levitt .

## v 0.94
- add const of egg-version .

## v 0.93
- fixed magit path . Thanks for SebastianRose .
- added egg-log-msg-cancel for quit from buffer commit message . Thanks for Alexander Prusov .
- use vc-git for showing vs-mode-line . Thanks for Alexander Prusov .
- hide HEAD for log . Thanks for Alexander Prusov .
- remove long long message in define-egg-buffer . Thanks for Alexander Prusov .
- fix bug in egg-decorate-log (substring args out of range) . Thanks for Alexander Prusov .
- add changelog to fix magit path. Thanks for Alexander Prusov .

## v 0.92
- fixed details of egg log buffer show escape charactors
- fixed log search error
- fixed egg-log-buffer-reflog-ref message no escap
- fixed history search to log-buffer unescaped
- change egg-auto-update default off
- add egg-switch-to-buffer option . Thank for Q.P.Liu .
- fixed that history page is not unescape .
- reverting change which broke IDing of refs (breaking push) . Thanks for A. Amar .
- remove debugging code from log decorator . Thanks for A. Amar .

## v 0.91

- support git 1.7.x from strav/master
- fixed log output
- status auto-update merge from bandresen/master
- Fixed bug in egg-hunk-section-cmd-visit-file-other-window. from eostrom/master
- Merge branch 'blamefix' of git://github.com/mkleehammer/egg into mkleehammer-master
- fork git://github.com/bogolisk/egg.git

