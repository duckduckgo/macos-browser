// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Purchase",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(
            name: "Purchase",
            targets: ["Purchase"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Purchase",
            dependencies: []),
        .testTarget(
            name: "PurchaseTests",
            dependencies: ["Purchase"]),
    ]
)
