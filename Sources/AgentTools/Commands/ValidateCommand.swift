// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Runs the standard validation flow for the Swift repository in the current directory.
///
/// Targeted validation is a fast preflight for a modified non-test SwiftPM
/// target. It builds that target first, then runs a conventionally named
/// `<Target>Tests` target when one exists. Use comprehensive validation to
/// verify the complete app or package and its dependencies.
struct ValidateCommand: ParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Run the standard validation flow for a Swift repository.",
    discussion: """
      Run from the repository root. Builds and tests the Xcode workspace, discovered Swift packages, or \
      Xcode project, in that order of preference. Validation never modifies source; run agt format first. \
      Build products and logs are written to .build/agt; downloads use SwiftPM's and Xcode's standard caches. \
      Inside another sandbox, such as an agent's, SwiftPM's and Xcode's own sandboxes are turned off. \
      Discovery results, such as package descriptions and scheme destinations, are cached in .build/agt \
      until a package manifest, Xcode project, or scheme changes.
      """
  )

  /// Target for fast preflight validation.
  @Option(help: "Build this non-test SwiftPM target, then run <target>Tests when present.")
  var target: String?

  /// Whether to clear previous validation output.
  @Flag(name: [.customShort("c"), .long], help: "Remove validation's build products and logs in .build/agt before running checks.")
  var clean = false

  /// Explicit workspace path.
  @Option(help: "Explicit workspace path (absolute or repo-relative).")
  var workspace: String?

  /// Explicit project path.
  @Option(help: "Explicit project path (absolute or repo-relative).")
  var project: String?

  /// Comma-separated Xcode schemes.
  @Option(help: ArgumentHelp("Xcode schemes for broad validation (default: repo name).", valueName: "csv"))
  var schemes: String?

  /// Comma-separated Xcode build destinations.
  @Option(help: ArgumentHelp("Xcode build destinations (default: platforms supported by the scheme).", valueName: "csv"))
  var destinations: String?

  /// Whether to run Xcode tests.
  @Flag(help: "Also run xcodebuild test for test destinations.")
  var runXcodeTests = false

  /// Comma-separated Xcode test destinations.
  @Option(help: ArgumentHelp("Xcode test destinations (default: platform=macOS).", valueName: "csv"))
  var testDestinations: String?

  /// Comma-separated Swift package directories.
  @Option(help: ArgumentHelp("Package directories for SwiftPM checks (absolute or repo-relative).", valueName: "csv"))
  var packageDirs: String?

  /// Whether to disable recursive package discovery.
  @Flag(help: "Disable recursive Package.swift discovery.")
  var noRecursivePackages = false

  /// Whether to disable SwiftPM's sandbox.
  @Flag(help: "Disable SwiftPM's internal sandbox. Validation does this automatically when it runs inside another sandbox.")
  var swiftpmDisableSandbox = false

  /// Whether to list the steps instead of running them.
  @Flag(help: "List the steps validation would run, with their commands, without running them.")
  var plan = false

  /// Terminal output options.
  @OptionGroup var output: OutputOptions

  /// Executes validation in the current directory.
  mutating func run() throws {
    let repoPath = FileManager.default.currentDirectoryPath
    try ValidationTool(config: config(repoPath: repoPath), repoPath: repoPath).run()
  }

  /// Resolves the parsed options into validation settings for a repository.
  func config(repoPath: String) -> ValidationConfig {
    let schemes = Self.parseCSV(schemes)
    let testDestinations = Self.parseCSV(testDestinations)
    let packageDirs = Self.parseCSV(packageDirs)

    return ValidationConfig(
      clean: clean,
      target: target,
      workspaceOverride: workspace,
      projectOverride: project,
      schemes: schemes.isEmpty ? [ValidationDiscovery.repoName(repoPath)] : schemes,
      destinations: Self.parseCSV(destinations),
      runXcodeTests: runXcodeTests,
      testDestinations: testDestinations.isEmpty ? ["platform=macOS"] : testDestinations,
      packageDirsOverride: packageDirs.isEmpty ? nil : packageDirs,
      recursivePackageDiscovery: !noRecursivePackages,
      swiftPMDisableSandbox: swiftpmDisableSandbox,
      outputMode: output.mode,
      planOnly: plan
    )
  }

  /// Splits a comma-separated option into trimmed non-empty items.
  private static func parseCSV(_ value: String?) -> [String] {
    (value ?? "")
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}
