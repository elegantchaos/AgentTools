// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// The outcome of configuring one runtime's sandbox.
struct SandboxConfigurationEntry: Equatable {
  /// The runtime whose configuration was checked.
  let runtime: AgentRuntime

  /// The configuration file.
  let file: URL

  /// Whether the file changed.
  let status: Status

  /// A one-line description for terminal output.
  var summary: String {
    switch status {
      case .updated: "\(runtime.rawValue): added the Swift validation caches to \(file.path)"
      case .unchanged: "\(runtime.rawValue): \(file.path) already allows the Swift validation caches"
    }
  }
}

extension SandboxConfigurationEntry {
  /// Whether configuring changed a file.
  enum Status: Equatable {
    /// Paths were added.
    case updated

    /// Every path was already present.
    case unchanged
  }
}
