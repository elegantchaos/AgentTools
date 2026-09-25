// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Shapes subprocess output into the diagnostics shown during validation.
enum ValidationOutput {
  /// Output fragments that are never shown.
  ///
  /// SwiftPM warns about its user configuration directory when validation runs in a sandbox that cannot
  /// write there; validation passes its own cache paths, so nothing is lost.
  private static let suppressedPatterns = [
    "remark: compiled module was created by a different version of the compiler",
    "disabling user-level cache features",
  ]

  /// Output fragments that make a line visible in filtered mode.
  private static let visiblePatterns = [
    "error:",
    "warning:",
    "note:",
    "BUILD FAILED",
    "BUILD SUCCEEDED",
  ]

  /// Maximum number of diagnostic lines reported for a failed step.
  private static let maximumFailureLines = 8

  /// Returns the trimmed line when filtered mode should show it, or `nil` to hide it.
  static func filteredLine(_ line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if suppressedPatterns.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
      return nil
    }

    return visiblePatterns.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) ? trimmed : nil
  }

  /// Returns `true` when the output contains a visible warning diagnostic.
  static func containsWarnings(_ output: String) -> Bool {
    output
      .split(whereSeparator: \.isNewline)
      .contains { filteredLine(String($0)).map(isWarningDiagnostic) == true }
  }

  /// Returns `true` when a line is a warning from a compiler or build tool: `warning:` starts the line or follows a
  /// location (`File.swift:1:1: warning:`), a tool name (`ld: warning:`), or a process tag (`tool[1:2] warning:`).
  ///
  /// Test output that merely mentions `warning:`, such as a test argument, does not count, and neither does
  /// `xcodebuild`'s upper-case `WARNING:` about choosing among matching destinations. Swift Testing's progress lines,
  /// which quote test arguments, start with a symbol: an SF Symbol from the private use planes, or `◇`, `✔`, `✘`, or `↳`.
  private static func isWarningDiagnostic(_ line: String) -> Bool {
    if let first = line.unicodeScalars.first, first.value >= 0xF0000 || "◇✔✘↳".unicodeScalars.contains(first) {
      return false
    }
    return line.hasPrefix("warning: ") || line.contains(": warning: ") || line.contains("] warning: ")
  }

  /// Extracts the first error block, with its leading notes and warnings, from failed step output.
  static func failureDiagnostics(_ output: String) -> [String] {
    let lines = output.split(whereSeparator: \.isNewline).map(String.init)

    guard let firstErrorIndex = lines.firstIndex(where: { $0.localizedCaseInsensitiveContains("error:") }) else {
      return Array(lines.compactMap(filteredLine).prefix(maximumFailureLines))
    }

    var start = firstErrorIndex
    while start > 0 {
      let candidate = lines[start - 1].trimmingCharacters(in: .whitespacesAndNewlines)
      guard !candidate.isEmpty, isDiagnostic(candidate) else { break }
      start -= 1
    }

    var collected: [String] = []
    for line in lines[start...].map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) {
      if isDiagnostic(line) {
        collected.append(line)
      } else if !collected.isEmpty {
        break
      }
    }

    return Array(collected.prefix(maximumFailureLines))
  }

  /// Returns `true` for compiler error, warning, or note lines.
  private static func isDiagnostic(_ line: String) -> Bool {
    line.localizedCaseInsensitiveContains("error:")
      || line.localizedCaseInsensitiveContains("note:")
      || line.localizedCaseInsensitiveContains("warning:")
  }
}
