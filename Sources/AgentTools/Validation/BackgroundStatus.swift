// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// The state of a background full validation, and the working tree it checked.
struct BackgroundStatus: Codable, Equatable {
  /// Where a background validation has got to.
  enum State: String, Codable {
    /// Still running.
    case running
    /// Finished, with every step passing.
    case passed
    /// Finished at a failing step.
    case failed
    /// Finished, but the working tree changed while it ran.
    case stale
    /// Stopped before finishing.
    case cancelled
  }

  /// Where the validation has got to.
  var state: State
  /// The process running the validation.
  var pid: Int32
  /// Fingerprint of the working tree when the validation started.
  var fingerprint: String
  /// When the validation started.
  var started: Date
  /// When the validation finished, if it has.
  var finished: Date?
  /// One summary line per step.
  var steps: [String] = []
  /// Identifies the validation that owns this record. A newer validation writes a new token, which tells the running
  /// one to stop.
  var token = ""

  /// Returns `true` when the validation holding `token` is running and still owns this record.
  func isOwned(byToken token: String) -> Bool {
    state == .running && self.token == token
  }

  /// Returns `true` when this is a pass for the working tree with `currentFingerprint`.
  func isCurrentPass(currentFingerprint: String) -> Bool {
    state == .passed && fingerprint == currentFingerprint
  }

  /// A one-sentence description, saying whether a finished result applies to the working tree with `currentFingerprint`.
  func headline(currentFingerprint: String) -> String {
    switch state {
      case .running:
        return "Full validation is running."
      case .stale:
        return "Full validation finished, but the working tree changed while it ran, so its result does not apply."
      case .cancelled:
        return "Full validation was cancelled before it finished."
      case .passed, .failed:
        let duration = finished.map { " after \(Self.format($0.timeIntervalSince(started)))" } ?? ""
        let tree = fingerprint == currentFingerprint ? "the current working tree" : "an earlier working tree"
        return "Full validation \(state.rawValue)\(duration), for \(tree)."
    }
  }

  /// Formats a duration as, for example, `45s`, `1m 35s`, or `1h 2m`.
  private static func format(_ interval: TimeInterval) -> String {
    let seconds = Int(interval.rounded())
    if seconds < 60 { return "\(seconds)s" }
    if seconds < 3600 { return "\(seconds / 60)m \(seconds % 60)s" }
    return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
  }
}

/// Reads and writes the background validation status and output in a directory.
struct BackgroundStatusStore {
  /// The directory holding the status and output.
  let directory: String

  /// The status file.
  var statusPath: String { "\(directory)/status.json" }
  /// The output of the background validation.
  var logPath: String { "\(directory)/output.log" }

  /// Returns the saved status, or `nil` when there is none or it cannot be read.
  func load() -> BackgroundStatus? {
    guard let data = FileManager.default.contents(atPath: statusPath) else { return nil }
    return try? JSONDecoder().decode(BackgroundStatus.self, from: data)
  }

  /// Saves a status, replacing the previous one.
  func save(_ status: BackgroundStatus) throws {
    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    try JSONEncoder().encode(status).write(to: URL(fileURLWithPath: statusPath), options: .atomic)
  }
}
