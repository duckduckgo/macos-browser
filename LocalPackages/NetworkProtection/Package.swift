// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let package = Package(
    name: "NetworkProtection",
    platforms: [
        .iOS("14.0"),
        .macOS("10.15")
    ],
    products: [
        .library(name: "NetworkProtection", targets: ["NetworkProtection"])
    ],
    dependencies: [
        // If you are updating the BSK dependency in the main app, this version will need to be updated to match.
        // There is work underway to move this package into BSK itself, after which this will not be required.
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "59.1.1"),
        .package(url: "https://github.com/duckduckgo/wireguard-apple", exact: "1.0.0")
    ],
    targets: [
        .target(
            name: "NetworkProtection",
            dependencies: [
                .target(name: "WireGuardC"),
                .product(name: "WireGuard", package: "wireguard-apple"),
                .product(name: "Common", package: "BrowserServicesKit")
            ]
            ),
        .target(name: "WireGuardC"),

        // MARK: - Test targets

        .testTarget(
            name: "NetworkProtectionTests",
            dependencies: [
                .target(name: "NetworkProtection")
            ],
            resources: [
                .copy("Resources/servers-original-endpoint.json"),
                .copy("Resources/servers-updated-endpoint.json")
            ]
        )
    ],
    cxxLanguageStandard: .cxx11
)
