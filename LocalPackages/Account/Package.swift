// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Account",
    platforms: [ .macOS(.v10_15) ],
    products: [
        .library(
            name: "Account",
            targets: ["Account"]),
    ],
    dependencies: [
//        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "75.2.0")
    ],
    targets: [
        .target(
            name: "Account",
            dependencies: [
//                .product(name: "BrowserServicesKit", package: "BrowserServicesKit")
            ]),
        .testTarget(
            name: "AccountTests",
            dependencies: ["Account"]),
    ]
)
