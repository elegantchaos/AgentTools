// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Adds writable paths to Claude Code's `settings.json`, as `sandbox.filesystem.allowWrite`.
///
/// Every other setting is kept. The settings are rewritten with sorted keys, so repeated runs produce the same text.
enum ClaudeSandboxSettings {
  /// Returns the settings with any of `paths` that are missing appended to `allowWrite`, or `nil` when none are missing.
  ///
  /// `data` is `nil` when there is no settings file yet.
  static func adding(_ paths: [String], to data: Data?) throws -> Data? {
    var settings = try data.map(decodedObject) ?? [:]
    var sandbox = try object(settings["sandbox"], named: "sandbox")
    var filesystem = try object(sandbox["filesystem"], named: "sandbox.filesystem")
    let existing: [String]
    switch filesystem["allowWrite"] {
      case nil: existing = []
      case let strings as [String]: existing = strings
      default: throw ToolError("sandbox.filesystem.allowWrite is not an array of strings")
    }

    let missing = paths.filter { !existing.contains($0) }
    guard !missing.isEmpty else { return nil }

    filesystem["allowWrite"] = existing + missing
    sandbox["filesystem"] = filesystem
    settings["sandbox"] = sandbox
    let encoded = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    return encoded + Data("\n".utf8)
  }

  /// Decodes settings that must be a JSON object.
  private static func decodedObject(_ data: Data) throws -> [String: Any] {
    try object(JSONSerialization.jsonObject(with: data), named: "the settings")
  }

  /// Returns `value` as an object, or an empty one when it is missing.
  private static func object(_ value: Any?, named name: String) throws -> [String: Any] {
    guard let value else { return [:] }
    guard let object = value as? [String: Any] else {
      throw ToolError("\(name) is not a JSON object")
    }
    return object
  }
}
