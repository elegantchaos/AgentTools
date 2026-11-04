// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Runs commands in a running clone over ssh as its guest user, and copies files back with scp.
///
/// Every ssh and scp call uses only the configured key and tart's own known hosts file, never `~/.ssh`, in batch
/// mode so nothing prompts. Clones share their base image's host key but take whatever address DHCP gives them, so
/// `forgetHostKey` drops any old key recorded for the address when a clone first boots, and new keys are accepted on
/// first contact. Commands are sent as one shell command line, built from arguments with `quote`.
struct VMGuest {
  /// The guest account to log in as.
  let user: String

  /// The clone's address.
  let host: String

  /// The private key for `user`.
  let sshKey: String

  /// tart's known hosts file.
  let knownHosts: String

  /// The path of `agt` in the guest.
  let agt: String

  /// The name of the directory share, which macOS guests mount under `/Volumes/My Shared Files`.
  static let shareName = "products"

  /// Where the shared folder appears in the guest.
  static let sharePath = "/Volumes/My Shared Files/\(shareName)"

  /// Creates a connection to the clone at `host` using `settings`.
  init(settings: VMSettings, host: String) {
    self.init(user: settings.guestUser, host: host, sshKey: settings.sshKey, knownHosts: settings.knownHosts, agt: settings.guestAgt)
  }

  /// Creates a connection from its parts.
  init(user: String, host: String, sshKey: String, knownHosts: String, agt: String) {
    self.user = user
    self.host = host
    self.sshKey = sshKey
    self.knownHosts = knownHosts
    self.agt = agt
  }

  /// The options shared by ssh and scp.
  private var options: [String] {
    [
      "-i", sshKey, "-o", "IdentitiesOnly=yes", "-o", "UserKnownHostsFile=\(knownHosts)", "-o", "BatchMode=yes",
      "-o", "StrictHostKeyChecking=accept-new", "-o", "ConnectTimeout=5", "-o", "LogLevel=ERROR",
    ]
  }

  /// A shell command that succeeds once the guest user owns the console and Finder is running.
  var readinessCommand: String {
    "[ \"$(stat -f %Su /dev/console)\" = \(Self.quote(user)) ] && pgrep -qx Finder"
  }

  /// The command line that forgets any host key recorded for the clone's address in tart's known hosts file.
  var forgetHostKeyArguments: [String] {
    ["ssh-keygen", "-R", host, "-f", knownHosts]
  }

  /// Returns the ssh command line that runs `command` in the guest.
  func sshArguments(_ command: [String]) -> [String] {
    sshArguments(script: command.map(Self.quote).joined(separator: " "))
  }

  /// Returns the ssh command line that runs the shell command `script` in the guest.
  func sshArguments(script: String) -> [String] {
    ["ssh"] + options + ["\(user)@\(host)", "--", script]
  }

  /// Returns the scp command line that copies the guest file `guestPath` to `hostPath`.
  func copyArguments(from guestPath: String, to hostPath: String) -> [String] {
    ["scp"] + options + ["\(user)@\(host):\(guestPath)", hostPath]
  }

  /// Returns the guest command that opens `app`, a path relative to the share unless absolute, passing it `arguments`.
  static func launchCommand(app: String, arguments: [String]) -> [String] {
    let path = app.hasPrefix("/") ? app : "\(sharePath)/\(app)"
    return ["open", path] + (arguments.isEmpty ? [] : ["--args"] + arguments)
  }

  /// Returns `word` quoted for a POSIX shell, leaving words made only of safe characters bare.
  static func quote(_ word: String) -> String {
    let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@%+=:,./_-")
    guard !word.isEmpty, word.unicodeScalars.allSatisfy(safe.contains) else {
      return "'\(word.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
    return word
  }

  /// Runs `command` in the guest and captures its output.
  func capture(_ command: [String]) throws -> CommandResult {
    try Self.capture(sshArguments(command))
  }

  /// Runs `command` in the guest with its output passed straight to this process's, returning its exit status.
  func run(_ command: [String]) throws -> Int32 {
    let arguments = sshArguments(command)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
  }

  /// Runs a host command line and captures its output.
  static func capture(_ arguments: [String]) throws -> CommandResult {
    try ValidationProcess(workingDirectory: FileManager.default.currentDirectoryPath).capture(arguments)
  }
}
