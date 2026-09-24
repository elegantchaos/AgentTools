// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Minimal package metadata decoded from `swift package describe --type json`.
struct SwiftPackageDescription: Codable {
  /// Minimal target metadata.
  struct Target: Codable {
    /// The target name.
    let name: String
    /// The package target kind.
    let type: String
    /// The target's source directory, relative to the package.
    var path: String?
  }

  /// Targets defined by the package.
  let targets: [Target]

  /// Whether the package defines at least one test target.
  var hasTestTargets: Bool {
    targets.contains { $0.type == "test" }
  }

  /// Whether the package defines a target with the given name.
  func hasTarget(named name: String, type: String? = nil) -> Bool {
    targets.contains { $0.name == name && (type == nil || $0.type == type) }
  }
}
