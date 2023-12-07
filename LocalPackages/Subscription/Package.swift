// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Subscription",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(
            name: "Subscription",
            targets: ["Subscription"]),
    ],
    dependencies: [
        .package(path: "../Account"),
        .package(path: "../Purchase"),
        .package(path: "../SwiftUIExtensions"),
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "90.0.0"),
    ],
    targets: [
        .target(
            name: "Subscription",
            dependencies: [
                .product(name: "Account", package: "Account"),
                .product(name: "Purchase", package: "Purchase"),
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions")
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
        .testTarget(
            name: "SubscriptionTests",
            dependencies: ["Subscription"],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
    ]
)
