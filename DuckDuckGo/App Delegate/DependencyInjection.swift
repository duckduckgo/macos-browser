//
//  DependencyInjection.swift
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

import AppKit
import Foundation

enum Testability {
    case mockable
    case testable
}

@propertyWrapper
struct Injected<Value> {

    private var _wrappedValue: Value?

    // swiftlint:disable implicit_getter
    var wrappedValue: Value {
        get {
            guard _wrappedValue != nil else {
                fatalError("\(Value.self) dependency not provided by the time of first use")
            }
            return _wrappedValue!
        }
        _modify {
            if _wrappedValue != nil && !AppDelegate.isRunningTests {
                assertionFailure("\(Value.self) dependency value already set")
            }

            // the trick is to modify the value in place so the Copy Construcor isn‘t called
            // and hope for caller‘s good intentions not to unwrap the old value
            yield &withUnsafeMutableBytes(of: &_wrappedValue) { ptr in
                return ptr.baseAddress!.assumingMemoryBound(to: Value.self)
            }.pointee

#if DEBUG
            assert(DependencyInjection.isRegisteringDependency,
                   "Don‘t set depencencies directly, use `DependencyInjection.register(&Client.key, value: value)` instead")
            DependencyInjection.isRegisteringDependency = false
#endif
        }
    }

    init(default getDefault: @escaping @autoclosure () -> Value, _ testability: Testability = .mockable) {
        if AppDelegate.isRunningTests, case .mockable = testability {
            return
        }

        self._wrappedValue = getDefault()
    }
    init(wrappedValue getDefault: @escaping @autoclosure () -> Value, _ testability: Testability = .mockable) {
        if AppDelegate.isRunningTests, case .mockable = testability {
            return
        }

        self._wrappedValue = getDefault()
    }
    init() {
    }

//    @available(*, unavailable, message: "@Injected is only available on properties of structs")
    static subscript<EnclosingSelf: AnyObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: KeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Injected<Value>>
    ) -> Value {
        get {
            // TODO: Redo with keypath storage
            fatalError()
//            if case .value(let value) = object[keyPath: storageKeyPath].wrapped {
//                assert(InjectedValues.store[wrappedKeyPath] == nil, "Trying to register the dependency twice!")
//                return value
//            }
//
//            guard var injected = InjectedValues.store[wrappedKeyPath] as? Self else {
//                if case .getDefault = object[keyPath: storageKeyPath].wrapped {
//                    return object[keyPath: storageKeyPath].wrappedValue
//                }
//                fatalError("Provide dependency value using `Client[dependency: \\.key] = value`")
//            }
//
//            if object[keyPath: storageKeyPath].wrapped != nil {
//                assertionFailure("Value for the dependency is registered twice!")
//            }
//            if case .value(let value) = injected.wrapped {
//                return value
//            }
//            defer {
//                InjectedValues.store[wrappedKeyPath] = injected
//            }
//            return injected.wrappedValue
        }
        set {
            fatalError("Use `DependencyInjection.register(\\.key) { value }` instead")
        }
    }

}

struct DependencyInjection {
#if DEBUG
    fileprivate static var isRegisteringDependency = false
    private static var resetInjectedValues: (() -> Void)?
#endif

    private static var store = [AnyKeyPath: Any]()

    private init() {}
    static func register<Client, Value>(_ keyPath: KeyPath<Client, Value>, getValue: @escaping () -> Value) {
#if DEBUG
        if AppDelegate.isRunningTests {
            return
        }
#endif

        assert(store[keyPath] == nil)
        store[keyPath] = Injected(wrappedValue: getValue())
    }

    static func register<Client, Value>(_ keyPath: KeyPath<Client, Value>, value: Value, _ testability: Testability = .mockable) {
#if DEBUG
        if AppDelegate.isRunningTests, case .mockable = testability {
            return
        }
#endif

        assert(store[keyPath] == nil)
        store[keyPath] = Injected(wrappedValue: value, testability)
    }

    static func register<Value>(_ dependency: inout Value, value: Value, _ testability: Testability = .mockable) {
#if DEBUG
        if AppDelegate.isRunningTests, case .mockable = testability {
            return
        }

        let wrappedPtr = withUnsafeMutableBytes(of: &dependency) { ptr in
            ptr.baseAddress!.assumingMemoryBound(to: Optional<Value>.self)
        }
        let initialValue = wrappedPtr.pointee

        isRegisteringDependency = true
#endif

        dependency = value

#if DEBUG
        // swiftlint:disable:next identifier_name
        resetInjectedValues = { [next=resetInjectedValues] in
            wrappedPtr.pointee = initialValue
            next?() ?? {
                self.resetInjectedValues = nil
            }()
        }
#endif
    }

#if DEBUG
    static func reset() {
        store = [:]
        resetInjectedValues?()
    }
#endif

}
