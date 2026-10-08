# 0008: Full Validation Runs Package Tests Through the Product Scheme

- Status: Accepted
- Date: 2026-10-07

## Context

Full validation tested each local package with its own step, after testing the product. Every step started `xcodebuild` and built its own graph, and on simulators each launched tests separately. Bookish's warm full validation took about 4 m 44 s over 22 steps, or about 2 m 25 s with the simulator pre-booted.

Packages that were workspace members were tested through their generated workspace schemes, on the rule that a workspace member is a root and gets a test action. On Xcode 27 that is false: a package's generated scheme has a test action only when the package is opened on its own, so those steps failed. Bookish worked around the failure by excluding every package and listing all their test targets in the Bookish scheme. Full validation then took four steps and about 81 s warm.

A scheme or test plan lists a package's tests by its `container:` path, and Xcode skips them without any message when the package is not a workspace member. A comparison of Bookish's scheme with its packages found two product packages whose tests full validation never ran. The [2026-10-07 journal](../Journal/2026-10-07.md) records the experiments.

## Decision

Full validation runs local package tests through the product schemes where it can, and checks that nothing is missed.

- A product scheme's test plan named `Full Validation` is run when it exists, with `-testPlan`. Otherwise the scheme's default tests run. Projects can keep a quicker default plan for working in Xcode.
- A package is covered when the product schemes run every one of its test targets in full, without selecting or skipping individual tests, and it is a workspace member. Covered packages get no test steps of their own.
- Every other product package that validation would test is named in a warning, giving the missing test targets or the missing workspace membership, and is tested separately. Validation does not fail because of a gap. A package the submodule policy leaves untested is not warned about: whether its tests run is the scheme's choice, and a warning on every run would be ignored.
- The check covers scheme testables as well as test plans. Packages in submodules the policy does not test are still examined when the product uses them, so `--plan` can say when a product scheme runs their tests.
- A package tested separately runs through a shared scheme for it only when that scheme runs all of its tests and it is a workspace member; otherwise in its own directory. Generated package schemes are never used through a workspace.

## Alternatives

- Rejected: warning about packages the submodule policy leaves untested. Bookish's scheme deliberately runs some submodules' tests and not others, so the warning would repeat on every run without calling for action.
- Rejected: failing validation when a package's tests are not covered. A gap costs time when it is tested separately, never coverage, and the warning names it.
- Rejected: always testing every package separately, even when the product scheme already runs its tests. It repeats work: on Bookish, the per-package plan took about 1.8 times as long warm with the simulator pre-booted, and 3.5 times without, though the runs were on different commits.
- Rejected: requiring a `Full Validation` plan. Schemes that list their tests directly, as Bookish's does, get the same speed and coverage check without one.
- Retained for later: running the plan through a running Xcode, using its Model Context Protocol bridge, to reuse the IDE's build. It would act on the user's open Xcode, could test unsaved editor contents, and conflicts with [0003](0003-validation-does-not-modify-the-project.md)'s separate build directories.

## Consequences

- A project gets the fast path by making its product scheme, or its `Full Validation` plan, list every local package's test targets, with the packages as workspace members. `--plan` shows which packages a scheme covers.
- `excludePackages` is no longer needed to avoid duplicate package tests; it now only stops packages from being tested separately, and excluded packages are not checked.
- Validation describes more submodule packages than before, which adds discovery time on a first run; the results are cached.
