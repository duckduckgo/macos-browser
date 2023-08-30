// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Accounts",
    platforms: [ .macOS(.v10_15) ],
    products: [
        .library(
            name: "Accounts",
            targets: ["Accounts"]),
    ],
    targets: [
        .target(
            name: "Accounts",
            dependencies: []),
        .testTarget(
            name: "AccountsTests",
            dependencies: ["Accounts"]),
    ]
)
