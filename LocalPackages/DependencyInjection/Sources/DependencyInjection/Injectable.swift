//
//  Injectable.swift
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

import Foundation

public protocol NoDependencies {}

public protocol Injectable {
    associatedtype Dependencies = NoDependencies
    associatedtype InjectedDependencies = NoDependencies

    associatedtype DependencyProvider
    associatedtype DependencyStorage: DependencyStorageProtocol

    static func getAllDependencyProviderKeyPaths() -> Set<AnyKeyPath>

    var dependencies: DependencyStorage { get }
}

public protocol DependencyStorageProtocol {
    var _storage: [AnyKeyPath: Any] { get } // swiftlint:disable:this identifier_name
}

public struct DependencyInjectionHelper {
    @TaskLocal public static var collectKeyPaths: (@Sendable () -> Set<AnyKeyPath>)!
}

public protocol DependenciesProtocol {
    var _storage: [AnyKeyPath: Any] { get } // swiftlint:disable:this identifier_name
}

public extension DependenciesProtocol {
    var _storage: [AnyKeyPath: Any] { // swiftlint:disable:this identifier_name
        DependencyInjectionHelper.collectKeyPaths().reduce(into: [:]) {
            $0[$1] = self[keyPath: $1]
        }
    }
}
