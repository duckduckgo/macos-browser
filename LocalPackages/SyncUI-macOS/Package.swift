// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SyncUI-macOS",
    defaultLocalization: "en",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(
            name: "SyncUI-macOS",
            targets: ["SyncUI-macOS"]),
    ],
    dependencies: [
        .package(path: "../PreferencesUI-macOS"),
        .package(path: "../SwiftUIExtensions"),
    ],
    targets: [
        .target(
            name: "SyncUI-macOS",
            dependencies: [
                .product(name: "PreferencesUI-macOS", package: "PreferencesUI-macOS"),
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions"),
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "SyncUITests",
            dependencies: [
                "SyncUI-macOS",
            ]
        ),
    ]
)
