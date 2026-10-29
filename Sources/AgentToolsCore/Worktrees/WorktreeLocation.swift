// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Enforces the directory and feature-branch conventions for a new worktree.
struct WorktreeLocation {
  /// Absolute destination under the main checkout.
  let path: String

  /// New branch created for the worktree.
  let branch: String

  /// Validates a semantic name before deriving paths or passing it to Git.
  init(name: String, mainCheckout: String) throws {
    guard name.count <= 64, name.range(of: "^[a-z0-9]+(?:-[a-z0-9]+)*$", options: .regularExpression) != nil else {
      throw ToolError("Invalid worktree name '\(name)'. Use lowercase letters, digits and single hyphens between words, up to 64 characters.")
    }
    path = "\(mainCheckout)/.worktrees/\(name)"
    branch = "feature/\(name)"
  }
}
