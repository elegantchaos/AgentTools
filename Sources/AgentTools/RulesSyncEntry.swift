// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/07/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Describes the synchronization state or completed action for one rules file.
struct RulesSyncEntry: Equatable {
  /// Possible synchronization states and actions.
  enum Status: String, Equatable {
    /// Both copies have identical content.
    case unchanged = "unchanged"

    /// A missing runtime copy was created.
    case copied = "copied to runtime"

    /// A divergent runtime copy was overwritten with shared content.
    case overwritten = "overwritten from shared"

    /// A runtime symlink was replaced with a regular copy.
    case replacedSymlink = "symlink replaced with copy"

    /// A runtime symlink will be replaced during synchronization.
    case symlink = "symlink; will replace with copy"

    /// The runtime file has no shared source and needs manual classification.
    case runtimeOnly = "runtime-only; review manually"

    /// Shared and runtime copies have different content.
    case drifted = "differs from shared"
  }

  /// Rules filename.
  let name: String

  /// Current synchronization status.
  let status: Status
}
