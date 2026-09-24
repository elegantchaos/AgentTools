// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import SwiftUI

/// Shows a greeting; its preview checks that `#Preview` builds during validation.
public struct GreetingView: View {
  /// The name to greet.
  let name: String

  /// Creates a view that greets `name`.
  public init(name: String) {
    self.name = name
  }

  /// The greeting text.
  public var body: some View {
    Text(greeting(for: name))
  }
}

#Preview {
  GreetingView(name: "World")
}
