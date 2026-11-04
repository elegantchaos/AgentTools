// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import CoreGraphics

/// Drags with a mouse button held from one screen point to another.
struct UIDragCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "drag",
    abstract: "Drag from one point to another, in screen points."
  )

  /// The starting horizontal coordinate.
  @Argument(help: "Starting horizontal position.")
  var fromX: Double

  /// The starting vertical coordinate.
  @Argument(help: "Starting vertical position.")
  var fromY: Double

  /// The final horizontal coordinate.
  @Argument(help: "Final horizontal position.")
  var toX: Double

  /// The final vertical coordinate.
  @Argument(help: "Final vertical position.")
  var toY: Double

  /// The button to hold.
  @Option(help: "Button to hold.")
  var button = MouseButton.left

  /// Modifiers held during the drag.
  @Option(help: "Modifiers to hold, such as option.", transform: ModifierKeys.init(parsing:))
  var modifiers: ModifierKeys = []

  /// Posts the drag.
  mutating func run() async throws {
    try await SelfResponsibleRunner.run(task: "post input events") {
      try UIPermission.eventPosting.require()
      try await EventSynthesizer().drag(from: CGPoint(x: fromX, y: fromY), to: CGPoint(x: toX, y: toY), button: button, modifiers: modifiers)
    }
  }
}
