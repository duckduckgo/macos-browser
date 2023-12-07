// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Account",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(
            name: "Account",
            targets: ["Account"]),
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "91.0.2"),
        .package(path: "../Purchase")
    ],
    targets: [
        .target(
            name: "Account",
            dependencies: [
                .product(name: "BrowserServicesKit", package: "BrowserServicesKit"),
                .product(name: "Purchase", package: "Purchase")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
        .testTarget(
            name: "AccountTests",
            dependencies: ["Account"],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
    ]
)
