// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SyncUI",
    platforms: [ .macOS(.v10_15) ],
    products: [
        .library(
            name: "SyncUI",
            targets: ["SyncUI"]),
    ],
    dependencies: [
        .package(path: "../SwiftUIExtensions")
    ],
    targets: [
        .target(
            name: "SyncUI",
            dependencies: [
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions")
            ],
            resources: [
                .process("SyncPDFTemplate.png")
            ]),
        .testTarget(
            name: "SyncUITests",
            dependencies: ["SyncUI"]),
    ]
)
