// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// The simulator chosen to run tests on one platform.
struct SimulatorChoice: Codable, Equatable {
  /// The simulator's platform.
  let platform: ApplePlatform
  /// The simulator's name.
  let name: String
  /// The simulator's OS version.
  let os: String
  /// The names of the platform's test devices for its newest OS, most preferred first.
  let testDeviceNames: [String]

  /// Whether the simulator is a test device for the platform's newest OS.
  var isTestDevice: Bool {
    testDeviceNames.contains(name)
  }

  /// The `xcodebuild` destination that runs tests on this simulator.
  var destination: String {
    "platform=\(platform.simulatorName ?? platform.rawValue),name=\(name),OS=\(os)"
  }

  /// A line for the validation output when the simulator is not a test device for the newest OS, or `nil` when it is.
  var note: String? {
    guard !isTestDevice else { return nil }
    let names = testDeviceNames.joined(separator: " or ")
    return "\(platform.rawValue) tests run on \(name) with \(platform.rawValue) \(os): there is no simulator named \(names)."
  }
}

/// Finds and creates the simulators kept for testing: one per platform and OS version, named like `Test iPhone 27.2`.
///
/// A test device is the most convenient simulator for App Store screenshots: the device of its family with the
/// largest display that the App Store asks for. See `deviceTypes(for:)` for how each device is chosen, and when the
/// choice needs revising.
enum TestSimulators {
  /// A test device to create with `simctl`.
  struct NewDevice: Equatable {
    /// The device's name.
    let name: String
    /// The `simctl` identifier of the device type.
    let deviceType: String
    /// The device type's name.
    let deviceTypeName: String
    /// The `simctl` identifier of the runtime.
    let runtime: String
    /// The runtime's name.
    let runtimeName: String

    /// The command that creates the device.
    var arguments: [String] {
      ["xcrun", "simctl", "create", name, deviceType, runtime]
    }
  }

  /// A runtime from `simctl list -j runtimes`.
  private struct Runtime: Decodable {
    /// A device type the runtime supports.
    struct DeviceType: Decodable {
      /// The device family, such as `iPhone` or `Apple TV`.
      let productFamily: String
      /// The device type's name.
      let name: String
      /// The device type's `simctl` identifier.
      let identifier: String
    }

    /// The runtime's platform, such as `iOS`.
    let platform: String
    /// The runtime's OS version.
    let version: String
    /// The runtime's name.
    let name: String
    /// The runtime's `simctl` identifier.
    let identifier: String
    /// Whether the runtime can be used.
    let isAvailable: Bool
    /// The device types the runtime supports, newest first within each family.
    let supportedDeviceTypes: [DeviceType]
  }

  /// The runtime list printed by `simctl list -j runtimes`.
  private struct RuntimeList: Decodable {
    /// Every installed runtime.
    let runtimes: [Runtime]
  }

  /// The device list printed by `simctl list -j devices`.
  private struct DeviceList: Decodable {
    /// A simulator.
    struct Device: Decodable {
      /// The simulator's name.
      let name: String
    }

    /// Simulators, by runtime identifier.
    let devices: [String: [Device]]
  }

  /// Returns the `simctl` product family of a test device family, and whether a device type of that family is
  /// preferred. The newest preferred type is used, or the newest of the family when none is preferred.
  ///
  /// ## Why these devices
  ///
  /// Test devices double as the simulators for App Store screenshots, so each one is the device whose screenshots
  /// App Store Connect asks for. It asks for the largest display in each family and scales those screenshots down
  /// for smaller devices, so the largest current display covers the whole family:
  ///
  /// - iPhone: the Pro Max, the largest iPhone display (6.9-inch when this was written).
  /// - iPad: the 13-inch iPad Pro, the largest iPad display. Memory variants, such as `(16GB)`, give identical
  ///   screenshots, so whichever `simctl` lists first is fine.
  /// - Apple TV: an Apple TV 4K running at 4K, for full-resolution screenshots; `simctl` also offers each model
  ///   "at 1080p", which is excluded.
  /// - Apple Watch: the Ultra, the largest watch display.
  /// - Apple Vision: there is one device, so the newest is used.
  ///
  /// Each test is a name pattern, not an exact device, because `simctl` lists device types newest first: the first
  /// match is the newest model of the right kind, so a new generation is picked up without a code change.
  ///
  /// ## When to revise
  ///
  /// - App Store Connect changes the size it asks for, for example a new largest iPhone that is not a Pro Max:
  ///   change the pattern to match the device with that display, found in App Store Connect's screenshot
  ///   specifications, and check it against `xcrun simctl list devicetypes`.
  /// - A product line is renamed or dropped, so the pattern matches nothing: every family falls back to its newest
  ///   device type, which still works for testing, but may not suit screenshots. Pick the replacement by the same
  ///   rule, the device with the largest display the App Store asks for.
  /// - A new family appears: add it to `ApplePlatform.testDeviceFamilies`, and add a case here.
  ///
  /// Existing test devices are never changed: only a new test device, for a newer runtime, uses a revised rule.
  private static func deviceTypes(for family: String) -> (productFamily: String, isPreferred: @Sendable (String) -> Bool) {
    switch family {
      case "iPhone": ("iPhone", { $0.contains("Pro Max") })
      case "iPad": ("iPad", { $0.hasPrefix("iPad Pro 13-inch") })
      case "TV": ("Apple TV", { $0.hasPrefix("Apple TV 4K") && !$0.contains("1080p") })
      case "Watch": ("Apple Watch", { $0.contains("Ultra") })
      default: ("Apple \(family)", { _ in true })
    }
  }

  /// Returns the components of a version string, for comparison.
  static func version(_ string: String) -> [Int] {
    string.split(separator: ".").compactMap { Int($0) }
  }

  /// Returns the simulator platforms among `platforms` whose chosen simulator is not a test device for the newest OS.
  static func missingTestDevices(for platforms: [ApplePlatform], in simulators: [ApplePlatform: SimulatorChoice]) -> [ApplePlatform] {
    platforms.filter { platform in simulators[platform].map { !$0.isTestDevice } ?? false }
  }

  /// Returns the OS version of each platform's newest available runtime.
  static func newestOS(runtimesJSON: String) throws -> [ApplePlatform: String] {
    var newest: [ApplePlatform: String] = [:]
    for platform in ApplePlatform.allCases {
      newest[platform] = try newestRuntime(for: platform, runtimesJSON: runtimesJSON)?.version
    }
    return newest
  }

  /// Returns the preferred test device for `platform` on its newest available runtime, or `nil` when no runtime
  /// supports one, or when a simulator with its name already exists in `devicesJSON`.
  static func newDevice(for platform: ApplePlatform, runtimesJSON: String, devicesJSON: String) throws -> NewDevice? {
    guard let runtime = try newestRuntime(for: platform, runtimesJSON: runtimesJSON),
      let family = platform.testDeviceFamilies.first
    else { return nil }
    let types = deviceTypes(for: family)
    let name = platform.testDeviceNames(os: runtime.version)[0]
    let existing = try JSONDecoder().decode(DeviceList.self, from: Data(devicesJSON.utf8)).devices.values.joined()
    guard !existing.contains(where: { $0.name == name }) else { return nil }
    let candidates = runtime.supportedDeviceTypes.filter { $0.productFamily == types.productFamily }
    guard let deviceType = candidates.first(where: { types.isPreferred($0.name) }) ?? candidates.first else { return nil }
    return NewDevice(name: name, deviceType: deviceType.identifier, deviceTypeName: deviceType.name, runtime: runtime.identifier, runtimeName: runtime.name)
  }

  /// Returns the newest available runtime for `platform`.
  private static func newestRuntime(for platform: ApplePlatform, runtimesJSON: String) throws -> Runtime? {
    let names = platform == .visionOS ? ["visionOS", "xrOS"] : [platform.rawValue]
    return try JSONDecoder().decode(RuntimeList.self, from: Data(runtimesJSON.utf8)).runtimes
      .filter { $0.isAvailable && names.contains($0.platform) }
      .max { version($0.version).lexicographicallyPrecedes(version($1.version)) }
  }
}
