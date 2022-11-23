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

import os
import Foundation

protocol DependencyProvider {
    associatedtype Parent: DependencyProvider
    static var keyPath: KeyPath<Parent, Self> { get }
}
protocol RootDependencyProvider: DependencyProvider where Parent == Self {
}
extension RootDependencyProvider {
    static var keyPath: KeyPath<Parent, Self> { \.self }
}

@propertyWrapper
struct Injected2<Value> {
    private var _wrappedValue: Value?
    var wrappedValue: Value {
        fatalError()
    }

    init<Provider: DependencyProvider>(from: @autoclosure () -> Provider, at: KeyPath<Provider, Value>) {

    }
}

@propertyWrapper
struct Injected5<Value> {
    private var _wrappedValue: Value?
    var wrappedValue: Value {
        fatalError()
    }

    init<Provider: DependencyProvider>(from providerType: Provider.Type, at: KeyPath<Provider, Value>) {

    }
}

@propertyWrapper
struct Injected3<Value> {
    private var _wrappedValue: Value?
    var wrappedValue: Value {
        fatalError()
    }

    init<Provider: DependencyProvider>(from: @autoclosure () -> Provider) {

    }
}

@propertyWrapper
struct Injected4<Value> {
    private var _wrappedValue: Value?
    var wrappedValue: Value {
        fatalError()
    }

    init<Provider: DependencyProvider>(from: @autoclosure () -> Provider, get: (Provider) -> Value) {

    }

    init<Provider: DependencyProvider>(wrappedValue: (Provider) -> Value, from: @autoclosure () -> Provider) {
        
    }
}


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
                if let value = _wrappedValue {
                    return value
                }
                if let none = (Value.self as? AnyOptionalType)?.none as? Value {
#if DEBUG
                    assert(AppDelegate.isRunningTests,
                           "Value not provided for Optional dependency \(Value.self), " +
                           "initialise it with nil value explicitly if it is intended")
#endif
                    return none
                }

                fatalError("\(Value.self) dependency not provided by the time of the first use")
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
        static subscript<Client: AnyObject>(_enclosingInstance object: Client,
                                            wrapped wrappedKeyPath: KeyPath<Client, Value>,
                                            storage storageKeyPath: ReferenceWritableKeyPath<Client, Injected<Value>>) -> Value {
            get {
                // we either get initialised with @Injected(default: value)
                if let value = object[keyPath: storageKeyPath]._wrappedValue {
                    assert(DependencyInjection.store[wrappedKeyPath] == nil,
                           "\(Client.self).\(Value.self) dependecy has been set twice!")
                    return value
                }

                // or by using DependencyInjection.register(\\Client.key, value: value)
                if let value = store[wrappedKeyPath] as? Value {
                    return value
                }

                if let none = (Value.self as? AnyOptionalType)?.none as? Value {
#if DEBUG
                    assert(AppDelegate.isRunningTests,
                           "Value not provided for Optional dependency \(Client.self).\(Value.self), " +
                           "initialise it with nil value explicitly if it is intended")
#endif
                    return none
                }

                fatalError("\(Client.self).\(Value.self) dependency not provided by the time of the first use. " +
                           "Provide dependency value using `DependencyInjection.register(\\\(Client.self).key, value: value)`")
            }
            set {
                fatalError("Don‘t set depencencies directly, " +
                           "use `DependencyInjection.register(\\\(Client.self).key, value: value)` instead")
            }
        }

        init(wrappedValue getDefault: @autoclosure () -> Value, _ testability: Testability = .appOnly) {
            if AppDelegate.isRunningTests, case .appOnly = testability {
                os_log("Ignoring %s dependency default value", log: .default, type: .debug, "\(Value.self)")
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

    static func register<Client, Value>(_ keyPath: KeyPath<Client, Value>, value: @autoclosure () -> Value, _ testability: Testability = .appOnly) {
#if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        if AppDelegate.isRunningTests, case .appOnly = testability {
            os_log("Skipping %s dependency registration", log: .default, type: .debug, "\(Client.self).\(Value.self)")
            return
        }
#endif

        assert(store[keyPath] == nil, "\(Client.self).\(Value.self) dependency is already registered")
        store[keyPath] = value()
    }

    static func register<Value>(_ dependency: UnsafeMutablePointer<Value> /* a.k.a. inout Value */,
                                value: @autoclosure () -> Value,
                                _ testability: Testability = .appOnly) {
#if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))

        // setting flag to privent direct `Struct.staticDependency = value` setting
        isRegisteringDependency = true

        if AppDelegate.isRunningTests, case .appOnly = testability {
            os_log("Skipping %s dependency registration", log: .default, type: .debug, "\(Value.self)")
            return
        }
#endif

        // we get here after retreiving the initial value from `yield &ptr` in Injected.wrappedValue._modify
        // the initial value can be nil although the result type is not
        // by this nullable pointer casting we allow the value to be nullable and so rollbackable
        assert(MemoryLayout<Value>.size == MemoryLayout<Value?>.size)
        assert(MemoryLayout<Value>.stride == MemoryLayout<Value?>.stride)
        let optionalPtr = dependency.withMemoryRebound(to: Value?.self, capacity: 1) { $0 }

#if DEBUG
        let initialValue = optionalPtr.pointee
#endif
        optionalPtr.pointee = value()

#if DEBUG
        if AppDelegate.isRunningTests {
            // rollback to default value in XCTestCase.tearDown
            resetInjectedValues = { [next=resetInjectedValues] in
                optionalPtr.pointee = initialValue
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
