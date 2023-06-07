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

@propertyWrapper
public struct Injected<Value>: @unchecked Sendable {

//    let wrappedValue: Value

    public init() {
//        fatalError("not implemented")
    }

//    init(wrappedValue: Value) {
//        self.wrappedValue = wrappedValue
//    }

    @available(*, unavailable, message: "@Injected is only available on properties of classes")
    public var wrappedValue: Value {
        fatalError()
    }
    public static subscript<Owner: Injectable>(_enclosingInstance owner: Owner,
                                               wrapped propertyKeyPath: KeyPath<Owner, Value>,
                                               storage selfKeyPath: KeyPath<Owner, Self>) -> Value {
//        owner.dependencyProvider._storage[propertyKeyPath] as! Value // swiftlint:disable:this force_cast
//        owner[keyPath: selfKeyPath].getSubject(withOwner: owner).value
        fatalError()
    }

//    @available(*, unavailable, message: "@Injected is only available on properties of classes")
//    var projectedValue: Injected<Value> {
//        fatalError()
//    }
//    static subscript<Owner: Injectable>(_enclosingInstance owner: Owner,
//                                        projected _: KeyPath<Owner, Injected<Value>>,
//                                        storage selfKeyPath: ReferenceWritableKeyPath<Owner, Self>) -> Injected<Value> {
////        owner[keyPath: selfKeyPath].getSubject(withOwner: owner).eraseToAnyPublisher()
//        fatalError()
//    }

}
