# AgentTools Roadmap

Roadmap for Sam's curation. Last reconciled: **9 November 2026**.

This overview tracks current priorities, follow-up work and return points for `agt`. Shared guidance that uses `agt` is tracked in the [Agents roadmap](https://github.com/elegantchaos/Agents/blob/main/ROADMAP.md).

## You Are Here

**Current focus: release the paired-worktree validation modes.**

PR #14 adds targeted, change-scoped and full validation in paired worktrees. Return point: merge, release, then merge elegantchaos/Agents#45 so the `swift:validation` skill uses the new flags, and return to Bookish.

## Current And Parked Work

| Slice | Finish condition | State |
| --- | --- | --- |
| Paired-worktree validation | PR #14 merged and released; Agents #45 merged and the Swift plugin refreshed. | In review. |
| Reuse recorded validation passes | Committed validation skips work whose inputs already passed, as described below, with a decision record. | Planned follow-up. |
| Retire paired worktrees | A paired validation worktree is removed or pruned when its development worktree goes away. | Open question in the [Validation Design](Extras/Documentation/Validation%20Design.md). |
| Sandbox setup for paired worktrees | `agt worktree create` and `agt prepare` create and prepare the paired worktree, so the first committed validation in a sandbox does not need Git metadata writes. | Candidate, from the PR #14 review. |

## Follow-Up: Reuse Recorded Validation Passes

Committed validation re-runs work that has already passed for identical inputs. A branch that keeps an `integration/<app>` submodule branch tests that submodule on every full run until the branch merges, and re-validating a commit that already passed repeats the whole run.

**Proposal.** Record each passing step with a key covering everything that can affect its result, and skip a step whose key already has a recorded pass:

| Step | Key |
| --- | --- |
| Whole run | Superproject commit, scope, effective configuration and toolchain. |
| Submodule package tests | Submodule commit, the commits of its local path dependencies, toolchain and platform. |

A submodule package's own tests are then skipped when its commit has a recorded pass or is already on the submodule's default branch, and otherwise run once and are recorded. Branch names are not used: an integration branch holds work that has not been through the submodule's own validation.

**Rules.**

- Record only passes, per step, so a failure elsewhere keeps a good step's result. Failures always rerun.
- Report a reused step as reused, with the commit and date it ran at, never as a fresh pass.
- `--no-reuse` forces a rerun for flaky or environment-dependent tests.
- Targeted validation never reuses results, because it checks live edits.
- Keep records per paired worktree, alongside the background status, and preserve them through `--clean`.
- `testSubmodules` gains `untested`, the new default; `changed` is removed.

**Deferred.** Reuse for local packages inside the repository, keyed by the tree hash of the package directory and its local dependencies. Workspace members resolve through the workspace's `Package.resolved`, and resources or scheme settings can sit outside the package directory, so a missed input would reuse a result that no longer applies. Consider it only if the first two keys do not save enough time.

**Records.** A new decision ("Validation reuses recorded passes for identical inputs"), a revision of decision 0008 so recorded evidence decides submodule testing, and updates to the Validation Design and the `swift:validation` skill.
