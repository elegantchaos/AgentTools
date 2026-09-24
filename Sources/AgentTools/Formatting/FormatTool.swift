// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Formats and lints every Swift file in a repository with `swift format`.
struct FormatTool {
  /// Repository root that formatting runs in.
  let repoPath: String
  /// Whether to lint strictly without modifying files.
  let check: Bool
  /// Terminal output mode.
  let outputMode: ValidateOutputMode

  /// Returns the repository's tracked and untracked, non-ignored Swift files that exist on disk, sorted.
  ///
  /// Files inside a `Resources` directory under `Tests` are fixtures and are left alone.
  static func swiftFiles(repoPath: String) throws -> [String] {
    let result = try ValidationProcess(workingDirectory: repoPath).capture(
      ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", "*.swift"]
    )
    guard result.status == 0 else {
      throw ToolError("Failed to list Swift files:\n\(result.stderr)")
    }

    let files = Set(result.stdout.split(separator: "\0").map(String.init))
    return
      files
      .filter { !ValidationDiscovery.isInTestResources($0) && FileManager.default.fileExists(atPath: "\(repoPath)/\($0)") }
      .sorted()
  }

  /// Returns the `swift format` arguments that rewrite files in place.
  static func formatArguments(_ files: [String]) -> [String] {
    ["swift", "format", "--in-place", "--parallel"] + files
  }

  /// Returns the `swift format lint` arguments, treating findings as errors when `strict`.
  static func lintArguments(_ files: [String], strict: Bool) -> [String] {
    ["swift", "format", "lint", "--parallel"] + (strict ? ["--strict"] : []) + files
  }

  /// Formats then lints, or only lints strictly when checking, printing a PASS/FAIL/SKIP summary.
  func run() throws {
    guard FileManager.default.fileExists(atPath: "\(repoPath)/.git") else {
      throw ToolError("Current working directory is not a git repo root: \(repoPath)")
    }

    let runner = StepRunner(repoPath: repoPath, outputMode: outputMode)
    defer { runner.printSummary() }

    let files = try Self.swiftFiles(repoPath: repoPath)
    guard !files.isEmpty else {
      runner.record("no Swift files", status: .skip)
      return
    }

    let logRoot = ValidationPaths.logRoot(repoPath: repoPath)
    if !check {
      try runner.run(
        title: "Format \(files.count) Swift files",
        summary: "format Swift files",
        arguments: Self.formatArguments(files),
        display: Self.formatArguments(["<\(files.count) files>"]),
        logPath: ValidationPaths.logPath("format", logRoot: logRoot)
      )
    }

    try runner.run(
      title: "Lint \(files.count) Swift files",
      summary: "lint Swift files",
      arguments: Self.lintArguments(files, strict: check),
      display: Self.lintArguments(["<\(files.count) files>"], strict: check),
      logPath: ValidationPaths.logPath("lint", logRoot: logRoot)
    )
  }
}
