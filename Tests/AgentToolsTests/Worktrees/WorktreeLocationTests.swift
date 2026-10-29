// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentToolsCore

/// Verifies worktree naming and path containment before Git can modify anything.
struct WorktreeLocationTests {
  /// The semantic name determines both the repository-local path and feature branch.
  @Test func namesDetermineLocationAndBranch() throws {
    let location = try WorktreeLocation(name: "dependency-preparation", mainCheckout: "/projects/Example")
    #expect(location.path == "/projects/Example/.worktrees/dependency-preparation")
    #expect(location.branch == "feature/dependency-preparation")
  }

  /// Rejects option injection, traversal and ambiguous names before any filesystem access.
  @Test(arguments: ["", "../escape", "a/b", "Uppercase", "a--b", "-option", "trailing-", "two words", ".hidden", "bad\nname", "trailing\n", String(repeating: "a", count: 65)])
  func unsafeNamesAreRejected(name: String) {
    #expect(throws: ToolError.self) {
      _ = try WorktreeLocation(name: name, mainCheckout: "/projects/Example")
    }
  }
}
