// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentToolsCore

/// Tests the wrappers around macOS's private process-responsibility functions.
struct ResponsibleProcessTests {
  /// The test runner was started by another program, so it is not its own responsible process.
  @Test func testProcessIsNotSelfResponsible() {
    #expect(ResponsibleProcess.isSelfResponsible() == false)
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
