# 0002: `agt` Owns Swift Validation

- Status: Accepted
- Date: 2026-09-24

## Context

Agent-driven work in Swift repositories needs one standard post-change validation flow: format, lint, build, and test. The shared `swift:validation` skill already obtains `agt` through its `scripts/ensure-agt.sh`.

## Decision

`agt validate` is the standard Swift validation command for agent-driven development, and the `swift:validation` skill runs it. Changes to how Swift validation works are made in AgentTools.

## Alternatives

- Rejected: keeping validation in ReleaseTools, which is scoped to release automation.

## Consequences

- `agt` serves any Swift repository, not only the Agents repository; `agt validate` runs in the repository being validated and does not use Agents root detection.
- Validation changes that shared skills depend on need an AgentTools release.
