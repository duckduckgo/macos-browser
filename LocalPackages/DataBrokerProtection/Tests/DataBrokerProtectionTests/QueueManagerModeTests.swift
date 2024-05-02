//
//  QueueManagerModeTests.swift
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

final class QueueManagerModeTests: XCTestCase {

    func testCurrentModeIdle_andNewModeManual_thenInterruptionAllowed() throws {
        // Given
        let sut = QueueManagerMode.idle

        // When
        let result = sut.canInterrupt(forNewMode: .manual)

        XCTAssertTrue(result)
    }

    func testCurrentModeIdle_andNewModeQueued_thenInterruptionAllowed() throws {
        // Given
        let sut = QueueManagerMode.idle

        // When
        let result = sut.canInterrupt(forNewMode: .queued)

        XCTAssertTrue(result)
    }

    func testCurrentModeManual_andNewModeQueued_thenInterruptionNotAllowed() throws {
        // Given
        let sut = QueueManagerMode.manual

        // When
        let result = sut.canInterrupt(forNewMode: .queued)

        XCTAssertFalse(result)
    }

    func testCurrentModeQueued_andNewModeManual_thenInterruptionAllowed() throws {
        // Given
        let sut = QueueManagerMode.queued

        // When
        let result = sut.canInterrupt(forNewMode: .manual)

        XCTAssertTrue(result)
    }
}
