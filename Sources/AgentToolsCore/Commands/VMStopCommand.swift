// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Stops a clone and deletes it.
struct VMStopCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "stop",
    abstract: "Stop a clone and delete it.",
    discussion: "Refuses the base image, and any VM whose name does not start with agt-."
  )

  /// The clone to stop.
  @OptionGroup var clone: VMCloneOptions

  /// Whether to keep the stopped clone.
  @Flag(help: "Leave the clone stopped instead of deleting it.")
  var keep = false

  /// Stops the clone if it is running, then deletes it unless asked to keep it.
  mutating func run() async throws {
    let settings = try await VMSettings.load(repoPath: FileManager.default.currentDirectoryPath, homeDirectory: FileManager.default.homeDirectoryForCurrentUser)
    let tart = try Tart.current()
    let name = try clone.resolve(tart: tart, settings: settings, running: false)
    if try tart.list().contains(where: { $0.name == name && $0.isRunning }) {
      try tart.stop(name)
    }
    if keep {
      print("Stopped \(name).")
    } else {
      try tart.delete(name)
      print("Stopped and deleted \(name).")
    }
  }
}
