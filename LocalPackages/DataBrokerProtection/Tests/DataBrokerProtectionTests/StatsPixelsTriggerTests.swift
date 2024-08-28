//
//  StatsPixelsTriggerTests.swift
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
@testable import DataBrokerProtection

final class StatsPixelsTriggerTests: XCTestCase {

    func testWhenFromDateIsNil_thenReturnsTrue() throws {
        // Given
        let fromDate: Date? = nil
        let sut = DefaultCustomStatsPixelsTrigger()

        // When
        let result = sut.shouldFireCustomStatsPixels(fromDate: fromDate)

        // Then
        XCTAssertTrue(result)
    }

    func testWhenFromDateIsOver24HoursAgo_thenReturnsTrue() throws {
        // Given
        let calendar = Calendar.current
        let fromDate = calendar.date(byAdding: .hour, value: -25, to: Date())
        let sut = DefaultCustomStatsPixelsTrigger()

        // When
        let result = sut.shouldFireCustomStatsPixels(fromDate: fromDate)

        // Then
        XCTAssertTrue(result)
    }

    func testWhenFromDateIsLessThan24HoursAgo_thenReturnsFalse() throws {
        // Given
        let calendar = Calendar.current
        let fromDate = calendar.date(byAdding: .hour, value: -23, to: Date())
        let sut = DefaultCustomStatsPixelsTrigger()

        // When
        let result = sut.shouldFireCustomStatsPixels(fromDate: fromDate)

        // Then
        XCTAssertFalse(result)
    }

}
