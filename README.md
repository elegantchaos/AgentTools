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

Show the installed version with `agt --version`.

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

`agt format` formats every tracked and untracked Swift file in place with `swift format`, then lints them and reports any findings without failing. Swift files inside a `Resources` directory under `Tests` are treated as fixtures and skipped; other files can opt out with a `// swift-format-ignore-file` comment, and whole files or directories with `format.exclude` in the project configuration. When linting finds anything, a summary line counts the findings, the files, and the most common rules; the full list is in the lint log. `agt format --check` modifies nothing and fails on any finding.

Check a change quickly with the fast phase, then run full validation:

```shell
agt validate --fast
agt validate
```

#### What the fast phase covers

The fast phase finds the smallest scope that covers the uncommitted changes, including untracked files, builds it for macOS, and runs the tests that depend on it:

- A changed file in a Swift package target builds that target with SwiftPM, and runs the package's test targets that depend on it. A changed test file runs its test target.
- A changed `Package.swift`, `Package.resolved`, or git submodule builds and tests its whole package.
- A build input outside every package target, such as an app source file, a resource, or an Xcode project file, builds the product scheme for macOS with `xcodebuild`.
- Anything else, such as documentation, is ignored. With no relevant changes, nothing runs.

`agt validate --target <name>` runs the fast phase for a named target instead of the changes, or builds the Xcode scheme of that name for macOS when no package defines the target.

`agt validate --fast --plan` shows where each changed file was assigned, and the steps.

#### What full validation covers

Full validation builds the product first, then tests it:

1. Every product scheme is built for every platform the product supports, macOS first, to catch compiler errors the fast check missed.
2. Then, platform by platform, it runs the tests of the product schemes whose test action includes tests, and the tests of the Swift packages that are part of the product.

The product is the Xcode workspace in the repository root, or else its Xcode project, or else its root `Package.swift`. The default product scheme is the one named after the repository, or the root package's scheme when there is no workspace or project. For an Xcode product, the platforms are those its schemes support; a Swift package product is built for macOS unless configured otherwise.

A local Swift package is part of the product when the product uses it: the workspace lists it, a project references it as a local package, it is the root package of a Swift package product, or it is a local path dependency of one of those. Other packages in the repository, such as examples and test fixtures, are not tested. Packages in git submodules are usually standalone products with their own tests, so by default their tests run only when the submodule differs from the commit the repository records, for example after editing it in place.

A package's tests run through the product's scheme for it when the workspace or project has one, sharing the product's build. Otherwise they run with SwiftPM on macOS, and on other platforms with `xcodebuild` in the package's own directory, using the scheme Xcode creates for the package; a package with no such scheme is reported as skipped on that platform.

Tests on iOS, tvOS, watchOS, and visionOS run on a simulator: for each platform, the first one with the newest OS that Xcode offers for the product scheme. A platform without an available simulator is reported as skipped.

Xcode products build and test with `xcodebuild`. A Swift package product builds and tests with SwiftPM on macOS, because Xcode runs a package's build plugins only for its all-targets scheme, and with `xcodebuild` on other platforms. Either way, validation trusts package plugins and macros without Xcode's interactive prompt, as `swift build` does.

#### Configuration

Projects configure formatting and validation in `.agt/config.json`, committed, with per-machine overrides in `.agt/local/config.json`, which should be ignored by git. Every key is optional, and command-line options override both files:

```json
{
  "format": {
    "exclude": ["Extras/Legacy"]
  },
  "validate": {
    "schemes": ["App"],
    "platforms": ["macOS", "iOS"],
    "testPlatforms": ["macOS"],
    "testSubmodules": "changed",
    "excludePackages": ["SlowTests"]
  }
}
```

- `format.exclude`: repository-relative files and directories that `agt format` leaves alone.
- `schemes` (`--schemes`): the schemes that build the product.
- `platforms` (`--platforms`): the platforms to build for: `macOS`, `iOS`, `tvOS`, `watchOS`, `visionOS`.
- `testPlatforms` (`--test-platforms`): the platforms to test on; defaults to the build platforms. `["macOS"]` avoids simulators.
- `testSubmodules` (`--test-submodules`): when to test packages in git submodules: `changed` (the default), `always`, or `never`.
- `excludePackages`: packages whose tests never run, by package name.

See what validation would do without running anything: every local package, with how its tests run or why they do not, then each step with its exact command:

```shell
agt validate --plan
```

Each run finishes with a PASS/FAIL/SKIP summary. Terminal output is shaped with `--output filtered|quiet|raw` (`filtered` is the default).

Validation writes its build products and per-step logs under `.build/agt/` in the repository, so it never shares a build directory with an IDE or with your own builds. Downloads use SwiftPM's and Xcode's standard caches, so they are shared.

Discovery, which finds packages, workspaces, schemes, and the platforms each scheme supports, can take tens of seconds on a large project. Its results are cached in `.build/agt/discovery.json` and reused until a package manifest, `Package.resolved`, Xcode project, workspace, or scheme changes, or `agt` or the selected Xcode changes. `agt validate --clean` discards the cache along with the build products.

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
