// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import CoreGraphics

/// How `agt ui press` activates an element it found.
///
/// Elements with a press action, such as buttons and menu items, are pressed. Elements without one that can take
/// keyboard focus, such as text and search fields, are focused instead, so that a following `agt ui type` goes to
/// them. Anything else is offered the press action anyway, which reports the element's refusal.
enum ElementActivation: Equatable {
  /// Perform the press action.
  case press

  /// Set the element's focus.
  case focus

  /// Returns the activation for an element with the accessibility actions `actions`, which can take focus when
  /// `canFocus` is set.
  static func choose(actions: [String], canFocus: Bool) -> ElementActivation {
    !actions.contains("AXPress") && canFocus ? .focus : .press
  }

  /// Returns the point to click to focus an element with `frame`, as a fallback when setting focus is refused: the
  /// centre of the part of the frame inside every rectangle in `clips`, such as its window and enclosing scroll areas.
  ///
  /// Throws when the element has no frame, or none of it is visible, rather than clicking somewhere else.
  static func clickPoint(frame: CGRect?, clips: [CGRect]) throws -> CGPoint {
    guard let frame, !frame.isEmpty else {
      throw ToolError("The element has no frame to click.")
    }
    let visible = clips.reduce(frame) { $0.intersection($1) }
    guard !visible.isNull, !visible.isEmpty else {
      let origin = "(\(Int(frame.minX)), \(Int(frame.minY)))"
      throw ToolError("The element's frame at \(origin), \(Int(frame.width))x\(Int(frame.height)) points, is outside the visible part of its window; scroll it into view and try again.")
    }
    return CGPoint(x: visible.midX, y: visible.midY)
  }
}
