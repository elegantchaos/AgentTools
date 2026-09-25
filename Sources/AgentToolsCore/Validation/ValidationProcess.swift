// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Runs validation subprocesses through `/usr/bin/env` in the repository directory.
struct ValidationProcess {
  /// Directory that commands run in.
  let workingDirectory: String

  /// Runs a command to completion and captures its separate output streams, adding `environment` to the inherited one.
  func capture(_ arguments: [String], environment: [String: String] = [:]) throws -> CommandResult {
    let process = makeProcess(arguments)
    if !environment.isEmpty {
      process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    }
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
  ///
  /// While it runs, `shouldStop` is checked about twice a second; when it returns `true`, the command is interrupted
  /// as if by Control-C, so tools such as `xcodebuild` can stop cleanly, and terminated if it has not exited ten
  /// seconds later.
  func runLogged(_ arguments: [String], logPath: String, outputMode: ValidateOutputMode, shouldStop: (() -> Bool)? = nil) throws -> ValidationCommandResult {
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
    var ticks = 0
    var interrupted: Date?
    while process.isRunning {
      usleep(100_000)
      ticks += 1
      if let interrupted {
        if Date.now.timeIntervalSince(interrupted) > 10 {
          process.terminate()
        }
      } else if ticks % 5 == 0, shouldStop?() == true {
        process.interrupt()
        interrupted = .now
      }
    }
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
