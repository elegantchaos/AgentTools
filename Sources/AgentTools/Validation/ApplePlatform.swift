// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// An Apple platform that validation builds and tests for.
enum ApplePlatform: String, Codable, CaseIterable {
  case macOS
  case iOS
  case tvOS
  case watchOS
  case visionOS

  /// Creates a platform from its name, ignoring case.
  init?(name: String) {
    guard let platform = Self.allCases.first(where: { $0.rawValue.lowercased() == name.lowercased() }) else { return nil }
    self = platform
  }

  /// Creates a platform from an SDK name in Xcode's `SUPPORTED_PLATFORMS` build setting.
  init?(sdk: String) {
    switch sdk {
      case "macosx": self = .macOS
      case "iphoneos", "iphonesimulator": self = .iOS
      case "appletvos", "appletvsimulator": self = .tvOS
      case "watchos", "watchsimulator": self = .watchOS
      case "xros", "xrsimulator": self = .visionOS
      default: return nil
    }
  }

  /// The generic `xcodebuild` destination that builds for this platform.
  var buildDestination: String {
    "generic/platform=\(rawValue)"
  }

  /// The platform name `xcodebuild -showdestinations` uses for this platform's simulators, or `nil` for macOS.
  var simulatorName: String? {
    self == .macOS ? nil : "\(rawValue) Simulator"
  }

  /// The device families of the simulators kept for testing on this platform, most preferred first. A test device
  /// is named "Test", its family, and its OS version, such as `Test iPhone 27.2`.
  var testDeviceFamilies: [String] {
    switch self {
      case .macOS: []
      case .iOS: ["iPhone", "iPad"]
      case .tvOS: ["TV"]
      case .watchOS: ["Watch"]
      case .visionOS: ["Vision"]
    }
  }

  /// The names of this platform's test devices for OS version `os`, most preferred first.
  func testDeviceNames(os: String) -> [String] {
    testDeviceFamilies.map { "Test \($0) \(os)" }
  }

  /// Returns `true` when `name` is one of this platform's test devices, for any OS version.
  func isTestDeviceName(_ name: String) -> Bool {
    testDeviceFamilies.contains { name.hasPrefix("Test \($0) ") }
  }

  /// Returns platforms with macOS first, where builds are fastest and tests need no simulator, keeping the
  /// others in order.
  static func hostFirst(_ platforms: [ApplePlatform]) -> [ApplePlatform] {
    platforms.filter { $0 == .macOS } + platforms.filter { $0 != .macOS }
  }
}
