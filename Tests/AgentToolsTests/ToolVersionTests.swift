// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentTools

/// Tests the version reported by `agt --version`.
struct ToolVersionTests {
  @Test(arguments: [
    ("v3.1.0", "v3.1.0-0-g39466d4", "AgentTools v3.1.0."),
    ("v3.1.0", "v3.1.0-2-g4f5ddf3", "AgentTools v3.1.0-2-g4f5ddf3."),
  ])
  func reportsTagOnlyWhenBuiltFromTheTag(tag: String, git: String, expected: String) {
    #expect(ToolVersion.description(tag: tag, git: git) == expected)
  }
}
