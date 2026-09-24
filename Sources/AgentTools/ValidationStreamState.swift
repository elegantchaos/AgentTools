// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Thread-safe aggregation state for streamed validation output.
final class ValidationStreamState: @unchecked Sendable {
  /// Lock protecting the mutable buffers.
  private let lock = NSLock()
  /// Complete raw subprocess output.
  private var combinedData = Data()
  /// Terminal text waiting to form a complete line.
  private var bufferedTerminalText = ""
  /// Whether the stream has completed.
  private var sawEOF = false

  /// Appends raw output to the combined buffer and, in filtered mode, the line buffer.
  func append(_ data: Data, outputMode: ValidateOutputMode) {
    lock.withLock {
      combinedData.append(data)
      guard outputMode == .filtered, let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
      bufferedTerminalText += chunk
    }
  }

  /// Returns complete filtered lines accumulated since the last drain.
  func drainFilteredLines() -> [String] {
    lock.withLock {
      let lines = bufferedTerminalText.components(separatedBy: .newlines)
      bufferedTerminalText = lines.last ?? ""
      return lines.dropLast().compactMap(ValidationOutput.filteredLine)
    }
  }

  /// Returns the final trailing filtered line after a stream completes.
  func flushTrailingFilteredLine() -> String? {
    lock.withLock {
      defer { bufferedTerminalText = "" }
      return ValidationOutput.filteredLine(bufferedTerminalText)
    }
  }

  /// Returns the full combined process output as a string.
  func outputString() -> String {
    lock.withLock { String(data: combinedData, encoding: .utf8) ?? "" }
  }

  /// Marks the stream as complete, returning `true` only on the first EOF.
  func markEOF() -> Bool {
    lock.withLock {
      guard !sawEOF else { return false }
      sawEOF = true
      return true
    }
  }
}
