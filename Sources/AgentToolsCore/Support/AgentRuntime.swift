// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// An agent runtime that `agt` maintains: its name, command, and home directory.
///
/// Each runtime keeps its user configuration, skills, and plugins in a home directory, which an environment
/// variable can override.
enum AgentRuntime: String, CaseIterable {
  /// OpenAI's Codex.
  case codex

  /// Anthropic's Claude Code.
  case claude

  /// Environment variable that overrides the runtime's home directory.
  var homeVariable: String {
    switch self {
      case .codex: "CODEX_HOME"
      case .claude: "CLAUDE_CONFIG_DIR"
    }
  }

  /// Name of the runtime's home directory inside the user's home directory.
  var defaultHomeName: String {
    switch self {
      case .codex: ".codex"
      case .claude: ".claude"
    }
  }

  /// Returns the runtime's home directory, honouring its environment override.
  func home(environment: [String: String], homeDirectory: URL) -> URL {
    environment[homeVariable].map { URL(fileURLWithPath: $0) }
      ?? homeDirectory.appendingPathComponent(defaultHomeName)
  }
}
