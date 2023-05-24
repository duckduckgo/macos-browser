// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DataBrokerProtection",
    platforms: [ .macOS(.v10_15) ],
    products: [
        .library(
            name: "DataBrokerProtection",
            targets: ["DataBrokerProtection"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "DataBrokerProtection",
            dependencies: []),
        .testTarget(
            name: "DataBrokerProtectionTests",
            dependencies: ["DataBrokerProtection"]),
    ]
)
