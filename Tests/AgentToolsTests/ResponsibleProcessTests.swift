// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Darwin
import Testing

@testable import AgentToolsCore

/// Tests the wrappers around macOS's private process-responsibility functions.
struct ResponsibleProcessTests {
  /// Responsibility depends on the resolved process ID, including an unavailable lookup, rather than the test host.
  @Test(arguments: [
    (pid_t?.some(42), Bool?.some(true)),
    (pid_t?.some(7), Bool?.some(false)),
    (pid_t?.none, Bool?.none),
  ])
  func checksResolvedResponsibility(resolvedPID: pid_t?, expected: Bool?) {
    let result = ResponsibleProcess.isSelfResponsible(processID: 42) { pid in
      #expect(pid == 42)
      return resolvedPID
    }
    #expect(result == expected)
  }

  /// A disclaimed process runs, and its exit status is returned.
  @Test func runsDisclaimedProcess() throws {
    #expect(try ResponsibleProcess.runDisclaimed(executable: "/bin/sh", arguments: ["-c", "exit 3"], environment: [:]) == 3)
  }

  /// A missing executable is reported as an error.
  @Test func reportsMissingExecutable() {
    #expect(throws: ToolError.self) {
      try ResponsibleProcess.runDisclaimed(executable: "/nonexistent/agt", arguments: [], environment: [:])
    }
  }
}
