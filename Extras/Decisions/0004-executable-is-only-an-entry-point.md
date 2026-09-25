# 0004: The Executable Is Only an Entry Point

- Status: Accepted
- Date: 2026-09-25

## Context

The tests depended directly on the `AgentTools` executable target. To link an executable into a test bundle, SwiftPM renames its entry point in the test build. When the root command became an `AsyncParsableCommand`, Swift 6.3.3 stopped applying that rename in release builds. The test binary then ran `agt`'s own `main`, which rejected the test runner's arguments, and CI failed on every push while local builds on Swift 6.4 passed.

## Decision

All of `agt`'s code, including the root command, lives in the `AgentToolsCore` library. The `AgentTools` executable target contains only the `@main` entry point, which runs `AgentToolsCommand`. Tests depend on `AgentToolsCore`, never on the executable.

## Alternatives

- Rejected: running CI tests in debug. It hides the problem for one configuration and leaves release test builds broken on affected toolchains.
- Rejected: waiting for CI runners to ship Xcode 27. It depends on GitHub's schedule and still breaks for anyone testing in release on Swift 6.3.
- Rejected: going back to a synchronous root command. It would give up async commands to work around a toolchain bug.

## Consequences

- New code goes in `AgentToolsCore`. The executable target gains nothing beyond its entry point.
- `AgentToolsCommand`, and whatever the entry point needs, must be `public`. Everything else can stay internal, since the tests use `@testable import AgentToolsCore`.
- Build plugins that generate sources for the library, such as Versionator, apply to `AgentToolsCore`.
