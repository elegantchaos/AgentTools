// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Tests the command-line shapes of the `agt vm` commands, and finding tart.
struct VMCommandParsingTests {
  /// `vm ui` keeps its own `--name` and passes everything from the subcommand on to the guest, options included.
  @Test func uiPassesArgumentsThrough() throws {
    let command = try VMUICommand.parse(["--name", "agt-x", "tree", "--app", "com.example.Bookish", "--depth", "3"])
    #expect(command.clone.name == "agt-x")
    #expect(command.arguments == ["tree", "--app", "com.example.Bookish", "--depth", "3"])
    #expect(try VMUICommand.parse(["screenshot", "a.png"]).clone.name == nil)
  }

  /// `vm launch` takes launch arguments after `--`.
  @Test func launchArguments() throws {
    let command = try VMLaunchCommand.parse(["Bookish.app", "--", "-reset"])
    #expect(command.application == "Bookish.app")
    #expect(command.arguments == ["-reset"])
  }

  /// `vm start` boots headless with the configured share unless told otherwise.
  @Test func startDefaults() throws {
    let plain = try VMStartCommand.parse([])
    #expect(plain.name == nil)
    #expect(!plain.window)
    #expect(!plain.build)
    #expect(plain.share == nil)
    let custom = try VMStartCommand.parse(["--name", "agt-mine", "--window", "--build", "--scheme", "App", "--share", "/b"])
    #expect(custom.name == "agt-mine")
    #expect(custom.window && custom.build)
    #expect(custom.scheme == "App")
    #expect(custom.share == "/b")
  }

  /// tart is found on `PATH` first, then in the usual install locations, and its absence is a clear error.
  @Test func locatingTart() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "agt-tart-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let home = root.appending(path: "home")
    let app = home.appending(path: "Applications/tart.app/Contents/MacOS")
    try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)

    #expect(throws: ToolError.self) { try Tart.locate(environment: ["PATH": root.path], homeDirectory: home, rootDirectory: root) }

    let bundled = app.appending(path: "tart")
    try Data("#!/bin/sh\n".utf8).write(to: bundled)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bundled.path)
    #expect(try Tart.locate(environment: [:], homeDirectory: home, rootDirectory: root).executable == bundled)

    let onPath = root.appending(path: "tart")
    try FileManager.default.copyItem(at: bundled, to: onPath)
    #expect(try Tart.locate(environment: ["PATH": root.path], homeDirectory: home, rootDirectory: root).executable == onPath)
  }
}
