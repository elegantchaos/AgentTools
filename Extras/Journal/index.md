# Development Journal

- [2026-11-24 Preferences for the Local Claude Profile](2026-11-24-claude-profile-preferences.md) — Restored the saved local model and let Claude use the profile's effort and token settings. Verified with loopback and terminal probes and targeted validation.

- [2026-11-20 Persistent Local Claude Profile](2026-11-20-claude-local-profile.md) — `agt claude` keeps onboarding and workspace trust in its own profile. Verified with two launches in a scratch home.

- [2026-11-20 Drop the ensure-agt.sh Drift Check](2026-11-20-drop-helper-copies.md) — `agt refresh` no longer checks copies of `ensure-agt.sh`, which the Agents repository has deleted; `agt` Is the Agents Repository's Only Dependency (0006) revised to drop the bootstrap exception.

- [2026-11-20 Local Claude Code Launcher](2026-11-20-claude-ollama-launcher.md) — Added `agt claude` with a temporary configuration and a picker populated from the local Ollama catalog. Targeted validation and a terminal picker smoke test passed.

- [2026-11-18 AgentTools 4.2.0](2026-11-18-release-4.2.0.md) — Release of PR #18's Claude Code sandbox exclusions for `agt` and `rt`; full local validation passed, and a timed-out CI job was re-run before merging.

- [2026-11-18 Run agt Outside Claude Code's Sandbox](2026-11-18-claude-excluded-commands.md) — A sandboxed probe showed full validation cannot run inside an agent sandbox, as simulators are unreachable there; `agt sandbox configure` now lists `agt` and `rt` in Claude Code's `sandbox.excludedCommands`; targeted validation passed all 323 tests.

- [2026-11-17 AgentTools 4.1.0](2026-11-17-release-4.1.0.md) — Release preparation for PR #17's Markdown link checking and historical repair; full validation passed all 321 tests, with merge, publication and local Mint installation authorised.

- [2026-11-17 PR #17 Review Fixes](2026-11-17-pr17-review-fixes.md) — Addressed all six findings with regression coverage, including multiline Markdown, target additions and merge history, escaped destinations and nested submodules; targeted and full macOS validation passed all 321 tests on `068d543`, and the rebuilt command resolves the repository's four known historical links in a dry run.

- [2026-11-16 PR #17 Review](2026-11-16-pr17-review.md) — Six reproduced defects in history selection, Markdown parsing and submodule indexing; addressed in the 17 November follow-up, with validation recorded there.

- [2026-11-16 Markdown Link Check And History Repair](2026-11-16-markdown-links.md) — `agt links` reports broken relative Markdown links, and `--fix-history` turns broken links in journal entries and reviews into permalinks at the commit that introduced them; replayed on Bookish, it matched the prototype used for PR #140.

- [2026-11-10 Simulator Runtimes Follow The Selected Xcode](2026-11-10-simulator-sdk-runtime.md) — Test simulators no longer use a runtime newer than the selected Xcode's simulator SDK.

- [2026-11-09 AgentTools 4.0.0](2026-11-09-release-4.0.0.md) — Major release of the paired-worktree validation modes from PR #14 and the lock release fix from PR #13; bare `agt validate` is now change-scoped and `--fast` is gone.

- [2026-11-09 Validation Review Fixes](2026-11-09-validation-review-fixes.md) — Empty change scopes no longer count as passes, lock waits are reported, `/private` checkouts work, submodules are tested when the branch moved them and must be pushed, and Swift 6.3 is back in CI.

- [2026-11-06 Validation Worktrees](2026-11-06-validation-worktrees.md) — Proposed paired validation worktrees, commit-based fast scope, and audit of existing decisions.

- [2026-11-05 Lock Release Race](2026-11-05-lock-release-race.md) — Reproduced checkout-lock contention after owner deallocation during parallel process launches; explicit unlocking passes 800 stress iterations and all 275 targeted tests after rebasing onto current main.

- [2026-11-04 AgentTools 3.15.0](2026-11-04-release-3.15.0.md) — Release of `agt vm` and `press` focusing text fields from PR #12; the guest's `agt` needs the new build and fresh grants for focusing.

- [2026-11-04 Running Apps in Throwaway tart Clones](2026-11-04-vm-commands.md) — `agt vm start|launch|ui|stop|list`: clone the base image, share build products read-only, wait for the console session, pass `agt ui` through ssh with screenshots copied to the host; only `agt-` clones are ever removed, never the base image ([0011](../Decisions/0011-agt-vm-only-touches-its-own-clones.md)).

- [2026-11-04 Driving a macOS GUI over ssh](2026-11-04-ui-driving.md) — `agt ui` commands; commands needing permissions relaunch as their own responsible process so grants belong to `agt` (keyed on its code hash), after finding ssh grants land on `sshd-keygen-wrapper`; ssh in as the console user; fixed inherited modifier flags and stale quit state.

- [2026-11-04 PR #10 Review](2026-11-04-pr10-review.md) — Copilot's findings: ignore checks for default packages, override manifests in the discovery fingerprint, and NUL-separated `check-ignore`; the submodule claim did not reproduce.

- [2026-11-03](2026-11-03.md) — `agt prepare` resolves only product packages not excluded by name, matching validation; package discovery skips Git-ignored paths even when some files are tracked, so Bookish's `Extras/Legacy` packages drop out of both commands.

- [2026-10-30 AgentTools 3.13.0](2026-10-30-release-3.13.0.md) — Release preparation for query permission requests, `--no-prompt`, request timeouts and link replacement; Agents #40 remains a separate merge.

- [2026-10-30 Calendar Access Diagnostics](2026-10-30-calendar-access-diagnostics.md) — Automatic query permission requests with `--no-prompt`, removal of authorize, revised Decision 0007, and state-specific sandbox/service diagnostics.

- [2026-10-29 AgentTools 3.12.0](2026-10-29-release-3.12.0.md) — Release preparation, validated code revision and the authorised merge/publish/Mint sequence; shared guidance rollout remains separate.

- [2026-10-29 PR #8 Review Fixes](2026-10-29-pr8-review-fixes.md) — Lock placement and waiting plans, creator safety/recovery tests, shared settings, ignore checks and cross-plan preparation coverage; decision proposal awaits separate confirmation.

- [2026-10-29 PR #8 Review Assessment](2026-10-29-pr8-review-assessment.md) — Confirms Claude's main findings, refines plan-contention behavior and decision-record scope, and corrects the proposed ignore query.

- [2026-10-29 Worktree Preparation](2026-10-29-worktree-preparation.md) — Worktree setup and dependency preparation commands, metadata-denial diagnostics, linked-worktree scheme discovery, and Bookish integration evidence.

- [2026-10-27 PR #6 Review](2026-10-27-pr6-review.md) — Ready; optional sandbox status-message correction. Strict lint, targeted and full validation pass; isolated CLI configuration probe passes.

- [2026-10-27](2026-10-27.md) — `agt sandbox configure` also allows writes to the Agents checkout, so agents in other projects can update shared guidance, and to the per-user temporary directory, where Foundation stages the atomic writes Swift Build needs; `.worktrees/` ignored.

- [2026-10-08](2026-10-08.md) — Defaulted maintenance commands to the shared Agents checkout in the user's home directory. Diagnosed terminal job-control stops in refresh plugin commands and fixed their process-group inheritance. Reviewed PR 3; found false coverage for filtered test plans and incomplete shared-scheme fallback routing. Focused tests and full AgentTools validation passed.

- [2026-07-23](2026-07-23.md) — Initial standalone package migration.
- [2026-09-23](2026-09-23.md) — Moved shared rules to `runtimes/codex`; linked skills into Codex and Claude Code runtime directories.
- [2026-09-24](2026-09-24.md) — Moved `validate` from ReleaseTools into `agt`; planned IDE-aware validation for 2.2; started the decision log.
- [2026-09-25](2026-09-25.md) — Full validation in the background, with cooperative superseding; package schemes only for root packages; test simulators; commands moved into the `AgentToolsCore` library to fix release-mode tests on CI ([0004](../Decisions/0004-executable-is-only-an-entry-point.md)); drafted `agt script` for managing agents' helper scripts ([0005](../Decisions/0005-agt-manages-agent-scripts.md), draft).
- [2026-09-26](2026-09-26.md) — Fixed a launch crash on macOS 26 in Xcode 27 builds (`swift_initBorrow` from swift-collections 1.7.0) with a swift-collections 1.7.1 floor; CI runs an Xcode 27 build on macOS 26.
- [2026-09-28](2026-09-28.md) — Profiled Bookish validation and rejected a shared Xcode DerivedData experiment; investigated package aggregation and SwiftPM 6.4.
- [2026-09-29](2026-09-29.md) — `agt sandbox configure` and `agt refresh` replace the Agents repository's last maintenance scripts, making `agt` its only dependency ([0006](../Decisions/0006-agt-is-the-agents-repositorys-only-dependency.md)); Codex config edited in place, including multi-line arrays and dotted keys; runtime commands found outside `PATH`.
- [2026-09-30](2026-09-30.md) — Open bug found on Bookish: a workspace member that a project or another package also references has no test action, so full validation routes its tests through a scheme `xcodebuild` refuses; Bookish excludes the packages for now, with ideas for the fix.
- [2026-10-07](2026-10-07.md) — Calendar access spikes: an app bundle launched with `open`, then a single `agt` relaunching itself with the private responsibility-disclaim spawn attribute, each received its own calendar permission, pinned to its code hash; the same binary run directly from the agent gets nothing. Added `agt calendar` ([0007](../Decisions/0007-agt-holds-its-own-privacy-permissions.md)). Found the cause of the package test-action bug; full validation now runs package tests through the product scheme or its `Full Validation` test plan, with a coverage check ([0008](../Decisions/0008-full-validation-runs-package-tests-through-the-product-scheme.md)).
