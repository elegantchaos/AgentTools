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
  /// Repository-relative files and directories to leave alone.
  let excluded: [String]
  /// Terminal output mode.
  let outputMode: ValidateOutputMode

  /// Returns the repository's tracked and untracked, non-ignored Swift files that exist on disk, sorted.
  ///
  /// Files inside a `Resources` directory under `Tests` are fixtures and are left alone, as are files at or under the
  /// repository-relative paths in `excluding`.
  static func swiftFiles(repoPath: String, excluding excluded: [String] = []) throws -> [String] {
    let result = try ValidationProcess(workingDirectory: repoPath).capture(
      ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", "*.swift"]
    )
    guard result.status == 0 else {
      throw ToolError("Failed to list Swift files:\n\(result.stderr)")
    }

    let files = Set(result.stdout.split(separator: "\0").map(String.init))
    return
      files
      .filter { !ValidationDiscovery.isInTestResources($0) && !isExcluded($0, by: excluded) && FileManager.default.fileExists(atPath: "\(repoPath)/\($0)") }
      .sorted()
  }

  /// Returns `true` when `file` is one of `excluded`, or lies in a directory that is.
  private static func isExcluded(_ file: String, by excluded: [String]) -> Bool {
    excluded.contains { path in
      let path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return file == path || file.hasPrefix("\(path)/")
    }
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

    let files = try Self.swiftFiles(repoPath: repoPath, excluding: excluded)
    guard !files.isEmpty else {
      runner.record("no Swift files", status: .skip)
      return
    }

    let paths = ValidationPaths(repoPath: repoPath)
    if !check {
      try runner.run(
        title: "Format \(files.count) Swift files",
        summary: "format Swift files",
        arguments: Self.formatArguments(files),
        display: Self.formatArguments(["<\(files.count) files>"]),
        logPath: paths.logPath("format")
      )
    }

    let lintLog = paths.logPath("lint")
    defer { printLintSummary(logPath: lintLog) }
    try runner.run(
      title: "Lint \(files.count) Swift files",
      summary: "lint Swift files",
      arguments: Self.lintArguments(files, strict: check),
      display: Self.lintArguments(["<\(files.count) files>"], strict: check),
      logPath: lintLog
    )
  }

  /// Prints a summary of the lint findings in a log, when there are any.
  private func printLintSummary(logPath: String) {
    guard let output = try? String(contentsOfFile: logPath, encoding: .utf8) else { return }
    let summary = LintSummary(output: output)
    if summary.findings > 0 {
      print("Lint: \(summary)")
    }
  }
}
