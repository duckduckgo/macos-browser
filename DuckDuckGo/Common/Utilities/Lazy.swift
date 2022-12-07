//
//  Lazy.swift
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

import Foundation

/// Initialize properties lazily and access $variableName optional value without causing initialization if needed
@propertyWrapper
struct Lazy<Owner: AnyObject, Value> {
    // swiftlint:disable opening_brace

    private enum State {
        case none(initialize: ((Owner) -> () -> Value))
        case some(Value)
    }
    private var state: State

    /*
     @Lazy(ClassName.initializingFunction) var varName: ValueType
     func initializingFunction() -> ValueType {
        return ValueType.init(with: self)
     }
     */
    init(_ initialize: @escaping (Owner) -> () -> Value) {
        self.state = .none(initialize: initialize)
    }

    /*
     @Lazy({ (self: ClassName) in return ValueType.init(with: self) }) var varName: ValueType
     */
    init(_ initialize: @escaping (Owner) -> Value) {
        self.state = .none { owner in
            {
                initialize(owner)
            }
        }
    }

    /*
     @Lazy({ (self: ClassName, value) in value.delegate = self }) var varName = ValueType()
     */
    init(wrappedValue: @escaping @autoclosure () -> Value, _ initialize: @escaping (Owner, inout Value) -> Void) {
        self.state = .none { owner in
            {
                var value = wrappedValue()
                initialize(owner, &value)
                return value
            }
        }
    }

    @available(*, unavailable, message: "@Lazy is only available on properties of classes")
    var wrappedValue: Value {
        fatalError()
    }
    static subscript(_enclosingInstance owner: Owner,
                     wrapped _: KeyPath<Owner, Value>,
                     storage selfKeyPath: ReferenceWritableKeyPath<Owner, Self>) -> Value {
        switch owner[keyPath: selfKeyPath].state {
        case .some(let value):
            return value
        case .none(let initialize):
            let value = initialize(owner)()
            owner[keyPath: selfKeyPath].state = .some(value)
            return value
        }
    }

    @available(*, unavailable, message: "@Lazy is only available on properties of classes")
    var projectedValue: Value? {
        fatalError()
    }
    static subscript(_enclosingInstance owner: Owner,
                     projected _: KeyPath<Owner, Value?>,
                     storage selfKeyPath: ReferenceWritableKeyPath<Owner, Self>) -> Value? {
        switch owner[keyPath: selfKeyPath].state {
        case .some(let value):
            return value
        case .none:
            return nil
        }
    }

}
