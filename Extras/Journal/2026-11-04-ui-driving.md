# Driving a macOS GUI over ssh

Bookish needs its macOS UI checked without taking over Sam's own Mac, so the plan is to run the app in a disposable tart VM (`golden-gate`, macOS 27.2) and drive it over ssh. This entry adds `agt ui`: `screenshot`, `tree`, `press`, `click`, `drag`, `scroll`, `type`, `key`, `launch` and `quit`, built on ScreenCaptureKit, `CGEvent`, `AXUIElement` and `NSWorkspace`, with no third-party dependencies.

## Findings from the VM

- A process started over ssh has `/usr/libexec/sshd-session` as its responsible process on macOS 27, found with `responsibility_get_pid_responsible_for_pid`. Older write-ups name `sshd-keygen-wrapper`; that is out of date. TCC charges Accessibility and Screen Recording to `sshd-session`.
- The ssh session is not cut off from the GUI. With nothing granted, `NSWorkspace` already saw the console session's frontmost app, and ScreenCaptureKit failed with "the user declined TCCs" rather than a connection error. So `launchctl asuser` and a per-user LaunchAgent are unnecessary: ssh in as the console user and grant `sshd-session`.
- ssh must log in as the user who owns the console. Logged in as `fatc` while `tester` held the console, `frontmostApplication` was nil and no apps were visible. Logged in as `tester`, everything worked.
- `CGPreflightPostEventAccess` follows the Accessibility grant; System Settings has no separate list for it.
- Without the permission, posted events vanish silently and AX returns nothing, so each command checks first and names the responsible executable in its error.

## Bugs found by driving it

- Typing after `key cmd+n` arrived as Command shortcuts and lost the text. Events created without a source take the session's current modifier flags, which the previous synthetic key event set. Every event is now posted through one helper that sets its flags explicitly.
- `quit` reported TextEdit still running after it had exited. `NSRunningApplication.isTerminated` only updates from a run loop, which a CLI doesn't run; `quit` now polls the process with `kill(pid, 0)`.
- A plain `quit` of TextEdit with an edited document times out on the save sheet, as intended. `agt ui press Delete --role AXButton` dismissed the sheet and the quit completed.

## Results

Unit tests cover key-combination and modifier parsing, tree capture and JSON encoding from an in-memory element source (depth limit, unexpanded menus, omitted attributes), the breadth-first press search, and the commands' argument parsing. They failed on their expectations against stubs before implementation, then passed. Nothing in the tests calls ScreenCaptureKit, AX or `CGEvent`, and no `agt ui` command was run on the host.

In the VM over ssh as `tester`, with Accessibility granted to `sshd-session`: `launch`, `key`, `type` (including an em dash and é), `tree`, `press` on a menu item and on a sheet button, `click` with count and modifiers, `drag`, `scroll` and `quit` all worked, with results checked through `tree`. Screenshots refused cleanly while Screen Recording was not yet granted.

`ResponsibleProcess` moved from `Calendar/` to `Support/`, since both command families use it now.

## Open

- A decision record for "`agt ui` runs under its caller's responsibility, intended for disposable machines" is proposed but not written; it needs Sam's confirmation.
- Remote lldb into the VM is a later stretch goal.

## Follow-up: The Grant Belongs to `sshd-keygen-wrapper`

The first finding above was wrong. With Screen Recording switched on for `sshd-session` in System Settings, captures were still refused. tccd's log for the request named `responsible_path=/usr/libexec/sshd-keygen-wrapper, binary_path=/usr/libexec/sshd-session`, and the system TCC database held Accessibility for `sshd-keygen-wrapper`, which worked, and Screen Recording for `sshd-session`, which tccd never consults. `sshd-keygen-wrapper` execs `sshd-session` in the same process. TCC keeps the executable the responsible process started as, while `responsibility_get_pid_responsible_for_pid` plus `proc_pidpath` report its current image. The permission error now maps `sshd-session` to `sshd-keygen-wrapper`, and the README names the wrapper. `sudo log show` with a `tccd` predicate is the reliable way to see which identity TCC is checking.

With Screen Recording granted to `sshd-keygen-wrapper`, the demo ran end to end in `golden-gate` over ssh as `tester`: `launch` TextEdit, `key cmd+n`, `tree` to find the text view, `click` into it, `type`, then `screenshot` of the display (1875×1021 points) and of TextEdit's window (603×505 at 265, 131, matching its position in the display image). The typed text read back through `tree`. The VM's system TCC database ends with Accessibility, Screen Recording and Full Disk Access granted to `/usr/libexec/sshd-keygen-wrapper`; only the first two are needed.

## Follow-up: `agt ui` Holds Its Own Permissions

Granting `sshd-keygen-wrapper` gave Screen Recording and Accessibility to every command run over ssh. Sam asked for the grants to belong to `agt` instead, the way `agt calendar` does it. The relaunch machinery moved out of the calendar code into `SelfResponsibleRunner` and `SelfResponsibleExecution` in `Support/`, and the eight `ui` commands that need a permission run through it. The restricted root a self-responsible `agt` accepts, renamed from `CalendarOnlyCommand` to `SelfResponsibleCommand`, now offers calendar and those eight `ui` commands, but not `launch` or `quit`, which start or stop other processes. The guard tests failed when the `ui` group was taken out of the restricted root. The `sshd-session` to `sshd-keygen-wrapper` mapping went, since the responsible process is now `agt` itself and the permission error names its path.

In `golden-gate`, with Screen Recording granted to `/Users/tester/agt` and the `sshd-keygen-wrapper` grants removed, `agt ui screenshot` worked over ssh and `screencapture -x` failed with "could not create image from display". Accessibility had not yet been granted to `agt`, and `tree` reported that with the path to allow.

The grant is keyed on the code hash, as the calendar grant is. Copying the identical build over `/Users/tester/agt` kept it. Re-signing that binary in place with a new identifier changed its CDHash and lost it, and restoring the original brought it back. So each rebuild whose code hash differs needs granting again, which matches what decision 0007 already accepts for calendars. Signing `agt` with a stable certificate would let TCC match its designated requirement instead, and could avoid re-granting; that is not done here.

With Accessibility also granted to `/Users/tester/agt`, and the `sshd-keygen-wrapper` entries removed so `agt` was the only grantee, the demo ran again over ssh: `launch` TextEdit, `key cmd+n`, `tree`, `press Bold --role AXMenuItem`, `click`, `key cmd+a`, `type`, and a window `screenshot`, while `screencapture -x` over ssh failed. Typed "agt" came back as "age" once, and "zqxj" as "Zqxj": TextEdit's autocorrection and capitalisation, not lost keys. macOS 27 calls the Accessibility list in Privacy & Security "Device Control and Data Access" (the `Privacy_Accessibility` pane's title in the tree), so the permission error and docs now use that name.

## Follow-up: Intermittent Lock Test

Full validation of b83ea03 failed twice in a row on `RepositoryOperationLockTests.ownershipIsExclusiveAndReleased`, which this branch does not touch, with "Cannot acquire the preparation/validation lock; held by validation". A full run on a clean checkout of `origin/main` passed, and a third full run of b83ea03, with nothing else running, passed too. The test is intermittent, and the cause was not found. Signing `agt` with a stable identity, so grants survive rebuilds, was tried and then dropped at Sam's request, because Mint installs could not be signed that way; grants stay tied to each build's code hash.

## Follow-up: Decision 0007 Rewritten

With Sam's approval, [0007](../Decisions/0007-agt-holds-its-own-privacy-permissions.md) is now titled "`agt` Holds Its Own Privacy Permissions". It is rewritten to cover `agt ui` as well as calendars: the restricted root's scope, the exclusion of `launch` and `quit`, `sshd-keygen-wrapper` as the rejected alternative over ssh, and stable signing kept for later because Mint builds can't be signed that way. Calendar-specific rules moved into their own Details section. This settles the decision record left open above.
