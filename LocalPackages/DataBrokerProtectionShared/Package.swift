// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Package.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
    name: "DataBrokerProtectionShared",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(
            name: "DataBrokerProtectionShared",
            targets: ["DataBrokerProtectionShared"])
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "236.1.0"),
        .package(path: "../SwiftUIExtensions"),
        .package(path: "../AppKitExtensions"),
        .package(path: "../XPCHelper"),
        .package(path: "../Freemium"),
    ],
    targets: [
        .target(
            name: "DataBrokerProtectionShared",
            dependencies: [
                .product(name: "BrowserServicesKit", package: "BrowserServicesKit"),
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions"),
                .product(name: "AppKitExtensions", package: "AppKitExtensions"),
                .byName(name: "XPCHelper"),
                .product(name: "PixelKit", package: "BrowserServicesKit"),
                .product(name: "Configuration", package: "BrowserServicesKit"),
                .product(name: "Persistence", package: "BrowserServicesKit"),
                .product(name: "Freemium", package: "Freemium"),
            ],
            resources: [.copy("Resources")],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "DataBrokerProtectionSharedTests",
            dependencies: [
                "DataBrokerProtectionShared",
                "BrowserServicesKit",
                "Freemium",
                .product(name: "PersistenceTestingUtils", package: "BrowserServicesKit"),
                .product(name: "SubscriptionTestingUtilities", package: "BrowserServicesKit"),
            ],
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
