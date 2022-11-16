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

typealias Injected = DependencyInjection.Injected
struct DependencyInjection {

    enum Testability {
        case appOnly
        case testable
    }

    @propertyWrapper
    struct Injected<Value> {
        private var _wrappedValue: Value?

        /// Used for struct and static variables
        var wrappedValue: Value {
            // swiftlint:disable:next implicit_getter
            get {
                guard _wrappedValue != nil else {
                    fatalError("\(Value.self) dependency not provided by the time of the first use")
                }
                return _wrappedValue!
            }
            // -> getting here right before the DependencyInjection.register(&Client.key, value: value) is called
            _modify {
#if DEBUG
                if _wrappedValue != nil && !AppDelegate.isRunningTests {
                    assertionFailure("\(Value.self) dependency value is already set")
                }
#endif

                // result type is non-optional but the actual value is nullable
                // the trick is to modify the value in place so the Copy Construcor isn‘t called
                // and hope for caller‘s good intentions not to unwrap the old value
                let nonOptionalPtr = withUnsafeMutableBytes(of: &_wrappedValue) { ptr in
                    return ptr.baseAddress!.assumingMemoryBound(to: Value.self)
                }
                // now passing control to DependencyInjection.register(&Client.key, value: value)
                yield &nonOptionalPtr.pointee

#if DEBUG
                // now we got back from DependencyInjection.register(&Client.key, value: value)
                // and it‘s the only place to check if the call was performed correctly:
                // by using DependencyInjection.register and not directly assigning the value
                assert(DependencyInjection.isRegisteringDependency, "Don‘t set depencencies directly, " +
                       "use `DependencyInjection.register(&Client.key, value: value)` instead")
                DependencyInjection.isRegisteringDependency = false
#endif
            }
        }

        /// Used for class instance variables
        static subscript<EnclosingSelf: AnyObject>(
            _enclosingInstance object: EnclosingSelf,
            wrapped wrappedKeyPath: KeyPath<EnclosingSelf, Value>,
            storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Injected<Value>>
        ) -> Value {
            get {
                // we either get initialised with @Injected(default: value)
                if let value = object[keyPath: storageKeyPath]._wrappedValue {
                    assert(DependencyInjection.store[wrappedKeyPath] == nil, "\(Value.self) dependecy has been set twice!")
                    return value
                }

                // or by using DependencyInjection.register(\\Client.key, value: value)
                guard let value = store[wrappedKeyPath] as? Value else {
                    fatalError("\(Value.self) dependency not provided by the time of the first use. " +
                               "Provide dependency value using `DependencyInjection.register(\\Client.key, value: value)`")
                }

                return value
            }
            set {
                fatalError("Don‘t set depencencies directly, use `DependencyInjection.register(\\Client.key, value: value)` instead")
            }
        }

        init(wrappedValue getDefault: @autoclosure () -> Value, _ testability: Testability = .appOnly) {
            if AppDelegate.isRunningTests, case .appOnly = testability {
                return
            }

            self._wrappedValue = getDefault()
        }

        init(default getDefault: @autoclosure () -> Value, _ testability: Testability = .appOnly) {
            self.init(wrappedValue: getDefault(), testability)
        }

        init() {}

    }

#if DEBUG
    private static var isRegisteringDependency = false
    private static var resetInjectedValues: (() -> Void)?
#endif

    private static var store = [AnyKeyPath: Any]()
    private init() {}

    static func register<Client, Value>(_ keyPath: KeyPath<Client, Value>, value: @autoclosure () -> Value) {
#if DEBUG
        if AppDelegate.isRunningTests {
            return
        }
#endif

        assert(store[keyPath] == nil)
        store[keyPath] = value()
    }

    static func register<Value>(_ dependency: inout Value, value: Value, _ testability: Testability = .appOnly) {
#if DEBUG
        if AppDelegate.isRunningTests, case .appOnly = testability {
            return
        }

        // we get here after retreiving the initial value from `yield &ptr` in Injected.wrappedValue._modify
        // the initial value can be nil although the result type is not
        // by this nullable pointer casting we allow the value to be nullable and so rollbackable
        let wrappedPtr = withUnsafeMutableBytes(of: &dependency) { ptr in
            ptr.baseAddress!.assumingMemoryBound(to: Optional<Value>.self)
        }
        let initialValue = wrappedPtr.pointee

        // setting flag to privent direct `Struct.staticDependency = value` setting
        isRegisteringDependency = true
#endif

        dependency = value

#if DEBUG
        if AppDelegate.isRunningTests {
            // rollback to default value in XCTestCase.tearDown
            resetInjectedValues = { [next=resetInjectedValues] in
                wrappedPtr.pointee = initialValue
                next?() ?? {
                    self.resetInjectedValues = nil
                }()
            }
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
