// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Package.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

let packageDependencies: [PackageDescription.Package.Dependency]
#if swift(>=5.9)
packageDependencies = []
#else
packageDependencies = [
    // pre Xcode 15 macros
    .package(path: "../DependencyInjectionMacroPlugin")
]
#endif

let dependencies: [PackageDescription.Target.Dependency]
#if swift(>=5.9)
dependencies = []
#else
dependencies = [
    .product(name: "DependencyInjectionMacros", package: "DependencyInjectionMacroPlugin")
]
#endif

let package = Package(
    name: "BuildToolPlugins",
    platforms: [ .macOS(.v12) ],
    products: [
      .plugin(
        name: "InputFilesChecker",
        targets: ["InputFilesChecker"]
      ),
      .plugin(
        name: "InjectableMacrosPlugin",
        targets: ["InjectableMacrosPlugin"]
      ),
    ],
    dependencies: packageDependencies,
    targets: [
        .plugin(
            name: "InputFilesChecker",
            capability: .buildTool()
        ),
        .plugin(
            name: "InjectableMacrosPlugin",
            capability: .buildTool(),
            dependencies: dependencies
        ),
    ]
)
