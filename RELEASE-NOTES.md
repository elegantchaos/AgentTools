# Release Notes

## 3.7.0

- Tests on simulators use the platform's test device for its newest installed runtime, named `Test <device> <version>`: `Test iPhone 27.2` (or `Test iPad 27.2`), `Test TV 27.0`, `Test Watch 27.0`, or `Test Vision …`. When the newest runtime has none, validation creates one, of the device the App Store asks screenshots for (the newest iPhone Pro Max, 13-inch iPad Pro, Apple TV 4K at 4K, or Apple Watch Ultra), and reports it. Previously it used the first simulator with the newest OS, which could be an iPad.
- A step interrupted because a newer validation replaced this one is recorded as STOP, not FAIL.
- Only warnings from compilers and build tools mark a step `[warnings]`: `warning:` at the start of a line, or after a location, a tool name, or a process tag. Swift Testing progress lines, which quote test arguments, and `xcodebuild`'s note about choosing among matching destinations, no longer do.

## 3.6.0

- Adds `agt validate --background`, which runs full validation as a detached process, after the fast phase with `--fast`, and returns. `agt validate --status` reports the latest result; `agt validate --wait` waits for it and fails unless full validation passed for the current working tree.
- Background results record a fingerprint of the working tree, including untracked files: a result is stale if the tree changed while it ran, and a pass for the current tree is reused instead of running again.
- A new validation stops any background validation that is still running, so the two never compete for build directories: the running one notices within a second, interrupts its current command, and exits.
- `agt validate --clean` keeps the background status.

## 3.5.0

- Adds `agt validate --fast`, which builds only what the uncommitted changes touched, for macOS, and runs the tests that depend on it: changed package targets build with SwiftPM and run the package's test targets that depend on them, changed manifests and submodules build and test their whole package, and other build inputs build the product scheme with `xcodebuild`. `--plan` shows where each changed file was assigned.
- `agt validate --target <name>` runs the fast phase for that target: it now runs every test target in the package that depends on it, instead of only one named `<name>Tests`.

## 3.4.3

- `agt format` prints a summary when linting finds anything: the number of findings and files, and the most common rules.
- Adds `format.exclude` to `.agt/config.json`: repository-relative files and directories that `agt format` leaves alone.

## 3.4.2

- `agt validate --plan` lists every local package, with how its tests run or why they do not: not part of the product, no tests, in an unchanged submodule, or excluded by configuration.
- Fixes workspaces that record a member project or package with an absolute path, such as `container:/path/to/App.xcodeproj`. The member was joined to the workspace's directory, so the project's local packages were not found and their tests did not run.

## 3.4.1

- Fixes local packages whose tests were skipped when Xcode listed no scheme for them. A package is part of the product when the workspace lists it, a project references it, it is the root package, or it is a local dependency of one of those; Xcode only lists a scheme for such a package when a scheme file exists. Packages without a scheme in the product's workspace or project now test with SwiftPM on macOS, and with `xcodebuild` in their own directory on other platforms.

## 3.4.0

- Full validation covers the whole product. It builds every product scheme for every supported platform, macOS first, then runs, platform by platform, the product schemes' tests and the tests of the local Swift packages that are part of the product, on simulators for iOS, tvOS, watchOS, and visionOS. Previously it took one of three routes (workspace, packages, or project), and ran no Xcode tests unless asked.
- Local packages in git submodules are tested only when the submodule has changed, by default.
- Adds project configuration in `.agt/config.json` and `.agt/local/config.json`: `schemes`, `platforms`, `testPlatforms`, `testSubmodules`, and `excludePackages`.
- Breaking: replaces `--destinations` and `--test-destinations` with `--platforms` and `--test-platforms`, which take platform names, and removes `--run-xcode-tests`: tests always run. Adds `--test-submodules`.
- `xcodebuild` runs trust package plugins and macros without Xcode's interactive prompt, as `swift build` does.

## 3.3.0

- `agt validate` caches discovery results, such as package descriptions and scheme platforms, in `.build/agt/discovery.json`, and reuses them until a package manifest, `Package.resolved`, Xcode project, workspace, or scheme changes. On a workspace with 16 packages, discovery drops from about 12 seconds to about 1.
- Adds `agt validate --plan`, which lists the steps validation would run, with their exact commands, without running them.

## 3.2.0

- Adds `agt --version`, which prints the release tag, or the full `git describe` output for a build that is not exactly a release.

## 3.1.0

- `agt validate` builds each Swift package into a private build directory under `.build/agt/`, so it no longer shares `.build` with the IDE or your own builds. Logs move to `.build/agt/logs` and Xcode products to `.build/agt/DerivedData`.
- SwiftPM builds use the default build system and no longer define `VALIDATING`; `#Preview` blocks build without it.
- Inside another sandbox, such as a coding agent's, `agt validate` turns off SwiftPM's and Xcode's own sandboxes, which cannot start there. The README lists the two locations an agent's sandbox must allow.
- A workspace or project that `xcodebuild` cannot read is now reported as a failure, instead of being skipped in favour of Swift packages.

## 3.0.0

- Adds `agt format`, which formats every tracked and untracked Swift file in the repository and lints them, reporting findings without failing. Swift files under `Tests/**/Resources` are skipped as fixtures. `agt format --check` modifies nothing and fails on any finding.
- Breaking: `agt validate` no longer formats or lints; it never modifies the project. Run `agt format` before it.

## 2.1.0

- Adds `agt validate`, the standard Swift validation flow previously provided by `rt validate` in ReleaseTools. Options, behaviour, output, and log locations are unchanged, except that Xcode products now go to `.build/agt-validate/DerivedData`.
- Help text and option errors now come from ArgumentParser, so their wording differs from `rt validate`.
- Removes the obsolete `skills/refresh-skill` repo-local skill source; the refresh skill now ships in the baseline plugin.

## 2.0.1

- `agt skills link` links skills into `~/.codex/skills` and `~/.claude/skills`, honouring `CODEX_HOME` and `CLAUDE_CONFIG_DIR`.
- `agt skills status` reports link status for each runtime directory.
- Linking refuses to replace any runtime path that is not a symlink.
- No longer uses `~/.agents/skills` or the `AGENTS_SKILLS_DIR` override.

## 2.0

- Reads shared rules from `runtimes/codex/rules` in the Agents repository.
- Detects the Agents repository root by `skills/`, `runtimes/`, and `COMMON.md`.
- Breaking: Agents checkouts that still use the top-level `codex/` layout are no longer recognised.

## 1.0

Initial standalone release.

- Adds the `agt` command-line tool.
- Synchronizes shared Codex rules into runtime copies.
- Synchronizes, links, reports, and audits shared skills.
- Supports explicit Agents checkout selection through `AGENTS_REPO_ROOT`.
