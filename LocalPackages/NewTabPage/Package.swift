// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Package.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
    name: "NewTabPage",
    platforms: [
        .macOS("11.4")
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NewTabPage",
            targets: ["NewTabPage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "237.1.0"),
        .package(path: "../WebKitExtensions"),
        .package(path: "../UserScriptActionsManager"),
        .package(path: "../Utilities"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NewTabPage",
            dependencies: [
                .product(name: "BrowserServicesKit", package: "BrowserServicesKit"),
                .product(name: "PersistenceTestingUtils", package: "BrowserServicesKit"),
                .product(name: "PrivacyStats", package: "BrowserServicesKit"),
                .product(name: "RemoteMessaging", package: "BrowserServicesKit"),
                .product(name: "UserScript", package: "BrowserServicesKit"),
                .product(name: "UserScriptActionsManager", package: "UserScriptActionsManager"),
                .product(name: "WebKitExtensions", package: "WebKitExtensions"),
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "NewTabPageTests",
            dependencies: [
                "NewTabPage",
                "Utilities",
            ]
        ),
    ]
)
