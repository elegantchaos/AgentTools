// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import CryptoKit
import Foundation

/// Discovery results saved between validation runs, such as package descriptions and scheme destinations.
///
/// Every result is discarded together when the fingerprint changes. The fingerprint covers the files that
/// discovery reads, such as package manifests and Xcode projects, and other inputs, such as the tool version
/// and the selected Xcode. Failed lookups are never saved, and a file that cannot be read counts as empty.
final class DiscoveryCache {
  /// The saved form of the cache.
  private struct Contents: Codable {
    /// Fingerprint of the inputs the entries were computed from.
    let fingerprint: String
    /// Encoded results, by lookup key.
    var entries: [String: Data]
  }

  /// Location of the cache file.
  private let path: String
  /// Current contents.
  private var contents: Contents
  /// Whether the contents changed since loading.
  private var changed = false
  /// Number of lookups answered from saved results.
  private(set) var reused = 0
  /// Number of lookups computed during this run.
  private(set) var computed = 0

  /// Loads the cache at `path`, keeping its entries only when they were computed for `fingerprint`.
  init(path: String, fingerprint: String) {
    self.path = path
    let saved = (try? Data(contentsOf: URL(fileURLWithPath: path))).flatMap { try? JSONDecoder().decode(Contents.self, from: $0) }
    contents = saved?.fingerprint == fingerprint ? saved! : Contents(fingerprint: fingerprint, entries: [:])
  }

  /// Returns a fingerprint of the names and contents of `files`, relative to `root`, and the other `inputs`,
  /// independent of file order.
  static func fingerprint(root: String, files: [String], inputs: [String]) -> String {
    var hasher = SHA256()
    for file in files.sorted() {
      hasher.update(data: Data(file.utf8))
      hasher.update(data: Data(SHA256.hash(data: (try? Data(contentsOf: URL(fileURLWithPath: "\(root)/\(file)"))) ?? Data())))
    }
    for input in inputs {
      hasher.update(data: Data(input.utf8))
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }

  /// Returns the saved value for `key`, or computes, saves, and returns it. Nothing is saved when `compute` throws.
  func value<T: Codable>(_ key: String, compute: () throws -> T) throws -> T {
    if let data = contents.entries[key], let value = try? JSONDecoder().decode(T.self, from: data) {
      reused += 1
      return value
    }
    let value = try compute()
    contents.entries[key] = try JSONEncoder().encode(value)
    changed = true
    computed += 1
    return value
  }

  /// Writes the cache when it changed.
  func save() throws {
    guard changed else { return }
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(contents).write(to: url, options: .atomic)
    changed = false
  }
}
