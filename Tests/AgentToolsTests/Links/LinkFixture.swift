// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// A throwaway Git repository with a GitHub `origin`, for link tests that need real history.
struct LinkFixture {
  /// Root of the repository.
  let root: URL

  /// Creates an empty repository under the package's `.build/tmp`.
  init() throws {
    let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    root = package.appending(path: ".build/tmp/links-\(UUID().uuidString)/Main")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try git(["init", "--quiet"])
    try git(["remote", "add", "origin", "git@github.com:example/project.git"])
  }

  /// The tool under test, run from the repository root.
  var tool: LinksTool { LinksTool(directory: root.path) }

  /// Writes a file, creating its folders.
  func write(_ path: String, _ text: String) throws {
    let url = root.appending(path: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: url, atomically: true, encoding: .utf8)
  }

  /// Returns a file's current text.
  func read(_ path: String) throws -> String {
    try String(contentsOf: root.appending(path: path), encoding: .utf8)
  }

  /// Commits every change in the working tree and returns the new commit's hash.
  @discardableResult
  func commit() throws -> String {
    try git(["add", "--all"])
    try git(["commit", "--quiet", "--allow-empty", "-m", "Fixture"])
    return try git(["rev-parse", "HEAD"])
  }

  /// Runs Git in the repository with a fixed identity, failing the test on an unexpected error.
  @discardableResult
  func git(_ arguments: [String]) throws -> String {
    let result = try ValidationProcess(workingDirectory: root.path).capture(
      ["git"] + arguments,
      environment: [
        "GIT_AUTHOR_NAME": "Sam Deane", "GIT_AUTHOR_EMAIL": "sam@elegantchaos.com",
        "GIT_COMMITTER_NAME": "Sam Deane", "GIT_COMMITTER_EMAIL": "sam@elegantchaos.com",
      ])
    guard result.status == 0 else { throw ToolError("Fixture Git failed: \(result.stderr)") }
    return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Deletes the repository and anything created beside it.
  func remove() {
    try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
  }
}
