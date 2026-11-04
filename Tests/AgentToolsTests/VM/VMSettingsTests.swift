// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Tests resolving `agt vm` settings from the user's and the project's configuration files.
struct VMSettingsTests {
  /// A temporary home directory and repository, removed when the test ends.
  private let root = FileManager.default.temporaryDirectory.appending(path: "agt-vm-settings-\(UUID().uuidString)")

  /// The temporary home directory.
  private var home: URL { root.appending(path: "home") }

  /// The temporary repository.
  private var repo: String { root.appending(path: "repo").path }

  /// Creates the temporary directories; each test removes them.
  init() throws {
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(atPath: repo, withIntermediateDirectories: true)
  }

  /// Writes `json` to `path`, creating its directory.
  private func write(_ json: String, to path: String) throws {
    try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try json.write(toFile: path, atomically: true, encoding: .utf8)
  }

  /// Without configuration files, the settings match the tart test machine's conventions and share validation's
  /// Debug build products.
  @Test func defaults() async throws {
    defer { try? FileManager.default.removeItem(at: root) }
    let settings = try await VMSettings.load(repoPath: repo, homeDirectory: home)
    #expect(settings.baseImage == "golden-gate")
    #expect(settings.guestUser == "tester")
    #expect(settings.sshKey == home.appending(path: ".tart/ssh/id_ed25519").path)
    #expect(settings.knownHosts == home.appending(path: ".tart/ssh/known_hosts").path)
    #expect(settings.guestAgt == "/usr/local/bin/agt")
    #expect(settings.scheme == nil)
    #expect(settings.share == "\(repo)/.build/agt/DerivedData/Build/Products/Debug")
  }

  /// The project's files override the user's, the local project file overrides the committed one, and the scheme
  /// falls back to the first validation scheme.
  @Test func layering() async throws {
    defer { try? FileManager.default.removeItem(at: root) }
    try write(#"{"vm": {"baseImage": "user-base", "guestUser": "someone", "sshKey": "~/keys/vm"}}"#, to: home.appending(path: ".agt/config.json").path)
    try write(#"{"vm": {"baseImage": "project-base", "share": "Build/Products"}, "validate": {"schemes": ["Bookish", "Other"]}}"#, to: "\(repo)/.agt/config.json")
    try write(#"{"vm": {"baseImage": "local-base"}}"#, to: "\(repo)/.agt/local/config.json")

    let settings = try await VMSettings.load(repoPath: repo, homeDirectory: home)

    #expect(settings.baseImage == "local-base")
    #expect(settings.guestUser == "someone")
    #expect(settings.sshKey == home.appending(path: "keys/vm").path)
    #expect(settings.scheme == "Bookish")
    #expect(settings.share == "\(repo)/Build/Products")
  }

  /// An explicit scheme wins over the validation schemes, and an absolute share is used as it is.
  @Test func explicitSchemeAndAbsoluteShare() async throws {
    defer { try? FileManager.default.removeItem(at: root) }
    try write(#"{"vm": {"scheme": "App", "share": "/Volumes/Builds"}, "validate": {"schemes": ["Bookish"]}}"#, to: "\(repo)/.agt/config.json")

    let settings = try await VMSettings.load(repoPath: repo, homeDirectory: home)

    #expect(settings.scheme == "App")
    #expect(settings.share == "/Volumes/Builds")
  }
}
