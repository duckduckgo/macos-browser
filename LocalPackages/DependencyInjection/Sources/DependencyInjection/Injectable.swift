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

    associatedtype DynamicDependencyProvider
    associatedtype DynamicDependencies: DynamicDependenciesProtocol
#if swift(>=5.9)
    var dependencyProvider: DynamicDependencies { get } // auto-generated
#endif

    static var _currentDependencies: DynamicDependencies! { get } // swiftlint:disable:this identifier_name
    static func getAllDependencyProviderKeyPaths(from dependencyProvider: Dependencies) -> Set<AnyKeyPath>
}

public protocol DynamicDependenciesProtocol {
    var _storage: [AnyKeyPath: Any] { get } // swiftlint:disable:this identifier_name
}

#if swift(<5.9)

private let dependencyProviderKey = UnsafeRawPointer(bitPattern: "dependencyProvider".hashValue)!
public extension Injectable where Self: AnyObject {

    var dependencyProvider: DynamicDependencies {
        get {
            guard let dependencyProvider = objc_getAssociatedObject(self, dependencyProviderKey) as? DynamicDependencies ?? Self._currentDependencies else {
                fatalError("dependencyProvider not initialized at init")
            }
            return dependencyProvider
        }
        set {
            objc_setAssociatedObject(self, dependencyProviderKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

}
#endif
