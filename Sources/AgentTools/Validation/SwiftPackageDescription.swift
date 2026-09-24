// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Minimal package metadata decoded from `swift package describe --type json`.
struct SwiftPackageDescription: Codable {
  /// Minimal product metadata.
  struct Product: Codable {
    /// The product name.
    let name: String
  }

  /// Minimal dependency metadata.
  struct Dependency: Codable {
    /// The dependency kind, such as `fileSystem` for a local path dependency.
    let type: String
    /// The directory of a local path dependency.
    let path: String?
  }

  /// Minimal target metadata.
  struct Target: Codable {
    /// The target name.
    let name: String
    /// The package target kind.
    let type: String
    /// The target's source directory, relative to the package.
    var path: String?
    /// Targets in the same package that this target depends on.
    var targetDependencies: [String]?

    /// Keys in `swift package describe` output.
    private enum CodingKeys: String, CodingKey {
      case name, type, path
      case targetDependencies = "target_dependencies"
    }
  }

  /// The package name.
  let name: String
  /// Products defined by the package.
  let products: [Product]
  /// Targets defined by the package.
  let targets: [Target]
  /// Packages the package depends on.
  let dependencies: [Dependency]

  /// Creates a description from its parts.
  init(name: String = "", products: [Product] = [], targets: [Target], dependencies: [Dependency] = []) {
    self.name = name
    self.products = products
    self.targets = targets
    self.dependencies = dependencies
  }

  /// Decodes a description, treating a missing name, product list, or dependency list as empty.
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
    products = try container.decodeIfPresent([Product].self, forKey: .products) ?? []
    targets = try container.decode([Target].self, forKey: .targets)
    dependencies = try container.decodeIfPresent([Dependency].self, forKey: .dependencies) ?? []
  }

  /// The directories of the package's local path dependencies.
  var localDependencyPaths: [String] {
    dependencies.compactMap { $0.type == "fileSystem" ? $0.path : nil }
  }

  /// Whether the package defines at least one test target.
  var hasTestTargets: Bool {
    targets.contains { $0.type == "test" }
  }

  /// Whether the package defines a target with the given name.
  func hasTarget(named name: String, type: String? = nil) -> Bool {
    targets.contains { $0.name == name && (type == nil || $0.type == type) }
  }
}
