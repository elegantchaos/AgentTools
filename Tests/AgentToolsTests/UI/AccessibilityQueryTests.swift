// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentToolsCore

/// Verifies how `agt ui press` finds the element it presses.
struct AccessibilityQueryTests {
  /// A menu item and a deeper toolbar button share a title; a text field has an identifier and a description.
  let application = FakeElement(
    AccessibilityAttributes(role: "AXApplication"),
    children: [
      FakeElement(
        AccessibilityAttributes(role: "AXWindow"),
        children: [
          FakeElement(AccessibilityAttributes(role: "AXToolbar"), children: [FakeElement(AccessibilityAttributes(role: "AXButton", title: "New"))]),
          FakeElement(AccessibilityAttributes(role: "AXTextField", identifier: "search", description: "Search Books")),
        ]
      ),
      FakeElement(AccessibilityAttributes(role: "AXMenuItem", title: "New")),
    ]
  )

  /// The match nearest the root wins, and a role narrows the candidates.
  @Test func nearestMatchWinsAndRoleNarrows() {
    #expect(AccessibilityQuery(text: "New").firstMatch(in: application, maximumDepth: 10)?.attributes.role == "AXMenuItem")
    #expect(AccessibilityQuery(text: "New", role: "AXButton").firstMatch(in: application, maximumDepth: 10)?.attributes.role == "AXButton")
  }

  /// Identifiers and descriptions match as well as titles.
  @Test(arguments: ["search", "Search Books"])
  func identifiersAndDescriptionsMatch(text: String) {
    #expect(AccessibilityQuery(text: text).firstMatch(in: application, maximumDepth: 10)?.attributes.role == "AXTextField")
  }

  /// Matching is exact, and elements beyond the depth limit are not searched.
  @Test func matchesAreExactAndDepthLimited() {
    #expect(AccessibilityQuery(text: "Search").firstMatch(in: application, maximumDepth: 10) == nil)
    #expect(AccessibilityQuery(text: "New", role: "AXButton").firstMatch(in: application, maximumDepth: 2) == nil)
  }
}
