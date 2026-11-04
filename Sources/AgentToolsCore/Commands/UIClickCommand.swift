// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import CoreGraphics

/// Clicks a mouse button at a screen point.
struct UIClickCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "click",
    abstract: "Click at a point in screen points."
  )

  /// The horizontal coordinate.
  @Argument(help: "Horizontal position in points from the left of the main display.")
  var x: Double

  /// The vertical coordinate.
  @Argument(help: "Vertical position in points from the top of the main display.")
  var y: Double

  /// The button to click.
  @Option(help: "Button to click.")
  var button = MouseButton.left

  /// The number of clicks.
  @Option(help: "Number of clicks: 2 for a double click, 3 for a triple click.")
  var count = 1

  /// Modifiers held during the click.
  @Option(help: "Modifiers to hold, such as cmd+shift.", transform: ModifierKeys.init(parsing:))
  var modifiers: ModifierKeys = []

  /// The point to click.
  var point: CGPoint {
    CGPoint(x: x, y: y)
  }

  /// Rejects click counts applications do not recognise.
  func validate() throws {
    guard (1...3).contains(count) else { throw ValidationError("--count must be 1, 2 or 3.") }
  }

  /// Posts the click.
  mutating func run() async throws {
    try UIPermission.eventPosting.require()
    try await EventSynthesizer().click(at: point, button: button, count: count, modifiers: modifiers)
  }
}
