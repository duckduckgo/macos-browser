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
    name: "Freemium",
    platforms: [ .macOS("11.4") ],
    products: [
        .library(
            name: "Freemium",
            targets: ["Freemium"]),
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/BrowserServicesKit", exact: "186.0.0"),
    ],
    targets: [
        .target(
            name: "Freemium",
            dependencies: [
                .product(name: "Subscription", package: "BrowserServicesKit"),
            ]
        ),
        .testTarget(
            name: "FreemiumTests",
            dependencies: [
                "Freemium",
                .product(name: "SubscriptionTestingUtilities", package: "BrowserServicesKit")
            ]
        ),
    ]
)