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

Run the standard post-change validation flow for a Swift repository:

```shell
agt validate
```

Comprehensive validation:

- formats and lints changed, staged, and untracked Swift files with `swift format`
- builds the Xcode workspace when one is usable; otherwise builds and tests every discovered Swift package; otherwise builds the Xcode project
- builds SwiftPM packages with `--build-system swiftbuild -Xswiftc -DVALIDATING`
- shapes output with `--output filtered|quiet|raw` (`filtered` is the default; `--quiet` and `--raw` are aliases)
- writes per-step logs to `.build/validation-logs`
- writes Xcode products to `.build/agt-validate/DerivedData`
- finishes with a PASS/FAIL/SKIP summary

Use `agt validate --target <name>` as a fast preflight after modifying a non-test SwiftPM target. It searches the discovered packages for that target, builds it and its dependencies, then runs a conventionally named `<name>Tests` target when one exists. When no package defines the target, it builds an Xcode scheme of that name instead. The option is not intended for test-target names.

After targeted validation passes, run `agt validate` to verify the complete app or package.

Run `agt validate --help` for the options that select workspaces, projects, schemes, destinations, Xcode tests, and package directories.

## Development

```shell
agt validate
```

Or directly with SwiftPM:

```shell
swift build
swift test
```
