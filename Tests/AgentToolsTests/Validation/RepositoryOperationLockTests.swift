// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Verifies that validation and preparation cannot concurrently own dependency directories.
struct RepositoryOperationLockTests {
  /// Lock contention fails promptly, and releasing ownership allows the next operation.
  @Test func ownershipIsExclusiveAndReleased() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent(".build/tmp/lock-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    do {
      let lock = try RepositoryOperationLock(repoPath: root.path)
      defer { withExtendedLifetime(lock) {} }
      #expect(throws: ToolError.self) {
        _ = try RepositoryOperationLock(repoPath: root.path)
      }
      _ = try ValidationPaths.prepare(repoPath: root.path, clean: true)
      #expect(throws: ToolError.self) {
        _ = try RepositoryOperationLock(repoPath: root.path)
      }
    }
    let next = try RepositoryOperationLock(repoPath: root.path)
    withExtendedLifetime(next) {}
  }
}
