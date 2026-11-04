// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import CoreGraphics

/// A mouse button `agt ui` can press, with the Core Graphics event types for it.
enum MouseButton: String, CaseIterable, ExpressibleByArgument {
  /// The primary button.
  case left

  /// The secondary button, which opens context menus.
  case right

  /// The Core Graphics button.
  var cgButton: CGMouseButton {
    switch self {
      case .left: .left
      case .right: .right
    }
  }

  /// The event type for pressing the button.
  var downType: CGEventType {
    switch self {
      case .left: .leftMouseDown
      case .right: .rightMouseDown
    }
  }

  /// The event type for releasing the button.
  var upType: CGEventType {
    switch self {
      case .left: .leftMouseUp
      case .right: .rightMouseUp
    }
  }

  /// The event type for moving the mouse with the button held.
  var dragType: CGEventType {
    switch self {
      case .left: .leftMouseDragged
      case .right: .rightMouseDragged
    }
  }
}
