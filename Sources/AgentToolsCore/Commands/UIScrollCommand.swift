// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import CoreGraphics

/// Scrolls whatever is under a screen point.
struct UIScrollCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "scroll",
    abstract: "Scroll at a point in screen points."
  )

  /// The horizontal coordinate.
  @Argument(help: "Horizontal position of the content to scroll.")
  var x: Double

  /// The vertical coordinate.
  @Argument(help: "Vertical position of the content to scroll.")
  var y: Double

  /// Points to scroll down; negative scrolls up.
  @Option(parsing: .unconditional, help: "Points to scroll down; negative values scroll up.")
  var down: Int32 = 0

  /// Points to scroll right; negative scrolls left.
  @Option(parsing: .unconditional, help: "Points to scroll right; negative values scroll left.")
  var right: Int32 = 0

  /// Rejects the one distance whose negation, needed for the wheel event, overflows.
  func validate() throws {
    guard down != .min, right != .min else { throw ValidationError("--down and --right must be greater than \(Int32.min).") }
  }

  /// Posts the scroll.
  mutating func run() async throws {
    try await SelfResponsibleRunner.run(task: "post input events") {
      try UIPermission.eventPosting.require()
      try await EventSynthesizer().scroll(at: CGPoint(x: x, y: y), down: down, right: right)
    }
  }
}
