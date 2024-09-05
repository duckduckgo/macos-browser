//
//  DuckPlayerExperimentPixelsUtilitiesTests.swift
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

import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser

class DuckPlayerExperimentPixelsUtilitiesTests: XCTestCase {

    func testShouldFirePixelDaily() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 1))!
        let endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 2))!
        let result = DuckPlayerExperimentPixelsUtilities.shouldFirePixel(startDate: startDate, endDate: endDate, daysDifference: .daily)
        XCTAssertTrue(result, "Pixel should fire for daily frequency when the difference is 1 day.")
    }

    func testShouldFirePixelWeeklySameMonth() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 2))!
        let endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 9))!
        let result = DuckPlayerExperimentPixelsUtilities.shouldFirePixel(startDate: startDate, endDate: endDate, daysDifference: .weekly)
        XCTAssertTrue(result, "Pixel should fire for weekly frequency when the difference is 7 days.")
    }

    func testShouldFirePixelWeeklyChangingMonths() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 25))!
        let endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 2))!
        let result = DuckPlayerExperimentPixelsUtilities.shouldFirePixel(startDate: startDate, endDate: endDate, daysDifference: .weekly)
        XCTAssertTrue(result, "Pixel should fire for weekly frequency when the difference is 7 days.")
    }

    func testShouldFirePixelWeeklyChangingYears() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2023, month: 12, day: 30))!
        let endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 6))!
        let result = DuckPlayerExperimentPixelsUtilities.shouldFirePixel(startDate: startDate, endDate: endDate, daysDifference: .weekly)
        XCTAssertTrue(result, "Pixel should fire for weekly frequency when the difference is 7 days across years.")
    }

    func testShouldNotFirePixelDaily() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 1))!
        let endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 1, hour: 12))!
        let result = DuckPlayerExperimentPixelsUtilities.shouldFirePixel(startDate: startDate, endDate: endDate, daysDifference: .daily)
        XCTAssertFalse(result, "Pixel should not fire for daily frequency when the difference is less than 1 day.")
    }

    func testShouldNotFirePixelWeeklySameMonth() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 2))!
        let endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 8))!
        let result = DuckPlayerExperimentPixelsUtilities.shouldFirePixel(startDate: startDate, endDate: endDate, daysDifference: .weekly)
        XCTAssertFalse(result, "Pixel should not fire for weekly frequency when the difference is 6 days.")
    }

    func testShouldNotFirePixelWeeklyChangingMonths() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 25))!
        let endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 1))!
        let result = DuckPlayerExperimentPixelsUtilities.shouldFirePixel(startDate: startDate, endDate: endDate, daysDifference: .weekly)
        XCTAssertFalse(result, "Pixel should not fire for weekly frequency when the difference is 6 days.")
    }

    func testShouldNotFirePixelWeeklyChangingYears() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2023, month: 12, day: 30))!
        let endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 5))!
        let result = DuckPlayerExperimentPixelsUtilities.shouldFirePixel(startDate: startDate, endDate: endDate, daysDifference: .weekly)
        XCTAssertFalse(result, "Pixel should not fire for weekly frequency when the difference is 6 days across years.")
    }

    func testShouldNotFirePixelWeekly() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 26))!
        let endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 2))!
        let result = DuckPlayerExperimentPixelsUtilities.shouldFirePixel(startDate: startDate, endDate: endDate, daysDifference: .weekly)
        XCTAssertFalse(result, "Pixel should not fire for weekly frequency when the difference is less than 7 days.")
    }

    func testNumberOfDaysFrom() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 22))!
        let endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 2))!
        let daysDifference = DuckPlayerExperimentPixelsUtilities.numberOfDaysFrom(startDate: startDate, endDate: endDate)
        XCTAssertEqual(daysDifference, 10, "The number of days between the two dates should be 10.")
    }

    func testNumberOfDaysFromChangingYears() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2023, month: 12, day: 31))!
        let endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let daysDifference = DuckPlayerExperimentPixelsUtilities.numberOfDaysFrom(startDate: startDate, endDate: endDate)
        XCTAssertEqual(daysDifference, 1, "The number of days between December 31, 2023, and January 1, 2024, should be 1.")
    }

    func testNumberOfDaysFromSameDay() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 2))!
        let endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 2))!
        let daysDifference = DuckPlayerExperimentPixelsUtilities.numberOfDaysFrom(startDate: startDate, endDate: endDate)
        XCTAssertEqual(daysDifference, 0, "The number of days between the same day should be 0.")
    }

    func testNumberOfDaysFromInvalidDates() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 3))!
        let endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 2))!
        let daysDifference = DuckPlayerExperimentPixelsUtilities.numberOfDaysFrom(startDate: startDate, endDate: endDate)
        XCTAssertEqual(daysDifference, -1, "The number of days should be negative when start date is after end date.")
    }
}
