# Validation Worktrees

Drafted [Validation Design](../Documentation/Validation%20Design.md). The proposal pairs each development worktree with one persistent validation worktree for fast and full runs, pins the tested commit, and keeps targeted checks in the live checkout. The pairing preserves incremental builds within a task and isolates separate tasks. Fast scope comes from the diff against the merge base with main.

The decision audit found that [0003](../Decisions/0003-validation-does-not-modify-the-project.md) needs to distinguish user-owned files from tracked files in the managed worktree. [0010](../Decisions/0010-agt-owns-worktree-setup-and-dependency-preparation.md) may need to cover managed checkout setup. [0002](../Decisions/0002-agt-owns-swift-validation.md) and [0008](../Decisions/0008-full-validation-runs-package-tests-through-the-product-scheme.md) still apply. The design leaves the meaning of changed submodules, sandbox setup, and shared simulator coordination open.

The proposed CLI makes change-scoped validation the default and exposes complete coverage as `--full`. Background execution uses the selected scope. Existing callers that require complete coverage need to request it explicitly.

The CLI proposal removes the former `--fast` flag, including its use as a migration alias.

Revised 0003 to protect the development worktree while permitting checkout updates in the managed validation worktree. Revised 0010 to assign AgentTools ownership of the paired validation worktree and preserve the existing permissions boundary.

Implemented the first version on `feature/validation-design`. Committed validation uses the paired checkout, while `--target` keeps the existing local runner. Background requests pin the resolved configuration, commit and, for change-scoped validation, the merge base. Baseline selection prefers local `main` and falls back to `origin/main`. Full validation includes eligible submodule packages by default, with explicit exclusions still applied. The implementation keeps explicit build paths in each pair and leaves simulator isolation and managed checkout retirement open.

The paired-worktree test covers clean admission, commit pinning, cache reuse, generated-file cleanup and separate checkouts. A SwiftPM fixture smoke test ran overlapping background validations in two development worktrees. The full run in the first pair reused its existing build directory. The smoke test also confirmed that full validation rejects dirty inputs and that a macOS-only SwiftPM plan can run without querying Xcode schemes.
