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
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", revision: "6a9024d4d9ae7376738ca471d69a9398c8445b69"),
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
