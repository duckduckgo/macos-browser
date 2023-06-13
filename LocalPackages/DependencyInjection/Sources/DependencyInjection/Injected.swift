//
//  Injected.swift
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

#if swift(<5.9)

@propertyWrapper
public struct ClassInjectedValue<Value>: @unchecked Sendable {

    public init() {
    }

    @available(*, unavailable, message: "@ClassInjectedValue is only available on properties of classes")
    public var wrappedValue: Value {
        fatalError()
    }

    public static subscript<Owner: Injectable & AnyObject>(_enclosingInstance owner: Owner,
                                                           wrapped propertyKeyPath: KeyPath<Owner, Value>,
                                                           storage selfKeyPath: KeyPath<Owner, Self>) -> Value {
        owner.dependencyProvider._storage.first { (keyPath, value) in
            type(of: keyPath).valueType == Value.self && "\(keyPath)".split(separator: ".").last == "\(propertyKeyPath)".split(separator: ".").last
        }!.value as! Value // swiftlint:disable:this force_cast
    }

}

public enum StructInjectedKeyPathsStorage {

    @TaskLocal public static var keyPaths: UnsafeMutablePointer<[AnyKeyPath]>!

}

public struct OwnedInjectedStruct<Owner: Injectable> {

    @propertyWrapper
    public struct StructInjectedValue<Value>: @unchecked Sendable {

        var storage: [AnyKeyPath: Any]!
        var keyPath: AnyKeyPath!

        public init() {
            self.keyPath = StructInjectedKeyPathsStorage.keyPaths.pointee.removeFirst()
            self.storage = Owner._currentDependencies!._storage
        }

        public var wrappedValue: Value {
            storage[keyPath] as! Value // swiftlint:disable:this force_cast
        }

    }
}

#endif
