// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Configuration
import Foundation

/// Validation settings from a project's configuration files; `nil` means not set.
struct ValidateFileSettings: Equatable {
  /// Schemes that build the product.
  var schemes: [String]?
  /// Platforms to build for.
  var platforms: [String]?
  /// Platforms to test on.
  var testPlatforms: [String]?
  /// When to test packages in git submodules: `changed`, `always`, or `never`.
  var testSubmodules: String?
  /// Packages whose tests never run.
  var excludePackages: [String]?
}

/// Formatting settings from a project's configuration files; `nil` means not set.
struct FormatFileSettings: Equatable {
  /// Repository-relative files and directories that `agt format` leaves alone.
  var exclude: [String]?
}

/// A project's `agt` configuration, layered from `.agt/local/config.json` (per machine, not committed) over
/// `.agt/config.json` (committed).
struct ProjectConfiguration {
  /// Settings for `agt validate`, under the `validate` key.
  let validate: ValidateFileSettings
  /// Settings for `agt format`, under the `format` key.
  let format: FormatFileSettings

  /// Returns the configuration files for a repository, most specific first.
  static func files(repoPath: String) -> [String] {
    ["\(repoPath)/.agt/local/config.json", "\(repoPath)/.agt/config.json"]
  }

  /// Loads the configuration for a repository; missing files count as empty.
  static func load(repoPath: String) async throws -> ProjectConfiguration {
    var providers: [any ConfigProvider] = []
    for path in files(repoPath: repoPath) {
      let fileConfig = ConfigReader(
        provider: InMemoryProvider(values: [
          AbsoluteConfigKey(["filePath"]): ConfigValue(.string(path), isSecret: false),
          AbsoluteConfigKey(["allowMissing"]): ConfigValue(.bool(true), isSecret: false),
        ])
      )
      do {
        providers.append(try await FileProvider<JSONSnapshot>(config: fileConfig))
      } catch {
        throw ToolError("Invalid configuration file \(path): \(error)")
      }
    }

    let config = ConfigReader(providers: providers)
    return ProjectConfiguration(
      validate: ValidateFileSettings(
        schemes: config.stringArray(forKey: "validate.schemes"),
        platforms: config.stringArray(forKey: "validate.platforms"),
        testPlatforms: config.stringArray(forKey: "validate.testPlatforms"),
        testSubmodules: config.string(forKey: "validate.testSubmodules"),
        excludePackages: config.stringArray(forKey: "validate.excludePackages")
      ),
      format: FormatFileSettings(exclude: config.stringArray(forKey: "format.exclude"))
    )
  }
}
