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
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", revision: "a5b3ae827b9b659fc6cde49e7729a9e1bb1044ac")
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
