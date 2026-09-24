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

  /// Returns a test destination for macOS, and for each simulator platform in `xcodebuild -showdestinations`
  /// output, the first simulator with the newest OS, named by device and OS so it survives simulators being recreated.
  static func testDestinations(fromShowDestinations output: String) -> [ApplePlatform: String] {
    var chosen: [ApplePlatform: (os: [Int], destination: String)] = [:]
    for line in output.split(separator: "\n") {
      let fields = destinationFields(String(line))
      guard let platformName = fields["platform"], let os = fields["OS"], let name = fields["name"],
        let platform = ApplePlatform.allCases.first(where: { $0.simulatorName == platformName })
      else { continue }
      let version = os.split(separator: ".").compactMap { Int($0) }
      if let current = chosen[platform], !current.os.lexicographicallyPrecedes(version) {
        continue
      }
      chosen[platform] = (version, "platform=\(platformName),name=\(name),OS=\(os)")
    }
    return chosen.mapValues(\.destination).merging([.macOS: "platform=macOS"]) { current, _ in current }
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
