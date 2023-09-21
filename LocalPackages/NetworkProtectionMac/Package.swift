// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkProtectionMac",
    platforms: [
        .iOS("14.0"),
        .macOS("11.4")
    ],
    products: [
        .library(name: "NetworkProtectionUI", targets: ["NetworkProtectionUI"]),
        .library(name: "NetworkProtectionPixels", targets: ["NetworkProtectionPixels"])
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "78.2.0"),
        .package(path: "../PixelKit"),
        .package(path: "../SwiftUIExtensions")
    ],
    targets: [
        .target(
            name: "NetworkProtectionUI",
            dependencies: [
                .product(name: "NetworkProtection", package: "BrowserServicesKit"),
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions")
            ],
            resources: [
                .copy("Resources/Assets.xcassets")
            ]),
        .testTarget(
            name: "NetworkProtectionUITests",
            dependencies: [
                "NetworkProtectionUI",
                .product(name: "NetworkProtectionTestUtils", package: "BrowserServicesKit")
            ]),

        .target(
            name: "NetworkProtectionPixels",
            dependencies: [
                .product(name: "PixelKit", package: "PixelKit")
            ],
            resources: []),
    ]
)
