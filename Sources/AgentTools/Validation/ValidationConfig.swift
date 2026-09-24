// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Validation settings resolved from `agt validate` options.
struct ValidationConfig {
  /// Whether to remove previous validation output first.
  let clean: Bool
  /// Whether to run the fast phase for uncommitted changes instead of full validation.
  let fast: Bool
  /// A target to run the fast phase for, instead of the changes.
  let target: String?
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
