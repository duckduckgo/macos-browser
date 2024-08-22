// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppKitExtensions",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(name: "AppKitExtensions", targets: ["AppKitExtensions"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "AppKitExtensions",
            dependencies: [
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "AppKitExtensionsTests",
            dependencies: [
                "AppKitExtensions"
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
