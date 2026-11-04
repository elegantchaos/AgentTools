// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// An element of an accessibility hierarchy, as `AccessibilityNode` and `AccessibilityQuery` walk it.
///
/// `SystemAccessibilityElement` reads a running application; tests supply in-memory elements.
protocol AccessibilityElement {
  /// The element's attributes.
  var attributes: AccessibilityAttributes { get }

  /// The element's children, in the order the application reports them.
  var children: [Self] { get }
}
