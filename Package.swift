// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "AgentTools",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "agt", targets: ["AgentTools"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.1"),
    // swift-collections is only used indirectly (through swift-configuration), but
    // 1.7.0 built with Swift 6.4 links `swift_initBorrow`, which is missing before macOS 27.
    .package(url: "https://github.com/apple/swift-collections", from: "1.7.1"),
    .package(url: "https://github.com/apple/swift-configuration", from: "1.2.1"),
    .package(url: "https://github.com/elegantchaos/Versionator.git", from: "2.1.1"),
  ],
  targets: [
    .executableTarget(
      name: "AgentTools",
      dependencies: [
        "AgentToolsCore"
      ]
    ),
    .target(
      name: "AgentToolsCore",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Configuration", package: "swift-configuration"),
      ],
      plugins: [
        .plugin(name: "VersionatorPlugin", package: "Versionator")
      ]
    ),
    .testTarget(
      name: "AgentToolsTests",
      dependencies: [
        "AgentToolsCore"
      ]
    ),
  ]
)
