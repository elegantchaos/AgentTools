# Worktree Setup And Dependency Preparation

Added `agt worktree create <name>` and `agt prepare` after fresh Bookish worktrees exposed dependency materialisation failures in Claude's sandbox. The worktree command owns semantic naming, `.worktrees/<name>` under the main checkout, `feature/<name>`, starting-revision validation, collision checks and recursive submodule initialisation. It invokes preparation with the destination checkout's configuration and retains the worktree with resume instructions when setup fails. Preparation is separately usable after dependency changes or cleaning and never escalates itself.

Preparation shares validation's discovery, package/container selection and scratch paths. It resolves packages for targeted SwiftPM validation even when a product scheme covers their tests, plus the Xcode product and independent package containers full validation uses. It does not build targets, run tests or boot simulators. `--plan` lists the resolution steps after discovery, which may itself resolve Xcode packages. Preparation and validation use an advisory checkout lock outside the directory removed by `validate --clean`; preparation stops a background validation before resolving and rejects competing foreground ownership.

Retained per-package scratch directories. The original rationale is isolation from IDE locks and build-flag churn ([24 September](2026-09-24.md#step-2-build-hygiene)); each package also owns independent resolution state. SwiftPM's shared repository cache and its existing `--shared --no-checkout` clones do not eliminate local `.git/config` or hook writes. Empty templates remove only sample-hook copying. No sandbox-policy exceptions, checkout copying, symlink sharing or metadata relocation were added.

Dependency clone/checkout permission errors now print preparation advice naming the denied metadata path. The matcher distinguishes `.git/config`, `.git/config.lock` and `.git/hooks` from unrelated paths and network failures, and works in raw, quiet and filtered output. Discovery preserves this failure class instead of silently skipping a package. Xcode scheme discovery uses validation's own dependency checkout directory.

Bookish integration found two defects before completion: constructing unparsed ArgumentParser defaults trapped after Git setup, and semantic worktree names changed the default Xcode scheme. Defaults now come from parsed options; repository-name discovery follows Git's `gitdir` and `commondir` metadata. Tests cover absolute and relative pointers. The retained Bookish checkout resumed successfully after these fixes.

## Validation

- Observed the expected red tests for missing commands and missing dependency-preparation advice, then green. Observed red/green for the metadata-path boundary and linked-worktree scheme discovery. All Swift tests ran through `agt validate`.
- AgentTools targeted suite: 207 tests in 30 suites passed. Full macOS validation and strict repository lint passed; no lint findings remain.
- Bookish at `bd870f1d`: worktree creation and recursive submodule initialisation passed. Preparation completed 21 SwiftPM and two Xcode resolution steps, including the standalone BookishCatalogue container. Subsequent targeted BookishDatastore validation passed 130 tests and BookishImporter passed 102 tests. Neither build/test log contained dependency fetch, clone or working-copy creation output.
- A complete create/initialise/prepare run against the Agents repository passed. Repeating its name from a linked worktree correctly rejected the existing main-checkout destination.
- This Codex sandbox allowed nested dependency Git metadata writes. An additional restricted `sandbox-exec` reproduction was blocked with `sandbox_apply: Operation not permitted`; no outside-sandbox fallback was attempted. Actual Claude runtime acceptance remains outstanding, distinct from unit-tested diagnostics and the passing Codex integration.
- Codex's existing-worktree attachment tool rejected the CLI-created checkout because it is not managed. Subsequent commands use explicit absolute working directories; shared guidance documents this integration boundary.

The existing validation and tool-ownership decisions apply; no decision records were changed. The stale `codex-git` selection in this repository's AGENTS.md now names its supported successor, `baseline:git`.

## Delivery Boundary

The companion Agents change updates COMMON.md, baseline Git setup, Swift validation preflight/failure handling, plugin versions and the shared roadmap. Publish the AgentTools release before adopting that guidance in installed plugins. No release, merge, runtime-plugin refresh, full Bookish product validation, simulator execution or interactive app checks are included in this implementation task.
