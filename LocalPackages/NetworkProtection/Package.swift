// swift-tools-version:5.3
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
        .package(name: "BrowserServicesKit", url: "https://github.com/duckduckgo/BrowserServicesKit", .exact("57.4.4"))
    ],
    targets: [
        .target(
            name: "NetworkProtection",
            dependencies: [
                .target(name: "WireGuardC"),
                .target(name: "WireGuard"),
                .product(name: "Common", package: "BrowserServicesKit")
            ]
            ),
        .target(name: "WireGuardC"),
        .binaryTarget(
            name: "WireGuard",
            path: "./Binaries/WireGuard.xcframework"
            ),

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
