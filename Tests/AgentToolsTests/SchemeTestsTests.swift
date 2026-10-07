// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentToolsCore

/// Tests reading which test targets a product scheme runs, from its scheme file and test plans.
struct SchemeTestsTests {
  /// The scheme file's path; its container directory is `/repo`.
  private let schemePath = "/repo/App.xcodeproj/xcshareddata/xcschemes/App.xcscheme"

  /// A scheme whose test action lists testables, one of them skipped.
  private let testablesScheme = """
    <Scheme>
       <TestAction buildConfiguration = "Debug">
          <Testables>
             <TestableReference
                skipped = "NO">
                <BuildableReference
                   BuildableIdentifier = "primary"
                   BlueprintIdentifier = "CoreTests"
                   BuildableName = "CoreTests"
                   ReferencedContainer = "container:Dependencies/Core">
                </BuildableReference>
             </TestableReference>
             <TestableReference skipped = "YES">
                <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "SlowTests" BuildableName = "SlowTests" BlueprintName = "SlowTests" ReferencedContainer = "container:Dependencies/Core">
                </BuildableReference>
             </TestableReference>
             <TestableReference skipped = "NO">
                <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "1234" BuildableName = "AppTests.xctest" BlueprintName = "AppTests" ReferencedContainer = "container:App.xcodeproj">
                </BuildableReference>
             </TestableReference>
          </Testables>
       </TestAction>
    </Scheme>
    """

  /// Returns a scheme whose test action uses the given test plans, the first being the default.
  private func planScheme(_ plans: [String]) -> String {
    let references = plans.enumerated().map { index, path in
      #"<TestPlanReference reference = "container:\#(path)"\#(index == 0 ? #" default = "YES""# : "")></TestPlanReference>"#
    }
    return "<Scheme><TestAction><TestPlans>\(references.joined())</TestPlans></TestAction></Scheme>"
  }

  /// Returns a test plan listing targets as container and name pairs, with optional disabled targets.
  private func plan(_ targets: [(String, String)], disabled: [(String, String)] = []) -> String {
    func entry(_ target: (String, String), enabled: Bool) -> String {
      #"{\#(enabled ? "" : #""enabled" : false, "#)"target" : {"containerPath" : "container:\#(target.0)", "identifier" : "\#(target.1)", "name" : "\#(target.1)"}}"#
    }
    let entries = targets.map { entry($0, enabled: true) } + disabled.map { entry($0, enabled: false) }
    return #"{"configurations" : [], "testTargets" : [\#(entries.joined(separator: ", "))], "version" : 1}"#
  }

  /// Testables are read with their containers resolved against the scheme's container directory, leaving out skipped
  /// ones. A package's testable names its target only in `BuildableName`; a project's has a `BlueprintName`.
  @Test func readsTestables() {
    let tests = SchemeTests.read(schemeFile: schemePath) { $0 == schemePath ? testablesScheme : nil }
    #expect(tests == SchemeTests(testPlan: nil, source: "testables", targets: [TestTarget(container: "/repo/Dependencies/Core", name: "CoreTests"), TestTarget(container: "/repo/App.xcodeproj", name: "AppTests")]))
  }

  /// A plan named Full Validation is selected even when it is not the scheme's default.
  @Test func prefersTheFullValidationPlan() {
    let files = [
      schemePath: planScheme(["Plans/Quick.xctestplan", "Plans/Full Validation.xctestplan"]),
      "/repo/Plans/Quick.xctestplan": plan([("Dependencies/Core", "CoreTests")]),
      "/repo/Plans/Full Validation.xctestplan": plan([("Dependencies/Core", "CoreTests"), ("Dependencies/Kit", "KitTests")], disabled: [("Dependencies/Slow", "SlowTests")]),
    ]
    let tests = SchemeTests.read(schemeFile: schemePath) { files[$0] }
    #expect(
      tests
        == SchemeTests(
          testPlan: "Full Validation",
          source: "test plan Full Validation",
          targets: [TestTarget(container: "/repo/Dependencies/Core", name: "CoreTests"), TestTarget(container: "/repo/Dependencies/Kit", name: "KitTests")]
        )
    )
  }

  /// Without a Full Validation plan, the scheme's default plan is read, and no plan is selected on the command line.
  @Test func fallsBackToTheDefaultPlan() {
    let files = [
      schemePath: planScheme(["Unit.xctestplan", "Other.xctestplan"]),
      "/repo/Unit.xctestplan": plan([("Dependencies/Core", "CoreTests")]),
    ]
    let tests = SchemeTests.read(schemeFile: schemePath) { files[$0] }
    #expect(tests == SchemeTests(testPlan: nil, source: "test plan Unit", targets: [TestTarget(container: "/repo/Dependencies/Core", name: "CoreTests")]))
  }

  /// A plan that cannot be read lists no targets.
  @Test func unreadablePlanListsNoTargets() {
    let tests = SchemeTests.read(schemeFile: schemePath) { $0 == schemePath ? planScheme(["Full Validation.xctestplan"]) : nil }
    #expect(tests == SchemeTests(testPlan: "Full Validation", source: "test plan Full Validation", targets: []))
  }

  /// A scheme file that cannot be read gives no result.
  @Test func unreadableSchemeGivesNothing() {
    #expect(SchemeTests.read(schemeFile: schemePath) { _ in nil } == nil)
  }

  /// The container directory is the one holding the workspace or project that holds the scheme.
  @Test(arguments: [
    ("/repo/App.xcodeproj/xcshareddata/xcschemes/App.xcscheme", "/repo"),
    ("/repo/Sub/App.xcworkspace/xcshareddata/xcschemes/App.xcscheme", "/repo/Sub"),
    ("/repo/App.xcodeproj/xcuserdata/sam.xcuserdatad/xcschemes/App.xcscheme", "/repo"),
  ])
  func findsTheContainerDirectory(path: String, expected: String) {
    #expect(SchemeTests.containerDirectory(ofSchemeFile: path) == expected)
  }
}
