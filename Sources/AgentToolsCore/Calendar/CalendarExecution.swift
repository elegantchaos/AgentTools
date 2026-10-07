// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// What a calendar command does, given whether `agt` is its own responsible process.
enum CalendarExecution: Equatable {
  /// Read the calendar in this process, which holds the permission.
  case query

  /// Run `agt` again as its own responsible process, and let that process read the calendar.
  case relaunch

  /// The private responsibility functions are missing, so calendar access cannot be confined to `agt`.
  case unavailable

  /// A relaunched `agt` is still not its own responsible process, so relaunching again would loop.
  case disclaimFailed

  /// Chooses the execution from whether this process is self-responsible, `nil` when that cannot be known, and whether
  /// it was started by a relaunch.
  static func plan(selfResponsible: Bool?, relaunched: Bool) -> CalendarExecution {
    switch (selfResponsible, relaunched) {
      case (nil, _): .unavailable
      case (true, _): .query
      case (false, false): .relaunch
      case (false, true): .disclaimFailed
    }
  }
}
