// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentToolsCore

/// Verifies which executable a missing-permission message tells the user to allow.
struct UIPermissionTests {
  /// Over ssh, TCC checks the wrapper sshd starts as, not the session it execs; other paths are named as they are.
  @Test(arguments: [
    ("/usr/libexec/sshd-session", "/usr/libexec/sshd-keygen-wrapper"),
    ("/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal", "/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal"),
  ])
  func granteeNamesTheExecutableTCCChecks(responsible: String, grantee: String) {
    #expect(UIPermission.grantee(responsiblePath: responsible) == grantee)
  }

  /// Without a responsible path there is nothing to name.
  @Test func granteeIsMissingWithoutAPath() {
    #expect(UIPermission.grantee(responsiblePath: nil) == nil)
  }
}
