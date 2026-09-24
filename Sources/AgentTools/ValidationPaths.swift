// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Repository-local output locations for a validation run.
struct ValidationPaths {
  /// Directory for per-step validation logs.
  let logRoot: String
  /// Private DerivedData directory for Xcode validation.
  let derivedDataPath: String

  /// Resolves the output locations for a repository, optionally clearing previous output, and creates them.
  static func prepare(repoPath: String, clean: Bool) throws -> ValidationPaths {
    let paths = ValidationPaths(
      logRoot: "\(repoPath)/.build/validation-logs",
      derivedDataPath: "\(repoPath)/.build/agt-validate/DerivedData"
    )

    let fileManager = FileManager.default
    if clean {
      try? fileManager.removeItem(atPath: paths.logRoot)
      try? fileManager.removeItem(atPath: paths.derivedDataPath)
    }
    try fileManager.createDirectory(atPath: paths.logRoot, withIntermediateDirectories: true)
    try fileManager.createDirectory(atPath: paths.derivedDataPath, withIntermediateDirectories: true)
    return paths
  }

  /// Returns the log file path for a step, using a filesystem-safe form of its name.
  func logPath(_ name: String) -> String {
    "\(logRoot)/\(name.replacingOccurrences(of: "[^A-Za-z0-9]+", with: "_", options: .regularExpression)).log"
  }
}
