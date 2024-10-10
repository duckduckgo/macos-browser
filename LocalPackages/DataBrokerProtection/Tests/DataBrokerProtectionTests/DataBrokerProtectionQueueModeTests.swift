//
//  DataBrokerProtectionQueueModeTests.swift
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

@testable import DataBrokerProtection
import XCTest

final class DataBrokerProtectionQueueModeTests: XCTestCase {

    func testCurrentModeIdle_andNewModeImmediate_thenInterruptionAllowed() throws {
        // Given
        let sut = DataBrokerProtectionQueueMode.idle

        // When
        let result = sut.canBeInterruptedBy(newMode: .immediate(errorHandler: nil, completion: nil))

        // Then
        XCTAssertTrue(result)
    }

    func testCurrentModeIdle_andNewModeScheduled_thenInterruptionAllowed() throws {
        // Given
        let sut = DataBrokerProtectionQueueMode.idle

        // When
        let result = sut.canBeInterruptedBy(newMode: .scheduled(errorHandler: nil, completion: nil))

        // Then
        XCTAssertTrue(result)
    }

    func testCurrentModeImmediate_andNewModeImmediate_thenInterruptionAllowed() throws {
        // Given
        let sut = DataBrokerProtectionQueueMode.immediate(errorHandler: nil, completion: nil)

        // When
        let result = sut.canBeInterruptedBy(newMode: .immediate(errorHandler: { _ in }, completion: {}))

        // Then
        XCTAssertTrue(result)
    }

    func testCurrentModeImmediate_andNewModeScheduled_thenInterruptionNotAllowed() throws {
        // Given
        let sut = DataBrokerProtectionQueueMode.immediate(errorHandler: nil, completion: nil)

        // When
        let result = sut.canBeInterruptedBy(newMode: .scheduled(errorHandler: nil, completion: nil))

        // Then
        XCTAssertFalse(result)
    }

    func testCurrentModeScheduled_andNewModeImmediate_thenInterruptionAllowed() throws {
        // Given
        let sut = DataBrokerProtectionQueueMode.scheduled(errorHandler: nil, completion: nil)

        // When
        let result = sut.canBeInterruptedBy(newMode: .immediate(errorHandler: nil, completion: nil))

        // Then
        XCTAssertTrue(result)
    }

    func testCurrentModeScheduled_andNewModeScheduled_thenInterruptionNotAllowed() throws {
        // Given
        let sut = DataBrokerProtectionQueueMode.scheduled(errorHandler: nil, completion: nil)

        // When
        let result = sut.canBeInterruptedBy(newMode: .scheduled(errorHandler: nil, completion: nil))

        // Then
        XCTAssertFalse(result)
    }

    func testWhenModeIsIdle_thenPriorityDateIsNil() throws {
        // Given
        let sut = DataBrokerProtectionQueueMode.idle

        // When
        let result = sut.priorityDate

        // Then
        XCTAssertNil(result)
    }

    func testWhenModeIsImmediate_thenPriorityDateIsNil() throws {
        // Given
        let sut = DataBrokerProtectionQueueMode.immediate(errorHandler: nil, completion: nil)

        // When
        let result = sut.priorityDate

        // Then
        XCTAssertNil(result)
    }

    func testWhenModeIsScheduled_thenPriorityDateIsNotNil() throws {
        // Given
        let sut = DataBrokerProtectionQueueMode.scheduled(errorHandler: nil, completion: nil)

        // When
        let result = sut.priorityDate

        // Then
        XCTAssertNotNil(result)
    }
}
