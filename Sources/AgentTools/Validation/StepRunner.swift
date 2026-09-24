// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Runs logged command steps, records PASS/FAIL/SKIP results, and prints the summary.
final class StepRunner {
  /// Subprocess runner rooted at the repository.
  let process: ValidationProcess
  /// Terminal output mode.
  private let outputMode: ValidateOutputMode
  /// Whether to list steps instead of running them.
  private let planOnly: Bool
  /// Steps recorded so far, in order.
  private var steps: [ValidationStepRecord] = []
  /// Commands listed so far in plan mode, in order.
  private(set) var plannedCommands: [[String]] = []

  /// Creates a runner for commands in `repoPath`; with `planOnly`, steps are listed instead of run.
  init(repoPath: String, outputMode: ValidateOutputMode, planOnly: Bool = false) {
    self.process = ValidationProcess(workingDirectory: repoPath)
    self.outputMode = outputMode
    self.planOnly = planOnly
  }

  /// Runs one logged step, recording PASS or FAIL and throwing on failure.
  ///
  /// `display` replaces the arguments when echoing the command, for commands whose full argument list is too long to show.
  func run(title: String, summary: String, arguments: [String], display: [String]? = nil, logPath: String) throws {
    let command = (display ?? arguments).joined(separator: " ")
    if planOnly {
      plannedCommands.append(arguments)
      print("\(plannedCommands.count). \(summary)")
      print("   + /usr/bin/env \(command)")
      return
    }

    print("== \(title)")
    print("+ /usr/bin/env \(command)")

    let result = try process.runLogged(arguments, logPath: logPath, outputMode: outputMode)

    guard result.status == 0 else {
      if outputMode != .raw {
        for line in ValidationOutput.failureDiagnostics(result.output) {
          print(line)
        }
      }
      print("log: \(logPath)")
      record(summary, status: .fail, warningsPresent: result.warningsPresent, logPath: logPath)
      throw ToolError("Command failed with exit code \(result.status): /usr/bin/env \(command)")
    }

    record(summary, status: .pass, warningsPresent: result.warningsPresent, logPath: logPath)
    if result.warningsPresent || outputMode == .quiet {
      print("log: \(logPath)")
    }
  }

  /// Records a step result and prints its status line.
  func record(_ summary: String, status: ValidationStepStatus, warningsPresent: Bool = false, logPath: String? = nil) {
    steps.append(ValidationStepRecord(summary: summary, status: status, warningsPresent: warningsPresent, logPath: logPath))

    var line = "\(status.rawValue) \(summary)"
    if warningsPresent {
      line += " [warnings]"
    }
    if status != .pass, let logPath {
      line += " (\(logPath))"
    }
    print(line)
  }

  /// Prints every recorded step, with log paths for failures, or the number of planned steps.
  func printSummary() {
    if planOnly {
      print("== Plan: \(plannedCommands.count) steps")
      return
    }
    guard !steps.isEmpty else { return }
    print("== Summary")
    for step in steps {
      var line = "\(step.status.rawValue) \(step.summary)"
      if step.warningsPresent {
        line += " [warnings]"
      }
      if step.status == .fail, let logPath = step.logPath {
        line += " -> \(logPath)"
      }
      print(line)
    }
  }
}
