// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SubscriptionUI",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(
            name: "SubscriptionUI",
            targets: ["SubscriptionUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", revision: "a63e7129d7ff9d5bb7241ce98ed61b701c07cd66"),
        .package(path: "../SwiftUIExtensions")
    ],
    targets: [
        .target(
            name: "SubscriptionUI",
            dependencies: [
                .product(name: "Subscription", package: "BrowserServicesKit"),
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions")
            ],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "SubscriptionUITests",
            dependencies: ["SubscriptionUI"]),
    ]
)
