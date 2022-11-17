//
//  XCTestCaseExtension.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

extension XCTestCase {

    struct DependencyInjection {
        static func register<Value>(_ dependency: inout Value, value: @autoclosure () -> Value, _ testability: DuckDuckGo_Privacy_Browser.DependencyInjection.Testability = .appOnly) {
            fatalError("Use `self.registerDependency` instead of `DependencyInjection.register`")
        }
        static func register<Client, Value>(_ keyPath: KeyPath<Client, Value>, value: @autoclosure () -> Value, _ testability: DuckDuckGo_Privacy_Browser.DependencyInjection.Testability = .appOnly) {
            fatalError("Use `self.registerDependency` instead of `DependencyInjection.register`")
        }
        static func reset() {
            DuckDuckGo_Privacy_Browser.DependencyInjection.reset()
        }
    }

    func registerDependency<Client, Value>(_ keyPath: KeyPath<Client, Value>, value: Value) {
        DuckDuckGo_Privacy_Browser.DependencyInjection.register(keyPath, value: value, .testable)
        addTeardownBlock {
            DuckDuckGo_Privacy_Browser.DependencyInjection.reset()
        }
    }

    func registerDependency<Value>(_ dependency: inout Value, value: Value) {
        DuckDuckGo_Privacy_Browser.DependencyInjection.register(&dependency, value: value, .testable)
        addTeardownBlock {
            DuckDuckGo_Privacy_Browser.DependencyInjection.reset()
        }
    }

}
