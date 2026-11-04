// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import CoreGraphics
import Testing

@testable import AgentToolsCore

/// Verifies how `agt ui press` chooses between pressing and focusing, and where it clicks when focusing is refused.
struct ElementActivationTests {
  /// Elements with a press action are pressed; focusable ones without it are focused; anything else is pressed.
  @Test(arguments: [
    (["AXPress"], false, ElementActivation.press),
    (["AXPress", "AXShowMenu"], true, .press),
    (["AXShowMenu"], true, .focus),
    ([], true, .focus),
    ([], false, .press),
  ])
  func choosesPressOrFocus(actions: [String], canFocus: Bool, expected: ElementActivation) {
    #expect(ElementActivation.choose(actions: actions, canFocus: canFocus) == expected)
  }

  /// The click lands in the centre of the visible part of the frame.
  @Test func clicksTheVisibleCentre() throws {
    let window = CGRect(x: 0, y: 0, width: 400, height: 300)
    #expect(try ElementActivation.clickPoint(frame: CGRect(x: 100, y: 100, width: 200, height: 20), clips: [window]) == CGPoint(x: 200, y: 110))
    let scrollArea = CGRect(x: 0, y: 50, width: 400, height: 100)
    #expect(try ElementActivation.clickPoint(frame: CGRect(x: 100, y: 140, width: 200, height: 20), clips: [window, scrollArea]) == CGPoint(x: 200, y: 145))
  }

  /// A frame outside its window or scroll area, or a missing frame, is an error rather than a click elsewhere.
  @Test(arguments: [
    CGRect(x: 100, y: 400, width: 200, height: 20),
    CGRect(x: 100, y: 200, width: 200, height: 20),
    nil,
  ])
  func refusesInvisibleFrames(frame: CGRect?) {
    let clips = [CGRect(x: 0, y: 0, width: 400, height: 300), CGRect(x: 0, y: 50, width: 400, height: 100)]
    #expect(throws: ToolError.self) { try ElementActivation.clickPoint(frame: frame, clips: clips) }
  }
}
