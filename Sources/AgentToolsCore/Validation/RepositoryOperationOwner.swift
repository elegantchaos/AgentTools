// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Diagnostic metadata written only while holding the checkout's operation lock.
struct RepositoryOperationOwner: Codable {
  /// Process holding the advisory lock.
  let pid: Int32

  /// Human-readable operation, such as validation or dependency preparation.
  let operation: String

  /// Whether the process is a background validation worker.
  let background: Bool

  /// Identifies the holder and the commands available to inspect background validation.
  var description: String {
    "\(operation) (PID \(pid))." + (background ? " Inspect it with `agt validate --status` or `agt validate --wait` from this checkout." : "")
  }
}
