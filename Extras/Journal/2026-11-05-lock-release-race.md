# Lock Release Race

Continued the investigation started on 29 October into the [3.12.0 tag run](https://github.com/elegantchaos/AgentTools/actions/runs/40909393892) on `feature/lock-release-race`, based on `5c316e3`. The Xcode 27 release build succeeded, but `ownershipIsExclusiveAndReleased()` could not reacquire the checkout lock after its owner left scope. The same commit had passed on main.

## Isolation

Added eight parallel test cases, each repeating the original ownership/cleanup sequence 100 times while launching `/usr/bin/true` through Foundation `Process`. The first stress run reproduced five ownership failures. A second run added a weak reference to establish that the old owner had been deallocated before reacquisition: it reproduced seven stress failures and a failure in the original test, all at reacquisition after deallocation. An unrelated refresh process-group test also failed because the sandbox denied `/bin/ps`.

The lock object released ownership only by closing its descriptor. Concurrent process creation can retain another reference to the same open file before close-on-exec processing. Apple's [descriptor implementation](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_descrip.c) shares the fileglob during process creation and closes it only when the final reference drops; [exec processing](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_exec.c) subsequently closes descriptors marked close-on-exec. This supports the process-launch reference window as the mechanism; no kernel trace was captured. A direct Swift `fork()` probe was rejected by the compiler and was removed; the retained stress test uses ordinary supported process launches.

## Change And Validation

`RepositoryOperationLock` explicitly calls `flock(LOCK_UN)` before closing the descriptor, both on deinitialization and when initialization throws. A failed contender unlocks only its own open-file description; the existing contention checks confirm that it does not release the current owner's lock. Cleaning still preserves the lock inode, and planning still waits for ownership. The existing [validation output ownership](../Decisions/0003-validation-does-not-modify-the-project.md) and [setup/preparation ownership](../Decisions/0010-agt-owns-worktree-setup-and-dependency-preparation.md) decisions apply; no decision records changed.

After the fix, `agt validate --target AgentToolsCore` built successfully and all 800 stress iterations passed. The run contained 219 tests in 32 suites and retained one failure: `RefreshTests.pluginCommandSharesProcessGroup`, because `/bin/ps` could not obtain the process group inside the sandbox. Formatting/lint and `git diff --check` passed without findings. The local toolchain was Swift 6.4.2 on macOS 27.2. A separate outside-sandbox targeted run was requested explicitly under the validation skill's external-blockage policy. Release-mode CI, the macOS 26 runner and comprehensive validation have not been run for this change.

The CLI-created worktree could not be attached through Codex's managed-worktree API; all commands use its absolute path. Installed AgentTools 3.15.0 and ReleaseTools 6.0.0 were refreshed through Mint on 5 November. No commit, push, merge or release was performed.

## Outside-Sandbox Follow-Up

Sam explicitly approved running `agt validate --target AgentToolsCore` outside the sandbox. That run passed the build and all 219 tests in 32 suites, including all 800 lock-turnover iterations and the previously blocked process-group test. This verifies the complete targeted suite in debug with Swift 6.4.2; release-mode CI, macOS 26 and comprehensive validation remain unrun. No further source changes were needed.

## PR Preparation

Rebased onto `e5d3db3` from current main before publishing; the only conflict was the journal index, and both sets of entries were retained. Formatting/lint and `git diff --check` passed. The approved outside-sandbox `agt validate --target AgentToolsCore` run passed all 275 tests in 43 suites on code commit `1836949`, including the 800 stress iterations. Release-mode and macOS 26 checks remain for CI, and comprehensive local validation remains unrun.
