// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentTools

/// Tests the cached discovery results used by `agt validate`.
struct DiscoveryCacheTests {
  @Test func fingerprintDependsOnFileContentsAndInputs() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try "let a = 1".write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
    try "{}".write(to: root.appendingPathComponent("Package.resolved"), atomically: true, encoding: .utf8)
    let files = ["Package.swift", "Package.resolved"]

    let original = DiscoveryCache.fingerprint(root: root.path, files: files, inputs: ["agt 1"])

    #expect(DiscoveryCache.fingerprint(root: root.path, files: files.reversed(), inputs: ["agt 1"]) == original)
    #expect(DiscoveryCache.fingerprint(root: "/private" + root.path, files: files, inputs: ["agt 1"]) == original)
    #expect(DiscoveryCache.fingerprint(root: root.path, files: files, inputs: ["agt 2"]) != original)
    try "let a = 2".write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
    #expect(DiscoveryCache.fingerprint(root: root.path, files: files, inputs: ["agt 1"]) != original)
  }

  @Test func reusesSavedValuesWithTheSameFingerprint() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let path = root.appendingPathComponent("discovery.json").path
    var computed = 0

    let first = DiscoveryCache(path: path, fingerprint: "one")
    #expect(
      try first.value("answer") {
        computed += 1
        return 42
      } == 42)
    try first.save()

    let second = DiscoveryCache(path: path, fingerprint: "one")
    #expect(
      try second.value("answer") {
        computed += 1
        return 0
      } == 42)
    #expect(computed == 1)

    let changed = DiscoveryCache(path: path, fingerprint: "two")
    #expect(
      try changed.value("answer") {
        computed += 1
        return 7
      } == 7)
    #expect(computed == 2)
  }

  @Test func failuresAreNotCached() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let cache = DiscoveryCache(path: root.appendingPathComponent("discovery.json").path, fingerprint: "one")

    #expect(throws: ToolError.self) {
      let _: Int = try cache.value("answer") { throw ToolError("not yet") }
    }
    #expect(try cache.value("answer") { 3 } == 3)
  }

  @Test func unreadableCacheFileIsIgnored() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let path = root.appendingPathComponent("discovery.json")
    try "not json".write(to: path, atomically: true, encoding: .utf8)

    #expect(try DiscoveryCache(path: path.path, fingerprint: "one").value("answer") { 5 } == 5)
  }

  @Test func fingerprintFilesCoverManifestsProjectsAndSchemes() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let files = [
      "Package.swift",
      "Package.resolved",
      "Dependencies/Core/Package.swift",
      "Dependencies/Core/Package@swift-6.swift",
      "App.xcworkspace/contents.xcworkspacedata",
      "App.xcodeproj/project.pbxproj",
      "App.xcodeproj/xcshareddata/xcschemes/App.xcscheme",
      "App.xcodeproj/xcuserdata/me.xcuserdatad/xcschemes/Mine.xcscheme",
      "Sources/App/App.swift",
      ".build/checkouts/Other/Package.swift",
      "Tests/AppTests/Resources/Fixture/Package.swift",
    ]
    for file in files {
      let url = root.appendingPathComponent(file)
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try "x".write(to: url, atomically: true, encoding: .utf8)
    }

    #expect(Set(ValidationDiscovery.fingerprintFiles(repoPath: root.path)) == Set(files.prefix(8)))
  }

  @Test func packageDescriptionIncludesTargetPaths() throws {
    let json = #"{"targets": [{"name": "Core", "type": "library", "path": "Sources/Core"}]}"#
    let package = try JSONDecoder().decode(SwiftPackageDescription.self, from: Data(json.utf8))
    #expect(package.targets.first?.path == "Sources/Core")
  }

  /// Creates an empty temporary directory.
  private func makeTemporaryDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AgentTools-Discovery-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
