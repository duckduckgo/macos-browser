// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppLauncher",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(
            name: "AppLauncher",
            targets: ["AppLauncher"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AppLauncher",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]),
        .testTarget(
            name: "AppLauncherTests",
            dependencies: ["AppLauncher"]),
    ]
)
