// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Adds writable paths to Claude Code's `settings.json`, as `sandbox.filesystem.allowWrite`, and commands that run
/// outside its sandbox, as `sandbox.excludedCommands`.
///
/// Every other setting is kept, and entries already present stay where they are. The settings are rewritten with
/// sorted keys, so repeated runs produce the same text.
enum ClaudeSandboxSettings {
  /// Returns the settings with any of `paths` that are missing appended to `allowWrite`, and any of
  /// `excludedCommands` that are missing appended to `excludedCommands`, or `nil` when nothing is missing.
  ///
  /// `data` is `nil` when there is no settings file yet.
  static func adding(_ paths: [String], excludedCommands: [String], to data: Data?) throws -> Data? {
    var settings = try data.map(decodedObject) ?? [:]
    var sandbox = try object(settings["sandbox"], named: "sandbox")
    var filesystem = try object(sandbox["filesystem"], named: "sandbox.filesystem")
    let addedPaths = try appendMissing(paths, to: &filesystem, key: "allowWrite", named: "sandbox.filesystem.allowWrite")
    let addedCommands = try appendMissing(
      excludedCommands, to: &sandbox, key: "excludedCommands", named: "sandbox.excludedCommands")
    guard addedPaths || addedCommands else { return nil }

    if addedPaths { sandbox["filesystem"] = filesystem }
    settings["sandbox"] = sandbox
    let encoded = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    return encoded + Data("\n".utf8)
  }

  /// Appends whichever of `values` are missing from the string array at `key` in `object`, creating it if needed,
  /// and returns whether any were added.
  private static func appendMissing(
    _ values: [String], to object: inout [String: Any], key: String, named name: String
  ) throws -> Bool {
    let existing: [String]
    switch object[key] {
      case nil: existing = []
      case let strings as [String]: existing = strings
      default: throw ToolError("\(name) is not an array of strings")
    }
    let missing = values.filter { !existing.contains($0) }
    guard !missing.isEmpty else { return false }
    object[key] = existing + missing
    return true
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
