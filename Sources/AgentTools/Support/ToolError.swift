// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// User-facing error for command failures.
struct ToolError: Error, CustomStringConvertible {
  /// Human-readable error description.
  let description: String

  /// Initializes with a user-facing message.
  init(_ description: String) {
    self.description = description
  }
}
