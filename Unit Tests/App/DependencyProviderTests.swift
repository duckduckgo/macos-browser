//
//  DependencyProviderTests.swift
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
import Combine
@testable import DuckDuckGo_Privacy_Browser

extension XCTestCase {

    func registerDependency<Client, Value>(_ keyPath: KeyPath<Client, Value>, value: Value) {
        DependencyInjection.register(keyPath, value: value, .testable)
        addTeardownBlock {
            DependencyInjection.reset()
        }
    }

    func registerDependency<Value>(_ dependency: inout Value, value: Value) {
        DependencyInjection.register(&dependency, value: value, .testable)
        addTeardownBlock {
            DependencyInjection.reset()
        }
    }

}

final class DependencyProviderTests: XCTestCase {

    func testDependencyProviderResetsValueAfterTest() {
        class Dep {
            var onDeinit: (() -> Void)?
            deinit {
                onDeinit?()
            }
        }
        struct Dependencies {
            @Injected(.testable) static var testDep = Dep()
        }

        weak var mock1: Dep?
        let deinitExpectation = expectation(description: "Dep should deinit")
        autoreleasepool {
            mock1 = Dependencies.testDep

            let mock2 = Dep()
            mock2.onDeinit = {
                deinitExpectation.fulfill()
            }

            registerDependency(&Dependencies.testDep, value: mock2)
            XCTAssertTrue(Dependencies.testDep === mock2)
        }

        DependencyInjection.reset()
        waitForExpectations(timeout: 0)

        XCTAssertTrue(Dependencies.testDep === mock1!)
    }

    func testDependencyProviderNoInitialValue() {
        class Dep {
            var onDeinit: (() -> Void)?
            deinit {
                onDeinit?() ?? {
                    XCTFail("Unexpected deinit")
                }()
            }
        }
        struct Dependencies {
            @Injected() static var testDep = Dep()
        }

        let deinitExpectation = expectation(description: "Dep should deinit")
        weak var weakMock: Dep?
        autoreleasepool {
            let mock = Dep()
            weakMock = mock
            mock.onDeinit = {
                deinitExpectation.fulfill()
            }

            registerDependency(&Dependencies.testDep, value: mock)
            XCTAssertTrue(Dependencies.testDep === mock)
        }
        XCTAssertTrue(Dependencies.testDep === weakMock!)

        DependencyInjection.reset()
        waitForExpectations(timeout: 0)
    }

}
