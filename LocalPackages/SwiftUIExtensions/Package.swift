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
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", revision: "4f3e79239495c11193895d96530df3f1b64ef9f2"),
    ],
    targets: [
        .target(
            name: "SwiftUIExtensions",
            dependencies: [],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
        .target(
            name: "PreferencesViews",
            dependencies: ["SwiftUIExtensions"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
    ]
)
