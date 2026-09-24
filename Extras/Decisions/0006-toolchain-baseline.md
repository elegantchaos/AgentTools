# 0006: Toolchain Baseline

- Status: Accepted
- Date: 2026-07-23 (recorded 2026-09-24)

## Context

`agt` is a macOS developer tool for the maintainers' own machines, which run current toolchains.

## Decision

The package targets macOS 26 and Swift 6.2 (tools version 6.2), and all tests use Swift Testing.

## Alternatives

- Rejected: supporting older macOS or Swift versions, and keeping XCTest.

## Consequences

- Current Swift and Foundation APIs can be used without availability checks.
- Raising the baseline is a routine change; lowering it needs a new decision.
