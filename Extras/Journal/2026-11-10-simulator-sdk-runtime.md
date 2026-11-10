# Simulator Runtimes Follow The Selected Xcode

Full validation of Bookish created and booted `Test iPhone 27.3`. Sam had installed Xcode 27.3, which brought an iOS 27.3 runtime (24C5037i), but the selected Xcode was still 27.2. The simulator's `identityservicesd` crashed at launch, with an XPC API-misuse assertion in `XPCPeerRequirement.hasEntitlement`, and macOS showed its crash dialog. The validation run was also cancelled partway through, for a reason the log does not show.

`TestSimulators` took each platform's newest *available* runtime, whatever Xcode was selected. It now takes the newest runtime no newer than the selected Xcode's simulator SDK, which `xcrun --sdk <simulator SDK> --show-sdk-version` reports. Versions are compared to as many components as the SDK version has, so a 27.2.1 runtime counts under SDK 27.2. A platform whose SDK version cannot be read is not limited. `ApplePlatform.simulatorSDK` names each platform's simulator SDK.

Tests cover the cap in `newestOS` and `newDevice`, and the version comparison, and failed before the change. `agt validate --target AgentToolsCore` passed 290 tests. With a build of this branch, `agt validate --full --plan` in Bookish chose `Test iPhone 27.2` where it had chosen `Test iPhone 27.3`.
