// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import CoreGraphics

/// Posts synthetic mouse and keyboard events into the login session, as if they came from the hardware.
///
/// Coordinates are screen points from the top left of the main display, matching the frames `agt ui tree` reports
/// and the pixels of a display screenshot. Each gesture pauses briefly between events, because applications can
/// drop or merge events that arrive faster than a person could produce them. Posting needs the Accessibility
/// permission; without it macOS discards the events silently, so commands check `UIPermission.eventPosting` first.
struct EventSynthesizer {
  /// The pause between the events of one gesture.
  static let pause = Duration.milliseconds(30)

  /// The number of intermediate positions in a drag.
  static let dragSteps = 20

  /// Moves the pointer to `point` and clicks `button` `count` times, holding `modifiers`.
  func click(at point: CGPoint, button: MouseButton, count: Int, modifiers: ModifierKeys) async throws {
    try await move(to: point)
    try post(modifiers.pressStrokes)
    for click in 1...count {
      try post(mouse: button.downType, at: point, button: button, clickState: click, modifiers: modifiers)
      try post(mouse: button.upType, at: point, button: button, clickState: click, modifiers: modifiers)
      try await Task.sleep(for: Self.pause)
    }
    try post(modifiers.releaseStrokes)
  }

  /// Presses `button` at `start`, moves to `end` in small steps, and releases it there, holding `modifiers`.
  func drag(from start: CGPoint, to end: CGPoint, button: MouseButton, modifiers: ModifierKeys) async throws {
    try await move(to: start)
    try post(modifiers.pressStrokes)
    try post(mouse: button.downType, at: start, button: button, clickState: 1, modifiers: modifiers)
    for step in 1...Self.dragSteps {
      let fraction = Double(step) / Double(Self.dragSteps)
      let point = CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
      try await Task.sleep(for: Self.pause)
      try post(mouse: button.dragType, at: point, button: button, clickState: 1, modifiers: modifiers)
    }
    try await Task.sleep(for: Self.pause)
    try post(mouse: button.upType, at: end, button: button, clickState: 1, modifiers: modifiers)
    try post(modifiers.releaseStrokes)
  }

  /// Moves the pointer to `point` and scrolls by the given points; positive values scroll down and right.
  func scroll(at point: CGPoint, down: Int32, right: Int32) async throws {
    try await move(to: point)
    // Wheel deltas point the other way: a positive wheel value moves the content towards the top left.
    try post(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: -down, wheel2: -right, wheel3: 0), modifiers: [])
  }

  /// Presses a key combination: its modifiers go down, the key goes down and up, then the modifiers come up.
  func press(_ combo: KeyCombo) async throws {
    try post(combo.keystrokes)
    try await Task.sleep(for: Self.pause)
  }

  /// Types `text` character by character, independent of the keyboard layout. Newlines press Return.
  func type(_ text: String) async throws {
    for character in text {
      if character.isNewline {
        try await press(KeyCombo(keyCode: KeyCombo.returnKeyCode, modifiers: []))
        continue
      }
      let units = Array(String(character).utf16)
      for isDown in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: isDown)
        event?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        try post(event, modifiers: [])
      }
      try await Task.sleep(for: Self.pause)
    }
  }
}

extension EventSynthesizer {
  /// Moves the pointer to `point` and waits for applications to see it, so a click lands where hover state expects.
  private func move(to point: CGPoint) async throws {
    try post(CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left), modifiers: [])
    try await Task.sleep(for: Self.pause)
  }

  /// Posts one mouse event of `type` at `point`.
  private func post(mouse type: CGEventType, at point: CGPoint, button: MouseButton, clickState: Int, modifiers: ModifierKeys) throws {
    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button.cgButton)
    event?.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
    try post(event, modifiers: modifiers)
  }

  /// Posts each keyboard event in `strokes`, in order, with the modifiers it records as held.
  private func post(_ strokes: [KeyStroke]) throws {
    for stroke in strokes {
      try post(CGEvent(keyboardEventSource: nil, virtualKey: stroke.keyCode, keyDown: stroke.isDown), modifiers: stroke.modifiers)
    }
  }

  /// Posts `event` with exactly `modifiers` held, or throws when it could not be created.
  ///
  /// An event created without a source takes its flags from the session's current modifier state, which earlier
  /// synthetic events leave behind; typing after `cmd+n` would otherwise arrive as Command shortcuts. Setting the
  /// flags on every event keeps each command independent of the ones before it.
  private func post(_ event: CGEvent?, modifiers: ModifierKeys) throws {
    guard let event else { throw ToolError("Could not create an input event.") }
    event.flags = modifiers.eventFlags
    event.post(tap: .cghidEventTap)
  }
}
