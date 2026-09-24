// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Runs validation subprocesses through `/usr/bin/env` in the repository directory.
struct ValidationProcess {
  /// Directory that commands run in.
  let workingDirectory: String

  /// Runs a command to completion and captures its separate output streams.
  func capture(_ arguments: [String]) throws -> CommandResult {
    let process = makeProcess(arguments)
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    return CommandResult(
      status: process.terminationStatus,
      stdout: String(decoding: stdout, as: UTF8.self),
      stderr: String(decoding: stderr, as: UTF8.self)
    )
  }

  /// Runs a command with merged output written to a log, streaming it to the terminal according to the output mode.
  func runLogged(_ arguments: [String], logPath: String, outputMode: ValidateOutputMode) throws -> ValidationCommandResult {
    let process = makeProcess(arguments)
    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    let logURL = URL(fileURLWithPath: logPath)
    try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: logPath, contents: nil)
    let logHandle = try FileHandle(forWritingTo: logURL)
    defer { try? logHandle.close() }

    let readHandle = outputPipe.fileHandleForReading
    let group = DispatchGroup()
    group.enter()

    let state = ValidationStreamState()
    readHandle.readabilityHandler = { handle in
      let data = handle.availableData
      if data.isEmpty {
        if state.markEOF() {
          group.leave()
        }
        return
      }

      state.append(data, outputMode: outputMode)
      try? logHandle.write(contentsOf: data)

      switch outputMode {
        case .quiet:
          break
        case .raw:
          // Flush buffered `print` output first so raw chunks stay in order when stdout is a pipe.
          fflush(stdout)
          FileHandle.standardOutput.write(data)
        case .filtered:
          for line in state.drainFilteredLines() {
            print(line)
          }
      }
    }

    try process.run()
    process.waitUntilExit()
    group.wait()
    readHandle.readabilityHandler = nil

    let output = state.outputString()
    if outputMode == .filtered, let trailing = state.flushTrailingFilteredLine() {
      print(trailing)
    }

    return ValidationCommandResult(
      status: process.terminationStatus,
      output: output,
      warningsPresent: ValidationOutput.containsWarnings(output)
    )
  }

  /// Creates a process for an `env`-resolved command in the working directory.
  private func makeProcess(_ arguments: [String]) -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
    return process
  }
}
