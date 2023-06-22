// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
#if canImport(CompilerPluginSupport)
import CompilerPluginSupport
#endif

let products: [Product]
let targets: [Target]
let packageDependencies: [Package.Dependency]
let targetDependencies: [Target.Dependency]
let swiftSettings: [SwiftSetting]
let linkerSettings: [LinkerSetting]

#if swift(>=5.9)

products = [
    .library(
        name: "libDependencyInjectionMacros.dylib",
        type: .dynamic,
        targets: ["DependencyInjectionMacros"]
    )
]

packageDependencies = []
targetDependencies = []

swiftSettings = [ .unsafeFlags( ["-I${TOOLCHAIN_DIR}/usr/lib/swift/host"] ) ]

linkerSettings = [
    .unsafeFlags([
        "-L${TOOLCHAIN_DIR}/usr/lib/swift/host",
        "-lSwiftBasicFormat",
        "-lSwiftDiagnostics",
        "-lSwiftParser",
        "-lSwiftSyntax",
        "-lSwiftSyntaxBuilder",
        "-lSwiftSyntaxMacros",
        "-lSwiftCompilerPluginMessageHandling",
    ])
]

targets = [
    .target(
        name: "DependencyInjectionMacros",
        dependencies: targetDependencies,
        swiftSettings: swiftSettings,
        linkerSettings: linkerSettings
    )
]

#else

products = [
    .executable(
        name: "DependencyInjectionMacros",
        targets: ["DependencyInjectionMacros"]
    ),
    // use a dummy dylib to suppress xcode warnings about no library present at
    // PackageFrameworks/libDependencyInjectionMacros.dylib.framework/Versions/A/libDependencyInjectionMacros.dylib
    .library(
        name: "libDependencyInjectionMacros.dylib",
        type: .dynamic,
        targets: ["libDependencyInjectionDummy"]
    ),
]

packageDependencies = [
    .package(url: "https://github.com/apple/swift-syntax.git", branch: "main"),
]

targetDependencies = [
    .product(name: "SwiftParser", package: "swift-syntax"),
    .product(name: "SwiftSyntax", package: "swift-syntax"),
    .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
    .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
]

swiftSettings = []
linkerSettings = []

targets = [
    .executableTarget(
        name: "DependencyInjectionMacros",
        dependencies: targetDependencies,
        swiftSettings: swiftSettings,
        linkerSettings: linkerSettings
    ),
    .target(
        name: "libDependencyInjectionDummy"
    )
]

#endif

let package = Package(
    name: "DependencyInjectionMacroPlugin",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: products,
    dependencies: packageDependencies,
    targets: targets
)
