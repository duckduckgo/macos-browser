// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Utilities",
    products: [
        .library(
            name: "Utilities",
            targets: ["Utilities"]),
    ],
    targets: [
        .target(
            name: "Utilities"
        )
    ]
)
