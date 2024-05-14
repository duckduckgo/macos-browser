//
//  DataBrokerProtectionProcessorConfigurationTests.swift
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

import XCTest
import Foundation
@testable import DataBrokerProtection

final class DataBrokerExecutionConfigTests: XCTestCase {

    private let sut = DataBrokerExecutionConfig()

    func testWhenOperationIsManualScans_thenConcurrentOperationsBetweenBrokersIsSix() {
        let value = sut.concurrentOperationsFor(.scan)
        let expectedValue = 6
        XCTAssertEqual(value, expectedValue)
    }

    func testWhenOperationIsAll_thenConcurrentOperationsBetweenBrokersIsTwo() {
        let value = sut.concurrentOperationsFor(.all)
        let expectedValue = 2
        XCTAssertEqual(value, expectedValue)
    }

    func testWhenOperationIsOptOut_thenConcurrentOperationsBetweenBrokersIsTwo() {
        let value = sut.concurrentOperationsFor(.optOut)
        let expectedValue = 2
        XCTAssertEqual(value, expectedValue)
    }
}
