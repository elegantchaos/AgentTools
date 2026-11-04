// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Configuration
import Foundation

/// The settings `agt vm` uses to clone, reach and share a folder with a tart test machine.
///
/// They come from the `vm` key of the project's `.agt/local/config.json`, then its `.agt/config.json`, then the
/// user's `~/.agt/config.json`, the first that sets a value winning. Machine-specific values, such as the base image
/// and ssh key, belong in the user's file; the scheme and share belong in the project's.
struct VMSettings: Equatable {
  /// The tart image that clones are made from. `agt vm` never stops, deletes or runs it.
  var baseImage: String

  /// The guest account that is logged in to the console and runs the app.
  var guestUser: String

  /// The private key ssh uses for the guest user.
  var sshKey: String

  /// The known hosts file for tart guests, kept apart from `~/.ssh` because clones reuse addresses.
  var knownHosts: String

  /// The path of `agt` in the guest, which holds the guest's Accessibility and Screen Recording grants.
  var guestAgt: String

  /// The scheme that `agt vm start --build` builds, or `nil` when none is configured.
  var scheme: String?

  /// The host folder shared read-only with each clone.
  var share: String

  /// Loads the settings for the repository at `repoPath`, filling in defaults.
  static func load(repoPath: String, homeDirectory: URL) async throws -> VMSettings {
    let paths = ProjectConfiguration.files(repoPath: repoPath) + [ConfigurationFiles.userPath(homeDirectory: homeDirectory)]
    let config = try await ConfigurationFiles.reader(paths: paths)
    let repo = URL(fileURLWithPath: repoPath, isDirectory: true)
    let home = homeDirectory.path

    /// Expands a leading `~` to the home directory and resolves a relative path against `base`.
    func path(_ value: String?, default fallback: String, base: URL) -> String {
      let raw = value ?? fallback
      let expanded = raw == "~" ? home : raw.hasPrefix("~/") ? home + raw.dropFirst() : raw
      return URL(fileURLWithPath: expanded, relativeTo: base).standardizedFileURL.path
    }

    return VMSettings(
      baseImage: config.string(forKey: "vm.baseImage") ?? "golden-gate",
      guestUser: config.string(forKey: "vm.guestUser") ?? "tester",
      sshKey: path(config.string(forKey: "vm.sshKey"), default: "~/.tart/ssh/id_ed25519", base: URL(fileURLWithPath: home, isDirectory: true)),
      knownHosts: path(config.string(forKey: "vm.knownHosts"), default: "~/.tart/ssh/known_hosts", base: URL(fileURLWithPath: home, isDirectory: true)),
      guestAgt: config.string(forKey: "vm.guestAgt") ?? "/usr/local/bin/agt",
      scheme: config.string(forKey: "vm.scheme") ?? config.stringArray(forKey: "validate.schemes")?.first,
      share: path(config.string(forKey: "vm.share"), default: ValidationPaths(repoPath: repoPath).debugProductsPath, base: repo)
    )
  }
}
