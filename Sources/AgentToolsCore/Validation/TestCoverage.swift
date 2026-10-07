// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Which local packages' tests the product schemes already run, and warnings about packages they miss.
///
/// Full validation tests a covered package only through the product scheme, sharing its build. A package is covered
/// when the scheme's tests include every one of the package's test targets and the package is a workspace member;
/// Xcode skips, without any message, a target whose package is not a member. Packages that are not covered are named
/// in a warning, and are tested separately when the submodule policy would test them.
struct TestCoverage: Equatable {
  /// The product scheme that runs each covered package's tests, keyed by the package's canonical directory.
  let schemes: [String: String]

  /// One warning for each product package with tests that no product scheme fully runs.
  let warnings: [String]

  /// Checks `packages` against the tests of the product schemes in `schemeTests`.
  ///
  /// Packages outside the product, without tests, or excluded by name are not checked. `tested` lists the packages
  /// validation would test separately, which decides how a warning ends. With no scheme tests, nothing is checked.
  static func check(packages: [LocalPackage], tested: [LocalPackage], excluded: [String], schemeTests: [String: SchemeTests], workspaceMembers: Set<String>, repoPath: String) -> TestCoverage {
    guard !schemeTests.isEmpty else { return TestCoverage(schemes: [:], warnings: []) }
    let members = Set(workspaceMembers.map(ValidationPaths.canonical))
    let separately = Set(tested.map { ValidationPaths.canonical($0.directory) })
    let repo = ValidationPaths.canonical(repoPath)
    var schemes: [String: String] = [:]
    var warnings: [String] = []

    for package in packages where package.inProduct && package.hasTests && !excluded.contains(package.name) {
      let directory = ValidationPaths.canonical(package.directory)
      let listing = schemeTests.keys.sorted().filter { scheme in
        schemeTests[scheme]?.targets.contains { ValidationPaths.canonical($0.container) == directory } ?? false
      }
      let listed = Set(
        listing.flatMap { scheme in
          (schemeTests[scheme]?.targets ?? []).filter { ValidationPaths.canonical($0.container) == directory }.map(\.name)
        })
      let missing = package.testTargets.filter { !listed.contains($0) }

      if let scheme = listing.first, missing.isEmpty, members.contains(directory) {
        schemes[directory] = scheme
        continue
      }

      let runner = describe(listing.isEmpty ? schemeTests.keys.sorted() : listing, in: schemeTests)
      let problem: String
      if !listing.isEmpty, !members.contains(directory) {
        problem = "\(runner) lists its tests, but Xcode skips them because the package is not a workspace member"
      } else {
        problem = "\(runner) does not run \(missing.joined(separator: ", "))"
      }
      let action = separately.contains(directory) ? "testing the package separately" : "the package is not tested separately"
      let path = directory == repo ? "." : directory.hasPrefix("\(repo)/") ? String(directory.dropFirst(repo.count + 1)) : directory
      warnings.append("\(path) (\(package.name)): \(problem); \(action).")
    }
    return TestCoverage(schemes: schemes, warnings: warnings)
  }
}

extension TestCoverage {
  /// Describes the named schemes and where their tests come from, such as `scheme App (test plan Full Validation)`.
  private static func describe(_ names: [String], in schemeTests: [String: SchemeTests]) -> String {
    names.map { name in "scheme \(name) (\(schemeTests[name]?.source ?? "tests"))" }.joined(separator: " or ")
  }
}
