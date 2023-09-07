// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LoginItems",
    platforms: [ .macOS(.v10_15) ],
    products: [
        .library(
            name: "LoginItems",
            targets: ["LoginItems"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LoginItems",
            dependencies: []),
    ]
)
