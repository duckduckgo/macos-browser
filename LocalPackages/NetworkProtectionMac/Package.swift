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
        .library(name: "NetworkProtectionIPC", targets: ["NetworkProtectionIPC"]),
        .library(name: "NetworkProtectionUI", targets: ["NetworkProtectionUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "81.0.0"),
        .package(path: "../Intercom"),
        .package(path: "../SwiftUIExtensions")
    ],
    targets: [
        // MARK: - NetworkProtectionIPC

        .target(
            name: "NetworkProtectionIPC",
            dependencies: [
                .product(name: "NetworkProtection", package: "BrowserServicesKit"),
                .product(name: "Intercom", package: "Intercom")
            ]),

        // MARK: - NetworkProtectionUI

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
            ])
    ]
)
