// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// The test targets a product scheme runs, read from its scheme file and test plans, and the test plan validation
/// selects.
///
/// A scheme's tests come from its test plan named `fullValidationPlan` when it has one, otherwise from its default test
/// plan, otherwise from the testables listed in the scheme. Xcode resolves `container:` paths in a scheme and in its
/// test plans against the directory of the workspace or project holding the scheme, so the targets are resolved the
/// same way.
struct SchemeTests: Equatable {
  /// The name of the test plan full validation runs when a scheme has it.
  static let fullValidationPlan = "Full Validation"

  /// The test plan to select with `-testPlan`, or `nil` to run the scheme's default tests.
  let testPlan: String?

  /// Where the targets were read from, for messages, such as `test plan Full Validation` or `testables`.
  let source: String

  /// The enabled test targets.
  let targets: [TestTarget]

  /// Reads the tests of the scheme in the file at `schemeFile`, reading files with `read`, which returns `nil` for a
  /// file it cannot read. Returns `nil` when the scheme file cannot be read.
  static func read(schemeFile: String, read: (String) -> String?) -> SchemeTests? {
    guard let contents = read(schemeFile), let directory = containerDirectory(ofSchemeFile: schemeFile) else { return nil }
    let plans = planReferences(schemeFile: contents)
    guard !plans.isEmpty else {
      return SchemeTests(testPlan: nil, source: "testables", targets: testables(schemeFile: contents).map { resolve($0, in: directory) })
    }

    let full = plans.first { planName($0.path) == fullValidationPlan }
    guard let chosen = full ?? plans.first(where: \.isDefault) ?? plans.first else { return nil }
    let name = planName(chosen.path)
    let targets = read(resolve(chosen.path, in: directory)).map(planTargets(json:)) ?? []
    return SchemeTests(testPlan: full == nil ? nil : name, source: "test plan \(name)", targets: targets.map { resolve($0, in: directory) })
  }

  /// Returns whether the scheme runs every test of each of `testTargets`, the test targets of the package in
  /// `directory`: each is listed for that package and none is filtered.
  func runsAllTests(_ testTargets: [String], in directory: String) -> Bool {
    let complete = Set(targets(in: directory).filter { !$0.isFiltered }.map(\.name))
    return testTargets.allSatisfy(complete.contains)
  }

  /// Returns the targets the scheme lists for the package or project in `directory`.
  func targets(in directory: String) -> [TestTarget] {
    let container = ValidationPaths.canonical(directory)
    return targets.filter { ValidationPaths.canonical($0.container) == container }
  }

  /// Returns the directory that holds the workspace or project containing the scheme file at `path`.
  static func containerDirectory(ofSchemeFile path: String) -> String? {
    let components = URL(fileURLWithPath: path).pathComponents
    guard let index = components.lastIndex(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) else { return nil }
    return NSString.path(withComponents: Array(components[..<index]))
  }
}

extension SchemeTests {
  /// A test plan a scheme refers to: its `container:` path and whether it is the default.
  private struct PlanReference {
    /// The plan's path relative to the container directory.
    let path: String

    /// Whether the scheme runs this plan by default.
    let isDefault: Bool
  }

  /// Returns the test plans a scheme file refers to, in order.
  private static func planReferences(schemeFile contents: String) -> [PlanReference] {
    elements("TestPlanReference", in: contents).compactMap { attributes in
      guard let reference = attribute("reference", in: attributes) else { return nil }
      return PlanReference(path: stripContainer(reference), isDefault: attribute("default", in: attributes) == "YES")
    }
  }

  /// Returns the testables a scheme file lists and does not skip, as relative containers and names.
  private static func testables(schemeFile contents: String) -> [TestTarget] {
    guard let regex = try? NSRegularExpression(pattern: #"<TestableReference([^>]*)>(.*?)</TestableReference>"#, options: .dotMatchesLineSeparators) else { return [] }
    let range = NSRange(contents.startIndex..., in: contents)
    return regex.matches(in: contents, range: range).compactMap { match in
      guard let attributes = Range(match.range(at: 1), in: contents).map({ String(contents[$0]) }),
        let body = Range(match.range(at: 2), in: contents).map({ String(contents[$0]) }),
        attribute("skipped", in: attributes) != "YES",
        let name = attribute("BlueprintName", in: body) ?? attribute("BuildableName", in: body)?.replacing(".xctest", with: ""),
        let container = attribute("ReferencedContainer", in: body)
      else { return nil }
      let isFiltered = attribute("useTestSelectionWhitelist", in: attributes) == "YES" || body.contains("<SkippedTests") || body.contains("<SelectedTests")
      return TestTarget(container: stripContainer(container), name: name, isFiltered: isFiltered)
    }
  }

  /// Returns a test plan's enabled targets, as relative containers and names, marking those that select or skip
  /// individual tests as filtered; a plan that cannot be decoded has none.
  ///
  /// The plan is read as plain JSON, so any form of test selection Xcode writes counts as a filter.
  private static func planTargets(json: String) -> [TestTarget] {
    guard let plan = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any], let entries = plan["testTargets"] as? [[String: Any]] else { return [] }
    return entries.compactMap { entry in
      guard entry["enabled"] as? Bool != false, let target = entry["target"] as? [String: Any],
        let container = target["containerPath"] as? String, let name = target["name"] as? String
      else { return nil }
      return TestTarget(container: stripContainer(container), name: name, isFiltered: isSelection(entry["selectedTests"]) || isSelection(entry["skippedTests"]))
    }
  }

  /// Returns whether a plan's `selectedTests` or `skippedTests` value names any tests.
  private static func isSelection(_ value: Any?) -> Bool {
    switch value {
      case let list as [Any]: !list.isEmpty
      case let object as [String: Any]: !object.isEmpty
      default: false
    }
  }

  /// Returns the name Xcode gives a test plan: its file name without the extension.
  private static func planName(_ path: String) -> String {
    URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
  }

  /// Returns `target` with its container resolved against `directory`.
  private static func resolve(_ target: TestTarget, in directory: String) -> TestTarget {
    TestTarget(container: resolve(target.container, in: directory), name: target.name, isFiltered: target.isFiltered)
  }

  /// Returns `path` resolved against `directory`, unless it is absolute.
  private static func resolve(_ path: String, in directory: String) -> String {
    path.hasPrefix("/") ? path : URL(fileURLWithPath: directory).appending(path: path).standardizedFileURL.path
  }

  /// Removes a `container:` prefix.
  private static func stripContainer(_ reference: String) -> String {
    reference.hasPrefix("container:") ? String(reference.dropFirst("container:".count)) : reference
  }

  /// Returns the attribute text of each `<name …>` element in `contents`.
  private static func elements(_ name: String, in contents: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: "<\(name)([^>]*)>") else { return [] }
    let range = NSRange(contents.startIndex..., in: contents)
    return regex.matches(in: contents, range: range).compactMap { Range($0.range(at: 1), in: contents).map { String(contents[$0]) } }
  }

  /// Returns the value of the XML attribute `name` in `text`.
  private static func attribute(_ name: String, in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: #"\b\#(name)\s*=\s*"([^"]*)""#),
      let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
      let range = Range(match.range(at: 1), in: text)
    else { return nil }
    return String(text[range])
  }
}
