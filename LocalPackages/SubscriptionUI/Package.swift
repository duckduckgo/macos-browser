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
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", revision: "74b9b87fc7d2b7d1ee3e163df043621b9b7e914f"),
        .package(path: "../SwiftUIExtensions")
    ],
    targets: [
        .target(
            name: "SubscriptionUI",
            dependencies: [
                .product(name: "BrowserServicesKit", package: "BrowserServicesKit"),
                .product(name: "Subscription", package: "BrowserServicesKit"),
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions"),
                .product(name: "PreferencesViews", package: "SwiftUIExtensions"),
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "SubscriptionUITests",
            dependencies: ["SubscriptionUI"]),
    ]
)
