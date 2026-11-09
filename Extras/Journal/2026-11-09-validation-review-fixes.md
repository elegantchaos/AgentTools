# Validation Review Fixes

Addressed the PR #14 review findings Sam selected.

- **Empty change scope.** A change-scoped run with nothing to build or test now records a distinct `empty` state instead of `passed`. `--wait` fails for it with a message pointing at `--full`, and a foreground run says it produced no validation evidence. The wait rule moved into `BackgroundStatus.waitFailure(currentCommit:requireFull:)` so it can be tested directly.
- **Silent waits.** The admission lock now reports when it waits. It covers only supersession and launch: a foreground run takes the checkout lock before releasing admission, so a later `--background` request returns immediately and its worker queues behind the foreground run.
- **No baseline.** Change-scoped validation without a local `main` or `origin/main` now fails with a clear message instead of a raw `git merge-base` error.
- **Found while testing: `/private` paths.** `ValidationCheckout` refused every development checkout whose path began with `/private`, such as anything under `$TMPDIR` or `/tmp`. Foundation strips `/private` only from paths that exist, so the resolved checkout path and the resolved state directory never matched before the state directory existed. The checkout comparisons and `snapshotPath` now canonicalise through `ValidationPaths.canonical`. A new test failed on the old code with the same error as the smoke run.
- **Tests.** Added coverage for the wait rules, the empty state, `--target` with `--full` or `--background`, the `origin/main` fallback and its error, refusal of an unowned or branch-attached checkout, symlink redirection with a positive control, `snapshotPath` escapes, and a source under `/private`.
- **CI.** The regenerated workflows tested only the first and last compilers, so Swift 6.3, the toolchain behind decision 0004, lost coverage. Added `.swift-ci.json` listing 6.2, 6.3 and 6.4 with log upload kept on, and regenerated. The generator also adds a README badge header regardless of `"header": false`; it was removed.

Validation: `agt validate --target AgentToolsCore` passed 285 tests on Swift 6.4, outside the sandbox because fixture repositories write Git hooks. A smoke test with the branch `agt` on the SwiftPM fixture confirmed the empty state, `--wait` failure, foreground wording, a full pass satisfying `--wait --full`, an immediate background launch during a foreground run, and wait messages for both locks. Swift 6.2 and 6.3 are checked only by CI.

The `testSubmodules` default (review finding 4 on decision 0008) remains open pending Sam's decision.
