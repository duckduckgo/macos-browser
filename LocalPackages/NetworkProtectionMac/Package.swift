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
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", revision: "de3fde7ad0f0bff6e0bdf42ebae5cdd5a87b6672"),
        .package(url: "https://github.com/airbnb/lottie-spm", exact: "4.4.1"),
        .package(path: "../XPCHelper"),
        .package(path: "../SwiftUIExtensions"),
        .package(path: "../LoginItems"),
    ],
    targets: [
        // MARK: - NetworkProtectionIPC

        .target(
            name: "NetworkProtectionIPC",
            dependencies: [
                .product(name: "NetworkProtection", package: "BrowserServicesKit"),
                .product(name: "XPCHelper", package: "XPCHelper"),
                .product(name: "PixelKit", package: "BrowserServicesKit"),
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),

        // MARK: - NetworkProtectionProxy

        .target(
            name: "NetworkProtectionProxy",
            dependencies: [
                .product(name: "NetworkProtection", package: "BrowserServicesKit"),
                .product(name: "PixelKit", package: "BrowserServicesKit"),
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),

        // MARK: - NetworkProtectionUI

        .target(
            name: "NetworkProtectionUI",
            dependencies: [
                .product(name: "NetworkProtection", package: "BrowserServicesKit"),
                .product(name: "PixelKit", package: "BrowserServicesKit"),
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions"),
                .product(name: "LoginItems", package: "LoginItems"),
                .product(name: "Lottie", package: "lottie-spm")
            ],
            resources: [
                .copy("Resources/Assets.xcassets")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),

        .testTarget(
            name: "NetworkProtectionUITests",
            dependencies: [
                "NetworkProtectionUI",
                .product(name: "NetworkProtectionTestUtils", package: "BrowserServicesKit"),
                .product(name: "LoginItems", package: "LoginItems"),
                .product(name: "PixelKitTestingUtilities", package: "BrowserServicesKit"),
            ]
        ),
    ]
)
