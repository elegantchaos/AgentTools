// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Per-project locations that validation writes to, all under `.build/agt/` in the repository.
///
/// Downloads use SwiftPM's and Xcode's standard caches, so validation shares them with ordinary builds.
struct ValidationPaths {
  /// Repository root.
  let repoPath: String

  /// Root of the per-project output.
  var root: String { "\(repoPath)/.build/agt" }
  /// Directory for per-step logs.
  var logRoot: String { "\(root)/logs" }
  /// Private DerivedData directory for Xcode validation.
  var derivedDataPath: String { "\(root)/DerivedData" }

  /// Resolves the locations for a repository, optionally clearing previous output, and creates them.
  static func prepare(repoPath: String, clean: Bool) throws -> ValidationPaths {
    let paths = ValidationPaths(repoPath: repoPath)
    let fileManager = FileManager.default
    if clean {
      try? fileManager.removeItem(atPath: paths.root)
    }
    for directory in [paths.logRoot, paths.derivedDataPath] {
      try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
    }
    return paths
  }

  /// Returns the private SwiftPM build directory for a package, keeping the root package apart from nested ones.
  func swiftPMScratchPath(forPackage packageDir: String) -> String {
    "\(root)/swiftpm/\(packageLocation(packageDir))"
  }

  /// Returns the private DerivedData directory for building a package from its own directory with `xcodebuild`.
  func packageDerivedDataPath(forPackage packageDir: String) -> String {
    "\(root)/\(packageLocation(packageDir))/DerivedData"
  }

  /// Returns `root` for the root package, or `packages/` followed by the package's repository-relative path.
  private func packageLocation(_ packageDir: String) -> String {
    let repo = Self.canonical(repoPath)
    let package = Self.canonical(packageDir)
    guard package != repo else { return "root" }
    let relative = package.hasPrefix("\(repo)/") ? String(package.dropFirst(repo.count + 1)) : package
    return "packages/\(relative)"
  }

  /// Returns a path with macOS's `/private` prefix removed from `/private/var`, `/private/tmp`, and `/private/etc`,
  /// so that both spellings of the same location compare equal.
  static func canonical(_ path: String) -> String {
    for directory in ["var", "tmp", "etc"] where path.hasPrefix("/private/\(directory)/") || path == "/private/\(directory)" {
      return String(path.dropFirst("/private".count))
    }
    return path
  }

  /// Returns the log file path for a step, using a filesystem-safe form of its name.
  func logPath(_ name: String) -> String {
    "\(logRoot)/\(name.replacingOccurrences(of: "[^A-Za-z0-9]+", with: "_", options: .regularExpression)).log"
  }
}
