// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Runs link checking and history repair against real repositories built for each test.
struct LinksToolTests {
  /// A check reports only links whose target is missing, whatever characters the names contain.
  @Test func checkReportsMissingTargets() throws {
    let fixture = try LinkFixture()
    defer { fixture.remove() }
    try fixture.write("Docs/Entrée one.md", "Target")
    try fixture.write(
      "Docs/Guide.md",
      """
      [encoded](Entr%C3%A9e%20one.md#part) [plain](<Entrée one.md>) [folder](../Docs) [root](/README.md)
      [web](https://example.com/missing.md) [mail](mailto:sam@example.com) [anchor](#here)
      [gone](Missing.md) and [outside](../../Elsewhere.md)
      ```
      [example](Example.md)
      ```
      """)
    try fixture.write("README.md", "[guide](Docs/Guide.md) [wrong case](docs/Guide.md)")
    try fixture.write("Untracked.md", "[ignored](Nowhere.md)")
    try fixture.git(["add", "Docs", "README.md"])

    let report = try fixture.tool.check()
    #expect(report.broken.map(\.location) == ["Docs/Guide.md:3", "Docs/Guide.md:3", "README.md:1"])
    #expect(report.broken.map(\.link.destination) == ["Missing.md", "../../Elsewhere.md", "docs/Guide.md"])
    #expect(report.unverified.isEmpty)
    #expect(report.hasBrokenLinks)
  }

  /// A repository whose links all resolve passes, including links to files not yet committed.
  @Test func checkPassesWhenEveryLinkResolves() throws {
    let fixture = try LinkFixture()
    defer { fixture.remove() }
    try fixture.write("README.md", "[new](New.md)")
    try fixture.git(["add", "README.md"])
    try fixture.write("New.md", "Not yet tracked")

    let report = try fixture.tool.check()
    #expect(report.hasBrokenLinks == false)
    #expect(report.lines == ["0 broken, 0 unverified"])
  }

  /// A link into a submodule that is not checked out cannot be judged, so it is listed apart and does not fail.
  @Test func submoduleLinksAreUnverifiedWhenNotCheckedOut() throws {
    let fixture = try LinkFixture()
    defer { fixture.remove() }
    try fixture.write("README.md", "[inside](Modules/Kit/README.md) [module](Modules/Kit)")
    let revision = try fixture.commit()
    try fixture.git(["update-index", "--add", "--cacheinfo", "160000,\(revision),Modules/Kit"])

    let report = try fixture.tool.check()
    #expect(report.broken.isEmpty)
    #expect(report.unverified.map(\.link.destination) == ["Modules/Kit/README.md"])
    #expect(report.unverified.first?.problem == .unverified(submodule: "Modules/Kit"))
    #expect(report.hasBrokenLinks == false)
  }

  /// A link to a target that was later renamed points at the commit that introduced the link, keeping its anchor
  /// and leaving the link text and the rest of the entry as written.
  @Test func renamedTargetBecomesAPermalinkToTheIntroducingCommit() throws {
    let fixture = try LinkFixture()
    defer { fixture.remove() }
    try fixture.write("Extras/Decisions/0003-old.md", "Decision")
    try fixture.write("Extras/Journal/Entry.md", "Start")
    try fixture.commit()
    try fixture.write("Extras/Journal/Entry.md", "See [Decision 0003](../Decisions/0003-old.md#context \"Why\") and [web](https://example.com).\n")
    let introduced = try fixture.commit()
    try fixture.write("Extras/Decisions/0003-old.md", "Decision, revised")
    try fixture.commit()
    try fixture.git(["mv", "Extras/Decisions/0003-old.md", "Extras/Decisions/0001-new.md"])
    try fixture.commit()

    let report = try fixture.tool.fixHistory(paths: [], dryRun: false)
    let url = "https://github.com/example/project/blob/\(introduced)/Extras/Decisions/0003-old.md#context"
    #expect(try fixture.read("Extras/Journal/Entry.md") == "See [Decision 0003](\(url) \"Why\") and [web](https://example.com).\n")
    #expect(report.repairs.map(\.outcome) == [.permalink(url: url, resolution: LinkResolution(commit: introduced, path: "Extras/Decisions/0003-old.md", isDirectory: false, basis: .introduced))])
    #expect(report.hasBrokenLinks == false)
    #expect(try fixture.tool.check().hasBrokenLinks == false)
  }

  /// A deleted target, here with an encoded name, resolves the same way, and the permalink is encoded again.
  @Test func deletedTargetWithAnEncodedPathIsRepaired() throws {
    let fixture = try LinkFixture()
    defer { fixture.remove() }
    try fixture.write("Docs/Old Plan é.md", "Plan")
    try fixture.write("Extras/Reviews/Review.md", "[plan](../../Docs/Old%20Plan%20%C3%A9.md) and [docs](../../Docs)")
    let introduced = try fixture.commit()
    try fixture.git(["rm", "--quiet", "-r", "Docs"])
    try fixture.commit()

    _ = try fixture.tool.fixHistory(paths: [], dryRun: false)
    #expect(
      try fixture.read("Extras/Reviews/Review.md")
        == "[plan](https://github.com/example/project/blob/\(introduced)/Docs/Old%20Plan%20%C3%A9.md) and [docs](https://github.com/example/project/tree/\(introduced)/Docs)")
  }

  /// When the linking file has itself moved, the target is found from where the file was when it carried the link.
  @Test func linkIsResolvedFromTheLinkingFilesOldLocation() throws {
    let fixture = try LinkFixture()
    defer { fixture.remove() }
    try fixture.write("Docs/Design.md", "Design")
    try fixture.write("Notes/Entry.md", "[design](../Docs/Design.md)")
    let introduced = try fixture.commit()
    try FileManager.default.createDirectory(at: fixture.root.appending(path: "Extras/Journal/Archive"), withIntermediateDirectories: true)
    try fixture.git(["mv", "Notes/Entry.md", "Extras/Journal/Archive/Entry.md"])
    try fixture.commit()
    try fixture.write("Extras/Journal/Archive/Entry.md", "[design](../Docs/Design.md)\n\nFollow-up.")
    try fixture.commit()

    let report = try fixture.tool.fixHistory(paths: [], dryRun: false)
    #expect(
      report.repairs.map(\.outcome) == [
        .permalink(
          url: "https://github.com/example/project/blob/\(introduced)/Docs/Design.md",
          resolution: LinkResolution(commit: introduced, path: "Docs/Design.md", isDirectory: false, basis: .introduced))
      ])
  }

  /// A link written after its target had gone uses the last commit that held the target, and says so.
  @Test func linkThatNeverResolvedFallsBackToTheCommitBeforeRemoval() throws {
    let fixture = try LinkFixture()
    defer { fixture.remove() }
    try fixture.write("Docs/Gone.md", "Gone")
    try fixture.commit()
    try fixture.write("Docs/Gone.md", "Gone, final text")
    let last = try fixture.commit()
    try fixture.git(["rm", "--quiet", "Docs/Gone.md"])
    try fixture.commit()
    try fixture.write("Extras/Journal/Entry.md", "[gone](../../Docs/Gone.md)")
    try fixture.commit()

    let report = try fixture.tool.fixHistory(paths: [], dryRun: false)
    #expect(
      report.repairs.map(\.outcome) == [
        .permalink(url: "https://github.com/example/project/blob/\(last)/Docs/Gone.md", resolution: LinkResolution(commit: last, path: "Docs/Gone.md", isDirectory: false, basis: .beforeRemoval))
      ])
    #expect(report.lines.first?.contains("fallback") == true)
  }

  /// A target that never existed is left as written and keeps the run failing.
  @Test func targetThatNeverExistedIsLeftUnresolved() throws {
    let fixture = try LinkFixture()
    defer { fixture.remove() }
    let entry = "[typo](../Decisions/Never.md)"
    try fixture.write("Extras/Journal/Entry.md", entry)
    try fixture.commit()

    let report = try fixture.tool.fixHistory(paths: [], dryRun: false)
    #expect(report.repairs.map(\.outcome) == [.unresolved])
    #expect(try fixture.read("Extras/Journal/Entry.md") == entry)
    #expect(report.hasBrokenLinks)
  }

  /// Only historical records are rewritten: by default the journal and reviews, otherwise the paths given.
  @Test(arguments: [([], "Extras/Journal/Entry.md"), (["Notes"], "Notes/Log.md")])
  func onlyHistoricalRecordsAreRewritten(paths: [String], rewritten: String) throws {
    let fixture = try LinkFixture()
    defer { fixture.remove() }
    let documents = ["Extras/Journal/Entry.md", "Notes/Log.md", "Docs/Guide.md"]
    try fixture.write("Old.md", "Old")
    for document in documents {
      try fixture.write(document, "[old](/Old.md)")
    }
    try fixture.commit()
    try fixture.git(["rm", "--quiet", "Old.md"])
    try fixture.commit()

    let report = try fixture.tool.fixHistory(paths: paths, dryRun: false)
    #expect(report.repairs.map(\.finding.file) == [rewritten])
    #expect(report.broken.map(\.file) == documents.filter { $0 != rewritten }.sorted())
    for document in documents where document != rewritten {
      #expect(try fixture.read(document) == "[old](/Old.md)")
    }
    #expect(report.hasBrokenLinks)
  }

  /// A dry run reports the repair it would make, changes nothing, and still fails because the link is broken.
  @Test func dryRunLeavesFilesUnchanged() throws {
    let fixture = try LinkFixture()
    defer { fixture.remove() }
    try fixture.write("Old.md", "Old")
    try fixture.write("Extras/Journal/Entry.md", "[old](../../Old.md)")
    let introduced = try fixture.commit()
    try fixture.git(["rm", "--quiet", "Old.md"])
    try fixture.commit()

    let report = try fixture.tool.fixHistory(paths: [], dryRun: true)
    #expect(try fixture.read("Extras/Journal/Entry.md") == "[old](../../Old.md)")
    #expect(report.lines == ["would fix   Extras/Journal/Entry.md:1  ../../Old.md  ->  \(introduced) Old.md  (the commit that introduced the link)", "0 broken, 0 unverified, 1 fixable"])
    #expect(report.hasBrokenLinks)
  }

  /// A shallow clone lacks the history the repair reads, so it stops before changing anything.
  @Test func shallowCloneIsRefused() throws {
    let fixture = try LinkFixture()
    defer { fixture.remove() }
    try fixture.write("Old.md", "Old")
    try fixture.write("Extras/Journal/Entry.md", "[old](../../Old.md)")
    try fixture.commit()
    try fixture.git(["rm", "--quiet", "Old.md"])
    try fixture.commit()
    let shallow = fixture.root.deletingLastPathComponent().appending(path: "Shallow")
    try fixture.git(["clone", "--quiet", "--depth", "1", fixture.root.absoluteString, shallow.path])

    #expect {
      try LinksTool(directory: shallow.path).fixHistory(paths: [], dryRun: false)
    } throws: { error in
      (error as? ToolError)?.description.contains("shallow clone") == true
    }
    #expect(try String(contentsOf: shallow.appending(path: "Extras/Journal/Entry.md"), encoding: .utf8) == "[old](../../Old.md)")
  }
}
