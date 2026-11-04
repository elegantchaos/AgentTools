// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import CoreGraphics
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

/// Captures the main display, or an application's frontmost window, through ScreenCaptureKit, and saves it as PNG.
///
/// Images are captured at one pixel per screen point, so a pixel's position in a display capture is the point to
/// click, and a window capture's pixels are offset by the window's origin. Capturing needs the Screen Recording
/// permission.
struct ScreenCapture {
  /// The captured image.
  let image: CGImage

  /// The captured area in screen points, from the top left of the main display.
  let frame: CGRect

  /// Captures the main display.
  static func mainDisplay() async throws -> ScreenCapture {
    let content = try await SCShareableContent.current
    guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? content.displays.first else {
      throw ToolError("There is no display to capture. Is anyone logged in to the console?")
    }
    let filter = SCContentFilter(display: display, excludingWindows: [])
    return try await capture(filter, frame: display.frame)
  }

  /// Captures the frontmost on-screen window of the application with process identifier `pid`.
  static func frontWindow(of pid: pid_t) async throws -> ScreenCapture {
    let content = try await SCShareableContent.current
    guard let windowID = frontWindowID(of: pid), let window = content.windows.first(where: { $0.windowID == windowID }) else {
      throw ToolError("Process \(pid) has no window on screen.")
    }
    return try await capture(SCContentFilter(desktopIndependentWindow: window), frame: window.frame)
  }

  /// Writes the image to `url` as PNG.
  func writePNG(to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
      throw ToolError("Could not create \(url.path).")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw ToolError("Could not write \(url.path).")
    }
  }
}

extension ScreenCapture {
  /// Captures what `filter` selects at one pixel per point.
  private static func capture(_ filter: SCContentFilter, frame: CGRect) async throws -> ScreenCapture {
    let configuration = SCStreamConfiguration()
    configuration.width = Int(frame.width)
    configuration.height = Int(frame.height)
    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    return ScreenCapture(image: image, frame: frame)
  }

  /// Returns the frontmost normal-level window of `pid`, using the window server's front-to-back order, which
  /// ScreenCaptureKit's window list does not promise.
  private static func frontWindowID(of pid: pid_t) -> CGWindowID? {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let window = windows.first { $0[kCGWindowOwnerPID as String] as? pid_t == pid && $0[kCGWindowLayer as String] as? Int == 0 }
    return window?[kCGWindowNumber as String] as? CGWindowID
  }
}
