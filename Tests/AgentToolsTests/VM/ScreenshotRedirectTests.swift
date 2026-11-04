// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentToolsCore

/// Tests rewriting a passed-through `agt ui screenshot` so its path names a host file.
struct ScreenshotRedirectTests {
  /// The path argument is swapped for the guest file, wherever it sits among the options, and resolved on the host.
  @Test(arguments: [
    (["screenshot", "out.png"], ["screenshot", "/tmp/guest.png"], "/work/out.png"),
    (["screenshot", "/shots/a.png", "--app", "com.example.Bookish"], ["screenshot", "/tmp/guest.png", "--app", "com.example.Bookish"], "/shots/a.png"),
    (["screenshot", "--app", "a.png", "b.png"], ["screenshot", "--app", "a.png", "/tmp/guest.png"], "/work/b.png"),
    (["screenshot", "--app=42", "../c.png"], ["screenshot", "--app=42", "/tmp/guest.png"], "/c.png"),
  ])
  func redirects(arguments: [String], guestArguments: [String], hostPath: String) throws {
    let redirect = try #require(ScreenshotRedirect(arguments: arguments, guestPath: "/tmp/guest.png", hostDirectory: "/work"))
    #expect(redirect.guestArguments == guestArguments)
    #expect(redirect.hostPath == hostPath)
  }

  /// Other commands, and a screenshot without a path, pass through unchanged.
  @Test(arguments: [["tree"], ["screenshot"], ["screenshot", "--help"], ["click", "screenshot.png"], []])
  func leavesOthersAlone(arguments: [String]) {
    #expect(ScreenshotRedirect(arguments: arguments, guestPath: "/tmp/guest.png", hostDirectory: "/work") == nil)
  }
}
