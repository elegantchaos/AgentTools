# 0001: Standalone `agt` Package

- Status: Accepted
- Date: 2026-07-23 (recorded 2026-09-24)

## Context

The maintenance tool for the shared Agents repository was embedded in that repository, coupling the tool's source and build to the content it maintains.

## Decision

`agt` is built from this standalone Swift package, released with annotated `vX.Y.Z` tags and GitHub releases, and installed with Mint (`mint install elegantchaos/AgentTools`).

## Alternatives

- Rejected: keeping the tool embedded in the Agents repository.

## Consequences

- The Agents repository and plugins obtain `agt` through `scripts/ensure-agt.sh`, which installs it with Mint; `--update` installs the latest release.
- Behaviour changes reach users only through a release, so releases must be cut for changes that shared plugins depend on.
