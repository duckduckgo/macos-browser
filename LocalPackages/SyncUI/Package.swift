// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SyncUI",
    defaultLocalization: "en",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(
            name: "SyncUI",
            targets: ["SyncUI"]),
    ],
    dependencies: [
        .package(path: "../SwiftUIExtensions"),
        .package(url: "https://github.com/duckduckgo/apple-toolbox.git", exact: "2.0.0"),
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", revision: "1f8fa1f51d799b6a6e2040c5a8d8da0b25e28951")
    ],
    targets: [
        .target(
            name: "SyncUI",
            dependencies: [
                .product(name: "PreferencesViews", package: "SwiftUIExtensions"),
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions"),
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "apple-toolbox")]
        ),
        .testTarget(
            name: "SyncUITests",
            dependencies: [
                "SyncUI",
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "apple-toolbox")]
        ),
    ]
)
