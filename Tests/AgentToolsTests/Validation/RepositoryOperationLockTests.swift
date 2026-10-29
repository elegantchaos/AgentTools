// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Verifies that validation and preparation cannot concurrently own dependency directories.
struct RepositoryOperationLockTests {
  /// Planning reports the owner, waits for release, and replaces the diagnostic metadata only after acquisition.
  @Test func planningWaitsForTheNamedBackgroundOwner() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent(".build/tmp/lock-wait-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    var owner: RepositoryOperationLock? = try RepositoryOperationLock(repoPath: root.path, operation: "background validation", background: true)
    var message = ""
    let next = try RepositoryOperationLock(repoPath: root.path, operation: "preparation planning", wait: true) { waiting in
      message = waiting
      owner = nil
    }
    defer { withExtendedLifetime(next) {} }
    #expect(owner == nil)
    #expect(message.contains("background validation"))
    #expect(message.contains("PID \(ProcessInfo.processInfo.processIdentifier)"))
    #expect(message.contains("agt validate --status"))
    #expect(message.contains("agt validate --wait"))
    let data = try Data(contentsOf: URL(fileURLWithPath: ValidationPaths(repoPath: root.path).lockPath))
    let metadata = try JSONDecoder().decode(RepositoryOperationOwner.self, from: data)
    #expect(metadata.operation == "preparation planning")
    #expect(metadata.background == false)
    #expect(metadata.pid == ProcessInfo.processInfo.processIdentifier)
  }

  /// Lock contention fails promptly, and releasing ownership allows the next operation.
  @Test func ownershipIsExclusiveAndReleased() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent(".build/tmp/lock-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    do {
      let lock = try RepositoryOperationLock(repoPath: root.path)
      defer { withExtendedLifetime(lock) {} }
      #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(".build/agt/lock").path))
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
