//
//  FutureExtensionTests.swift
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

import Combine
import Common
import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class FutureExtensionTests: XCTestCase {

    // MARK: - Promise

    func testUnfulfilledPromiseDoesNotHaveValue() {
        autoreleasepool {
            let promise = Future<String, Never>.promise()
            var value: String?
            let c = promise.future.sink {
                XCTFail("unexpected value")
                value = $0
            }

            XCTAssertNil(value)
            withExtendedLifetime(c, {})
        }
    }

    func testInstantlyFulfilledPromiseHasValue() {
        autoreleasepool {
            let promise = Future<String, Never>.promise()
            promise.fulfill("test")
            var value: String?
            let c = promise.future.sink {
                XCTAssertEqual($0, "test")
                value = $0
            }

            XCTAssertEqual(value, "test")
            withExtendedLifetime(c, {})
        }
    }

    func testFulfilledPromiseHasValue() {
        autoreleasepool {
            let promise = Future<String, Never>.promise()
            var value: String?

            let eFulfilled = expectation(description: "fulfilled")
            let c = promise.future.sink {
                XCTAssertEqual($0, "test")
                value = $0
                eFulfilled.fulfill()
            }

            promise.fulfill("test")
            waitForExpectations(timeout: 0)
            XCTAssertEqual(value, "test")
            withExtendedLifetime(c, {})
        }
    }

    func testPromiseFulfilledAsyncHasValue() {
        autoreleasepool {
            let promise = Future<String, Never>.promise()
            var value: String?

            let eFulfilled = expectation(description: "fulfilled")
            let c = promise.future.sink {
                XCTAssertEqual($0, "test")
                value = $0
                eFulfilled.fulfill()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                promise.fulfill("test")
            }
            waitForExpectations(timeout: 1)
            XCTAssertEqual(value, "test")
            withExtendedLifetime(c, {})
        }
    }

    func testPromiseFulfilledInBackgroundHasValue() {
        autoreleasepool {
            let promise = Future<String, Never>.promise()
            var value: String?

            let eFulfilled = expectation(description: "fulfilled")
            let c = promise.future.sink {
                XCTAssertEqual($0, "test")
                value = $0
                eFulfilled.fulfill()
            }

            DispatchQueue.global().async {
                promise.fulfill("test")
            }
            waitForExpectations(timeout: 1)
            XCTAssertEqual(value, "test")
            withExtendedLifetime(c, {})
        }
    }

    // - global queue -

    func testUnfulfilledPromiseOnGlobalQueueDoesNotHaveValue() {
        let e = expectation(description: "background job done")
        DispatchQueue.global().async {
            let promise = Future<String, Never>.promise()
            var value: String?
            let c = promise.future.sink {
                XCTFail("unexpected value")
                value = $0
            }

            XCTAssertNil(value)
            withExtendedLifetime(c, {})

            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testInstantlyFulfilledPromiseOnGlobalQueueHasValue() {
        let e = expectation(description: "background job done")
        DispatchQueue.global().async {
            let promise = Future<String, Never>.promise()
            promise.fulfill("test")
            var value: String?
            let c = promise.future.sink {
                XCTAssertEqual($0, "test")
                value = $0
            }

            XCTAssertEqual(value, "test")
            withExtendedLifetime(c, {})

            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testFulfilledPromiseOnGlobalQueueHasValue() {
        let e = expectation(description: "background job done")
        let eFulfilled = expectation(description: "fulfilled")
        DispatchQueue.global().async {
            let promise = Future<String, Never>.promise()
            var value: String?

            let c = promise.future.sink {
                XCTAssertEqual($0, "test")
                value = $0
                eFulfilled.fulfill()
            }

            promise.fulfill("test")
            self.wait(for: [eFulfilled], timeout: 0)
            XCTAssertEqual(value, "test")
            withExtendedLifetime(c, {})

            e.fulfill()
        }
        wait(for: [e], timeout: 1)
    }

    func testPromiseOnGlobalQueueFulfilledAsyncHasValue() {
        let e = expectation(description: "background job done")
        let eFulfilled = expectation(description: "fulfilled")
        DispatchQueue.global().async {
            let promise = Future<String, Never>.promise()
            var value: String?

            let c = promise.future.sink {
                XCTAssertEqual($0, "test")
                value = $0
                eFulfilled.fulfill()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                promise.fulfill("test")
            }
            self.wait(for: [eFulfilled], timeout: 1)
            XCTAssertEqual(value, "test")
            withExtendedLifetime(c, {})

            e.fulfill()
        }
        wait(for: [e], timeout: 1)
    }

    func testPromiseOnGlobalQueueFulfilledInBackgroundHasValue() {
        let e = expectation(description: "background job done")
        let eFulfilled = expectation(description: "fulfilled")
        DispatchQueue.global().async {
            let promise = Future<String, Never>.promise()
            var value: String?

            let c = promise.future.sink {
                XCTAssertEqual($0, "test")
                value = $0
                eFulfilled.fulfill()
            }

            DispatchQueue.global().async {
                promise.fulfill("test")
            }
            self.wait(for: [eFulfilled], timeout: 1)
            XCTAssertEqual(value, "test")
            withExtendedLifetime(c, {})

            e.fulfill()
        }
        wait(for: [e], timeout: 1)
    }

    // - main queue async -

    @MainActor
    func testUnfulfilledPromiseAsyncDoesNotHaveValue() {
        let promise = Future<String, Never>.promise()
        var value: String?
        let c = promise.future.sink {
            XCTFail("unexpected value")
            value = $0
        }

        XCTAssertNil(value)
        withExtendedLifetime(c, {})
    }

    func testInstantlyFulfilledPromiseAsyncHasValue() {
        let promise = Future<String, Never>.promise()
        promise.fulfill("test")
        var value: String?
        let c = promise.future.sink {
            XCTAssertEqual($0, "test")
            value = $0
        }

        XCTAssertEqual(value, "test")
        withExtendedLifetime(c, {})
    }

    @MainActor
    func testFulfilledPromiseAsyncHasValue() async {
        let eFulfilled = expectation(description: "fulfilled")
        let promise = Future<String, Never>.promise()
        var value: String?

        let c = promise.future.sink {
            XCTAssertEqual($0, "test")
            value = $0
            eFulfilled.fulfill()
        }

        promise.fulfill("test")
        await fulfillment(of: [eFulfilled], timeout: 0)
        XCTAssertEqual(value, "test")
        withExtendedLifetime(c, {})
    }

    func testPromiseAsyncFulfilledAsyncHasValue() {
        let e = expectation(description: "async job done")
        let eFulfilled = expectation(description: "fulfilled")
        RunLoop.main.perform {
            let promise = Future<String, Never>.promise()
            var value: String?

            let c = promise.future.sink {
                XCTAssertEqual($0, "test")
                value = $0
                eFulfilled.fulfill()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                promise.fulfill("test")
            }
            self.wait(for: [eFulfilled], timeout: 1)
            XCTAssertEqual(value, "test")
            withExtendedLifetime(c, {})

            e.fulfill()
        }
        wait(for: [e], timeout: 1)
    }

    @MainActor
    func testPromiseAsyncFulfilledInBackgroundHasValue() async {
        let eFulfilled = expectation(description: "fulfilled")
        let promise = Future<String, Never>.promise()
        var value: String?

        let c = promise.future.sink {
            XCTAssertEqual($0, "test")
            value = $0
            eFulfilled.fulfill()
        }

        DispatchQueue.global().async {
            promise.fulfill("test")
        }
        await fulfillment(of: [eFulfilled], timeout: 1)
        XCTAssertEqual(value, "test")
        withExtendedLifetime(c, {})
    }

    // MARK: - Publishers.First.get()

    @MainActor
    func testWhenFirstSucceeds_getFutureReceivesValue() async throws {
        let subj = PassthroughSubject<Int, Never>()

        let future = subj.first().promise()
        subj.send(1)

        let result = try await future.get()
        XCTAssertEqual(result, 1)
    }

    @MainActor
    func testWhenFirstFails_getFutureThrowsError() async throws {

        struct E: Error {}
        let subj = PassthroughSubject<Int, E>()

        let future = subj.first().promise()
        subj.send(completion: .failure(E()))

        do {
            _=try await future.get()
            XCTFail("future.get() should fail")
        } catch {
            XCTAssertTrue(error is E)
        }
    }

    @MainActor
    func testWhenFirstTimeouts_getFutureThrowsError() async throws {

        let subj = PassthroughSubject<Int, Never>()

        let future = subj.timeout(0.001).first().promise()

        do {
            _=try await future.get()
            XCTFail("future.get() should timeout")
        } catch {
            XCTAssertTrue(error is TimeoutError)
        }
    }

}
