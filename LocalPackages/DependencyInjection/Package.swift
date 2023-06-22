// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let packageDependencies: [PackageDescription.Package.Dependency]
let products: [PackageDescription.Product]
let targets: [PackageDescription.Target]

let package = Package(
    name: "DependencyInjection",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "DependencyInjection",
            targets: ["DependencyInjection"]
        ),
    ],
    dependencies: [],
    targets: [
        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "DependencyInjection",
            dependencies: []
        ),
    ]
)
