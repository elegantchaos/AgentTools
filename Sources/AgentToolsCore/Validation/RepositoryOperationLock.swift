// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Darwin
import Foundation

/// Holds an advisory lock while preparation or validation owns a checkout's build directories.
/// Cleaning preserves the lock file's inode, so another process cannot acquire a replacement lock.
final class RepositoryOperationLock {
  /// Descriptor whose lifetime owns the exclusive lock.
  private let descriptor: Int32

  /// Acquires exclusive ownership, optionally waiting for a running operation without replacing it.
  /// The wait callback is called once on contention, before blocking in the OS advisory lock.
  init(repoPath: String, operation: String = "validation", background: Bool = false, wait: Bool = false, reportWait: (String) -> Void = { print($0) }) throws {
    let paths = ValidationPaths(repoPath: repoPath)
    try FileManager.default.createDirectory(atPath: paths.root, withIntermediateDirectories: true)
    let descriptor = open(paths.lockPath, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else { throw ToolError("Cannot open the preparation/validation lock: \(String(cString: strerror(errno)))") }
    do {
      if flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
        guard errno == EWOULDBLOCK else {
          throw ToolError("Cannot acquire the preparation/validation lock: \(String(cString: strerror(errno)))")
        }
        let owner = (try? Data(contentsOf: URL(fileURLWithPath: paths.lockPath))).flatMap { try? JSONDecoder().decode(RepositoryOperationOwner.self, from: $0) }
        let holder = owner?.description ?? "another preparation or validation operation."
        guard wait else { throw ToolError("Cannot acquire the preparation/validation lock; held by \(holder)") }
        reportWait("Waiting for the preparation/validation lock; held by \(holder)")
        guard flock(descriptor, LOCK_EX) == 0 else {
          throw ToolError("Interrupted while waiting for the preparation/validation lock: \(String(cString: strerror(errno)))")
        }
      }
      let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
      let owner = RepositoryOperationOwner(pid: getpid(), operation: operation, background: background)
      try handle.truncate(atOffset: 0)
      try handle.seek(toOffset: 0)
      try handle.write(contentsOf: JSONEncoder().encode(owner))
    } catch {
      close(descriptor)
      throw error
    }
    self.descriptor = descriptor
  }

  /// Releases the lock even when an operation fails.
  deinit {
    close(descriptor)
  }
}
