// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Validation settings resolved from `agt validate` options.
struct ValidationConfig {
  /// Whether to remove previous validation output first.
  let clean: Bool
  /// Optional targeted validation target.
  let target: String?
  /// Explicit workspace path.
  let workspaceOverride: String?
  /// Explicit project path.
  let projectOverride: String?
  /// Schemes selected for Xcode validation.
  let schemes: [String]
  /// Explicit build destinations.
  let destinations: [String]
  /// Whether to run Xcode tests.
  let runXcodeTests: Bool
  /// Test destinations for Xcode tests.
  let testDestinations: [String]
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
