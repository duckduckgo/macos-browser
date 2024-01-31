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
    name: "DataBrokerProtection",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(
            name: "DataBrokerProtection",
            targets: ["DataBrokerProtection"])
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "104.0.0"),
        .package(path: "../PixelKit"),
        .package(path: "../SwiftUIExtensions"),
        .package(path: "../XPCHelper")
    ],
    targets: [
        .target(
            name: "DataBrokerProtection",
            dependencies: [
                .product(name: "BrowserServicesKit", package: "BrowserServicesKit"),
                .product(name: "PixelKit", package: "PixelKit"),
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions"),
                .byName(name: "XPCHelper")
            ],
            resources: [.process("Resources")],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        ),
        .testTarget(
            name: "DataBrokerProtectionTests",
            dependencies: [
                "DataBrokerProtection",
                "BrowserServicesKit"
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "BrowserServicesKit")]
        )
    ]
)
