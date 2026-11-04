// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Configuration
import Foundation

/// Reads layered `agt` JSON configuration files, so every settings type loads them the same way.
enum ConfigurationFiles {
  /// Returns a reader over the JSON files at `paths`, the first taking precedence; missing files count as empty.
  static func reader(paths: [String]) async throws -> ConfigReader {
    var providers: [any ConfigProvider] = []
    for path in paths {
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
    return ConfigReader(providers: providers)
  }

  /// Returns the path of the user's own configuration file in `homeDirectory`.
  static func userPath(homeDirectory: URL) -> String {
    homeDirectory.appending(path: ".agt/config.json").path
  }
}
