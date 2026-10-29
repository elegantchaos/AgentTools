# PR #8 Review Fixes

Addressed the code findings from [Claude's review](https://github.com/elegantchaos/AgentTools/pull/8#pullrequestreview-5700505022) and the [focused assessment](2026-10-29-pr8-review-assessment.md). The complete decision log was read earlier in this conversation; the output-ownership requirement in Decision 0003 was rechecked for the lock fix. No decision record was created or changed: the proposed narrow ownership record still requires separate confirmation under the records skill.

## Disposition

- **Lock ownership:** the advisory lock and diagnostic owner metadata now live at `.build/agt/lock`. Cleaning preserves the same inode alongside background state. Lock tests verify contention survives cleanup and ownership is released afterward.
- **Plan contention:** both plan modes wait for the active operation without superseding it. The diagnostic names the holder's PID and operation, and gives `agt validate --status`/`--wait` for background workers. The metadata is informational; the OS advisory lock remains authoritative. A deterministic wait test releases the initial owner from the wait notification, with no timing delay or background test task.
- **Worktree setup coverage:** network-free Git fixtures cover creation from a linked checkout, branch/destination collisions, symbolic-link rejection, direct bare and bare-main-linked rejection, and retention/recovery after preparation or submodule failures. Fixture commits use Sam Deane as both author and committer. The bare-main-linked test first demonstrated that the old implementation created an unsupported checkout inside the bare repository.
- **Configuration ownership:** selection and file settings resolve in `RepositorySelectionOptions.configuration`, shared by both commands. Preparation no longer constructs a validation command. Validation applies its own action flags afterward; tests verify these actions remain off for preparation and its CLI rejects them.
- **Ignored directories:** setup warns without changing ignore rules. The query checks `.worktrees/`, including the trailing slash, so it works before the directory exists. Both ignored/unignored cases have regression coverage.
- **Plan wording:** preparation plan output says it is planning and explains that discovery may still evaluate manifests and resolve Xcode packages.
- **Plan coverage:** a cross-plan test checks that full validation's Xcode container/scheme/DerivedData/working-directory contexts are covered by preparation across container-based and Swift-only macOS/simulator cases. It demonstrated a missing context for an explicit Xcode test scheme in a Swift-only macOS product; preparation now covers that route. Additional SwiftPM preparation remains intentional for targeted tests.
- **Existing discovery correction:** scheme listing resolves into validation's SourcePackages directory, not the developer's IDE checkout directory, as recorded in the original implementation journal.

## Validation And Remaining Work

Targeted `agt validate --target AgentToolsCore` passed 218 tests after observed red/green steps for lock placement, bare-main rejection and the missing preparation context. Formatting reported no lint findings. Final fast/full validation and CLI contention checks follow on the committed code revision and will be recorded below.

The shared validation workflow now distinguishes waiting plan commands from superseding execution. Actual Claude runtime acceptance remains outstanding. No permission fallback or sandbox-policy change was used.
