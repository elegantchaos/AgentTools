# 0009: Agents Repository Defaults to the Shared Checkout

- Status: Accepted
- Date: 2026-10-08

## Context

`agt refresh`, `agt rules` and `agt skills` found the Agents repository by scanning the working directory and its ancestors for `skills/`, `runtimes/` and `COMMON.md`, unless `AGENTS_REPO_ROOT` was set. Run from anywhere else, they failed. The shared checkout lives at `~/.local/share/agents` on every machine that uses `agt`, so the scan only ever found it when the user happened to be inside it.

## Decision

Maintenance commands use `AGENTS_REPO_ROOT` when it is set and non-empty. Otherwise they use `~/.local/share/agents`, which must contain `skills/`, `runtimes/` and `COMMON.md`. They do not search the working directory or its ancestors.

## Alternatives

- Rejected: scanning ancestors first and falling back to the shared checkout. It makes the result depend on the working directory, so running inside another checkout, or a test fixture, silently changes which repository is maintained.

## Consequences

- The commands run from any directory.
- Working on a different checkout, including in tests, requires `AGENTS_REPO_ROOT`.
- A missing or incomplete default checkout reports its absolute path, the required markers, and the override variable.
