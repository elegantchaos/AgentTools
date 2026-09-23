// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentTools

/// Tests linking discovered skills into runtime skill directories.
struct SkillsPublicToolTests {
  /// Defaults to each runtime's home directory when no overrides are set.
  @Test func defaultDestinationsUseRuntimeHomes() {
    let home = URL(fileURLWithPath: "/home/user")

    let destinations = SkillLinkDestination.defaults(environment: [:], homeDirectory: home)

    #expect(
      destinations == [
        .init(label: "codex", directory: URL(fileURLWithPath: "/home/user/.codex/skills")),
        .init(label: "claude", directory: URL(fileURLWithPath: "/home/user/.claude/skills")),
      ]
    )
  }

  /// Honours CODEX_HOME and CLAUDE_CONFIG_DIR overrides.
  @Test func destinationsHonourRuntimeHomeOverrides() {
    let destinations = SkillLinkDestination.defaults(
      environment: ["CODEX_HOME": "/custom/codex", "CLAUDE_CONFIG_DIR": "/custom/claude"],
      homeDirectory: URL(fileURLWithPath: "/home/user")
    )

    #expect(
      destinations == [
        .init(label: "codex", directory: URL(fileURLWithPath: "/custom/codex/skills")),
        .init(label: "claude", directory: URL(fileURLWithPath: "/custom/claude/skills")),
      ]
    )
  }

  /// Links every discovered skill into every destination.
  @Test func linksSkillsIntoEveryDestination() throws {
    try withTemporarySkillsRepository { repoRoot, destinations in
      try SkillsPublicTool(repoRoot: repoRoot, linkDestinations: destinations).runLink()

      let expected = repoRoot.appendingPathComponent("skills/refresh-skill").path
      for destination in destinations {
        let link = destination.directory.appendingPathComponent("refresh")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == expected)
      }
    }
  }

  /// Leaves a real directory in place rather than deleting it to create a link.
  @Test func refusesToReplaceRealDirectory() throws {
    try withTemporarySkillsRepository { repoRoot, destinations in
      let existing = destinations[0].directory.appendingPathComponent("refresh")
      let marker = existing.appendingPathComponent("SKILL.md")
      try write("user skill", to: marker)

      #expect(throws: ToolError.self) {
        try SkillsPublicTool(repoRoot: repoRoot, linkDestinations: destinations).runLink()
      }
      #expect(try String(contentsOf: marker, encoding: .utf8) == "user skill")
    }
  }

  /// Creates a repository with one repo-local skill and two empty destinations.
  private func withTemporarySkillsRepository(
    _ body: (URL, [SkillLinkDestination]) throws -> Void
  ) throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .resolvingSymlinksInPath()
    let repoRoot = root.appendingPathComponent("repo", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try write(
      "---\nname: refresh\n---\n",
      to: repoRoot.appendingPathComponent("skills/refresh-skill/SKILL.md")
    )
    let destinations = [
      SkillLinkDestination(label: "codex", directory: root.appendingPathComponent("codex/skills")),
      SkillLinkDestination(label: "claude", directory: root.appendingPathComponent("claude/skills")),
    ]
    try body(repoRoot, destinations)
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
