// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Selects the same package directories, Xcode container and schemes for preparation and validation.
struct RepositorySelectionOptions: ParsableArguments {
  /// Explicit workspace path.
  @Option(help: "Explicit workspace path (absolute or repo-relative).")
  var workspace: String?

  /// Explicit project path.
  @Option(help: "Explicit project path (absolute or repo-relative).")
  var project: String?

  /// Comma-separated Xcode schemes.
  @Option(help: ArgumentHelp("Schemes that build the product (default: the repo name, or the root package's scheme).", valueName: "csv"))
  var schemes: String?

  /// Comma-separated Swift package directories.
  @Option(help: ArgumentHelp("Package directories for SwiftPM checks (absolute or repo-relative).", valueName: "csv"))
  var packageDirs: String?

  /// Whether to disable recursive package discovery.
  @Flag(help: "Disable recursive Package.swift discovery.")
  var noRecursivePackages = false

  /// Whether to disable SwiftPM's sandbox.
  @Flag(help: "Disable SwiftPM's internal sandbox. This happens automatically inside another sandbox.")
  var swiftpmDisableSandbox = false

  /// Resolves common selection and file settings without enabling any validation action.
  /// Validation alone adds its action flags after resolving these shared settings.
  func configuration(file: ValidateFileSettings, outputMode: ValidateOutputMode, planOnly: Bool, platforms: String? = nil, testPlatforms: String? = nil, testSubmodules: TestSubmodules? = nil) throws -> ValidationConfig {
    let schemes = Self.parseCSV(schemes)
    let packageDirs = Self.parseCSV(packageDirs)
    return ValidationConfig(
      clean: false, fast: false, background: false, status: false, wait: false, backgroundWorker: false, target: nil,
      workspaceOverride: workspace, projectOverride: project,
      schemes: schemes.isEmpty ? file.schemes ?? [] : schemes,
      platforms: try Self.parsePlatforms(platforms.map(Self.parseCSV) ?? file.platforms ?? []),
      testPlatforms: try Self.parsePlatforms(testPlatforms.map(Self.parseCSV) ?? file.testPlatforms ?? []),
      testSubmodules: try testSubmodules ?? Self.parseTestSubmodules(file.testSubmodules),
      excludedPackages: file.excludePackages ?? [],
      packageDirsOverride: packageDirs.isEmpty ? nil : packageDirs,
      recursivePackageDiscovery: !noRecursivePackages, swiftPMDisableSandbox: swiftpmDisableSandbox,
      outputMode: outputMode, planOnly: planOnly
    )
  }

  /// Converts platform names, failing on an unknown name.
  private static func parsePlatforms(_ names: [String]) throws -> [ApplePlatform] {
    try names.map { name in
      guard let platform = ApplePlatform(name: name) else {
        throw ToolError("Unknown platform '\(name)'. Use \(ApplePlatform.allCases.map(\.rawValue).joined(separator: ", ")).")
      }
      return platform
    }
  }

  /// Converts a configured submodule test policy, failing on an unknown value.
  private static func parseTestSubmodules(_ value: String?) throws -> TestSubmodules {
    guard let value else { return .changed }
    guard let policy = TestSubmodules(rawValue: value) else {
      throw ToolError("Unknown testSubmodules value '\(value)'. Use \(TestSubmodules.allCases.map(\.rawValue).joined(separator: ", ")).")
    }
    return policy
  }

  /// Splits a comma-separated option into trimmed non-empty items.
  private static func parseCSV(_ value: String?) -> [String] {
    (value ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
  }
}
