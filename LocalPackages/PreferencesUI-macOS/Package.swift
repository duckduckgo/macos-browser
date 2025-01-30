// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PreferencesUI-macOS",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(name: "PreferencesUI-macOS", targets: ["PreferencesUI-macOS"]),
    ],
    dependencies: [
        .package(path: "../SwiftUIExtensions"),
    ],
    targets: [
        .target(
            name: "PreferencesUI-macOS",
            dependencies: [
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
    ]
)
