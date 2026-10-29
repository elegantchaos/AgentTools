// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Keeps Xcode's default scheme independent of a linked worktree's semantic directory name.
struct WorktreeDiscoveryTests {
  /// Models Git's gitdir pointer and commondir files without creating or mutating a real repository.
  @Test(arguments: [true, false])
  func linkedWorktreesUseTheMainRepositoryName(absolutePointer: Bool) throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent(".build/tmp/discovery-\(UUID().uuidString)/Bookish")
    defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
    let worktree = root.appendingPathComponent(".worktrees/some-task")
    let metadata = root.appendingPathComponent(".git/worktrees/some-task")
    try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: metadata, withIntermediateDirectories: true)
    try "gitdir: \(absolutePointer ? metadata.path : "../../.git/worktrees/some-task")\n".write(to: worktree.appendingPathComponent(".git"), atomically: true, encoding: .utf8)
    try "../..\n".write(to: metadata.appendingPathComponent("commondir"), atomically: true, encoding: .utf8)
    #expect(ValidationDiscovery.repoName(worktree.path) == "Bookish")
  }
}
