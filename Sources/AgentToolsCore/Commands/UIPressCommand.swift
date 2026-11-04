// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Presses an accessibility element found by its title, identifier or description.
struct UIPressCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "press",
    abstract: "Press an element by its exact title, identifier or description.",
    discussion: "Searches breadth first, menus included, and presses the match nearest the application element, without moving the pointer."
  )

  /// The text to match.
  @Argument(help: "Exact title, identifier or description of the element.")
  var text: String

  /// The role the element must have.
  @Option(help: "Role the element must have, such as AXButton or AXMenuItem.")
  var role: String?

  /// The application to search.
  @OptionGroup var app: UIAppOptions

  /// Levels below the application element to search.
  @Option(help: "Levels below the application to search.")
  var depth = 30

  /// The search the arguments describe.
  var query: AccessibilityQuery {
    AccessibilityQuery(text: text, role: role)
  }

  /// Finds and presses the element.
  mutating func run() async throws {
    try UIPermission.accessibility.require()
    let root = try SystemAccessibilityElement.application(processIdentifier: app.target.runningApplication().processIdentifier)
    guard let element = query.firstMatch(in: root, maximumDepth: depth) else {
      throw ToolError("No element within \(depth) levels has the title, identifier or description '\(text)'\(role.map { " and the role \($0)" } ?? "").")
    }
    try element.press()
    let attributes = element.attributes
    print("Pressed \(attributes.role ?? "element") '\(text)'.")
  }
}
