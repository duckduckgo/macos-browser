// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SyncUI",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(
            name: "SyncUI",
            targets: ["SyncUI"]),
    ],
    dependencies: [
        .package(path: "../SwiftUIExtensions"),
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", revision: "c13a918d233767d2b0c64dfc1aaa7beb0bf18bea"),
    ],
    targets: [
        .target(
            name: "SyncUI",
            dependencies: [
                .product(name: "PreferencesViews", package: "SwiftUIExtensions"),
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
        .testTarget(
            name: "SyncUITests",
            dependencies: ["SyncUI"],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
    ]
)
