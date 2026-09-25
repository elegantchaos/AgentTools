// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentTools

/// Tests how validation chooses, describes, and creates the simulators that run tests.
struct TestSimulatorTests {
  @Test func theTestDeviceForTheNewestRuntimeIsPreferred() throws {
    let simulators = XcodeDestinations.simulators(
      fromShowDestinations: destinations(
        "{ platform:iOS Simulator, id:A, OS:27.2, name:iPad (A16) }",
        "{ platform:iOS Simulator, id:B, OS:27.0, name:Test iPhone 27.0 }",
        "{ platform:iOS Simulator, id:C, OS:27.2, name:Test iPad 27.2 }",
        "{ platform:iOS Simulator, id:D, OS:27.2, name:Test iPhone 27.2 }",
      ),
      newestOS: [.iOS: "27.2"]
    )
    let iOS = try #require(simulators[.iOS])
    #expect(iOS.destination == "platform=iOS Simulator,name=Test iPhone 27.2,OS=27.2")
    #expect(iOS.isTestDevice)
    #expect(iOS.note == nil)
  }

  @Test func theSecondFamilyIsUsedWhenTheFirstHasNoTestDevice() {
    let simulators = XcodeDestinations.simulators(
      fromShowDestinations: destinations(
        "{ platform:iOS Simulator, id:A, OS:27.2, name:iPhone 18 Pro }",
        "{ platform:iOS Simulator, id:B, OS:27.2, name:Test iPad 27.2 }",
      ))
    #expect(simulators[.iOS]?.destination == "platform=iOS Simulator,name=Test iPad 27.2,OS=27.2")
    #expect(simulators[.iOS]?.isTestDevice == true)
  }

  @Test func anOlderTestDeviceIsUsedAndReportedWhenTheNewestHasNone() {
    let simulators = XcodeDestinations.simulators(
      fromShowDestinations: destinations(
        "{ platform:iOS Simulator, id:A, OS:27.2, name:iPad (A16) }",
        "{ platform:iOS Simulator, id:B, OS:26.5, name:Test iPhone 26.5 }",
        "{ platform:iOS Simulator, id:C, OS:27.0, name:Test iPhone 27.0 }",
      ),
      newestOS: [.iOS: "27.2"]
    )
    #expect(simulators[.iOS]?.destination == "platform=iOS Simulator,name=Test iPhone 27.0,OS=27.0")
    #expect(simulators[.iOS]?.isTestDevice == false)
    #expect(simulators[.iOS]?.note == "iOS tests run on Test iPhone 27.0 with iOS 27.0: there is no simulator named Test iPhone 27.2 or Test iPad 27.2.")
  }

  @Test func withoutAnyTestDeviceTheNewestSimulatorIsUsed() {
    let simulators = XcodeDestinations.simulators(
      fromShowDestinations: destinations(
        "{ platform:tvOS Simulator, id:A, OS:26.5, name:Apple TV }",
        "{ platform:tvOS Simulator, id:B, OS:27.0, name:Apple TV 4K (3rd generation) }",
      ))
    #expect(simulators[.tvOS]?.destination == "platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=27.0")
    #expect(simulators[.tvOS]?.note == "tvOS tests run on Apple TV 4K (3rd generation) with tvOS 27.0: there is no simulator named Test TV 27.0.")
  }

  @Test func platformsWithoutACurrentTestDeviceAreListed() {
    let simulators = XcodeDestinations.simulators(
      fromShowDestinations: destinations(
        "{ platform:iOS Simulator, id:A, OS:27.2, name:Test iPhone 27.2 }",
        "{ platform:tvOS Simulator, id:B, OS:27.0, name:Test TV 26.5 }",
      ))
    #expect(TestSimulators.missingTestDevices(for: [.macOS, .iOS, .tvOS, .watchOS], in: simulators) == [.tvOS])
  }

  @Test func newestRuntimesAreFoundForEachPlatform() throws {
    #expect(try TestSimulators.newestOS(runtimesJSON: runtimes) == [.iOS: "27.2", .tvOS: "27.0", .watchOS: "27.0"])
  }

  @Test(arguments: [
    (ApplePlatform.iOS, TestSimulators.NewDevice(name: "Test iPhone 27.2", deviceType: "iPhone-18-Pro-Max", deviceTypeName: "iPhone 18 Pro Max", runtime: "iOS-27-2", runtimeName: "iOS 27.2")),
    (.tvOS, TestSimulators.NewDevice(name: "Test TV 27.0", deviceType: "Apple-TV-4K-3rd-4K", deviceTypeName: "Apple TV 4K (3rd generation)", runtime: "tvOS-27-0", runtimeName: "tvOS 27.0")),
    (.watchOS, TestSimulators.NewDevice(name: "Test Watch 27.0", deviceType: "Ultra-4", deviceTypeName: "Apple Watch Ultra 4 (49mm)", runtime: "watchOS-27-0", runtimeName: "watchOS 27.0")),
  ])
  func aNewTestDeviceIsTheScreenshotDeviceOnTheNewestRuntime(platform: ApplePlatform, expected: TestSimulators.NewDevice) throws {
    #expect(try TestSimulators.newDevice(for: platform, runtimesJSON: runtimes, devicesJSON: #"{"devices": {}}"#) == expected)
  }

  @Test func anExistingTestDeviceIsNotCreatedAgain() throws {
    let devices = #"{"devices": {"iOS-27-2": [{"name": "Test iPhone 27.2"}]}}"#
    #expect(try TestSimulators.newDevice(for: .iOS, runtimesJSON: runtimes, devicesJSON: devices) == nil)
    #expect(try TestSimulators.newDevice(for: .visionOS, runtimesJSON: runtimes, devicesJSON: devices) == nil)
    #expect(
      TestSimulators.NewDevice(name: "Test TV 27.0", deviceType: "T", deviceTypeName: "TV", runtime: "R", runtimeName: "tvOS").arguments
        == ["xcrun", "simctl", "create", "Test TV 27.0", "T", "R"]
    )
  }

  /// `simctl list -j runtimes` output, with device types newest first as `simctl` lists them.
  private let runtimes = """
    {"runtimes": [
      {"platform": "iOS", "version": "27.0", "name": "iOS 27.0", "identifier": "iOS-27-0", "isAvailable": true,
       "supportedDeviceTypes": [{"productFamily": "iPhone", "name": "iPhone 17 Pro Max", "identifier": "iPhone-17-Pro-Max"}]},
      {"platform": "iOS", "version": "27.2", "name": "iOS 27.2", "identifier": "iOS-27-2", "isAvailable": true,
       "supportedDeviceTypes": [
         {"productFamily": "iPhone", "name": "iPhone 18 Pro", "identifier": "iPhone-18-Pro"},
         {"productFamily": "iPhone", "name": "iPhone 18 Pro Max", "identifier": "iPhone-18-Pro-Max"},
         {"productFamily": "iPhone", "name": "iPhone 17 Pro Max", "identifier": "iPhone-17-Pro-Max"},
         {"productFamily": "iPad", "name": "iPad Pro 13-inch (M5)", "identifier": "iPad-Pro-13-M5"}
       ]},
      {"platform": "iOS", "version": "27.4", "name": "iOS 27.4", "identifier": "iOS-27-4", "isAvailable": false,
       "supportedDeviceTypes": [{"productFamily": "iPhone", "name": "iPhone 19 Pro Max", "identifier": "iPhone-19-Pro-Max"}]},
      {"platform": "tvOS", "version": "27.0", "name": "tvOS 27.0", "identifier": "tvOS-27-0", "isAvailable": true,
       "supportedDeviceTypes": [
         {"productFamily": "Apple TV", "name": "Apple TV 4K (3rd generation) (at 1080p)", "identifier": "Apple-TV-4K-3rd-1080p"},
         {"productFamily": "Apple TV", "name": "Apple TV 4K (3rd generation)", "identifier": "Apple-TV-4K-3rd-4K"}
       ]},
      {"platform": "watchOS", "version": "27.0", "name": "watchOS 27.0", "identifier": "watchOS-27-0", "isAvailable": true,
       "supportedDeviceTypes": [
         {"productFamily": "Apple Watch", "name": "Apple Watch Series 12 (46mm)", "identifier": "Series-12"},
         {"productFamily": "Apple Watch", "name": "Apple Watch Ultra 4 (49mm)", "identifier": "Ultra-4"}
       ]}
    ]}
    """

  /// Returns `xcodebuild -showdestinations` output listing `lines`.
  private func destinations(_ lines: String...) -> String {
    (["Available destinations for the \"App\" scheme:", "\t\t{ platform:macOS, arch:arm64, id:0000, name:My Mac }"] + lines.map { "\t\t\($0)" })
      .joined(separator: "\n")
  }
}
