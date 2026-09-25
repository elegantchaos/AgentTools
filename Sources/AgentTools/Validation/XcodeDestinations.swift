// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Reads the platforms a scheme supports and the destinations available to test it.
enum XcodeDestinations {
  /// Minimal build settings metadata decoded from `xcodebuild -showBuildSettings -json`.
  private struct BuildSettingsEntry: Decodable {
    /// Build settings indexed by their Xcode keys.
    let buildSettings: [String: String]
  }

  /// `xcodebuild` arguments that trust a package's build plugins and macros without Xcode's interactive prompt, as
  /// `swift build` does. Every `xcodebuild` invocation passes them.
  static let trustArguments = ["-skipPackagePluginValidation", "-skipMacroValidation"]

  /// Returns the `xcodebuild` arguments that print a scheme's build settings as JSON.
  static func showBuildSettingsArguments(container: [String], scheme: String, paths: ValidationPaths, sandbox: EnclosingSandbox) -> [String] {
    ["xcodebuild"] + container + ["-scheme", scheme, "-derivedDataPath", paths.derivedDataPath] + trustArguments + sandbox.xcodebuildDefaults
      + ["-showBuildSettings", "-json"]
  }

  /// Returns the `xcodebuild` arguments that list a scheme's available destinations.
  static func showDestinationsArguments(container: [String], scheme: String, paths: ValidationPaths, sandbox: EnclosingSandbox) -> [String] {
    ["xcodebuild"] + container + ["-scheme", scheme, "-derivedDataPath", paths.derivedDataPath] + trustArguments + sandbox.xcodebuildDefaults
      + ["-showdestinations"]
  }

  /// Returns the unique platforms in every `SUPPORTED_PLATFORMS` entry of build settings JSON, in order.
  static func platforms(fromBuildSettingsJSON output: String) throws -> [ApplePlatform] {
    let entries = try JSONDecoder().decode([BuildSettingsEntry].self, from: Data(output.utf8))
    var platforms: [ApplePlatform] = []
    for entry in entries {
      let sdks = entry.buildSettings["SUPPORTED_PLATFORMS"]?.split { $0 == " " || $0 == "," || $0 == "\n" || $0 == "\t" } ?? []
      for platform in sdks.compactMap({ ApplePlatform(sdk: String($0)) }) where !platforms.contains(platform) {
        platforms.append(platform)
      }
    }
    return platforms
  }

  /// Returns the simulator that runs tests on each simulator platform in `xcodebuild -showdestinations` output.
  ///
  /// The platform's test device for its newest OS is preferred: `newestOS` gives the newest installed runtime, and
  /// defaults to the newest OS among the destinations. Without one, a test device for an older OS is used, then the
  /// first simulator with the newest OS. Destinations name the device and OS, so they survive simulators being
  /// recreated.
  static func simulators(fromShowDestinations output: String, newestOS: [ApplePlatform: String] = [:]) -> [ApplePlatform: SimulatorChoice] {
    var available: [ApplePlatform: [(name: String, os: String)]] = [:]
    for line in output.split(separator: "\n") {
      let fields = destinationFields(String(line))
      guard let platformName = fields["platform"], let os = fields["OS"], let name = fields["name"],
        let platform = ApplePlatform.allCases.first(where: { $0.simulatorName == platformName })
      else { continue }
      available[platform, default: []].append((name, os))
    }

    var chosen: [ApplePlatform: SimulatorChoice] = [:]
    for (platform, simulators) in available {
      guard let newestAvailable = newest(simulators) else { continue }
      let wanted = platform.testDeviceNames(os: newestOS[platform] ?? newestAvailable.os)
      let simulator =
        wanted.lazy.compactMap { name in newest(simulators.filter { $0.name == name }) }.first
        ?? newest(simulators.filter { platform.isTestDeviceName($0.name) })
        ?? newestAvailable
      chosen[platform] = SimulatorChoice(platform: platform, name: simulator.name, os: simulator.os, testDeviceNames: wanted)
    }
    return chosen
  }

  /// Returns the first of `simulators` with the newest OS.
  private static func newest(_ simulators: [(name: String, os: String)]) -> (name: String, os: String)? {
    simulators.reduce(nil) { best, candidate in
      best.map { TestSimulators.version($0.os).lexicographicallyPrecedes(TestSimulators.version(candidate.os)) ? candidate : $0 } ?? candidate
    }
  }

  /// Splits a `{ key:value, key:value }` destination line into its fields.
  private static func destinationFields(_ line: String) -> [String: String] {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}") else { return [:] }
    var fields: [String: String] = [:]
    for field in trimmed.dropFirst().dropLast().split(separator: ",") {
      let parts = field.split(separator: ":", maxSplits: 1)
      if parts.count == 2 {
        fields[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
      }
    }
    return fields
  }
}
