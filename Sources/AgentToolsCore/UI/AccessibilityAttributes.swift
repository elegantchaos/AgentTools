// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import CoreGraphics

/// The attributes `agt ui tree` reports for one accessibility element, and `agt ui press` matches against.
///
/// Each is `nil` when the element does not provide it, and is then left out of the JSON.
struct AccessibilityAttributes: Encodable, Equatable {
  /// The role, such as `AXButton`.
  var role: String?

  /// The subrole, such as `AXCloseButton`.
  var subrole: String?

  /// The visible title.
  var title: String?

  /// The value, such as a text field's contents or a checkbox's state, as text.
  var value: String?

  /// The developer-assigned identifier, such as a SwiftUI `accessibilityIdentifier`.
  var identifier: String?

  /// The accessibility description, which is often the only label an icon button has.
  var description: String?

  /// Whether the element accepts interaction.
  var enabled: Bool?

  /// The element's frame in screen points, from the top left of the main display.
  var frame: Frame?

  /// Creates attributes; every attribute is optional.
  init(
    role: String? = nil, subrole: String? = nil, title: String? = nil, value: String? = nil, identifier: String? = nil, description: String? = nil, enabled: Bool? = nil, frame: CGRect? = nil
  ) {
    self.role = role
    self.subrole = subrole
    self.title = title
    self.value = value
    self.identifier = identifier
    self.description = description
    self.enabled = enabled
    self.frame = frame.map(Frame.init)
  }
}

extension AccessibilityAttributes {
  /// A rectangle in screen points, encoded with named fields.
  struct Frame: Encodable, Equatable {
    /// The left edge.
    let x: Double

    /// The top edge.
    let y: Double

    /// The width.
    let width: Double

    /// The height.
    let height: Double

    /// Creates a frame from a Core Graphics rectangle.
    init(_ rect: CGRect) {
      x = rect.origin.x
      y = rect.origin.y
      width = rect.width
      height = rect.height
    }
  }
}
