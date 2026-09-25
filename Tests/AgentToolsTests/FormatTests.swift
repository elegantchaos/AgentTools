// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Tests file selection, arguments, and option parsing used by `agt format`.
struct FormatTests {
  @Test func selectsTrackedAndUntrackedSwiftFiles() throws {
    let repoURL = try makeTemporaryRepo()
    defer { try? FileManager.default.removeItem(at: repoURL) }

    try write("ignored.swift\n", to: repoURL.appendingPathComponent(".gitignore"))
    for path in ["Tracked.swift", "Sources/Module/Nested.swift", "Deleted.swift", "Notes.txt"] {
      try write("let x = 1\n", to: repoURL.appendingPathComponent(path))
    }
    try git(["add", "."], in: repoURL)
    try FileManager.default.removeItem(at: repoURL.appendingPathComponent("Deleted.swift"))
    try write("let y = 2\n", to: repoURL.appendingPathComponent("Untracked.swift"))
    try write("let z = 3\n", to: repoURL.appendingPathComponent("ignored.swift"))
    try write("let f = 4\n", to: repoURL.appendingPathComponent("Tests/ModuleTests/Resources/Fixture.package/Sources/Fixture.swift"))

    let files = try FormatTool.swiftFiles(repoPath: repoURL.path)

    #expect(files == ["Sources/Module/Nested.swift", "Tracked.swift", "Untracked.swift"])
  }

  @Test func excludedPathsAreSkipped() throws {
    let repoURL = try makeTemporaryRepo()
    defer { try? FileManager.default.removeItem(at: repoURL) }
    for path in ["Sources/App.swift", "Extras/Legacy/Old.swift", "Extras/LegacyNotes.swift", "Generated.swift"] {
      try write("let x = 1\n", to: repoURL.appendingPathComponent(path))
    }

    let files = try FormatTool.swiftFiles(repoPath: repoURL.path, excluding: ["Extras/Legacy", "Generated.swift/"])

    #expect(files == ["Extras/LegacyNotes.swift", "Sources/App.swift"])
  }

  @Test func lintSummaryCountsFindingsFilesAndRules() {
    let output = """
      Sources/A.swift:1:1: error: [Indentation] replace leading whitespace
      Sources/A.swift:2:1: error: [Indentation] replace leading whitespace
      Sources/B.swift:3:5: warning: [LineLength] line is too long
      Sources/B.swift:4:1: error: [Indentation] replace leading whitespace
      note: unrelated
      """

    let summary = LintSummary(output: output)

    #expect(summary.findings == 4)
    #expect(summary.files == 2)
    #expect(summary.description == "4 findings in 2 files: Indentation 3, LineLength 1")
    #expect(LintSummary(output: "").findings == 0)
  }

  @Test func lintSummaryListsOnlyTheMostCommonRules() {
    let output = (1...7).map { "A.swift:\($0):1: error: [Rule\($0)] message" }.joined(separator: "\n")
    #expect(LintSummary(output: output).description == "7 findings in 1 file: Rule1 1, Rule2 1, Rule3 1, Rule4 1, Rule5 1, and 2 more rules")
  }

  @Test func formatWritesInPlaceInParallel() {
    #expect(
      FormatTool.formatArguments(["A.swift", "B.swift"]) == ["swift", "format", "--in-place", "--parallel", "A.swift", "B.swift"]
    )
  }

  @Test(arguments: [
    (false, ["swift", "format", "lint", "--parallel", "A.swift"]),
    (true, ["swift", "format", "lint", "--parallel", "--strict", "A.swift"]),
  ])
  func lintIsStrictOnlyWhenChecking(strict: Bool, expected: [String]) {
    #expect(FormatTool.lintArguments(["A.swift"], strict: strict) == expected)
  }

  @Test func checkDefaultsToOff() throws {
    #expect(try FormatCommand.parse([]).check == false)
    #expect(try FormatCommand.parse(["--check"]).check)
  }

  @Test(arguments: [
    ([String](), ValidateOutputMode.filtered),
    (["--quiet"], ValidateOutputMode.quiet),
    (["--output", "raw"], ValidateOutputMode.raw),
  ])
  func outputOptionsAreShared(arguments: [String], expected: ValidateOutputMode) throws {
    #expect(try FormatCommand.parse(arguments).output.mode == expected)
  }

  /// Creates an initialized git repository in a temporary directory.
  private func makeTemporaryRepo() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("AgentTools-Format-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    try git(["init", "--quiet"], in: url)
    return url
  }

  /// Runs a git command in a directory, failing the test on a non-zero exit.
  private func git(_ arguments: [String], in directory: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git"] + arguments
    process.currentDirectoryURL = directory
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
  }

  /// Writes UTF-8 content, creating the parent directory when needed.
  private func write(_ contents: String, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }
}
