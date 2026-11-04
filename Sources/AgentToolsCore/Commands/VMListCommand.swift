// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Lists the clones `agt vm` made.
struct VMListCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List the clones agt vm made, with their states."
  )

  /// Prints each clone's name and state.
  mutating func run() async throws {
    let clones = try Tart.current().list().filter { VMClone.isClone($0.name) }
    if clones.isEmpty {
      print("No clones.")
    }
    for clone in clones {
      print("\(clone.name)\t\(clone.state)")
    }
  }
}
