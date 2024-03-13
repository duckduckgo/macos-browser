// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LoginItems",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(
            name: "LoginItems",
            targets: ["LoginItems"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/apple-toolbox.git", exact: "2.0.0"),
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", revision: "1f8fa1f51d799b6a6e2040c5a8d8da0b25e28951")
    ],
    targets: [
        .target(
            name: "LoginItems",
            dependencies: [
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "apple-toolbox")]
        ),
    ]
)
