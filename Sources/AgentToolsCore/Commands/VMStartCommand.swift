// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Clones the base image, boots the clone with a host folder shared, and waits until its GUI session is ready.
struct VMStartCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "start",
    abstract: "Clone the base image and boot the clone, sharing a host folder read-only.",
    discussion: """
      Prints the clone's name and address once the guest user owns the console and Finder is running. The share \
      appears in the guest at "/Volumes/My Shared Files/products". If the clone fails to become ready it is \
      deleted, and tart's output is left in the log the error names.
      """
  )

  /// The clone's name, or `nil` to generate one.
  @Option(help: "Name for the clone, starting with agt- (default: generated from the base image).")
  var name: String?

  /// The host folder to share, or `nil` for the configured one.
  @Option(help: "Host folder to share read-only (default: the vm.share setting).")
  var share: String?

  /// Whether to show the VM's window.
  @Flag(help: "Show the VM's window, to watch it.")
  var window = false

  /// Whether to build the scheme first.
  @Flag(help: "Build the scheme for macOS first, as agt validate --target does.")
  var build = false

  /// The scheme to build, or `nil` for the configured one.
  @Option(help: "Scheme to build with --build (default: the vm.scheme setting).")
  var scheme: String?

  /// How long to wait for the guest.
  @Option(help: "Seconds to wait for the guest to be ready.")
  var timeout = 300

  /// Builds if asked, then clones, boots and waits for the clone.
  mutating func run() async throws {
    let directory = FileManager.default.currentDirectoryPath
    let settings = try await VMSettings.load(repoPath: directory, homeDirectory: FileManager.default.homeDirectoryForCurrentUser)
    let tart = try Tart.current()
    let clone = name ?? VMClone.generatedName(base: settings.baseImage)
    try VMClone.requireDisposable(clone, base: settings.baseImage)

    if build {
      guard let scheme = scheme ?? settings.scheme else {
        throw ToolError("--build needs a scheme: pass --scheme, or set vm.scheme or validate.schemes in .agt/config.json.")
      }
      var validate = try ValidateCommand.parse(["--target", scheme])
      try await validate.run()
    }

    let sharePath = share.map { URL(fileURLWithPath: $0, relativeTo: URL(fileURLWithPath: directory, isDirectory: true)).standardizedFileURL.path } ?? settings.share
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: sharePath, isDirectory: &isDirectory), isDirectory.boolValue else {
      throw ToolError("The folder to share, \(sharePath), does not exist; build first, or pass --build or --share.")
    }

    try tart.clone(settings.baseImage, as: clone)
    let log = FileManager.default.temporaryDirectory.appending(path: "agt-vm-\(clone).log").path
    print("Cloned \(settings.baseImage) as \(clone); booting.")
    do {
      let process = try tart.start(name: clone, share: sharePath, window: window, logPath: log)
      let guest = try await waitUntilReady(clone, process: process, tart: tart, settings: settings)
      print("\(clone) is ready at \(guest.host), sharing \(sharePath) as \(VMGuest.sharePath).")
    } catch {
      try? tart.stop(clone)
      try? tart.delete(clone)
      throw ToolError("\(error) \(clone) was deleted; tart's output is in \(log).")
    }
  }

  /// Polls until the clone has an address, ssh works, and the guest user owns the console with Finder running.
  ///
  /// The first time the clone has an address, any host key recorded for that address by an earlier clone is
  /// forgotten, so the new clone's key is accepted.
  private func waitUntilReady(_ clone: String, process: Process, tart: Tart, settings: VMSettings) async throws -> VMGuest {
    let deadline = ContinuousClock.now + .seconds(timeout)
    var guest: VMGuest?
    while true {
      guard process.isRunning else {
        throw ToolError("tart run exited with status \(process.terminationStatus) before \(clone) was ready.")
      }
      if guest == nil, let address = try tart.ip(clone) {
        let connection = VMGuest(settings: settings, host: address)
        _ = try VMGuest.capture(connection.forgetHostKeyArguments)
        guest = connection
      }
      if let guest, try VMGuest.capture(guest.sshArguments(script: guest.readinessCommand)).status == 0 {
        return guest
      }
      guard ContinuousClock.now < deadline else {
        let reason = guest == nil ? "it has no address" : "ssh failed, or \(settings.guestUser) does not own the console with Finder running"
        throw ToolError("\(clone) was not ready after \(timeout) seconds: \(reason).")
      }
      try await Task.sleep(for: .seconds(2))
    }
  }
}
