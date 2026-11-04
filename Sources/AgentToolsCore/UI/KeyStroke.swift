// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import CoreGraphics

/// One keyboard event `EventSynthesizer` posts: a key going down or up, with the modifiers held as it happens.
///
/// Gestures are built as lists of these, so that the order of modifier presses and releases can be checked without
/// posting events.
struct KeyStroke: Equatable {
  /// The virtual key code.
  let keyCode: CGKeyCode

  /// Whether the key goes down, rather than up.
  let isDown: Bool

  /// The modifiers held once this event has happened.
  let modifiers: ModifierKeys
}
