// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Carbon.HIToolbox
import CoreGraphics
import Testing

@testable import AgentToolsCore

/// Verifies the command-line shapes of the `agt ui` commands.
struct UICommandParsingTests {
  /// A click defaults to one left click with no modifiers, and accepts a button, count and modifiers.
  @Test func clickOptions() throws {
    let plain = try UIClickCommand.parse(["100", "200.5"])
    #expect(plain.point == CGPoint(x: 100, y: 200.5))
    #expect(plain.button == .left)
    #expect(plain.count == 1)
    #expect(plain.modifiers == [])
    let fancy = try UIClickCommand.parse(["1", "2", "--button", "right", "--count", "2", "--modifiers", "cmd+shift"])
    #expect(fancy.button == .right)
    #expect(fancy.count == 2)
    #expect(fancy.modifiers == [.command, .shift])
  }

  /// Out-of-range click counts and unknown modifiers are rejected while parsing.
  @Test(arguments: [["1", "2", "--count", "0"], ["1", "2", "--count", "4"], ["1", "2", "--modifiers", "cmd+nope"]])
  func clickRejectsInvalidOptions(arguments: [String]) {
    #expect(throws: (any Error).self) { try UIClickCommand.parse(arguments) }
  }

  /// Scroll distances accept negative values, but not the one whose negation overflows.
  @Test func scrollRejectsUnnegatableDistances() throws {
    let scroll = try UIScrollCommand.parse(["1", "2", "--down", "-120", "--right", "40"])
    #expect(scroll.down == -120)
    #expect(scroll.right == 40)
    #expect(throws: (any Error).self) { try UIScrollCommand.parse(["1", "2", "--down", "\(Int32.min)"]) }
    #expect(throws: (any Error).self) { try UIScrollCommand.parse(["1", "2", "--right", "\(Int32.min)"]) }
  }

  /// A key command parses its combination when the command line is parsed.
  @Test func keyParsesItsCombo() throws {
    let command = try UIKeyCommand.parse(["cmd+n"])
    #expect(command.combo == KeyCombo(keyCode: CGKeyCode(kVK_ANSI_N), modifiers: [.command]))
    #expect(throws: (any Error).self) { try UIKeyCommand.parse(["cmd+nope"]) }
  }

  /// `--app` takes a process identifier when numeric, and a bundle identifier otherwise; without it the frontmost app is used.
  @Test func appTargets() throws {
    #expect(try UITreeCommand.parse([]).app.target == .frontmost)
    #expect(try UITreeCommand.parse(["--app", "4242"]).app.target == .processIdentifier(4242))
    #expect(try UITreeCommand.parse(["--app", "com.example.Bookish"]).app.target == .bundleIdentifier("com.example.Bookish"))
  }

  /// The tree defaults to a bounded depth without menus, and a press needs a query.
  @Test func treeAndPressDefaults() throws {
    let tree = try UITreeCommand.parse([])
    #expect(tree.depth == 12)
    #expect(tree.menus == false)
    let press = try UIPressCommand.parse(["Add Book", "--role", "AXButton"])
    #expect(press.query == AccessibilityQuery(text: "Add Book", role: "AXButton"))
    #expect(throws: (any Error).self) { try UIPressCommand.parse([]) }
  }
}
