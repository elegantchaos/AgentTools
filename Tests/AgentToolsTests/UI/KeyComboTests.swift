// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Carbon.HIToolbox
import CoreGraphics
import Testing

@testable import AgentToolsCore

/// Verifies how key-combination text such as `cmd+shift+n` becomes a key code and modifiers.
struct KeyComboTests {
  /// Named keys and single characters map to their US ANSI virtual key codes.
  @Test(arguments: [
    ("return", kVK_Return),
    ("enter", kVK_Return),
    ("escape", kVK_Escape),
    ("esc", kVK_Escape),
    ("tab", kVK_Tab),
    ("space", kVK_Space),
    ("delete", kVK_Delete),
    ("backspace", kVK_Delete),
    ("forwarddelete", kVK_ForwardDelete),
    ("left", kVK_LeftArrow),
    ("pagedown", kVK_PageDown),
    ("f5", kVK_F5),
    ("a", kVK_ANSI_A),
    ("z", kVK_ANSI_Z),
    ("7", kVK_ANSI_7),
    (",", kVK_ANSI_Comma),
    ("/", kVK_ANSI_Slash),
  ])
  func keyNamesMapToKeyCodes(name: String, code: Int) throws {
    let combo = try KeyCombo(parsing: name)
    #expect(combo == KeyCombo(keyCode: CGKeyCode(code), modifiers: []))
  }

  /// Modifiers before the key are collected, in any order and case, with their aliases.
  @Test func modifiersPrecedeTheKey() throws {
    let combo = try KeyCombo(parsing: "Shift+CMD+n")
    #expect(combo == KeyCombo(keyCode: CGKeyCode(kVK_ANSI_N), modifiers: [.command, .shift]))
    let aliases = try KeyCombo(parsing: "command+option+alt+control+ctrl+fn+opt+f1")
    #expect(aliases.modifiers == [.command, .option, .control, .function])
  }

  /// Unknown keys, unknown modifiers and empty components are reported by name.
  @Test(arguments: [
    ("cmd+nosuchkey", KeyParseError.unknownKey("nosuchkey")),
    ("hyper+a", KeyParseError.unknownModifier("hyper")),
    ("cmd+", KeyParseError.empty("cmd+")),
    ("", KeyParseError.empty("")),
    ("cmd", KeyParseError.unknownKey("cmd")),
  ])
  func invalidCombosAreRejected(text: String, error: KeyParseError) {
    #expect(throws: error) { try KeyCombo(parsing: text) }
  }

  /// A combination presses its modifiers, then the key, then releases the modifiers in reverse, so nothing stays held.
  @Test func keystrokesPressAndReleaseModifiersAroundTheKey() throws {
    let combo = try KeyCombo(parsing: "shift+cmd+n")
    let n = CGKeyCode(kVK_ANSI_N)
    #expect(
      combo.keystrokes == [
        KeyStroke(keyCode: CGKeyCode(kVK_Command), isDown: true, modifiers: [.command]),
        KeyStroke(keyCode: CGKeyCode(kVK_Shift), isDown: true, modifiers: [.command, .shift]),
        KeyStroke(keyCode: n, isDown: true, modifiers: [.command, .shift]),
        KeyStroke(keyCode: n, isDown: false, modifiers: [.command, .shift]),
        KeyStroke(keyCode: CGKeyCode(kVK_Shift), isDown: false, modifiers: [.command]),
        KeyStroke(keyCode: CGKeyCode(kVK_Command), isDown: false, modifiers: []),
      ])
  }

  /// Every modifier has a key to press, and an unmodified key is just a press and a release.
  @Test func everyModifierHasAKeyAndPlainKeysNeedNoModifierEvents() throws {
    let all: ModifierKeys = [.command, .shift, .option, .control, .function]
    #expect(all.pressStrokes.map(\.keyCode) == [kVK_Command, kVK_Shift, kVK_Option, kVK_Control, kVK_Function].map { CGKeyCode($0) })
    #expect(all.releaseStrokes.last?.modifiers == [])
    #expect(try KeyCombo(parsing: "return").keystrokes.count == 2)
  }

  /// Modifier sets parse on their own for mouse commands, and translate to event flags.
  @Test func modifierKeysParseAndProduceEventFlags() throws {
    let modifiers = try ModifierKeys(parsing: "cmd+shift")
    #expect(modifiers == [.command, .shift])
    #expect(modifiers.eventFlags == [.maskCommand, .maskShift])
    #expect(throws: KeyParseError.unknownModifier("a")) { try ModifierKeys(parsing: "cmd+a") }
  }
}
