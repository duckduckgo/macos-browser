// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Package.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import PackageDescription

let package = Package(
    name: "NetworkProtectionMac",
    platforms: [
        .macOS("11.4")
    ],
    products: [
        .library(name: "NetworkProtectionIPC", targets: ["NetworkProtectionIPC"]),
        .library(name: "NetworkProtectionProxy", targets: ["NetworkProtectionProxy"]),
        .library(name: "NetworkProtectionUI", targets: ["NetworkProtectionUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "132.0.2"),
        .package(path: "../XPCHelper"),
        .package(path: "../SwiftUIExtensions"),
        .package(path: "../LoginItems"),
        .package(url: "https://github.com/duckduckgo/apple-toolbox.git", exact: "2.0.0"),
        .package(path: "../PixelKit"),
    ],
    targets: [
        // MARK: - NetworkProtectionIPC

        .target(
            name: "NetworkProtectionIPC",
            dependencies: [
                .product(name: "NetworkProtection", package: "BrowserServicesKit"),
                .product(name: "XPCHelper", package: "XPCHelper"),
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "apple-toolbox")]
        ),

        // MARK: - NetworkProtectionProxy

        .target(
            name: "NetworkProtectionProxy",
            dependencies: [
                .product(name: "NetworkProtection", package: "BrowserServicesKit"),
                .product(name: "PixelKit", package: "PixelKit"),
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "apple-toolbox")]
        ),

        // MARK: - NetworkProtectionUI

        .target(
            name: "NetworkProtectionUI",
            dependencies: [
                .product(name: "NetworkProtection", package: "BrowserServicesKit"),
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions"),
                .product(name: "LoginItems", package: "LoginItems"),
                .product(name: "PixelKit", package: "PixelKit"),
            ],
            resources: [
                .copy("Resources/Assets.xcassets")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "apple-toolbox")]
        ),

        .testTarget(
            name: "NetworkProtectionUITests",
            dependencies: [
                "NetworkProtectionUI",
                .product(name: "NetworkProtectionTestUtils", package: "BrowserServicesKit"),
                .product(name: "LoginItems", package: "LoginItems"),
                .product(name: "PixelKitTestingUtilities", package: "PixelKit"),
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "apple-toolbox")]
        ),
    ]
)
