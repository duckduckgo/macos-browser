// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUIExtensions",
    platforms: [ .macOS(.v10_15) ],
    products: [
        .library(
            name: "SwiftUIExtensions",
            targets: ["SwiftUIExtensions"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftUIExtensions",
            dependencies: []),
    ]
)
