# 0007: `agt` Holds Its Own Privacy Permissions

- Status: Accepted
- Date: 2026-10-07
- Revised: 2026-11-04

## Decision

Commands that need a macOS privacy permission run in `agt` as its own responsible process. The grant then belongs to the `agt` executable, not to the terminal, agent app or ssh session that started it. These commands are `agt calendar`, which reads calendars and reminders, and the `agt ui` commands that need Accessibility (called Device Control and Data Access from macOS 27) or Screen Recording.

- Such a command relaunches `agt` with the private `responsibility_spawnattrs_setdisclaim` spawn attribute, so macOS charges the permission to `agt`. Output passes straight through the inherited standard streams, and the relaunched `agt` exits when the `agt` that started it exits, so cancelled work cannot carry on unseen.
- Whenever `agt` is its own responsible process, found with the private `responsibility_get_pid_responsible_for_pid`, it accepts only those commands. It never accepts a command that starts or stops other processes, including `agt ui launch` and `agt ui quit`, so nothing else runs with the permissions or inherits them.
- Each command checks its permission before doing anything. A missing permission fails with advice naming what to allow, or, for calendars, with a request as described below.
- `agt` embeds an Info.plist in its binary, with a bundle identifier, a display name, and usage descriptions for calendars and reminders.
- `agt` stays ad-hoc signed, so grants are tied to each build's code hash.

## Details: Calendars

- `events` and `reminders` request full access to their own resource when permission is undetermined, then continue if it is granted. Both accept `--no-prompt`, which suppresses requests and fails without reading when access is missing. Existing grants need no request; denied, write-only and restricted states fail with recovery advice. There is no separate `authorize` command.
- A permission request waits at most two minutes, because macOS keeps an unanswered dialog open indefinitely.
- What reaches the caller is limited in code: read-only access; at most 14 days ahead; events give start, end, all-day, title, location and calendar; reminders give only incomplete ones, with title, due date and list; text is reduced to one line of at most 80 characters, with any link in it replaced; never notes, attendees, URLs or attachments.
- A user configuration file names the calendars and reminder lists to include. It filters noise; it is not a security boundary, since an agent can edit it.

## Context

macOS charges a privacy permission (TCC) to a process's responsible process. For a command-line tool that is normally the app that launched it, such as Terminal or the Claude desktop app, so a grant there covers every process an agent runs. Over ssh it is `/usr/libexec/sshd-keygen-wrapper`, so a grant there covers every command run over ssh.

Calendar text is a route for prompt injection, since anyone who can send Sam an invitation can write in it, and reading events needs full access; there is no read-only tier. `agt ui` drives a disposable test machine over ssh, where Screen Recording and Accessibility should not reach every ssh command. The [2026-10-07](../Journal/2026-10-07.md) and [2026-11-04](../Journal/2026-11-04-ui-driving.md) journal entries record the spikes and VM experiments behind this decision.

## Alternatives Considered

- Rejected: a separate helper executable or app bundle holding the permissions. Any process running as the user can launch whichever program holds them, so a helper suggests a boundary that does not exist, and adds a second program to install and keep in step.
- Rejected: granting the launching process, such as `sshd-keygen-wrapper` for `agt ui` over ssh. It hands the permissions to everything that process starts.
- Rejected: AppleScript or Shortcuts for calendars. They give the host control of Calendar and Reminders, including creating and changing items.
- Rejected: third-party tools such as icalBuddy, which leave the permission with the terminal, and calendar connectors, which add OAuth scopes and a third party.
- Rejected: a separate `agt calendar authorize` as the only command that can prompt. Queries already fail without access, so it only adds a step before the same macOS dialog. `--no-prompt` guarantees that a query shows no dialog.
- Retained for later: signing `agt` with a stable identity, so that grants match its designated requirement and survive rebuilds. Builds installed through Mint cannot be signed that way.
- Retained for later: an app bundle launched through LaunchServices, the public alternative to the private spawn attribute, if Apple removes the private functions.

## Consequences

- These commands depend on private API. If it disappears, they report that they are unavailable, and nothing else in `agt` changes.
- Each new `agt` build needs its permissions granted again. A modified `agt` cannot use them without the user granting or approving it.
- The relaunch changes which process holds a permission, but does not leave an enclosing agent sandbox. Inside one, EventKit can report undetermined access despite an existing grant, and permission requests can fail, so calendar queries retry outside it through the agent's approval flow.
- `Package.swift` passes the Info.plist to the linker with unsafe flags, which SwiftPM allows because `agt` is always built as a root package.
- The entry point checks the responsible process before parsing the command line. This extends [0004](0004-executable-is-only-an-entry-point.md): the executable still only calls into `AgentToolsCore`.
