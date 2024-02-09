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
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "104.2.1"),
    ],
    targets: [
        .target(
            name: "PixelKit",
            dependencies: [
                .product(name: "Macros", package: "BrowserServicesKit"),
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .unsafeFlags(["-Xfrontend", "-load-plugin-executable", "-Xfrontend", "${BUILT_PRODUCTS_DIR}/MacrosImplementation#MacrosImplementation"]),
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
