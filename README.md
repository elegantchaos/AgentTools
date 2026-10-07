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

Run `agt refresh`, `agt rules` and `agt skills` from the root of the Agents repository, or set `AGENTS_REPO_ROOT` to use a different checkout. Run `agt format` and `agt validate` from the root of the Swift repository being checked. `agt sandbox configure` and `agt calendar` run anywhere.

### Refresh

Bring this machine's Claude Code and Codex up to date with the Agents repository:

```shell
agt refresh
```

It warns about plugin copies of `ensure-agt.sh` that differ from the `baseline` plugin's, runs `agt skills sync --all`, `agt skills link` and `agt sandbox configure`, then installs or refreshes every plugin in the repository's marketplace files (`.claude-plugin/marketplace.json` for Claude Code and `.agents/plugins/marketplace.json` for Codex). Each runtime's command is found on `PATH`, or else in its usual install locations, including the copies bundled with the Claude and ChatGPT apps; a runtime that is not installed is skipped. Every step is safe to repeat. It does not update `agt` itself.

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

### Calendar

List today's events, or those for up to 14 days from today:

```shell
agt calendar events
agt calendar events --days 7
```

List incomplete reminders due within the same range, or overdue by up to seven days:

```shell
agt calendar reminders --days 3
```

Each item is one line: its date and time, its title, an event's location, and the calendar or list it is in. Multi-day all-day events show their final included date, so an ongoing event's span is visible. Text is reduced to a single line of at most 80 characters, because calendar text can come from anyone who sends an invitation. Notes, attendees, URLs and attachments are never read.

macOS grants calendar and reminder access to the process responsible for the program asking, normally the terminal or app that started it. So that the permission belongs to `agt` alone, `agt calendar` runs a second `agt` as its own responsible process, using a private macOS function, and that process reads the calendar. Whenever `agt` is its own responsible process it accepts only `agt calendar` commands, so nothing else it could run, and nothing those would start, inherits the permission.

Grant access once with:

```shell
agt calendar authorize
```

It shows macOS's prompt, naming the `agt` executable, for calendars and for reminders. The permission is tied to the exact `agt` binary, so authorize again after each update. `events` and `reminders` never prompt; without access they say to run `authorize`.

To include only some calendars or reminder lists, name them in `~/.agt/config.json`:

```json
{
  "calendar": {
    "calendars": ["Home", "Work"],
    "reminderLists": ["Reminders"]
  }
}
```

This filters out calendars you do not want reported, such as subscriptions. It is not a security boundary, since anything running as you can edit the file.

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

#### Full validation in the background

Full validation can take minutes, so it can run in the background while work continues:

```shell
agt validate --fast --background
agt validate --wait
```

`--background` starts full validation as a detached process and returns immediately; with `--fast`, it starts once the fast phase passes. `agt validate --status` reports the latest result, and `agt validate --wait` waits for a running validation to finish, then fails unless full validation passed for the current working tree. Output goes to `.build/agt/background/output.log`.

Each result records a fingerprint of the working tree, including untracked files, so a result is only trusted for the tree it checked. If the tree changes while validation runs, the result is marked stale. Starting background validation when it has already passed for the current tree does nothing.

Only one validation runs at a time, since they share build directories. Any new run, background or foreground, replaces the marker that a running background validation checks, and that validation stops itself at its next check, interrupting its current command. If it has not stopped within 30 seconds, it is killed.

#### What full validation covers

Full validation builds the product first, then tests it:

1. Every product scheme is built for every platform the product supports, macOS first, to catch compiler errors the fast check missed.
2. Then, platform by platform, it runs the tests of the product schemes whose test action includes tests, and the tests of the Swift packages that are part of the product and that those schemes do not already run.

The product is the Xcode workspace in the repository root, or else its Xcode project, or else its root `Package.swift`. The default product scheme is the one named after the repository, or the root package's scheme when there is no workspace or project. For an Xcode product, the platforms are those its schemes support; a Swift package product is built for macOS unless configured otherwise.

A local Swift package is part of the product when the product uses it: the workspace lists it, a project references it as a local package, it is the root package of a Swift package product, or it is a local path dependency of one of those. Other packages in the repository, such as examples and test fixtures, are not tested. Packages in git submodules are usually standalone products with their own tests, so by default their tests run only when the submodule differs from the commit the repository records, for example after editing it in place.

The fastest arrangement is for the product scheme to run every package's tests itself, so the whole product builds once per platform and Xcode runs all the tests together. When a product scheme has a test plan named `Full Validation`, validation runs that plan (`-testPlan "Full Validation"`), leaving the scheme's default plan free for quicker runs in Xcode; otherwise it runs the scheme's default tests. A test plan or scheme lists a package's tests by its `container:` path, and Xcode runs them only when the package is a member of the workspace, skipping them without any message otherwise.

Validation checks this coverage. A package whose test targets a product scheme runs, from a workspace member, needs no test step of its own, and `--plan` says it is tested by that scheme. For any other package of the product with tests, validation prints a warning naming the test targets the schemes miss, or saying the package is not a workspace member, and then tests the package separately, unless the submodule policy leaves it untested.

A package tested separately runs through a shared scheme for it in the workspace or project when that scheme lists its tests. Otherwise it runs with SwiftPM on macOS, and on other platforms with `xcodebuild` in the package's own directory, using the scheme Xcode creates for the package; a package with no such scheme is reported as skipped on that platform. Xcode's generated package schemes have a test action only when the package is opened on its own, never inside a workspace, so they are not used through the workspace.

Tests on iOS, tvOS, watchOS, and visionOS run on a simulator: the platform's test device for its newest installed runtime, named `Test <device> <version>`, such as `Test iPhone 27.2`. The devices are `iPhone` (or `iPad`), `TV`, `Watch`, and `Vision`. When the newest runtime has no test device, validation creates one and reports it, choosing the device the App Store asks screenshots for: the newest iPhone Pro Max, 13-inch iPad Pro, Apple TV 4K at 4K, or Apple Watch Ultra. If that fails, it reports why and uses a test device for an older runtime, or else the first simulator with the newest OS. A platform without an available simulator is reported as skipped.

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
- `excludePackages`: packages whose tests never run separately, by package name. The coverage check does not report them.

See what validation would do without running anything: every local package, with how its tests run or why they do not, then each step with its exact command:

```shell
agt validate --plan
```

Each run finishes with a PASS/FAIL/SKIP summary, and STOP for a step interrupted because a newer validation replaced this one. A step is marked `[warnings]` when a compiler or build tool reported a warning. Terminal output is shaped with `--output filtered|quiet|raw` (`filtered` is the default).

Validation writes its build products and per-step logs under `.build/agt/` in the repository, so it never shares a build directory with an IDE or with your own builds. Downloads use SwiftPM's and Xcode's standard caches, so they are shared.

Discovery, which finds packages, workspaces, schemes, and the platforms each scheme supports, can take tens of seconds on a large project. Its results are cached in `.build/agt/discovery.json` and reused until a package manifest, `Package.resolved`, Xcode project, workspace, or scheme changes, or `agt` or the selected Xcode changes. `agt validate --clean` discards the cache along with the build products.

Run `agt format --help` or `agt validate --help` for all options.

#### In an agent sandbox

When validation runs inside another sandbox, such as a coding agent's, it detects this and turns off the sandboxes that SwiftPM and Xcode would otherwise start for package manifests, plugins, macros, and build scripts, since those cannot start inside another sandbox.

The agent's sandbox must still allow writes to two locations outside the repository. `agt sandbox configure` adds both to Claude Code's and Codex's user configuration, keeping every other setting, and backs up a file with a `.bak` suffix before changing it:

```shell
agt sandbox configure
```

The two locations are:

- `~/Library/Caches/org.swift.swiftpm`, which Xcode always uses for package manifests, and which validation shares for package downloads.
- The per-user clang module cache, which Xcode uses when a package manifest imports macro support. Find its path with:

  ```shell
  echo "$(getconf DARWIN_USER_CACHE_DIR)clang/ModuleCache"
  ```

To configure them by hand for Claude Code, add both to `sandbox.filesystem.allowWrite` in `~/.claude/settings.json`:

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
