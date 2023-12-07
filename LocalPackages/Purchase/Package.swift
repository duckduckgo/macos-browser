// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Purchase",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(
            name: "Purchase",
            targets: ["Purchase"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "90.0.0"),
    ],
    targets: [
        .target(
            name: "Purchase",
            dependencies: [],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
        .testTarget(
            name: "PurchaseTests",
            dependencies: ["Purchase"],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
    ]
)
