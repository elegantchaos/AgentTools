// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// The runtime commands that install, or refresh, every plugin in the Agents repository's marketplace.
///
/// Each runtime lists the repository's plugins in its own marketplace file. Claude Code loads plugins in place, so
/// it registers the marketplace, updates it, then installs and updates each plugin to record its current version.
/// Codex runs plugins from a cached copy, which `plugin add` replaces.
enum PluginInstallPlan {
  /// Returns the repository-relative path of the runtime's marketplace file.
  static func marketplacePath(for runtime: AgentRuntime) -> String {
    switch runtime {
      case .claude: ".claude-plugin/marketplace.json"
      case .codex: ".agents/plugins/marketplace.json"
    }
  }

  /// Returns the arguments for each runtime command, in order, for the marketplace in `marketplace`.
  static func commands(for runtime: AgentRuntime, marketplace: Data, repoRoot: String) throws -> [[String]] {
    let decoded = try JSONDecoder().decode(Marketplace.self, from: marketplace)
    let plugins = decoded.plugins.map { "\($0.name)@\(decoded.name)" }
    switch runtime {
      case .claude:
        return [
          ["plugin", "marketplace", "add", repoRoot],
          ["plugin", "marketplace", "update", decoded.name],
        ] + plugins.flatMap { [["plugin", "install", $0], ["plugin", "update", $0]] }
      case .codex:
        return [["plugin", "marketplace", "add", repoRoot]] + plugins.map { ["plugin", "add", $0] }
    }
  }
}

extension PluginInstallPlan {
  /// The parts of a marketplace file that installation needs.
  private struct Marketplace: Decodable {
    /// The marketplace's name, which qualifies plugin names.
    let name: String

    /// The plugins it lists.
    let plugins: [Plugin]
  }

  /// A plugin listed in a marketplace file.
  private struct Plugin: Decodable {
    /// The plugin's name.
    let name: String
  }
}
