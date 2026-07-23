// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/07/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentTools

/// Tests one-way synchronization from shared rules to runtime copies.
struct RulesPublicToolTests {
  /// Replaces a matching runtime symlink with a regular file.
  @Test func replacesMatchingSymlinkWithCopy() throws {
    try withTemporaryRulesDirectories { repoRoot, runtimeRulesDirectory in
      let sharedRule = repoRoot.appendingPathComponent("codex/rules/git.rules")
      let runtimeRule = runtimeRulesDirectory.appendingPathComponent("git.rules")
      try write("shared", to: sharedRule)
      try FileManager.default.createDirectory(
        at: runtimeRulesDirectory,
        withIntermediateDirectories: true
      )
      try FileManager.default.createSymbolicLink(
        at: runtimeRule,
        withDestinationURL: sharedRule
      )

      let report = try RulesPublicTool(
        repoRoot: repoRoot,
        runtimeRulesDirectory: runtimeRulesDirectory
      ).synchronize()

      #expect(report.entries == [.init(name: "git.rules", status: .replacedSymlink)])
      #expect(
        try String(contentsOf: runtimeRule, encoding: .utf8)
          == RulesPublicTool.managedHeader + "shared"
      )
      #expect(try runtimeRule.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == false)
    }
  }

  /// Reports a runtime symlink without changing it during status inspection.
  @Test func statusReportsSymlinkWithoutReplacingIt() throws {
    try withTemporaryRulesDirectories { repoRoot, runtimeRulesDirectory in
      let sharedRule = repoRoot.appendingPathComponent("codex/rules/git.rules")
      let runtimeRule = runtimeRulesDirectory.appendingPathComponent("git.rules")
      try write("shared", to: sharedRule)
      try FileManager.default.createDirectory(
        at: runtimeRulesDirectory,
        withIntermediateDirectories: true
      )
      try FileManager.default.createSymbolicLink(
        at: runtimeRule,
        withDestinationURL: sharedRule
      )

      let report = try RulesPublicTool(
        repoRoot: repoRoot,
        runtimeRulesDirectory: runtimeRulesDirectory
      ).inspect()

      #expect(report.entries == [.init(name: "git.rules", status: .symlink)])
      #expect(try runtimeRule.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
    }
  }

  /// Overwrites a divergent runtime file with the canonical shared content.
  @Test func overwritesRuntimeEdit() throws {
    try withTemporaryRulesDirectories { repoRoot, runtimeRulesDirectory in
      let sharedRule = repoRoot.appendingPathComponent("codex/rules/git.rules")
      let runtimeRule = runtimeRulesDirectory.appendingPathComponent("git.rules")
      try write("shared", to: sharedRule)
      try write("runtime edit", to: runtimeRule)

      let report = try RulesPublicTool(
        repoRoot: repoRoot,
        runtimeRulesDirectory: runtimeRulesDirectory
      ).synchronize()

      #expect(report.entries == [.init(name: "git.rules", status: .overwritten)])
      #expect(
        try String(contentsOf: runtimeRule, encoding: .utf8)
          == RulesPublicTool.managedHeader + "shared"
      )
    }
  }

  /// Copies a missing shared rule into the runtime directory.
  @Test func copiesMissingRuntimeRule() throws {
    try withTemporaryRulesDirectories { repoRoot, runtimeRulesDirectory in
      let sharedRule = repoRoot.appendingPathComponent("codex/rules/git.rules")
      let runtimeRule = runtimeRulesDirectory.appendingPathComponent("git.rules")
      try write("shared", to: sharedRule)

      let report = try RulesPublicTool(
        repoRoot: repoRoot,
        runtimeRulesDirectory: runtimeRulesDirectory
      ).synchronize()

      #expect(report.entries == [.init(name: "git.rules", status: .copied)])
      #expect(
        try String(contentsOf: runtimeRule, encoding: .utf8)
          == RulesPublicTool.managedHeader + "shared"
      )
    }
  }

  /// Reports runtime-only files without deleting or importing them.
  @Test func preservesRuntimeOnlyFile() throws {
    try withTemporaryRulesDirectories { repoRoot, runtimeRulesDirectory in
      let runtimeRule = runtimeRulesDirectory.appendingPathComponent("default.rules")
      try write("manual", to: runtimeRule)
      let tool = RulesPublicTool(
        repoRoot: repoRoot,
        runtimeRulesDirectory: runtimeRulesDirectory
      )

      let report = try tool.synchronize()

      #expect(report.entries == [.init(name: "default.rules", status: .runtimeOnly)])
      #expect(try String(contentsOf: runtimeRule, encoding: .utf8) == "manual")
    }
  }

  /// Rejects a repository-side default file because it must remain runtime-only.
  @Test func rejectsSharedDefaultRules() throws {
    try withTemporaryRulesDirectories { repoRoot, runtimeRulesDirectory in
      let sharedDefault = repoRoot.appendingPathComponent("codex/rules/default.rules")
      try write("shared default", to: sharedDefault)
      let tool = RulesPublicTool(
        repoRoot: repoRoot,
        runtimeRulesDirectory: runtimeRulesDirectory
      )

      do {
        _ = try tool.synchronize()
        Issue.record("Expected a shared default.rules file to be rejected.")
      } catch let error as ToolError {
        #expect(error.description.contains("default.rules"))
      }
    }
  }

  /// Detects drift without changing the runtime file.
  @Test func statusReportsDriftWithoutOverwriting() throws {
    try withTemporaryRulesDirectories { repoRoot, runtimeRulesDirectory in
      let sharedRule = repoRoot.appendingPathComponent("codex/rules/git.rules")
      let runtimeRule = runtimeRulesDirectory.appendingPathComponent("git.rules")
      try write("shared", to: sharedRule)
      try write("runtime edit", to: runtimeRule)
      let tool = RulesPublicTool(
        repoRoot: repoRoot,
        runtimeRulesDirectory: runtimeRulesDirectory
      )

      let report = try tool.inspect()

      #expect(report.entries == [.init(name: "git.rules", status: .drifted)])
      #expect(try String(contentsOf: runtimeRule, encoding: .utf8) == "runtime edit")
    }
  }

  /// Creates isolated shared and runtime rule directories for one test.
  private func withTemporaryRulesDirectories(
    _ body: (URL, URL) throws -> Void
  ) throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let repoRoot = root.appendingPathComponent("repo", isDirectory: true)
    let runtimeRulesDirectory = root.appendingPathComponent("runtime", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(
      at: repoRoot.appendingPathComponent("codex/rules"),
      withIntermediateDirectories: true
    )
    try body(repoRoot, runtimeRulesDirectory)
  }

  /// Writes UTF-8 test content, creating its parent directory when needed.
  private func write(_ contents: String, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }
}
