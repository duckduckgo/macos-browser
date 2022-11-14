//
//  AppDependencyProvider.swift
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

#if DEBUG
// will use TestsDependencyProvider when running tests and DependencyProvider when not
typealias SomeDependencyProvider = DebugDependencyProvider
#else
// Will use DependencyProvider directly for Release builds
typealias SomeDependencyProvider = DependencyProvider
#endif

/// Used to provide dependencies for objects
///
/// In this example, Tab class can use dependencies default app dependencies
/// and mock dependencies can be provided for tests
///
///     extension DependencyProvider<SomeClient> {
///         var providedValue: String { ValueProvider.value }
///     }
///     class SomeClient: DependencyProviderClient {
///         var providedValue: String
///         init() {
///             self.providedValue = type(of: self).dependencyProvider.providedValue
///         }
///         func updateValue() {
///             self.providedValue = dependencyProvider.providedValue
///         }
///     }
///     class DependencyProviderTests: XCTestCase {
///         func test() {
///             TestsDependencyProvider<SomeClient>.shared.providedValue = "test value"
///             let client = SomeClient()
///             XCTAssertEqual(client.providedValue, "test value")
///             TestsDependencyProvider<SomeClient>.shared.providedValue = "new value"
///             client.updateValue()
///             XCTAssertEqual(client.providedValue, "new value")
///         }
///     }
///
protocol DependencyProviderClient { }

extension DependencyProviderClient {
    var dependencyProvider: SomeDependencyProvider<Self> {
        DependencyProviders.provider(for: Self.self)
    }
    static var dependencyProvider: SomeDependencyProvider<Self> {
        DependencyProviders.provider(for: Self.self)
    }
}

private protocol DependencyProviderProtocol {
}

private struct DependencyProviders {

    private static var store = [AnyKeyPath: DependencyProviderProtocol]()

    static func provider<T: DependencyProviderClient>(for clientType: T.Type) -> SomeDependencyProvider<T> {
        dispatchPrecondition(condition: .onQueue(.main))

        if let provider = self.store[\T.dependencyProvider] as? SomeDependencyProvider<T> {
            return provider
        }

        let provider = SomeDependencyProvider<T>()
        DependencyProviders.store[\T.dependencyProvider] = provider

        return provider
    }

#if DEBUG
    private static var testsStore = [AnyKeyPath: DependencyProviderProtocol]()

    static func testsDependencyProvider<T: DependencyProviderClient>(for clientType: T.Type) -> TestsDependencyProvider<T> {
        dispatchPrecondition(condition: .onQueue(.main))

        if let provider = self.testsStore[\T.dependencyProvider] as? TestsDependencyProvider<T> {
            return provider
        }

        let provider = TestsDependencyProvider<T>()
        DependencyProviders.testsStore[\T.dependencyProvider] = provider

        return provider
    }
#endif
}

final class DependencyProvider<Client: DependencyProviderClient>: DependencyProviderProtocol {
    init() {}
}

#if DEBUG

@dynamicMemberLookup
final class DebugDependencyProvider<Client: DependencyProviderClient>: DependencyProviderProtocol {

    init() { }

    private let dependencyProvider = DependencyProvider<Client>()

    subscript<T>(dynamicMember keyPath: KeyPath<DependencyProvider<Client>, T>) -> T {
        if AppDelegate.isRunningTests {
            return TestsDependencyProvider<Client>.shared[dynamicMember: keyPath]
        }
        return dependencyProvider[keyPath: keyPath]
    }
}

@dynamicMemberLookup
final class TestsDependencyProvider<Client: DependencyProviderClient>: DependencyProviderProtocol {
    fileprivate init() {}

    private var storage = [AnyKeyPath: Any]()

    static var shared: TestsDependencyProvider<Client> {
        DependencyProviders.testsDependencyProvider(for: Client.self)
    }

    subscript<T>(dynamicMember keyPath: KeyPath<DependencyProvider<Client>, T>) -> T {
        get {
            guard let dependency = storage[keyPath] as? T else {
                fatalError("Please provide \(String(describing: T.self)) dependency using `TestsDependencyProvider<\(String(describing: Client.self))>.shared.someDependency = someMock` in test setup")
            }
            return dependency
        }
        set {
            storage[keyPath] = newValue
        }
    }

    subscript(_ keyPath: PartialKeyPath<DependencyProvider<Client>>) -> Any? {
        get {
            storage[keyPath]
        }
        set {
            storage[keyPath] = newValue
        }
    }

    func useDefault(for keyPath: PartialKeyPath<DependencyProvider<Client>>) {
        self[keyPath] = DependencyProvider<Client>()[keyPath: keyPath]
    }

    func useDefault(for keyPaths: [PartialKeyPath<DependencyProvider<Client>>]) {
        for keyPath in keyPaths {
            useDefault(for: keyPath)
        }
    }

    static func useDefault(for keyPaths: [PartialKeyPath<DependencyProvider<Client>>]) {
        self.shared.useDefault(for: keyPaths)
    }

    static func setUp(using block: (TestsDependencyProvider) -> Void) {
        block(self.shared)
    }

    static func reset() {
        self.shared.storage = [:]
    }

}

#endif
