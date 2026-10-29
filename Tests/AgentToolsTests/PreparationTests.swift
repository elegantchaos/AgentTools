// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Testing

@testable import AgentToolsCore

/// Exercises preparation entry points and dependency permission diagnostics.
struct PreparationTests {
  /// Git-only repositories still support worktree creation's default preparation call.
  @Test func defaultPreparationHandlesRepositoriesWithoutSwift() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent(".build/tmp/prepare-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
    try await PrepareCommand.prepare(repoPath: root.path)
  }

  /// Both operations must be available from the installed command's entry point.
  @Test(arguments: [["prepare", "--plan"], ["worktree", "create", "dependency-preparation", "--base", "HEAD"]])
  func preparationCommandsAreAvailable(arguments: [String]) throws {
    _ = try AgentToolsCommand.parseAsRoot(arguments)
  }

  /// A failed dependency checkout must name the recovery operation.
  @Test func dependencyPermissionFailureNamesPreparation() {
    let output = """
      error: 'chaostesting': Failed to clone repository https://github.com/elegantchaos/ChaosTesting.git:
      fatal: could not write config file /repo/.build/agt/checkouts/ChaosTesting/.git/config: Operation not permitted
      """
    #expect(ValidationOutput.failureDiagnostics(output).contains { $0.contains("agt prepare") })
  }

  /// Only dependency Git configuration and hooks denials should suggest preparation.
  @Test(arguments: [
    ("fatal: clone failed: /repo/checkouts/Core/.git/config.lock: Permission denied", true),
    ("fatal: cannot copy template to '/repo/checkouts/Core/.git/hooks/commit-msg.sample': Operation not permitted", true),
    ("fatal: clone failed: /repo/checkouts/Core/.git/configuration: Operation not permitted", false),
    ("fatal: could not write config file /repo/.git/config: Operation not permitted", false),
    ("error: clone failed: /repo/checkouts/Core/Sources/config: Permission denied", false),
    ("error: Failed to clone repository: Could not resolve host github.com", false),
  ])
  func metadataPermissionClassification(output: String, expected: Bool) {
    let requiresPreparation = !ValidationOutput.dependencyPreparationAdvice(output).isEmpty
    #expect(requiresPreparation == expected)
  }
}
