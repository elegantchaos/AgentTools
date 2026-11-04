// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import CoreGraphics
import Foundation
import Testing

@testable import AgentToolsCore

/// Verifies how an accessibility hierarchy is captured as a tree and encoded as JSON.
struct AccessibilityNodeTests {
  /// A small application hierarchy: a menu bar with one item, and a window holding a button and a text field.
  let application = FakeElement(
    AccessibilityAttributes(role: "AXApplication", title: "Bookish"),
    children: [
      FakeElement(AccessibilityAttributes(role: "AXMenuBar"), children: [FakeElement(AccessibilityAttributes(role: "AXMenuBarItem", title: "File"))]),
      FakeElement(
        AccessibilityAttributes(role: "AXWindow", subrole: "AXStandardWindow", title: "Library", enabled: true, frame: CGRect(x: 10, y: 20, width: 800, height: 600)),
        children: [
          FakeElement(AccessibilityAttributes(role: "AXButton", title: "Add", identifier: "add-book", description: "Add Book", enabled: false)),
          FakeElement(AccessibilityAttributes(role: "AXTextField", value: "Dune")),
        ]
      ),
    ]
  )

  /// Encoding writes each element's attributes beside its children, and leaves out attributes it does not have.
  @Test func encodesAttributesBesideChildren() throws {
    let node = AccessibilityNode(application, depth: 2)
    let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(node)) as? [String: Any])
    #expect(json["role"] as? String == "AXApplication")
    #expect(json["subrole"] == nil)
    let children = try #require(json["children"] as? [[String: Any]])
    let window = children[1]
    #expect(window["subrole"] as? String == "AXStandardWindow")
    #expect(window["enabled"] as? Bool == true)
    let frame = try #require(window["frame"] as? [String: Double])
    #expect(frame == ["x": 10, "y": 20, "width": 800, "height": 600])
    let button = try #require((window["children"] as? [[String: Any]])?.first)
    #expect(button["identifier"] as? String == "add-book")
    #expect(button["description"] as? String == "Add Book")
    #expect(button["enabled"] as? Bool == false)
    #expect(button["children"] == nil)
    #expect(button["omittedChildren"] == nil)
  }

  /// Elements at the depth limit list no children, but say how many they have.
  @Test func depthLimitCountsOmittedChildren() {
    let node = AccessibilityNode(application, depth: 1)
    let window = node.children[1]
    #expect(window.attributes.title == "Library")
    #expect(window.children.isEmpty)
    #expect(window.omittedChildren == 2)
    #expect(AccessibilityNode(application, depth: 0).omittedChildren == 2)
  }

  /// Elements the caller chooses not to expand appear with a count of their children instead.
  @Test func unexpandedElementsCountTheirChildren() {
    let node = AccessibilityNode(application, depth: 5) { $0.role != "AXMenuBar" }
    let menuBar = node.children[0]
    #expect(menuBar.children.isEmpty)
    #expect(menuBar.omittedChildren == 1)
    #expect(node.children[1].children.count == 2)
  }
}
