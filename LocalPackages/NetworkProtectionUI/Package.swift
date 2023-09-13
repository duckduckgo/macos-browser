// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkProtectionUI",
    platforms: [
        .iOS("14.0"),
        .macOS("10.15")
    ],
    products: [
        .library(
            name: "NetworkProtectionUI",
            targets: ["NetworkProtectionUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit-DBP", revision: "c840508eaa948235460959ee4c1cd36094df672b"),
        .package(path: "../SwiftUIExtensions")
    ],
    targets: [
        .target(
            name: "NetworkProtectionUI",
            dependencies: [
                .product(name: "NetworkProtection", package: "BrowserServicesKit-DBP"),
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions")
            ],
            resources: [
                .copy("Resources/Assets.xcassets")
            ]),
        .testTarget(
            name: "NetworkProtectionUITests",
            dependencies: [
                "NetworkProtectionUI",
                .product(name: "NetworkProtectionTestUtils", package: "BrowserServicesKit-DBP")
            ])
    ]
)
