// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// A Swift package in the repository, as validation sees it.
struct LocalPackage: Equatable {
  /// The package directory.
  let directory: String
  /// The package name.
  let name: String
  /// Whether the package defines test targets.
  let hasTests: Bool
  /// The scheme that tests the package in the root container, or `nil` when the container has none for it.
  let scheme: String?
  /// The repository-relative path of the git submodule containing the package, or `nil` for packages in the repository.
  let submodule: String?
  /// Whether that submodule differs from the commit the repository records.
  let submoduleChanged: Bool
  /// Whether the product uses the package: the workspace or a project references it, it is the root package of a
  /// Swift package product, or it is a local dependency of one of those.
  var inProduct = true
  /// The scheme that tests the package when `xcodebuild` opens the package directory itself, used on platforms other
  /// than macOS when the root container has no scheme for it.
  var packageScheme: String?

  /// Returns the package's scheme among `schemes`: its all-targets scheme when there is one, otherwise the scheme of
  /// one of its products, or of the package name.
  static func scheme(for package: SwiftPackageDescription, in schemes: [String]) -> String? {
    let candidates = ["\(package.name)-Package"] + package.products.map(\.name) + [package.name]
    return candidates.first(where: schemes.contains)
  }
}
