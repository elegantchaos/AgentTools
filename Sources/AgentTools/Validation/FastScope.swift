// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// A target in a local Swift package.
struct PackageTarget: Hashable {
  /// The package directory.
  let packageDirectory: String
  /// The target name.
  let name: String
}

/// What the fast phase builds and tests: the smallest scope that covers a change.
///
/// A changed file in a package target builds that target and runs the package's test targets that depend on it; a
/// changed test file runs its test target. A changed manifest or submodule covers its whole package. A build input
/// outside every package target, such as an app source file or an Xcode project file, needs the product built.
/// Anything else is ignored.
struct FastScope {
  /// Extensions of files outside packages that affect an Xcode build.
  private static let buildInputExtensions: Set<String> = [
    "swift", "h", "m", "mm", "c", "cc", "cpp", "metal", "xcstrings", "strings", "stringsdict", "plist", "storyboard", "xib",
    "entitlements", "xcconfig", "intentdefinition",
  ]

  /// Non-test targets to build.
  private(set) var builds: [PackageTarget] = []
  /// Test targets to run.
  private(set) var tests: [PackageTarget] = []
  /// Directories of packages to build and test entirely.
  private(set) var wholePackages: [String] = []
  /// Repository-relative changed files outside every package that need the product built.
  private(set) var productSources: [String] = []
  /// One line per changed file, saying where it was assigned.
  private(set) var assignments: [String] = []
  /// Named targets that no package defines.
  private(set) var unmatchedTargets: [String] = []

  /// Whether there is nothing to build or test.
  var isEmpty: Bool {
    builds.isEmpty && tests.isEmpty && wholePackages.isEmpty && productSources.isEmpty && unmatchedTargets.isEmpty
  }

  /// Finds what repository-relative `changedFiles` touch among `packages`.
  init(changedFiles: [String], packages: [(directory: String, description: SwiftPackageDescription)], repoPath: String) {
    let repo = ValidationPaths.canonical(repoPath)
    let located = packages.map { package -> (relative: String, directory: String, description: SwiftPackageDescription) in
      let path = ValidationPaths.canonical(package.directory)
      let relative = path == repo ? "" : path.hasPrefix("\(repo)/") ? String(path.dropFirst(repo.count + 1)) : path
      return (relative, package.directory, package.description)
    }

    for file in changedFiles {
      let covered = located.filter { $0.relative == file || $0.relative.hasPrefix("\(file)/") }
      if !covered.isEmpty {
        for package in covered {
          append(package.directory, to: &wholePackages)
        }
        assignments.append("\(file): \(covered.map { "package \($0.description.name)" }.joined(separator: ", "))")
        continue
      }

      let containing = located.filter { $0.relative.isEmpty || file.hasPrefix("\($0.relative)/") }.max { $0.relative.count < $1.relative.count }
      guard let package = containing else {
        addOutsideTargets(file)
        continue
      }

      let inPackage = package.relative.isEmpty ? file : String(file.dropFirst(package.relative.count + 1))
      let name = URL(fileURLWithPath: inPackage).lastPathComponent
      if !inPackage.contains("/"), name == "Package.swift" || name == "Package.resolved" || name.hasPrefix("Package@swift-") {
        append(package.directory, to: &wholePackages)
        assignments.append("\(file): package \(package.description.name)")
        continue
      }

      let target = package.description.targets
        .filter { target in target.path.map { inPackage.hasPrefix("\($0)/") } ?? false }
        .max { ($0.path?.count ?? 0) < ($1.path?.count ?? 0) }
      guard let target else {
        addOutsideTargets(file)
        continue
      }
      add(target, in: package.directory, description: package.description)
      let location = package.relative.isEmpty ? "the root package" : package.relative
      assignments.append("\(file): target \(target.name) in \(location)")
    }
  }

  /// Finds the named targets among `packages`.
  init(targets names: [String], packages: [(directory: String, description: SwiftPackageDescription)]) {
    for name in names {
      guard let package = packages.first(where: { $0.description.hasTarget(named: name) }),
        let target = package.description.targets.first(where: { $0.name == name })
      else {
        unmatchedTargets.append(name)
        continue
      }
      add(target, in: package.directory, description: package.description)
    }
  }

  /// Adds a file that no package target contains: a build input needs the product built; anything else is ignored.
  private mutating func addOutsideTargets(_ file: String) {
    if Self.isBuildInput(file) {
      productSources.append(file)
      assignments.append("\(file): the product")
    } else {
      assignments.append("\(file): ignored")
    }
  }

  /// Adds a target: a test target runs; any other target builds, and the test targets that depend on it run.
  private mutating func add(_ target: SwiftPackageDescription.Target, in directory: String, description: SwiftPackageDescription) {
    guard !wholePackages.contains(directory) else { return }
    if target.type == "test" {
      append(PackageTarget(packageDirectory: directory, name: target.name), to: &tests)
      return
    }
    append(PackageTarget(packageDirectory: directory, name: target.name), to: &builds)
    for test in description.targets where test.type == "test" && (test.targetDependencies ?? []).contains(target.name) {
      append(PackageTarget(packageDirectory: directory, name: test.name), to: &tests)
    }
  }

  /// Appends an element unless it is already present.
  private func append<T: Equatable>(_ element: T, to list: inout [T]) {
    if !list.contains(element) {
      list.append(element)
    }
  }

  /// Returns `true` for files outside packages that affect an Xcode build.
  private static func isBuildInput(_ file: String) -> Bool {
    let components = file.split(separator: "/")
    if components.contains(where: { $0.hasSuffix(".xcassets") || $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
      return true
    }
    return buildInputExtensions.contains(URL(fileURLWithPath: file).pathExtension)
  }
}
