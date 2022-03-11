//
//  DispatchQueueExtensionsTests.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class DispatchQueueExtensionsTests: XCTestCase {

    func testDispatchWorkItemSync() {
        let queue = DispatchQueue(label: "test queue")

        var dispatched = false
        let job = DispatchWorkItem {
            dispatchPrecondition(condition: .onQueue(queue))
            dispatchPrecondition(condition: .onQueue(.main))

            usleep(UInt32(0.05 * 1_000_000))
            dispatched = true
        }
        queue.dispatch(job, sync: true)
        XCTAssertTrue(dispatched)
    }

    func testDispatchWorkItemAsync() {
        var e: XCTestExpectation!
        let job = DispatchWorkItem {
            dispatchPrecondition(condition: .onQueue(.main))
            e.fulfill()
        }
        DispatchQueue.main.dispatch(job, sync: false)
        e = expectation(description: "DispatchWorkItem dispatched")
        waitForExpectations(timeout: 1)
    }

}
