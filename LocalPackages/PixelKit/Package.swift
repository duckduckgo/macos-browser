// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PixelKit",
    platforms: [
        .iOS("14.0"),
        .macOS("10.15")
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PixelKit",
            targets: ["PixelKit"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "PixelKit",
            dependencies: []),
        .testTarget(
            name: "PixelKitTests",
            dependencies: ["PixelKit"])
    ]
)
