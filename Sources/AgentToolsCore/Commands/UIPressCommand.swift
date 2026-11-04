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
    abstract: "Press an element, or focus a field, by its exact title, identifier or description.",
    discussion: """
      Searches breadth first, menus included, and presses the match nearest the application element, without moving \
      the pointer. An element with no press action that can take focus, such as a text or search field, is focused \
      instead, so that type goes to it. If the field refuses focus, it is clicked in the centre of its visible part; \
      a field scrolled out of view is an error.
      """
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
    try await SelfResponsibleRunner.run(task: "press an element") {
      try UIPermission.accessibility.require()
      let root = try SystemAccessibilityElement.application(processIdentifier: app.target.runningApplication().processIdentifier)
      guard let element = query.firstMatch(in: root, maximumDepth: depth) else {
        throw ToolError("No element within \(depth) levels has the title, identifier or description '\(text)'\(role.map { " and the role \($0)" } ?? "").")
      }
      let role = element.attributes.role ?? "element"
      switch ElementActivation.choose(actions: element.actions, canFocus: element.canFocus) {
        case .press:
          try element.press()
          print("Pressed \(role) '\(text)'.")
        case .focus:
          if element.focus() {
            print("Focused \(role) '\(text)'.")
            return
          }
          let point = try ElementActivation.clickPoint(frame: element.frame, clips: element.clips)
          try UIPermission.eventPosting.require()
          try await EventSynthesizer().click(at: point, button: .left, count: 1, modifiers: [])
          guard element.isFocused else {
            throw ToolError("\(role) '\(text)' refused focus, and clicking it at (\(Int(point.x)), \(Int(point.y))) did not focus it either.")
          }
          print("Focused \(role) '\(text)' by clicking it at (\(Int(point.x)), \(Int(point.y))).")
      }
    }
  }
}
