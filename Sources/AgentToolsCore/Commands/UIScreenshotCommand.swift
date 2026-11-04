// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Saves a PNG of the main display, or of one application's frontmost window.
struct UIScreenshotCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "screenshot",
    abstract: "Save a PNG of the main display or an application's frontmost window.",
    discussion: "Images have one pixel per screen point. Prints the captured area in screen points, so window pixels can be converted to click coordinates."
  )

  /// Where to write the PNG.
  @Argument(help: "Path of the PNG to write.")
  var path: String

  /// The application whose window to capture, or `nil` for the display.
  @Option(name: .customLong("app"), help: "Capture this application's frontmost window instead (bundle identifier or process identifier).", transform: AppTarget.init(argument:))
  var application: AppTarget?

  /// Captures and saves the image.
  mutating func run() async throws {
    try UIPermission.screenRecording.require()
    let capture =
      if let application {
        try await ScreenCapture.frontWindow(of: application.runningApplication().processIdentifier)
      } else {
        try await ScreenCapture.mainDisplay()
      }
    let url = URL(filePath: path)
    try capture.writePNG(to: url)
    let frame = capture.frame
    print("Saved \(url.path): \(Int(frame.width))x\(Int(frame.height)) points at (\(Int(frame.minX)), \(Int(frame.minY))).")
  }
}
