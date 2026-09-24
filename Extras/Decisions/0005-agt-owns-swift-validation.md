# 0005: `agt` Owns Swift Validation

- Status: Accepted
- Date: 2026-09-24

## Context

The standard Swift validation flow (format, lint, build, test) lived in ReleaseTools as `rt validate`. It serves agent-driven development in any Swift repository and has nothing to do with releasing, and the `swift:validation` skill already carries `scripts/ensure-agt.sh`.

## Decision

Swift validation lives in AgentTools as `agt validate`, keeping the `rt validate` option names and behaviour. The `swift:validation` skill runs it through its own `scripts/ensure-agt.sh`.

## Alternatives

- Rejected: keeping validation in ReleaseTools.
- Retained for later: changing how validation builds, such as routing builds through an open IDE, once the port is released.

## Consequences

- `rt validate` is deprecated and will be removed from ReleaseTools after projects switch.
- Validation work planned in ReleaseTools' roadmap (local package validation manifests, `Runner`-based subprocesses with `VALIDATING=1`) belongs here.
- Projects whose `AGENTS.md` names `rt validate` need a refresh.
