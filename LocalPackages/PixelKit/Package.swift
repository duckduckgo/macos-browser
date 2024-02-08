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
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", revision: "bab38045b1b750733f44311a0cfb018d9650cd12"),
    ],
    targets: [
        .target(
            name: "PixelKit",
            dependencies: [
                .product(name: "Macros", package: "BrowserServicesKit"),
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
        .testTarget(
            name: "PixelKitTests",
            dependencies: [
                "PixelKit",
                "PixelKitTestingUtilities",
                .product(name: "Macros", package: "BrowserServicesKit"),
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
        .target(
            name: "PixelKitTestingUtilities",
            dependencies: [
                "PixelKit",
                .product(name: "Macros", package: "BrowserServicesKit"),
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        )
    ]
)
