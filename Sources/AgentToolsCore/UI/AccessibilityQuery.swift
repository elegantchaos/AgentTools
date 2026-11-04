// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Finds the accessibility element `agt ui press` acts on, by exact title, identifier or description.
struct AccessibilityQuery: Equatable {
  /// The text that must equal the element's title, identifier or description.
  let text: String

  /// The role the element must have, or `nil` to accept any.
  var role: String? = nil

  /// Returns the matching element nearest `root`, searching at most `maximumDepth` levels below it.
  ///
  /// The search is breadth first, so a window's own button wins over a same-named one deep inside a list.
  func firstMatch<Element: AccessibilityElement>(in root: Element, maximumDepth: Int) -> Element? {
    var level = [root]
    for depth in 0...max(maximumDepth, 0) {
      if let match = level.first(where: { matches($0.attributes) }) {
        return match
      }
      guard depth < maximumDepth else { break }
      level = level.flatMap(\.children)
    }
    return nil
  }

  /// Whether `attributes` has the role, if one is required, and the text as its title, identifier or description.
  private func matches(_ attributes: AccessibilityAttributes) -> Bool {
    guard role == nil || attributes.role == role else { return false }
    return [attributes.title, attributes.identifier, attributes.description].contains(text)
  }
}
