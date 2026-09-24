# 0003: Validation Does Not Modify the Project

- Status: Accepted
- Date: 2026-09-24

## Context

Validation runs after every change, and its full phase is planned to run in the background while the user or agent keeps editing. Anything validation writes into the project could race with those edits, and a check that rewrites what it checks cannot be trusted to report on the code as written.

## Decision

`agt validate` never modifies the project's source or any other tracked or user-owned file. It writes only its own outputs: build products, logs, and caches, in directories it owns. Commands that change source, such as formatting, are separate commands.

## Alternatives

- Rejected: formatting as the first step of validation.

## Consequences

- Formatting and linting move to `agt format`, which the `swift:validation` skill runs before `agt validate`.
- Validation can run in the background, or be repeated, without disturbing work in progress.
- Validation's build directories must be separate from those the IDE and the developer use.
