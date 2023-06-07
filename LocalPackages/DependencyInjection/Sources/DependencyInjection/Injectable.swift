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

public protocol Injectable: AnyObject {
    associatedtype Dependencies = NoDependencies
    associatedtype InjectedDependencies = NoDependencies

    associatedtype DynamicDependencyProvider
    associatedtype DD //: DynamicDependenciesProtocol // auto-generated struct
    var dependencyProvider: DD { get } // auto-generated
}

public protocol DynamicDependenciesProtocol {
    init()

    var _storage: [AnyKeyPath: Any] { get } // swiftlint:disable:this identifier_name
}

private let dependencyProviderKey = UnsafeRawPointer(bitPattern: "dependencyProvider".hashValue)!
//extension Injectable {

//    var dependencyProvider: DynamicDependencies {
//        get {
//            if let dependencyProvider = objc_getAssociatedObject(self, dependencyProviderKey) as? DynamicDependencies {
//                return dependencyProvider
//            }
//            let dependencyProvider = DynamicDependencies.init()
//            objc_setAssociatedObject(self, dependencyProviderKey, dependencyProvider, .OBJC_ASSOCIATION_RETAIN)
//
//            return dependencyProvider
//        }
//        set {
//            objc_setAssociatedObject(self, dependencyProviderKey, newValue, .OBJC_ASSOCIATION_RETAIN)
//        }
//    }

//}

//@dynamicMemberLookup
//struct DD_Str<Owner: Injectable> {
//    var _storage: [AnyKeyPath: Any]
//
//    init() {
//        self._storage = [:] //AppStateRestorationManager_Injected_Helpers._currentDependencies._storage
//    }
//    init(_ storage: [AnyKeyPath: Any]) {
//        self._storage = storage
//    }
//    init(_ emptyArrayLiteral: [Any]) {
//        assert(emptyArrayLiteral.isEmpty)
//        self.init()
//    }
//    init(_ dependencyProvider: Owner.Dependencies) {
//        self._storage = [:]
////        AppStateRestorationManager_Injected_Helpers.getAllDependencyProviderKeyPaths(from: dependencyProvider).reduce(into: [:]) {
////            $0[$1] = dependencyProvider[keyPath: $1]
////        }
//    }
//    init(_ dependencyProvider: Owner.DynamicDependencyProvider) {
//        self._storage = [:] //dependencyProvider._storage
//    }
//
//    subscript<T>(dynamicMember keyPath: KeyPath<Owner.Dependencies, T>) -> T {
//        self._storage[keyPath] as! T // swiftlint:disable force_cast
//    }
//}


