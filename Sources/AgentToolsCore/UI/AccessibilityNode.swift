// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// A snapshot of an accessibility element and its descendants, down to a depth limit, for `agt ui tree`.
///
/// Encodes as one JSON object per element: its attributes, then `children`. An element whose children were not
/// captured, because of the depth limit or because the caller chose not to expand it, reports their number as
/// `omittedChildren` instead.
struct AccessibilityNode: Encodable {
  /// The element's attributes.
  let attributes: AccessibilityAttributes

  /// The captured children; empty when there are none or they were omitted.
  let children: [AccessibilityNode]

  /// The number of children not captured, or `nil` when none were left out.
  let omittedChildren: Int?

  /// Captures `element` and up to `depth` levels below it, expanding only elements for which `shouldExpand` is true.
  init<Element: AccessibilityElement>(_ element: Element, depth: Int, expanding shouldExpand: (AccessibilityAttributes) -> Bool = { _ in true }) {
    attributes = element.attributes
    let elementChildren = element.children
    if depth > 0, shouldExpand(attributes) {
      children = elementChildren.map { AccessibilityNode($0, depth: depth - 1, expanding: shouldExpand) }
      omittedChildren = nil
    } else {
      children = []
      omittedChildren = elementChildren.isEmpty ? nil : elementChildren.count
    }
  }

  /// Writes the attributes and the children into one JSON object.
  func encode(to encoder: any Encoder) throws {
    try attributes.encode(to: encoder)
    var container = encoder.container(keyedBy: CodingKeys.self)
    if !children.isEmpty {
      try container.encode(children, forKey: .children)
    }
    try container.encodeIfPresent(omittedChildren, forKey: .omittedChildren)
  }
}

extension AccessibilityNode {
  /// The keys this type adds beside the attributes.
  private enum CodingKeys: String, CodingKey {
    /// The captured children.
    case children

    /// The count of children not captured.
    case omittedChildren
  }
}
