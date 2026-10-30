# Calendar Access Diagnostics

Calendar queries reported undetermined access inside the Codex sandbox even after the installed executable was granted Calendar and Reminders permission outside it. The same installed executable queried successfully outside the sandbox. Authorization inside the sandbox failed with NSMachErrorDomain 4099. The calendar relaunch assigns permission to agt but does not remove its enclosing sandbox.

On `feature/calendar-access-diagnostics`, missing-access diagnostics now distinguish undetermined, denied, write-only and restricted states. An undetermined result explains that sandboxing may hide an existing grant and advises an approved query outside the sandbox before another authorization request. Denied and write-only access point to System Settings; restrictions identify policy. Authorization failures retain the resource, macOS error domain, code and explanation, with conditional sandbox advice. Cancellation still propagates as cancellation. No automatic escalation, permission changes or approval-rule changes were added; Decision 0007's attribution and query-only behavior remain unchanged.

The new diagnostic tests failed on their expectations before implementation, then passed. The sandboxed target run built successfully and passed the calendar tests, but the existing RefreshTests.pluginCommandSharesProcessGroup test failed because the sandbox blocks /bin/ps. Full `agt validate` passed outside the sandbox through the approval flow: the macOS executable build and all 221 tests in 32 suites. Formatting and lint passed without findings; whitespace checks passed. The rebuilt CLI's `calendar events` command reproduced undetermined access inside the sandbox and printed the new recovery advice without prompting. The README documents that advice. No installed executable was replaced or newly built executable authorized; live authorization of the new binary remains untested to avoid changing the user's grants.

## Follow-up: Automatic Permission Requests And `--no-prompt`

Sam requested removal of the separate authorize command, automatic permission requests from events/reminders, and `--no-prompt` on both queries to suppress those requests. Each query now requests only its own resource when undetermined and continues after approval. Existing grants need no request; denied, write-only and restricted states fail without reading. A failed request preserves its underlying service error and cancellation remains cancellation. Decision 0007 was revised with Sam's explicit permission. README and CLI help describe the new behavior.

New regression tests initially failed to compile against the absent query option. After implementation, the sandboxed target run built and passed the calendar tests; its only failure was the existing process-group test's blocked /bin/ps call. Tests cover both roots' option parsing and removal of authorize, automatic requests and grant reuse, suppression with/without an existing grant, refused requests and status-specific diagnostics. The installed executable and user grants remain unchanged; live macOS permission-dialog testing is not performed.

Revision validation: `agt format` and lint pass without findings. Full `agt validate` outside the sandbox passes the macOS executable build and all 224 tests in 32 suites. Rebuilt CLI help exposes `--no-prompt` for both queries and only events/reminders as calendar subcommands. Whitespace checks pass. Changed files were checked against the coding, Swift, testing, records and Git guidance; no remaining findings. Live permission dialogs remain untested and no installed binary was replaced.

## Follow-up: Sandboxed Process-Group Test

Sam requested trying a native child helper instead of /bin/ps in RefreshTests.pluginCommandSharesProcessGroup. The test now compiles a small C probe with the installed /usr/bin/cc and launches it through the real runPassingThrough path. The child calls getpgrp() directly and compares it with the parent's supplied group. A second case deliberately supplies a mismatched group and verifies exit status 43, checking that the probe detects failure. The temporary source and executable are removed by the existing test cleanup. No production process-launch behavior changed.

The original sandboxed ps failure was observed before this revision. After replacement, `agt format` and lint pass without findings, and sandboxed `agt validate --target AgentToolsCore` builds the core and passes all 224 tests in 32 suites, including both probe cases. Whitespace and relevant skill checklist checks pass. Full validation was not repeated for this test-only revision; the preceding full result applies to b062ab7, while the new targeted result covers the changed test. The probe requires the compiler already provided by the project's Xcode toolchain.

## Follow-up: Review Fixes And Calendar Isolation

A review of aecc443 raised two unverified live risks, plus message, documentation and decision gaps. A query that follows a grant now reads through a new `EKEventStore`, because the old `authorize` never read after requesting and the same instance might not see the granted data. A new instance was chosen over `reset()` so the store calls nothing that could be mistaken for a change to user data. Whether the original instance really went stale was not established; only a live test could show it, and the fix cannot be unit tested because tests must not touch EventKit.

An unanswered dialog may block a query, with no timeout. The README now directs unattended callers to `--no-prompt`. No timeout was added until a live test shows whether one is needed. A suppressed request now reports that `--no-prompt` caused it and no longer suggests removing the flag. Decision 0007 now records why `authorize` was removed and that the relaunch does not leave an enclosing sandbox.

Sam asked for certainty that tests cannot reach real calendars or reminders, or change them. An audit found none did. `CalendarIsolationTests` now enforces this from source text: tests may not name EventKit, the real store, `CalendarRunner` or the launcher's `main`, and calendar test files may not call `run()`; only `EventKitCalendarStore.swift` imports EventKit; only `CalendarRunner` creates the real store; and the real store may not use EventKit's write, reset or item-creation APIs. Temporarily adding violations to the store and a test file made the suite fail; both were reverted. This is a text check, so it guards against accidents and not deliberate circumvention.

The new tests failed to compile before implementation. In Claude's sandbox the target run passed all calendar suites, but 10 `WorktreeCreatorTests` issues came from Git fixtures being denied hook-template copies. Full `agt validate` outside the sandbox passes the macOS build and all 228 tests in 33 suites. Live permission dialogs remain untested and need Sam to run them.

## Follow-up: Live Permission Results

Sam ran the dialogs from Terminal, using copies re-signed with their own identifier, since `tccutil reset` cannot find a bare executable by bundle identifier and resetting without one would affect every app. A new code signature started as not determined. `--no-prompt` failed without a dialog, and refusing the dialog reported denied with Settings advice. Approving printed complete events in the same run, and a later run printed identical output with no dialog. Reminders asked separately and also read in the same run. Whether the new `EKEventStore` was needed is still unknown, since the old path was not tried.

An unanswered dialog stayed open for more than five minutes with the query blocked, and it stayed open after Ctrl-C. A new query started while it was open showed no second dialog and resumed when it was approved. Queries now wait at most two minutes, and the message says the dialog may still be open.

After that Ctrl-C, event output appeared behind a shell prompt, which suggests that the relaunched child outlived its parent. This was inferred from the output and the cause was not found: nothing in `agt` handles SIGINT. A relaunched query now exits when its parent does, whatever ended the parent.

The events also showed a Zoom URL with its password in a location, against Decision 0007's rule that URLs never reach the caller. `CalendarText.singleLine` now replaces links in every field with `[link]`, before truncating.

The new text and timeout tests failed to compile before implementation. The parent watch has no automated test, because exercising it needs a real relaunch.

Full `agt validate` outside the sandbox passes the macOS build and all 233 tests in 33 suites. Sam then ran a fresh copy live. An unanswered request exited after two minutes with the new message and left the dialog open. After Ctrl-C during a second request, no process remained, and approving the dialog printed nothing. A later query showed the Zoom location as `[link]` and its other lines were unchanged.
