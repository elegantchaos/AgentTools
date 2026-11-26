# Checks Test Device

While checking Bookish PR 159 in the iOS simulator, a manual check had to wait for full validation, because both used `Test iPhone 27.2`. Validation's app-hosted iOS tests run on the test device itself, without clones, and a simulator holds one install and data container per bundle identifier, so a manual build installed during the run can swap with the test host.

Sam wants agents to start checks without waiting, while keeping the test devices `agt validate` creates, which are chosen for App Store screenshots, and running UI tests on them for consistency. The [roadmap](../../ROADMAP.md#candidate-checks-test-device) now records a candidate: a persistent twin of each test device for UI tests and manual checks, with clones as the alternative to measure. Nothing is implemented; until then, agents use another simulator on the same OS for manual checks during validation.
