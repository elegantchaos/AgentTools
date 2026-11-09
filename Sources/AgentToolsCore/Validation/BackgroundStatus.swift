// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// The state and tested commit of a background validation.
struct BackgroundStatus: Codable, Equatable {
  /// Where a background validation has got to.
  enum State: String, Codable {
    /// Still running.
    case running
    /// Finished, with every step passing.
    case passed
    /// Finished at a failing step.
    case failed
    /// Finished without building or testing anything, because nothing in scope changed. Not a pass.
    case empty
    /// Stopped before finishing.
    case cancelled
  }

  /// Where the validation has got to.
  var state: State
  /// The process running the validation.
  var pid: Int32
  /// Pinned commit built by the worker.
  var commit: String
  /// When the validation started.
  var started: Date
  /// When the validation finished, if it has.
  var finished: Date?
  /// One summary line per step.
  var steps: [String] = []
  /// Identifies the validation that owns this record. A newer validation writes a new token, which tells the running
  /// one to stop.
  var token = ""

  /// Whether the worker ran the complete configured scope.
  var full = true

  /// Returns `true` when the validation holding `token` is running and still owns this record.
  func isOwned(byToken token: String) -> Bool {
    state == .running && self.token == token
  }

  /// Returns `true` when this is a pass for the working tree with `currentCommit`.
  func isCurrentPass(currentCommit: String?) -> Bool {
    state == .passed && commit == currentCommit
  }

  /// Returns why waiting for this result fails for `currentCommit`, or `nil` when it satisfies the wait.
  /// `requireFull` rejects a change-scoped pass.
  func waitFailure(currentCommit: String?, requireFull: Bool) -> String? {
    if state == .empty, commit == currentCommit {
      return "Change-scoped validation found nothing to build or test for the current commit, so there is no pass. Use --full for complete coverage."
    }
    guard isCurrentPass(currentCommit: currentCommit) else {
      return "Background validation did not pass for the current clean commit."
    }
    if requireFull, !full {
      return "Only change-scoped validation passed for the current commit; --full requires a full pass."
    }
    return nil
  }

  /// A one-sentence description, saying whether a finished result applies to the working tree with `currentCommit`.
  func headline(currentCommit: String?) -> String {
    let scope = full ? "Full validation" : "Change-scoped validation"
    let tree = commit == currentCommit ? "the current clean commit" : "a different checkout state"
    switch state {
      case .running:
        return "\(scope) is running."
      case .cancelled:
        return "\(scope) was cancelled before it finished."
      case .empty:
        return "\(scope) found nothing to build or test, for \(tree)."
      case .passed, .failed:
        let duration = finished.map { " after \(Self.format($0.timeIntervalSince(started)))" } ?? ""
        return "\(scope) \(state.rawValue)\(duration), for \(tree)."
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
