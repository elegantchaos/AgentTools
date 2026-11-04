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
