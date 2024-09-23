//
//  KVOListenerTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

// A simple class to observe
class TestObject: NSObject {
    @objc dynamic var value: Int = 0
}

final class KVOListenerTests: XCTestCase {
    var cancellables: Set<AnyCancellable> = []

    func testKVOListenerReceivesUpdates() {
        let testObject = TestObject()
        let listener = KVOListener<TestObject, Int>(object: testObject, keyPath: "value")

        let expectation = self.expectation(description: "Listener should receive updates")

        listener.sink(receiveValue: { newValue in
                XCTAssertEqual(newValue, 42)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        testObject.value = 42

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testKVOListenerDoesNotReceiveUpdatesAfterCancel() {
        let testObject = TestObject()
        let listener = KVOListener<TestObject, Int>(object: testObject, keyPath: "value")

        var receivedValues: [Int] = []

        let subscription = listener
            .sink(receiveValue: { newValue in
                receivedValues.append(newValue)
            })

        // Change the value to trigger KVO
        testObject.value = 1

        // Cancel the subscription
        subscription.cancel()

        // Change the value again
        testObject.value = 2

        // Assert that no new values were received after cancellation
        XCTAssertEqual(receivedValues, [1])
    }

    func testKVOListenerHandlesMultipleUpdates() {
        let testObject = TestObject()
        let listener = KVOListener<TestObject, Int>(object: testObject, keyPath: "value")

        var receivedValues: [Int] = []

        listener
            .sink(receiveValue: { newValue in
                receivedValues.append(newValue)
            })
            .store(in: &cancellables)

        // Change the value multiple times
        testObject.value = 10
        testObject.value = 20
        testObject.value = 30

        // Assert that all values were received
        XCTAssertEqual(receivedValues, [10, 20, 30])
    }
}
