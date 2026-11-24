// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 20/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Darwin
import Foundation

/// Starts an interactive Claude Code session with Ollama's installed models and its own persistent profile.
struct ClaudeCommand: ParsableCommand {
  /// Opens the terminal UI without changing a user's regular Claude settings.
  static let configuration = CommandConfiguration(
    commandName: "claude",
    abstract: "Launch Claude Code using the local Ollama server.",
    discussion: "Run from a terminal. Ollama must already be listening on 127.0.0.1:11434. The session is tool-free and uses a separate local profile."
  )

  /// The installed Ollama model to select initially.
  @Option(help: "Installed Ollama model to select at startup. Defaults to the saved model or gpt-oss:20b.")
  var model: String?

  /// The base URL shared by the catalog request and Claude Code.
  static let endpoint = "http://127.0.0.1:11434"

  /// Settings owned by the launcher so the private profile uses the local provider.
  private static let providerEnvironment = [
    "ANTHROPIC_BASE_URL": endpoint,
    "ANTHROPIC_API_KEY": "ollama",
    "CLAUDE_CODE_USE_BEDROCK": "0",
    "CLAUDE_CODE_USE_FOUNDRY": "0",
    "CLAUDE_CODE_USE_VERTEX": "0",
    "NO_PROXY": "127.0.0.1",
    "no_proxy": "127.0.0.1",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "DISABLE_AUTOUPDATER": "1",
  ]

  /// Reads the catalog, then runs Claude Code in the terminal's process group until it exits.
  func run() throws {
    guard isatty(STDIN_FILENO) == 1, isatty(STDOUT_FILENO) == 1 else {
      throw ToolError("Run agt claude in an interactive terminal.")
    }
    let locator = RuntimeCommandLocator.current
    guard let executable = locator.locate(.claude) else {
      throw ToolError("Claude Code was not found. Install the Claude Code CLI and try again.")
    }
    let userHome =
      locator.environment["HOME"]
      .flatMap { $0.hasPrefix("/") ? URL(filePath: $0, directoryHint: .isDirectory) : nil } ?? locator.homeDirectory
    let home = try Self.prepareProfile(in: userHome)
    let arguments = try launchArguments(catalog: fetchCatalog(), profile: home)

    let code = try runInTerminal(executable.path, arguments: arguments, environment: launchEnvironment(locator.environment, home: home))
    if code != 0 { throw ExitCode(rawValue: code) }
  }

  /// Opens the local profile's private home, preserving the existing Claude state on later launches.
  static func prepareProfile(in userHome: URL) throws -> URL {
    let profile = userHome.appending(path: "Library/Application Support/AgentTools/ClaudeOllama", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    return profile
  }

  /// Builds the launch flags from Ollama's OpenAI-compatible model catalog.
  func launchArguments(catalog: Data, profile: URL? = nil) throws -> [String] {
    guard let catalog = try? JSONDecoder().decode(Catalog.self, from: catalog), !catalog.data.isEmpty else {
      throw ToolError("Ollama returned no usable models at \(Self.endpoint)/v1/models.")
    }
    let ids = catalog.data.map(\.id)
    let savedModel = profile.flatMap { Self.savedModel(in: $0) }.flatMap { ids.contains($0) ? $0 : nil }
    let startingModel = model ?? savedModel ?? "gpt-oss:20b"
    guard ids.contains(startingModel) else {
      throw ToolError("Ollama does not have \(startingModel). Choose an installed model with --model: \(ids.joined(separator: ", ")).")
    }
    let rows = ids.map { ["model": $0, "label": $0] }
    let settings = try JSONSerialization.data(withJSONObject: [
      "modelPicker": ["replaceBuiltInOptions": true, "options": rows],
      "env": Self.providerEnvironment,
    ])
    return [
      "--bare", "--setting-sources", "user", "--tools", "", "--strict-mcp-config",
      "--mcp-config", #"{"mcpServers":{}}"#, "--system-prompt", "Reply briefly.",
      "--model", startingModel, "--settings", String(decoding: settings, as: UTF8.self),
    ]
  }

  /// Sets provider and auth for this process only, ignoring inherited Claude overrides and credentials.
  func launchEnvironment(_ inherited: [String: String], home: URL) -> [String: String] {
    var environment = inherited.filter { key, _ in
      !key.hasPrefix("ANTHROPIC_") && !key.hasPrefix("CLAUDE_CODE_") && key != "MAX_THINKING_TOKENS"
    }
    environment["HOME"] = home.path
    environment["CLAUDE_CONFIG_DIR"] = home.appending(path: ".claude").path
    return environment.merging(Self.providerEnvironment) { _, local in local }
  }

  /// Reads the saved selection without importing any of Claude's other preferences into the launcher.
  private static func savedModel(in home: URL) -> String? {
    let settings = home.appending(path: ".claude/settings.json", directoryHint: .notDirectory)
    guard let data = try? Data(contentsOf: settings) else { return nil }
    return (try? JSONDecoder().decode(ProfileSettings.self, from: data))?.model
  }

  /// The preference needed to match Claude's default against the installed catalog.
  private struct ProfileSettings: Decodable {
    /// Claude's saved default model ID.
    let model: String?
  }

  /// Reads the server inventory without starting or loading a model.
  private func fetchCatalog() throws -> Data {
    let process = ValidationProcess(workingDirectory: FileManager.default.currentDirectoryPath)
    let result = try process.capture([
      "/usr/bin/curl", "-q", "--noproxy", "127.0.0.1", "--fail", "--silent", "--show-error",
      "--max-time", "5", "\(Self.endpoint)/v1/models",
    ])
    guard result.status == 0 else {
      throw ToolError("Could not read the Ollama model list at \(Self.endpoint). Check that the service is running. \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    return Data(result.stdout.utf8)
  }

  /// Inherits the current terminal and process group so the child can read input and handle terminal signals.
  private func runInTerminal(_ executable: String, arguments: [String], environment: [String: String]) throws -> Int32 {
    let argv = ([executable] + arguments).map { strdup($0) } + [nil]
    let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
    defer {
      for string in argv + envp { free(string) }
    }
    var pid = pid_t()
    let result = posix_spawn(&pid, executable, nil, nil, argv, envp)
    guard result == 0 else {
      throw ToolError("Could not start Claude Code: \(String(cString: strerror(result))).")
    }

    var status: Int32 = 0
    while waitpid(pid, &status, 0) == -1 {
      guard errno == EINTR else {
        throw ToolError("Could not wait for Claude Code: \(String(cString: strerror(errno))).")
      }
    }
    let signal = status & 0x7f
    return signal == 0 ? (status >> 8) & 0xff : 128 + signal
  }

  /// The subset of the model catalog used by the launcher.
  private struct Catalog: Decodable {
    /// Models returned by /v1/models.
    let data: [Model]

    /// An installed model and its provider ID.
    struct Model: Decodable {
      /// The raw tag sent to Ollama.
      let id: String
    }
  }
}
