// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentToolsCore

/// Tests naming clones and refusing to remove anything else.
struct VMCloneTests {
  /// Generated names carry the clone prefix and the base image's name, and differ each time.
  @Test func generatedNames() {
    let first = VMClone.generatedName(base: "golden-gate")
    let second = VMClone.generatedName(base: "golden-gate")
    #expect(first.hasPrefix("agt-golden-gate-"))
    #expect(first != second)
    #expect(VMClone.isClone(first))
  }

  /// Only names with the clone prefix that are not the base image are disposable.
  @Test(arguments: [
    ("agt-golden-gate-1a2b3c", "golden-gate", true),
    ("golden-gate", "golden-gate", false),
    ("agt-base", "agt-base", false),
    ("my-vm", "golden-gate", false),
    ("agt-", "golden-gate", false),
  ])
  func disposable(name: String, base: String, expected: Bool) {
    let accepted = (try? VMClone.requireDisposable(name, base: base)) != nil
    #expect(accepted == expected, "\(name) with base \(base)")
  }
}
