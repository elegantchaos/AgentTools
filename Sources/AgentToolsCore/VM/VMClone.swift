// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Names the throwaway clones `agt vm` makes, and decides which VMs it may stop and delete.
///
/// Every clone's name starts with `agt-`, which is how `agt vm list` finds them and why `agt vm stop` refuses any
/// other VM. The base image is refused by name as well, in case it was itself given the prefix.
enum VMClone {
  /// The prefix of every clone's name.
  static let prefix = "agt-"

  /// Returns a new clone name for `base`, such as `agt-golden-gate-3fa94c`.
  static func generatedName(base: String) -> String {
    "\(prefix)\(base)-\(UUID().uuidString.prefix(6).lowercased())"
  }

  /// Returns `true` when `name` is one of the clones' names.
  static func isClone(_ name: String) -> Bool {
    name.hasPrefix(prefix) && name.count > prefix.count
  }

  /// Throws unless `name` is a clone that may be stopped and deleted: never the base image, and never a VM that
  /// `agt vm` did not name.
  static func requireDisposable(_ name: String, base: String) throws {
    guard name != base else {
      throw ToolError("\(name) is the base image; agt vm never stops, deletes or runs it.")
    }
    guard isClone(name) else {
      throw ToolError("\(name) is not a clone made by agt vm, whose names start with \(prefix); stop or delete it with tart.")
    }
  }
}
