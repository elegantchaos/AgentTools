// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Carbon.HIToolbox
import CoreGraphics

/// The modifier keys held during a synthesised key press or mouse event, parsed from text such as `cmd+shift`.
struct ModifierKeys: OptionSet, Hashable {
  /// The raw bits.
  let rawValue: UInt8

  /// Command.
  static let command = ModifierKeys(rawValue: 1 << 0)

  /// Shift.
  static let shift = ModifierKeys(rawValue: 1 << 1)

  /// Option.
  static let option = ModifierKeys(rawValue: 1 << 2)

  /// Control.
  static let control = ModifierKeys(rawValue: 1 << 3)

  /// Function.
  static let function = ModifierKeys(rawValue: 1 << 4)

  /// Creates a set from its raw bits.
  init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Parses modifier names joined with `+`, such as `cmd+shift`.
  init(parsing text: String) throws(KeyParseError) {
    try self.init(names: Self.components(of: text))
  }

  /// Combines the modifiers called `names`, ignoring case.
  init(names: some Sequence<Substring>) throws(KeyParseError) {
    self = []
    for name in names {
      guard let modifier = Self.byName[name.lowercased()] else { throw .unknownModifier(String(name)) }
      insert(modifier)
    }
  }

  /// The equivalent Core Graphics event flags.
  var eventFlags: CGEventFlags {
    var flags: CGEventFlags = []
    for (modifier, flag) in [(Self.command, CGEventFlags.maskCommand), (.shift, .maskShift), (.option, .maskAlternate), (.control, .maskControl), (.function, .maskSecondaryFn)] where contains(modifier) {
      flags.insert(flag)
    }
    return flags
  }

  /// Key events that press these modifiers one at a time, each carrying the modifiers held so far.
  var pressStrokes: [KeyStroke] {
    var held: ModifierKeys = []
    return Self.keys.compactMap { modifier, key in
      guard contains(modifier) else { return nil }
      held.insert(modifier)
      return KeyStroke(keyCode: key, isDown: true, modifiers: held)
    }
  }

  /// Key events that release these modifiers in the reverse order of `pressStrokes`, each carrying those still held.
  var releaseStrokes: [KeyStroke] {
    var held = self
    return Self.keys.reversed().compactMap { modifier, key in
      guard contains(modifier) else { return nil }
      held.remove(modifier)
      return KeyStroke(keyCode: key, isDown: false, modifiers: held)
    }
  }

  /// Splits `text` at each `+`, rejecting it when it or any component is empty.
  static func components(of text: String) throws(KeyParseError) -> [Substring] {
    let components = text.split(separator: "+", omittingEmptySubsequences: false)
    guard !components.contains(where: \.isEmpty) else { throw .empty(text) }
    return components
  }
}

extension ModifierKeys {
  /// Each modifier and the left-hand key that produces it, in the order they are pressed.
  private static let keys: [(ModifierKeys, CGKeyCode)] = [
    (.command, CGKeyCode(kVK_Command)),
    (.shift, CGKeyCode(kVK_Shift)),
    (.option, CGKeyCode(kVK_Option)),
    (.control, CGKeyCode(kVK_Control)),
    (.function, CGKeyCode(kVK_Function)),
  ]

  /// Modifier names and their aliases, in lower case.
  private static let byName: [String: ModifierKeys] = [
    "cmd": .command, "command": .command,
    "shift": .shift,
    "opt": .option, "option": .option, "alt": .option,
    "ctrl": .control, "control": .control,
    "fn": .function,
  ]
}
