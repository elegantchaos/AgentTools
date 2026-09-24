# 0002: Agents Repository Root Detection

- Status: Accepted
- Date: 2026-09-23 (recorded 2026-09-24)

## Context

`agt rules` and `agt skills` operate on a checkout of the shared Agents repository, which moved its runtime-specific content from a top-level `codex/` directory into `runtimes/` to make room for Claude Code.

## Decision

The Agents repository root is the nearest directory containing `skills/`, `runtimes/`, and `COMMON.md`, unless `AGENTS_REPO_ROOT` names a checkout explicitly.

## Alternatives

- Rejected: continuing to recognise the old `codex/` layout alongside `runtimes/`.

## Consequences

- Checkouts using the old layout are not recognised (breaking in 2.0).
- `agt validate` does not use root detection; it runs in the repository being validated.
