// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PixelKit",
    platforms: [
        .macOS("11.4")
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PixelKit",
            targets: ["PixelKit"]
        ),
        .library(
            name: "PixelKitTestingUtilities",
            targets: ["PixelKitTestingUtilities"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "90.0.0"),
    ],
    targets: [
        .target(
            name: "PixelKit",
            dependencies: [],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
        .testTarget(
            name: "PixelKitTests",
            dependencies: ["PixelKit", "PixelKitTestingUtilities"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
        .target(
            name: "PixelKitTestingUtilities",
            dependencies: ["PixelKit"],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        )
    ]
)
