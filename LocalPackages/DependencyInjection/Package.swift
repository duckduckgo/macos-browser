// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
#if canImport(CompilerPluginSupport)
import CompilerPluginSupport
#endif


let products: [PackageDescription.Product]
let targets: [PackageDescription.Target]

#if swift(>=5.9)

products = [
    .library(
        name: "DependencyInjection",
        targets: ["DependencyInjection"]
    ),
]

targets = [
    // Macro implementation that performs the source transformation of a macro.
    .macro(
        name: "DependencyInjectionMacros",
        dependencies: [
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
        ]
    ),

    // Library that exposes a macro as part of its API, which is used in client programs.
    .target(name: "DependencyInjection", dependencies: ["DependencyInjectionMacros"]),

    // A test target used to develop the macro implementation.
    .testTarget(
        name: "DependencyInjectionTests",
        dependencies: [
            "DependencyInjectionMacros",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
        ]
    ),
]

#else

products = [
    .library(
        name: "DependencyInjection",
        targets: ["DependencyInjection"]
    ),
    .executable(
        name: "DependencyInjectionMacros",
        targets: ["DependencyInjectionMacros"]
    ),
]

targets = [
    .executableTarget(
        name: "DependencyInjectionMacros",
        dependencies: [
            .product(name: "SwiftParser", package: "swift-syntax"),
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
        ]
    ),

    // Library that exposes a macro as part of its API, which is used in client programs.
    .target(name: "DependencyInjection", dependencies: ["DependencyInjectionMacros"]),

    // A test target used to develop the macro implementation.
    .testTarget(
        name: "DependencyInjectionTests",
        dependencies: [
            "DependencyInjectionMacros",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
        ]
    ),
]

#endif

let package = Package(
    name: "DependencyInjection",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: products,
    dependencies: [
        // Depend on the latest Swift 5.9 prerelease of SwiftSyntax
        .package(url: "https://github.com/apple/swift-syntax.git", branch: "main"),
    ],
    targets: targets
)
