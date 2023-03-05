// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SyncUI",
    platforms: [ .macOS(.v10_15)],
    products: [
        .library(
            name: "SyncUI",
            targets: ["SyncUI"]),
    ],
    dependencies: [],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SyncUI",
            dependencies: []),
        .testTarget(
            name: "SyncUITests",
            dependencies: ["SyncUI"]),
    ]
)
