# 0003: Validation Does Not Modify the Project

- Status: Accepted
- Date: 2026-09-24
- Revised: 2026-11-06

## Context

Validation runs after every change, and its full phase is planned to run in the background while the user or agent keeps editing. Anything validation writes into the project could race with those edits, and a check that rewrites what it checks cannot be trusted to report on the code as written.

## Decision

`agt validate` protects the development worktree's source, tracked files, and other user-owned files. Targeted validation reads the development worktree and writes build products, logs, and caches to directories it owns. Commands that edit project files, such as formatting, are separate commands.

Change-scoped and full validation build a pinned commit in an AgentTools-owned validation worktree. AgentTools may reset tracked files and update submodules there to materialise the requested commit. The development worktree and its branch are untouched.

## Alternatives

- Rejected: formatting as the first step of validation.

## Consequences

- Formatting and linting move to `agt format`, which the `swift:validation` skill runs before `agt validate`.
- Validation can run in the background, or be repeated, without disturbing work in progress.
- Validation's build directories must be separate from those the IDE and the developer use.
