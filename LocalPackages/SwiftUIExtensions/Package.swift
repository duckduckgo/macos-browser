// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUIExtensions",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(name: "SwiftUIExtensions", targets: ["SwiftUIExtensions"]),
        .library(name: "PreferencesViews", targets: ["PreferencesViews"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SwiftUIExtensions",
            dependencies: [
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "PreferencesViews",
            dependencies: [
                "SwiftUIExtensions",
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
    ]
)
