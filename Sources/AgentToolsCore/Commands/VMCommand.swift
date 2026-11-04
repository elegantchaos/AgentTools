// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Parent command for running a macOS app in a throwaway tart clone and driving it from the host.
struct VMCommand: AsyncParsableCommand {
  /// Command metadata and available subcommands.
  static let configuration = CommandConfiguration(
    commandName: "vm",
    abstract: "Run an app in a throwaway tart clone and drive it with agt ui from the host.",
    discussion: """
      start clones the base image, boots the clone with a host folder shared read-only, and waits until the guest \
      user owns the console. launch opens an app from the share, ui runs agt ui in the guest, and stop deletes the \
      clone. Clone names start with agt-; when only one clone is running, the commands use it without --name. \
      The base image and any VM agt did not name are never stopped, deleted or driven. Requires tart (https://tart.run). \
      Settings come from the vm key of .agt/local/config.json, .agt/config.json and ~/.agt/config.json, in that \
      order: baseImage (default golden-gate), guestUser (tester), sshKey (~/.tart/ssh/id_ed25519), knownHosts \
      (~/.tart/ssh/known_hosts), guestAgt (/usr/local/bin/agt), scheme (the first validate.schemes) and share \
      (.build/agt/DerivedData/Build/Products/Debug, where agt validate builds). ssh never reads ~/.ssh.
      """,
    subcommands: [VMStartCommand.self, VMLaunchCommand.self, VMUICommand.self, VMStopCommand.self, VMListCommand.self]
  )
}
