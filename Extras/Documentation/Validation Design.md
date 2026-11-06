# Validation Design

**Status:** Proposed

Validation gives fast feedback during editing and records broader evidence for a committed change. Targeted validation builds the live development checkout. Change-scoped and full validation build a pinned commit in a persistent validation worktree paired with the development checkout that requested it. The pairing lets separate tasks validate concurrently and lets each task reuse its own build outputs.

## Terminology

- **Development worktree** means the checkout where a person or agent edits the project. This includes the primary checkout.
- **Validation worktree** means the AgentTools-owned, detached checkout dedicated to change-scoped and full validation for one development worktree.
- **Baseline** means the merge base between the requested commit and local `main` or, if absent, `origin/main`, pinned when the request is accepted.

## Request and scope

Formatting and linting belong to `agt format`. Validation builds and tests the inputs it is given and leaves user-owned source and configuration alone.

| Mode | Inputs | Scope |
| --- | --- | --- |
| Targeted (`--target`) | Live development worktree, including uncommitted edits | Named Swift package target and its dependent tests, or the named Xcode scheme for macOS when no package defines the target |
| Change-scoped (default) | Committed tree in the paired validation worktree | macOS build and tests selected from the change against the baseline |
| Full (`--full`) | Committed tree in the paired validation worktree | Product builds and eligible tests across configured platforms |

Callers that require full coverage select `--full` explicitly.

Change-scoped and full requests require a clean development worktree, including clean submodules. Staged, unstaged and untracked changes must be resolved before admission. Ignored machine settings are handled separately from source inputs. AgentTools pins the requested commit before execution or handoff to a background worker. Later edits and branch switches in the development worktree have no effect on the inputs.

Validation selects the configured workspace, project or package, schemes, platforms and package policy. Command-line options override machine-local settings, which override committed project settings. The effective machine-local settings come from the requesting development worktree. Project-relative paths for committed validation resolve against the validation snapshot. An override that would read live project sources outside that snapshot must be rejected or resolved inside it.

## Worktree ownership and reuse

AgentTools creates the paired worktree on demand and reuses it for later change-scoped and full runs from the same development worktree, including after that worktree switches branches. It recreates a missing owned checkout and refuses to reset or remove an unrelated checkout at the expected location. No user branch moves when validation switches revisions.

An exclusive lock covers creation, checkout changes, submodule synchronisation, cleaning, discovery and execution. A replacement run can reset the tree only after the previous run and its build processes release ownership. Change-scoped and full share the lock and background state for their pair. Other pairs have separate locks, build outputs, logs and background state. Targeted validation keeps its existing checkout-local build paths and lock, and has no ownership of the paired worktree.

Before building, the paired tree and its submodules match the pinned revision. Leftover generated files that can affect inputs are removed. Known build outputs, dependency state and discovery data can survive between runs so long as their validity checks hold. Explicit cleaning discards reusable build and discovery outputs for the selected execution checkout while preserving the lock and run records. Dependency download caches may be shared. Build outputs must be isolated from other pairs and ordinary development builds, whether provided by tool defaults or explicit paths.

AgentTools creates and updates its validation worktree and prepares dependencies within the caller's permissions. A permission or dependency failure is reported as a setup failure. Preparation may evaluate manifests and resolve dependencies. It supplies no build or test evidence.

## Planning and execution

Discovery identifies the product, local package targets and dependencies, schemes, test plans, platforms and test destinations. Product packages include the root package, workspace members, referenced local packages and their local dependencies. Discovery can be reused while the inputs that affect it match, including manifests, dependency resolutions, project and scheme definitions, options and toolchain. A plan reports the selected scope, coverage and steps without running target builds or tests. Discovery itself may evaluate manifests or resolve dependencies, so it follows the same checkout ownership rules.

### Change-scoped validation

Change-scoped validation maps paths changed between the pinned baseline and the requested commit. A changed package source selects its target and dependent tests. A changed test selects its test target. Manifest, resolution or submodule changes widen selection to the affected package. An app source, resource or project-level build input outside package scope selects the macOS product scheme. Deletions and moves must contribute their old paths to scope selection. Ambiguous build inputs widen scope. Documentation and other known non-build inputs are ignored. A diff with no relevant changes produces an empty plan. If the baseline cannot be determined, validation reports a planning failure.

### Full validation

Full validation selects its scope independently of the changed paths. It builds the product schemes for their configured platforms, with macOS first, then runs eligible product and package tests. Xcode products use Xcode build and test actions. Swift package products use SwiftPM on macOS and Xcode for other platforms.

A product scheme runs its `Full Validation` test plan when present and otherwise runs its default tests. A local package is covered by a product scheme when it is a workspace member and the scheme or test plan runs all its test targets in full. Eligible packages with incomplete coverage are reported and tested separately. A separate package test uses a shared workspace scheme only if it provides complete coverage. Otherwise it uses the package's own context. Package exclusions and submodule policy govern separate package testing. Full validation includes eligible submodule packages by default and with `testSubmodules: changed`. Explicit `never` omits their separate test steps. Tests already selected by a product scheme still run through that scheme. Non-host tests use an eligible simulator, with unavailable destinations reported as skips.

## Background runs and evidence

Foreground and background execution use the same scope selection. A background request runs the change-scoped plan by default and the full plan when it explicitly requests full scope. Status and wait address the requesting development worktree's background run. A newer change-scoped or full request may supersede a background run for that pair under the ownership rules above. Replacement never crosses pair boundaries.

Results identify the checked commit, scope and outcome. The step summary and logs distinguish passes, failures, skips, warnings and interruptions. A completed result remains evidence for its checked inputs when the requesting worktree changes. Status distinguishes that result from a pass for the current clean commit. Waiting succeeds only when the requested background scope passes and the result applies to the requesting checkout. A change-scoped pass supplies evidence for that scope. An existing pass may be reused for equivalent validation inputs. A cancelled or superseded run cannot publish a pass for its replacement.

## Open questions

- Do Xcode's default DerivedData settings guarantee isolation across validation worktrees? Can concurrent tests safely share a simulator, or does simulator execution need separate coordination?
- How are paired worktrees retired after a development worktree is removed, and what setup or recovery path works when an agent sandbox protects linked-worktree metadata?

## Related decisions

- [0002 · AgentTools owns Swift validation](../Decisions/0002-agt-owns-swift-validation.md) establishes the command and ownership.
- [0003 · Validation does not modify the project](../Decisions/0003-validation-does-not-modify-the-project.md) protects project files and separates build outputs from development.
- [0008 · Full validation runs package tests through the product scheme](../Decisions/0008-full-validation-runs-package-tests-through-the-product-scheme.md) governs test coverage.
- [0010 · AgentTools owns worktree setup and dependency preparation](../Decisions/0010-agt-owns-worktree-setup-and-dependency-preparation.md) sets the setup and permissions boundary.
