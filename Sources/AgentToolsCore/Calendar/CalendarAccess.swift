// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Whether `agt` may read one kind of calendar item.
enum CalendarAccess: Sendable, CustomStringConvertible {
  /// Full access was granted.
  case granted

  /// The user has not been asked yet.
  case notDetermined

  /// The user refused access.
  case denied

  /// A device policy prevents access.
  case restricted

  /// Only adding items was granted, which does not allow reading them.
  case writeOnly

  /// The state in words, for messages.
  var description: String {
    switch self {
      case .granted: "granted"
      case .notDetermined: "not determined"
      case .denied: "denied"
      case .restricted: "restricted"
      case .writeOnly: "write only"
    }
  }
}
