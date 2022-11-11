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

final class DependencyProviderTests: XCTestCase {

    func testDependencyProvider() {
        let client = SomeClient()
        XCTAssertEqual(client.providedValue, "value")
        ValueProvider.value = "another value"
        client.updateValue()
        XCTAssertEqual(client.providedValue, "another value")
    }

    func testTestDependencyProvider() {
        TestsDependencyProvider<SomeClient>.shared.providedValue = "test value"
        let client = SomeClient()
        XCTAssertEqual(client.providedValue, "test value")
        TestsDependencyProvider<SomeClient>.shared.providedValue = "new value"
        client.updateValue()
        XCTAssertEqual(client.providedValue, "new value")
    }

}

private struct ValueProvider {
    static var value = "value"
}

extension DependencyProvider<SomeClient> {
    var providedValue: String { ValueProvider.value }
}

final class SomeClient: DependencyProviderClient {
    var providedValue: String
    init() {
        self.providedValue = type(of: self).dependencyProvider.providedValue
    }
    func updateValue() {
        self.providedValue = dependencyProvider.providedValue
    }
}
