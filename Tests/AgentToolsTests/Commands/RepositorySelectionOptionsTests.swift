// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentToolsCore

/// Verifies shared configuration resolution independently of validation's action flags.
struct RepositorySelectionOptionsTests {
  /// Preparation receives common selection and file defaults without enabling any validation action.
  @Test func preparationResolvesSharedSettingsWithoutValidationActions() throws {
    let command = try PrepareCommand.parse(["--schemes", "Other", "--package-dirs", "Dependencies/Core", "--plan"])
    let file = ValidateFileSettings(schemes: ["App"], platforms: ["macOS", "iOS"], testPlatforms: ["iOS"], testSubmodules: "always", excludePackages: ["Slow"])
    let config = try command.selection.configuration(file: file, outputMode: .quiet, planOnly: command.plan)
    #expect(config.schemes == ["Other"])
    #expect(config.packageDirsOverride == ["Dependencies/Core"])
    #expect(config.platforms == [.macOS, .iOS])
    #expect(config.testPlatforms == [.iOS])
    #expect(config.testSubmodules == .always)
    #expect(config.excludedPackages == ["Slow"])
    #expect(config.planOnly)
    #expect(config.outputMode == .quiet)
    #expect(config.clean == false)
    #expect(config.fast == false)
    #expect(config.background == false)
    #expect(config.backgroundWorker == false)
    #expect(config.status == false)
    #expect(config.wait == false)
    #expect(config.target == nil)
  }

  /// Action flags stay on the validation CLI instead of leaking through the shared selection arguments.
  @Test(arguments: ["--clean", "--fast", "--background", "--target"])
  func preparationRejectsValidationActions(option: String) {
    do {
      _ = try PrepareCommand.parse([option])
      Issue.record("Preparation accepted validation action \(option)")
    } catch {
      #expect(PrepareCommand.message(for: error).contains(option))
    }
  }
}
