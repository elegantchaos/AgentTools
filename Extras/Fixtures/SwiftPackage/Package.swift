// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "SwiftPackage",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .library(name: "Greeting", targets: ["Greeting"])
  ],
  targets: [
    .target(name: "Greeting"),
    .testTarget(name: "GreetingTests", dependencies: ["Greeting"]),
  ]
)
