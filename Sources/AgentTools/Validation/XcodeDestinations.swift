// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Derives generic Xcode build destinations from a scheme's supported platforms.
enum XcodeDestinations {
  /// Minimal build settings metadata decoded from `xcodebuild -showBuildSettings -json`.
  private struct BuildSettingsEntry: Decodable {
    /// Build settings indexed by their Xcode keys.
    let buildSettings: [String: String]
  }

  /// Returns the `xcodebuild` arguments that print a scheme's build settings as JSON.
  static func showBuildSettingsArguments(container: [String], scheme: String, paths: ValidationPaths, sandbox: EnclosingSandbox) -> [String] {
    ["xcodebuild"] + container + ["-scheme", scheme, "-derivedDataPath", paths.derivedDataPath] + sandbox.xcodebuildDefaults + ["-showBuildSettings", "-json"]
  }

  /// Returns unique generic destinations for every `SUPPORTED_PLATFORMS` entry in build settings JSON.
  static func destinations(fromBuildSettingsJSON output: String) throws -> [String] {
    let entries = try JSONDecoder().decode([BuildSettingsEntry].self, from: Data(output.utf8))
    let sdkPlatforms = entries.flatMap { entry in
      entry.buildSettings["SUPPORTED_PLATFORMS"]?
        .split { $0 == " " || $0 == "," || $0 == "\n" || $0 == "\t" }
        .map(String.init) ?? []
    }

    var destinations: [String] = []
    for sdkPlatform in sdkPlatforms {
      guard let destination = destination(forSupportedPlatform: sdkPlatform), !destinations.contains(destination) else {
        continue
      }
      destinations.append(destination)
    }
    return destinations
  }

  /// Maps an SDK platform name to its generic build destination.
  static func destination(forSupportedPlatform sdkPlatform: String) -> String? {
    switch sdkPlatform {
      case "macosx":
        "generic/platform=macOS"
      case "iphoneos", "iphonesimulator":
        "generic/platform=iOS"
      case "appletvos", "appletvsimulator":
        "generic/platform=tvOS"
      case "watchos", "watchsimulator":
        "generic/platform=watchOS"
      case "xros", "xrsimulator":
        "generic/platform=visionOS"
      default:
        nil
    }
  }
}
