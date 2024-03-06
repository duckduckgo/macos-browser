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
        .package(url: "https://github.com/duckduckgo/apple-toolbox.git", exact: "1.0.0"),
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", revision: "2fa74adb82a6478ee9f737f54d8bed75eefa725d")
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
