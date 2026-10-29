// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Resolved repository settings shared by preparation and validation, plus validation-only action flags.
struct ValidationConfig {
  /// Whether to remove previous validation output first.
  var clean: Bool
  /// Whether to run the fast phase for uncommitted changes instead of full validation.
  var fast: Bool
  /// Whether to run full validation in the background, after the fast phase when `fast` is set.
  var background: Bool
  /// Whether to report the background validation.
  var status: Bool
  /// Whether to wait for the background validation.
  var wait: Bool
  /// Whether this process is a background validation.
  var backgroundWorker: Bool
  /// A target to run the fast phase for, instead of the changes.
  var target: String?
  /// Explicit workspace path.
  let workspaceOverride: String?
  /// Explicit project path.
  let projectOverride: String?
  /// Schemes that build the product; empty to use the default.
  let schemes: [String]
  /// Platforms to build for; empty to use the platforms the product supports.
  let platforms: [ApplePlatform]
  /// Platforms to test on; empty to test on every build platform.
  let testPlatforms: [ApplePlatform]
  /// When to test packages in git submodules.
  let testSubmodules: TestSubmodules
  /// Packages whose tests never run.
  let excludedPackages: [String]
  /// Explicit Swift package directories.
  let packageDirsOverride: [String]?
  /// Whether to discover nested packages.
  let recursivePackageDiscovery: Bool
  /// Whether to disable SwiftPM sandboxing.
  let swiftPMDisableSandbox: Bool
  /// Validation output mode.
  let outputMode: ValidateOutputMode
  /// Whether to list the steps instead of running them.
  let planOnly: Bool
}
