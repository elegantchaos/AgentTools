# 0007: Calendar Access Runs in `agt` as Its Own Responsible Process

- Status: Accepted
- Date: 2026-10-07

## Context

The Agents repository's `baseline:summaries` skill should report upcoming appointments and reminders. Agents should see only what that needs, not have broad calendar access. Anyone who can send Sam an invitation can put text in his calendar, so whatever reaches an agent is a route for prompt injection.

macOS charges a privacy permission (TCC) to a process's responsible process. For a command-line tool that is normally the app that launched it, such as Terminal or the Claude desktop app, so granting calendar access there would grant it to every process an agent runs. Reading events on macOS 14 and later needs full access; there is no read-only tier. The [2026-10-07 journal](../Journal/2026-10-07.md) records the spikes this decision rests on.

## Decision

Calendar and reminder access is an `agt calendar` command family in the single `agt` executable, and `agt` holds the permission as its own responsible process.

- `agt` embeds an Info.plist in its binary, with a bundle identifier, a display name, and usage descriptions for calendars and reminders.
- `agt calendar` relaunches `agt` with the private `responsibility_spawnattrs_setdisclaim` spawn attribute, so macOS charges the permission to `agt` itself. Output passes straight through the inherited standard streams.
- Whenever `agt` is its own responsible process, found with the private `responsibility_get_pid_responsible_for_pid`, it accepts only the calendar commands, so nothing else can run, or start other processes, with the permission.
- `agt calendar authorize` is the only command that can prompt. `events` and `reminders` fail with an instruction to run `authorize` when access is missing.
- What reaches the caller is limited in code: read-only access; at most 14 days ahead; events give start, end, all-day, title, location and calendar; reminders give only incomplete ones, with title, due date and list; text is reduced to one line of at most 80 characters; never notes, attendees, URLs or attachments.
- A user configuration file names the calendars and reminder lists to include. It filters noise; it is not a security boundary, since an agent can edit it.

## Alternatives

- Rejected: a separate helper executable or app bundle holding the permission. Any process running as the user can launch whichever program holds it, so a helper suggests a boundary that does not exist, and adds a second program to install and keep in step.
- Rejected: AppleScript or Shortcuts. They give the host control of Calendar and Reminders, including creating and changing items.
- Rejected: third-party tools such as icalBuddy, which leave the permission with the terminal, and calendar connectors, which add OAuth scopes and a third party.
- Retained for later: the public alternative to the private spawn attribute, an app bundle launched through LaunchServices, if Apple removes the private functions.

## Consequences

- `agt` depends on private API for this command family. If it disappears, `agt calendar` reports that it is unavailable and nothing else in `agt` changes.
- The grant is pinned to the code hash of the ad-hoc signed `agt`, so each `agt` update needs `agt calendar authorize` and a new approval. A modified `agt` cannot read calendars without the user seeing a prompt.
- `Package.swift` passes the Info.plist to the linker with unsafe flags, which SwiftPM allows because `agt` is always built as a root package.
- The entry point checks the responsible process before parsing the command line. This extends [0004](0004-executable-is-only-an-entry-point.md): the executable still only calls into `AgentToolsCore`.
