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
        .package(url: "https://github.com/duckduckgo/apple-toolbox.git", exact: "1.0.0"),
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", revision: "a5b3ae827b9b659fc6cde49e7729a9e1bb1044ac")
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
