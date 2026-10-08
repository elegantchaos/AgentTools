// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Which local packages' tests the product schemes already run, and warnings about packages they miss.
///
/// Full validation tests a covered package only through the product scheme, sharing its build. A package is covered
/// when the scheme's tests include every one of the package's test targets and the package is a workspace member;
/// Xcode skips, without any message, a target whose package is not a member. A package that is not covered is named in
/// a warning and tested separately, unless the submodule policy leaves it untested, in which case it is neither.
struct TestCoverage: Equatable {
  /// The product scheme that runs each covered package's tests, keyed by the package's canonical directory.
  let schemes: [String: String]

  /// One warning for each package that no product scheme fully runs and that is therefore tested separately.
  let warnings: [String]

  /// Checks `packages` against the tests of the product schemes in `schemeTests`.
  ///
  /// Packages outside the product, without tests, or excluded by name are not checked. `tested` lists the packages
  /// validation would test separately; only those are warned about when not covered. With no scheme tests, nothing is
  /// checked.
  static func check(packages: [LocalPackage], tested: [LocalPackage], excluded: [String], schemeTests: [String: SchemeTests], workspaceMembers: Set<String>, repoPath: String) -> TestCoverage {
    guard !schemeTests.isEmpty else { return TestCoverage(schemes: [:], warnings: []) }
    let members = Set(workspaceMembers.map(ValidationPaths.canonical))
    let separately = Set(tested.map { ValidationPaths.canonical($0.directory) })
    let repo = ValidationPaths.canonical(repoPath)
    var schemes: [String: String] = [:]
    var warnings: [String] = []

    for package in packages where package.inProduct && package.hasTests && !excluded.contains(package.name) {
      let directory = ValidationPaths.canonical(package.directory)
      let listing = schemeTests.keys.sorted().filter { !(schemeTests[$0]?.targets(in: directory).isEmpty ?? true) }
      let complete = Set(listing.flatMap { completeTargetNames(in: schemeTests[$0], directory: directory) })
      if let scheme = listing.first, members.contains(directory), complete.isSuperset(of: package.testTargets) {
        schemes[directory] = scheme
        continue
      }

      guard separately.contains(directory) else { continue }
      let partial = Set(listing.flatMap { schemeTests[$0]?.targets(in: directory).filter(\.isFiltered).map(\.name) ?? [] })
      let runner = describe(listing.isEmpty ? schemeTests.keys.sorted() : listing, in: schemeTests)
      let problem: String
      if !listing.isEmpty, !members.contains(directory) {
        problem = "\(runner) lists its tests, but Xcode skips them because the package is not a workspace member"
      } else {
        let absent = package.testTargets.filter { !complete.contains($0) && !partial.contains($0) }
        let filtered = package.testTargets.filter { !complete.contains($0) && partial.contains($0) }
        let parts = (absent.isEmpty ? [] : ["does not run \(absent.joined(separator: ", "))"]) + (filtered.isEmpty ? [] : ["runs only some tests of \(filtered.joined(separator: ", "))"])
        problem = "\(runner) \(parts.joined(separator: ", and "))"
      }
      let path = directory == repo ? "." : directory.hasPrefix("\(repo)/") ? String(directory.dropFirst(repo.count + 1)) : directory
      warnings.append("\(path) (\(package.name)): \(problem); testing the package separately.")
    }
    return TestCoverage(schemes: schemes, warnings: warnings)
  }
}

extension TestCoverage {
  /// Returns the names of the targets of the package in `directory` that `tests` runs without filtering.
  private static func completeTargetNames(in tests: SchemeTests?, directory: String) -> [String] {
    tests?.targets(in: directory).filter { !$0.isFiltered }.map(\.name) ?? []
  }

  /// Describes the named schemes and where their tests come from, such as `scheme App (test plan Full Validation)`.
  private static func describe(_ names: [String], in schemeTests: [String: SchemeTests]) -> String {
    names.map { name in "scheme \(name) (\(schemeTests[name]?.source ?? "tests"))" }.joined(separator: " or ")
  }
}
