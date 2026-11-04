// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// The `--name` option shared by `agt vm` commands that act on an existing clone.
struct VMCloneOptions: ParsableArguments {
  /// The clone named on the command line, if any.
  @Option(help: "The clone to use (default: the only running clone, or for stop the only clone).")
  var name: String?

  /// Returns the clone to act on, refusing the base image and VMs agt did not make. Without `--name`, it is the
  /// only clone, considering only running ones when `running` is set.
  func resolve(tart: Tart, settings: VMSettings, running: Bool) throws -> String {
    if let name {
      try VMClone.requireDisposable(name, base: settings.baseImage)
      return name
    }
    let clones = try tart.list().filter { VMClone.isClone($0.name) && $0.name != settings.baseImage && (!running || $0.isRunning) }
    guard clones.count == 1, let clone = clones.first else {
      let kind = running ? "running clone" : "clone"
      let names = clones.map(\.name).joined(separator: ", ")
      throw ToolError(clones.isEmpty ? "There is no \(kind); start one with agt vm start." : "There is more than one \(kind) (\(names)); choose one with --name.")
    }
    return clone.name
  }

  /// Returns a connection to the running clone this option selects.
  func guest(tart: Tart, settings: VMSettings) throws -> VMGuest {
    let clone = try resolve(tart: tart, settings: settings, running: true)
    guard let address = try tart.ip(clone) else {
      throw ToolError("\(clone) has no address; is it running?")
    }
    return VMGuest(settings: settings, host: address)
  }
}
