// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ApplicationServices
import ArgumentParser
import Foundation

/// Prints an application's accessibility tree as JSON.
struct UITreeCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "tree",
    abstract: "Print an application's accessibility tree as JSON.",
    discussion: """
      Each element lists its role, subrole, title, value, identifier, description, enabled state and frame in screen \
      points, where it has them, then its children. Elements whose children were left out, by the depth limit or \
      because they are menus, give their number as omittedChildren.
      """
  )

  /// The application to read.
  @OptionGroup var app: UIAppOptions

  /// Levels below the application element to include.
  @Option(help: "Levels below the application to include.")
  var depth = 12

  /// Whether to expand the menu bar.
  @Flag(help: "Include the contents of the menu bar.")
  var menus = false

  /// Rejects a negative depth.
  func validate() throws {
    guard depth >= 0 else { throw ValidationError("--depth must be zero or more.") }
  }

  /// Reads and prints the tree.
  mutating func run() async throws {
    try await SelfResponsibleRunner.run(task: "read the accessibility tree") {
      try UIPermission.accessibility.require()
      let root = try SystemAccessibilityElement.application(processIdentifier: app.target.runningApplication().processIdentifier)
      let menus = menus
      let node = AccessibilityNode(root, depth: depth) { menus || $0.role != kAXMenuBarRole }
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      print(String(decoding: try encoder.encode(node), as: UTF8.self))
    }
  }
}
