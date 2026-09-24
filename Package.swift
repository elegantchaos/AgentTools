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
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0"),
    .package(url: "https://github.com/elegantchaos/Versionator.git", from: "2.1.1"),
  ],
  targets: [
    .executableTarget(
      name: "AgentTools",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      plugins: [
        .plugin(name: "VersionatorPlugin", package: "Versionator")
      ]
    ),
    .testTarget(
      name: "AgentToolsTests",
      dependencies: [
        "AgentTools"
      ]
    ),
  ]
)
