// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

@testable import AgentToolsCore

/// An in-memory accessibility element, so tree capture and searching can be tested without a running application.
struct FakeElement: AccessibilityElement, Equatable {
  /// The element's attributes.
  let attributes: AccessibilityAttributes

  /// The element's children.
  let children: [FakeElement]

  /// Creates an element with `attributes` and `children`.
  init(_ attributes: AccessibilityAttributes, children: [FakeElement] = []) {
    self.attributes = attributes
    self.children = children
  }
}
