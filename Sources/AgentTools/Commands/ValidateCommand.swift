// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Runs the standard validation flow for the Swift repository in the current directory.
///
/// Full validation builds every product scheme for every supported platform,
/// then runs the tests of the product and its local packages. The fast phase
/// (`--fast`, or `--target`) builds only what a change touched, for macOS, and
/// runs the tests that depend on it.
struct ValidateCommand: AsyncParsableCommand {
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

  /// Whether to run the fast phase for uncommitted changes.
  @Flag(help: "Build only what the uncommitted changes touched, for macOS, and run the tests that depend on it.")
  var fast = false

  /// Target for the fast phase.
  @Option(help: "Run the fast phase for this target instead of the changes: build it and run the test targets that depend on it, or build the Xcode scheme of this name when no package defines it.")
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
  @Option(help: ArgumentHelp("Schemes that build the product (default: the repo name, or the root package's scheme).", valueName: "csv"))
  var schemes: String?

  /// Comma-separated build platforms.
  @Option(help: ArgumentHelp("Platforms to build for: macOS, iOS, tvOS, watchOS, visionOS (default: those the product supports).", valueName: "csv"))
  var platforms: String?

  /// Comma-separated test platforms.
  @Option(help: ArgumentHelp("Platforms to test on (default: the build platforms).", valueName: "csv"))
  var testPlatforms: String?

  /// When to test packages in git submodules.
  @Option(help: "When to test packages in git submodules (default: changed).")
  var testSubmodules: TestSubmodules?

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
  mutating func run() async throws {
    let repoPath = FileManager.default.currentDirectoryPath
    let file = try await ProjectConfiguration.load(repoPath: repoPath).validate
    try ValidationTool(config: config(repoPath: repoPath, file: file), repoPath: repoPath).run()
  }

  /// Resolves the parsed options, over the project's configuration file settings, into validation settings.
  func config(repoPath: String, file: ValidateFileSettings = ValidateFileSettings()) throws -> ValidationConfig {
    let schemes = Self.parseCSV(schemes)
    let platforms = self.platforms.map(Self.parseCSV) ?? file.platforms ?? []
    let testPlatforms = self.testPlatforms.map(Self.parseCSV) ?? file.testPlatforms ?? []
    let packageDirs = Self.parseCSV(packageDirs)

    return ValidationConfig(
      clean: clean,
      fast: fast,
      target: target,
      workspaceOverride: workspace,
      projectOverride: project,
      schemes: schemes.isEmpty ? file.schemes ?? [] : schemes,
      platforms: try Self.parsePlatforms(platforms),
      testPlatforms: try Self.parsePlatforms(testPlatforms),
      testSubmodules: try testSubmodules ?? Self.parseTestSubmodules(file.testSubmodules),
      excludedPackages: file.excludePackages ?? [],
      packageDirsOverride: packageDirs.isEmpty ? nil : packageDirs,
      recursivePackageDiscovery: !noRecursivePackages,
      swiftPMDisableSandbox: swiftpmDisableSandbox,
      outputMode: output.mode,
      planOnly: plan
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
    (value ?? "")
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}
