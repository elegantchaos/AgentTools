# AgentTools

[![Tests](https://github.com/elegantchaos/AgentTools/actions/workflows/Tests.yml/badge.svg)](https://github.com/elegantchaos/AgentTools/actions/workflows/Tests.yml)
[![Latest release](https://img.shields.io/github/v/release/elegantchaos/AgentTools)](https://github.com/elegantchaos/AgentTools/releases)
[![Swift 6.2](https://img.shields.io/badge/swift-6.2-F05138.svg)](https://swift.org)
![Platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)

Command-line tools for agent-driven development: maintenance for the shared [Agents](https://github.com/elegantchaos/Agents) repository, and standard formatting and validation for Swift repositories.

## Installation

Install the latest release with [Mint](https://github.com/yonaskolb/Mint):

```shell
mint install elegantchaos/AgentTools
```

## Usage

```shell
agt <command>
```

Run `agt rules` and `agt skills` from the root of the Agents repository, or set `AGENTS_REPO_ROOT` to use a different checkout. Run `agt format` and `agt validate` from the root of the Swift repository being checked.

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

### Format and Validate

`agt format` and `agt validate` are the standard way to check a Swift repository after a change. They run after every change, so speed comes first: they must add as little friction as possible. Within that constraint, they have two goals.

**Consistent process.** Routine housekeeping, such as formatting and linting, happens the same way every time, so no change skips it and every project follows the same steps.

**Fast, complete verification.** Validation confirms, as quickly as possible, that a change has broken nothing:

- *Fast feedback first.* Build errors should surface as early as possible, so validation starts at the smallest useful scope: the affected module, built for the host platform.
- *Complete coverage after.* A change can also break another platform, an integration between modules, or a test. Full validation builds the whole product for every platform it supports and runs all of its tests.

Validation never modifies the project, so formatting is a separate command. After a change, run both from the repository root:

```shell
agt format
agt validate
```

`agt format` formats every tracked and untracked Swift file in place with `swift format`, then lints them and reports any findings without failing. Swift files inside a `Resources` directory under `Tests` are treated as fixtures and skipped; other files can opt out with a `// swift-format-ignore-file` comment. `agt format --check` modifies nothing and fails on any finding.

Run the fast check for a module you have changed:

```shell
agt validate --target <name>
```

When the fast check passes, run full validation.

Each run finishes with a PASS/FAIL/SKIP summary. Terminal output is shaped with `--output filtered|quiet|raw` (`filtered` is the default).

Validation writes its build products and per-step logs under `.build/agt/` in the repository, so it never shares a build directory with an IDE or with your own builds. Downloads use SwiftPM's and Xcode's standard caches, so they are shared.

Run `agt format --help` or `agt validate --help` for all options.

#### In an agent sandbox

When validation runs inside another sandbox, such as a coding agent's, it detects this and turns off the sandboxes that SwiftPM and Xcode would otherwise start for package manifests, plugins, macros, and build scripts, since those cannot start inside another sandbox.

The agent's sandbox must still allow writes to two locations outside the repository:

- `~/Library/Caches/org.swift.swiftpm`, which Xcode always uses for package manifests, and which validation shares for package downloads.
- The per-user clang module cache, which Xcode uses when a package manifest imports macro support. Find its path with:

  ```shell
  echo "$(getconf DARWIN_USER_CACHE_DIR)clang/ModuleCache"
  ```

For Claude Code, add both to `sandbox.filesystem.allowWrite` in `~/.claude/settings.json`:

```json
{
  "sandbox": {
    "filesystem": {
      "allowWrite": ["~/Library/Caches/org.swift.swiftpm", "/var/folders/.../C/clang/ModuleCache"]
    }
  }
}
```

For Codex, add both to `sandbox_workspace_write.writable_roots` in `~/.codex/config.toml`, using absolute paths:

```toml
sandbox_workspace_write.writable_roots = ["/Users/you/Library/Caches/org.swift.swiftpm", "/var/folders/.../C/clang/ModuleCache"]
```

`Extras/Scripts/sandbox-check.sh [repository]` runs validation in a sandbox that allows only these locations, the repository, and temporary directories.

## Development

```shell
agt format
agt validate
```

Or directly with SwiftPM:

```shell
swift build
swift test
```
