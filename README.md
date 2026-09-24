# AgentTools

[![Tests](https://github.com/elegantchaos/AgentTools/actions/workflows/Tests.yml/badge.svg)](https://github.com/elegantchaos/AgentTools/actions/workflows/Tests.yml)
[![Latest release](https://img.shields.io/github/v/release/elegantchaos/AgentTools)](https://github.com/elegantchaos/AgentTools/releases)
[![Swift 6.2](https://img.shields.io/badge/swift-6.2-F05138.svg)](https://swift.org)
![Platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)

Command-line tools for agent-driven development: maintenance for the shared [Agents](https://github.com/elegantchaos/Agents) repository, and a standard validation flow for Swift repositories.

## Installation

Install the latest release with [Mint](https://github.com/yonaskolb/Mint):

```shell
mint install elegantchaos/AgentTools
```

## Usage

```shell
agt <command>
```

Run `agt rules` and `agt skills` from the root of the Agents repository, or set `AGENTS_REPO_ROOT` to use a different checkout. Run `agt validate` from the root of the Swift repository being validated.

### Rules

Inspect differences between canonical shared rules and Codex runtime copies:

```shell
agt rules status
```

Synchronize canonical rules into the runtime rules directory:

```shell
agt rules sync
```

### Skills

Initialize or update all public skill submodules to their recorded revisions:

```shell
agt skills sync --all
```

Rebuild runtime skill links in `~/.codex/skills` and `~/.claude/skills` (or under `CODEX_HOME` and `CLAUDE_CONFIG_DIR` when set). Existing links are replaced; any other file or directory with a skill's name is left in place and reported as an error:

```shell
agt skills link
```

Inspect submodule and runtime-link status:

```shell
agt skills status
```

Audit skills for publication blockers:

```shell
agt skills audit --all
```

### Validate

`agt validate` is the standard way to check a Swift repository after a change. It has two goals.

**Consistent process.** Routine housekeeping, such as formatting and linting, happens automatically and the same way every time, so no change skips it and every project follows the same steps.

**Fast, complete verification.** It confirms, as quickly as possible, that a change has broken nothing:

- *Fast feedback first.* Build errors should surface as early as possible, so validation starts at the smallest useful scope: the affected module, built for the host platform.
- *Complete coverage after.* A change can also break another platform, an integration between modules, or a test. Full validation builds the whole product for every platform it supports and runs all of its tests.

Run full validation from the repository root:

```shell
agt validate
```

Run the fast check for a module you have changed:

```shell
agt validate --target <name>
```

When the fast check passes, run full validation.

Each run finishes with a PASS/FAIL/SKIP summary. Per-step logs are written to `.build/validation-logs`, and terminal output is shaped with `--output filtered|quiet|raw` (`filtered` is the default).

Run `agt validate --help` for all options.

## Development

```shell
agt validate
```

Or directly with SwiftPM:

```shell
swift build
swift test
```
