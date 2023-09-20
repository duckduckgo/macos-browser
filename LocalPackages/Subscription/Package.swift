// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Subscription",
    platforms: [ .macOS(.v10_15) ],
    products: [
        .library(
            name: "Subscription",
            targets: ["Subscription"]),
    ],
    dependencies: [
        .package(path: "../SwiftUIExtensions")
    ],
    targets: [
        .target(
            name: "Subscription",
            dependencies: [
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions")
            ]),
        .testTarget(
            name: "SubscriptionTests",
            dependencies: ["Subscription"]),
    ]
)
