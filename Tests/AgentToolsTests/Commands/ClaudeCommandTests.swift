// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 20/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Exercises the launcher through the root parser and checks the catalog and provider passed to Claude Code.
struct ClaudeCommandTests {
  /// The default and an explicit model reach Claude Code by their exact Ollama IDs.
  @Test(arguments: ["gpt-oss:20b", "qwen3-coder-next:q4_K_M"])
  func buildsLocalPicker(model: String) throws {
    let options = model == "gpt-oss:20b" ? ["claude"] : ["claude", "--model", model]
    let command = try #require(try AgentToolsCommand.parseAsRoot(options) as? ClaudeCommand)
    let catalog = Data(#"{"data":[{"id":"gpt-oss:20b"},{"id":"qwen3-coder-next:q4_K_M"}]}"#.utf8)
    let arguments = try command.launchArguments(catalog: catalog)
    #expect(arguments.dropLast(2).suffix(2) == ["--model", model])

    #expect(!arguments.contains("--effort"))
    #expect(arguments.contains("--bare"))
    #expect(arguments.contains("--strict-mcp-config"))
    let optionPairs = zip(arguments, arguments.dropFirst()).map { [$0.0, $0.1] }
    #expect(optionPairs.contains(["--setting-sources", "user"]))
    #expect(optionPairs.contains(["--tools", ""]))
    #expect(optionPairs.contains(["--mcp-config", #"{"mcpServers":{}}"#]))

    let settings = try #require(arguments.last)
    let json = try JSONSerialization.jsonObject(with: Data(settings.utf8))
    let configuration = try #require(json as? [String: Any])
    let environment = try #require(configuration["env"] as? [String: String])
    #expect(environment["ANTHROPIC_BASE_URL"] == "http://127.0.0.1:11434")
    #expect(environment["ANTHROPIC_API_KEY"] == "ollama")
    #expect(environment["CLAUDE_CODE_MAX_OUTPUT_TOKENS"] == nil)
    #expect(configuration["effortLevel"] == nil)
    let picker = try #require(configuration["modelPicker"] as? [String: Any])
    #expect(picker["replaceBuiltInOptions"] as? Bool == true)
    #expect(
      picker["options"] as? [[String: String]] == [
        ["model": "gpt-oss:20b", "label": "gpt-oss:20b"],
        ["model": "qwen3-coder-next:q4_K_M", "label": "qwen3-coder-next:q4_K_M"],
      ])
  }

  /// The local profile restores its model, while an explicit selection applies once.
  @Test func selectsInstalledProfileModel() throws {
    let profile = FileManager.default.temporaryDirectory.appending(path: "agt-claude-test-\(UUID().uuidString)")
    let settingsDirectory = profile.appending(path: ".claude")
    try FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: profile) }

    let settings = settingsDirectory.appending(path: "settings.json")
    let data = Data(#"{"model":"qwen3.8:27b-mlx","effortLevel":"high"}"#.utf8)
    try data.write(to: settings)
    let command = try ClaudeCommand.parse([])
    let explicit = try ClaudeCommand.parse(["--model", "gpt-oss:20b"])
    let catalog = Data(#"{"data":[{"id":"gpt-oss:20b"},{"id":"qwen3.8:27b-mlx"}]}"#.utf8)
    let defaultOnly = Data(#"{"data":[{"id":"gpt-oss:20b"}]}"#.utf8)
    let saved = try command.launchArguments(catalog: catalog, profile: profile)
    let override = try explicit.launchArguments(catalog: catalog, profile: profile)
    let fallback = try command.launchArguments(catalog: defaultOnly, profile: profile)

    #expect(saved.dropLast(2).suffix(2) == ["--model", "qwen3.8:27b-mlx"])
    #expect(override.dropLast(2).suffix(2) == ["--model", "gpt-oss:20b"])
    #expect(fallback.dropLast(2).suffix(2) == ["--model", "gpt-oss:20b"])
    #expect(try Data(contentsOf: settings) == data)
    #expect(throws: ToolError.self) {
      try ClaudeCommand.parse(["--model", "missing:latest"]).launchArguments(catalog: catalog, profile: profile)
    }
  }

  /// An unavailable starting model or invalid response prevents the launcher from opening.
  @Test(arguments: [#"{"data":[{"id":"other:latest"}]}"#, #"{"data":[]}"#, "invalid"])
  func rejectsUnusableCatalog(response: String) throws {
    let command = try ClaudeCommand.parse([])
    #expect(throws: ToolError.self) {
      try command.launchArguments(catalog: Data(response.utf8))
    }
  }

  /// A second launch uses the same private directory and leaves the saved Claude state intact.
  @Test func retainsLocalProfile() throws {
    let fileManager = FileManager.default
    let userHome = fileManager.temporaryDirectory.appending(path: "agt-claude-test-\(UUID().uuidString)")
    defer { try? fileManager.removeItem(at: userHome) }

    let profile = try ClaudeCommand.prepareProfile(in: userHome)
    #expect(profile == userHome.appending(path: "Library/Application Support/AgentTools/ClaudeOllama", directoryHint: .isDirectory))
    let permissions = try fileManager.attributesOfItem(atPath: profile.path)[.posixPermissions] as? Int
    #expect(permissions == 0o700)

    let settings = profile.appending(path: ".claude.json")
    let state = Data(#"{"hasCompletedOnboarding":true}"#.utf8)
    try state.write(to: settings)
    let nextProfile = try ClaudeCommand.prepareProfile(in: userHome)
    #expect(nextProfile == profile)
    #expect(try Data(contentsOf: nextProfile.appending(path: ".claude.json")) == state)
  }

  /// Tokens, provider overrides and custom headers from the caller never reach the local session.
  @Test func isolatesLocalProvider() throws {
    let command = try ClaudeCommand.parse([])
    let environment = command.launchEnvironment(
      [
        "ANTHROPIC_API_KEY": "hosted-key",
        "ANTHROPIC_AUTH_TOKEN": "hosted-token",
        "ANTHROPIC_CUSTOM_HEADERS": "authorization: hosted",
        "CLAUDE_CODE_OAUTH_TOKEN": "oauth-token",
        "CLAUDE_CODE_USE_BEDROCK": "1",
        "MAX_THINKING_TOKENS": "1024",
        "HOME": "/regular",
        "PATH": "/usr/bin",
      ], home: URL(filePath: "/ollama-profile"))
    #expect(environment["ANTHROPIC_BASE_URL"] == "http://127.0.0.1:11434")
    #expect(environment["ANTHROPIC_API_KEY"] == "ollama")
    #expect(environment["ANTHROPIC_AUTH_TOKEN"] == nil)
    #expect(environment["ANTHROPIC_CUSTOM_HEADERS"] == nil)
    #expect(environment["CLAUDE_CODE_OAUTH_TOKEN"] == nil)
    #expect(environment["CLAUDE_CODE_USE_BEDROCK"] == "0")
    #expect(environment["HOME"] == "/ollama-profile")
    #expect(environment["CLAUDE_CONFIG_DIR"] == "/ollama-profile/.claude")
    #expect(environment["PATH"] == "/usr/bin")
    #expect(environment["CLAUDE_CODE_DISABLE_THINKING"] == nil)
    #expect(environment["MAX_THINKING_TOKENS"] == nil)
    #expect(environment["CLAUDE_CODE_MAX_CONTEXT_TOKENS"] == nil)
    #expect(environment["CLAUDE_CODE_MAX_OUTPUT_TOKENS"] == nil)
    #expect(environment["CLAUDE_CODE_MAX_RETRIES"] == nil)
  }
}
