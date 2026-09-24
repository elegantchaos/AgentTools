# 0003: Canonical Shared Rules

- Status: Accepted
- Date: 2026-09-23 (recorded 2026-09-24)

## Context

Codex reads rules from its runtime rules directory, where manual edits and approvals accumulate. Shared rules need one source of truth.

## Decision

Shared rules are canonical in `runtimes/codex/rules` in the Agents repository. `agt rules sync` generates runtime copies, each with a managed header, and overwrites runtime edits. `default.rules` is runtime-only and must not be stored in the shared repository.

## Alternatives

- Rejected: symlinking runtime rules to the shared files, and treating runtime copies as editable sources.

## Consequences

- Useful runtime edits must be applied to the shared files before syncing, or they are lost.
- `agt rules status` reports drift without changing files.
