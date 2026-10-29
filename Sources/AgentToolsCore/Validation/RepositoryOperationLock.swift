// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Darwin
import Foundation

/// Holds an advisory lock while preparation or validation owns a checkout's build directories.
/// The lock file lives outside `.build/agt` so `validate --clean` cannot remove a held lock.
final class RepositoryOperationLock {
  /// Descriptor whose lifetime owns the exclusive lock.
  private let descriptor: Int32

  /// Acquires the checkout's lock immediately, failing if another operation owns it.
  init(repoPath: String) throws {
    let directory = "\(repoPath)/.build"
    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    let descriptor = open("\(directory)/agt-operation.lock", O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else { throw ToolError("Cannot open the preparation/validation lock: \(String(cString: strerror(errno)))") }
    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
      let reason = String(cString: strerror(errno))
      close(descriptor)
      throw ToolError("Cannot acquire the preparation/validation lock (another operation may be running): \(reason)")
    }
    self.descriptor = descriptor
  }

  /// Releases the lock even when an operation fails.
  deinit {
    close(descriptor)
  }
}
