// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Tests the tart, ssh and scp command lines `agt vm` runs, and the shell commands it sends to the guest.
struct VMArgumentsTests {
  /// A connection to a clone at a fixed address.
  private let guest = VMGuest(user: "tester", host: "192.168.64.7", sshKey: "/keys/id", knownHosts: "/keys/known hosts", agt: "/usr/local/bin/agt")

  /// The options every ssh and scp call passes.
  private let options = [
    "-i", "/keys/id", "-o", "IdentitiesOnly=yes", "-o", "UserKnownHostsFile=/keys/known hosts", "-o", "BatchMode=yes",
    "-o", "StrictHostKeyChecking=accept-new", "-o", "ConnectTimeout=5", "-o", "LogLevel=ERROR",
  ]

  /// A headless run shares the folder read-only under a fixed name; a windowed run omits `--no-graphics`.
  @Test func runArguments() {
    let tart = Tart(executable: URL(fileURLWithPath: "/bin/tart"))
    #expect(tart.runArguments(name: "agt-x", share: "/build/Debug", window: false) == ["/bin/tart", "run", "agt-x", "--no-graphics", "--dir=products:/build/Debug:ro"])
    #expect(tart.runArguments(name: "agt-x", share: nil, window: true) == ["/bin/tart", "run", "agt-x"])
  }

  /// ssh runs one quoted command line as the guest user, with the tart key and known hosts only.
  @Test func sshArguments() {
    #expect(guest.sshArguments(["agt", "ui", "type", "it's"]) == ["ssh"] + options + ["tester@192.168.64.7", "--", "agt ui type 'it'\\''s'"])
  }

  /// scp copies from the guest with the same options, and the old host key is forgotten from tart's file only.
  @Test func scpAndForgetArguments() {
    #expect(guest.copyArguments(from: "/tmp/shot.png", to: "/work/shot.png") == ["scp"] + options + ["tester@192.168.64.7:/tmp/shot.png", "/work/shot.png"])
    #expect(guest.forgetHostKeyArguments == ["ssh-keygen", "-R", "192.168.64.7", "-f", "/keys/known hosts"])
  }

  /// Words made of safe characters stay bare; anything else is single-quoted.
  @Test(arguments: [("plain", "plain"), ("/a/b-c_d.e", "/a/b-c_d.e"), ("", "''"), ("two words", "'two words'"), ("$HOME", "'$HOME'"), ("it's", "'it'\\''s'")])
  func quoting(word: String, quoted: String) {
    #expect(VMGuest.quote(word) == quoted)
  }

  /// The readiness check waits for the guest user to own the console with Finder running.
  @Test func readinessCommand() {
    #expect(guest.readinessCommand == "[ \"$(stat -f %Su /dev/console)\" = tester ] && pgrep -qx Finder")
  }

  /// Apps are opened from the share unless given an absolute guest path, with any arguments after `--args`.
  @Test func launchCommand() {
    #expect(VMGuest.launchCommand(app: "Bookish.app", arguments: []) == ["open", "/Volumes/My Shared Files/products/Bookish.app"])
    #expect(VMGuest.launchCommand(app: "/System/Applications/TextEdit.app", arguments: ["-reset", "a b"]) == ["open", "/System/Applications/TextEdit.app", "--args", "-reset", "a b"])
  }
}
