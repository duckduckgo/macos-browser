//
//  MutableDependencyStorage.swift
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

/// helper struct used for resolving the dependencies
@dynamicMemberLookup
public struct MutableDependencyStorage<Root> {

    private var storagePtr: UnsafeMutablePointer<[AnyKeyPath: Any]>

    public init(_ storagePtr: UnsafeMutablePointer<[AnyKeyPath: Any]>) {
        self.storagePtr = storagePtr
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<Root, T>) -> T {
        get {
            self.storagePtr.pointee[keyPath] as! T // swiftlint:disable:this force_cast
        }
        nonmutating set {
            self.storagePtr.pointee[keyPath] = newValue
        }
    }

}
