//
//  DataBrokerProtectionEngagementPixelsTests.swift
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

final class DataBrokerProtectionEngagementPixelsTests: XCTestCase {

    private let database = MockDatabase()
    private let repository = MockDataBrokerProtectionEngagementPixelsRepository()
    private let handler = MockDataBrokerProtectionPixelsHandler()

    private var fakeProfile: DataBrokerProtectionProfile {
        let name = DataBrokerProtectionProfile.Name(firstName: "John", lastName: "Doe")
        let address = DataBrokerProtectionProfile.Address(city: "City", state: "State")

        return DataBrokerProtectionProfile(names: [name], addresses: [address], phones: [String](), birthYear: 1900)
    }

    override func tearDown() {
        database.clear()
        repository.clear()
        handler.clear()
    }

    func testWhenThereIsNoProfile_thenNoEngagementPixelIsFired() {
        database.setFetchedProfile(nil)
        let sut = DataBrokerProtectionEngagementPixels(database: database, handler: handler, repository: repository)

        sut.fireEngagementPixel(currentDate: Date())

        // We test we have no interactions with the repository
        XCTAssertFalse(repository.wasDailyPixelSent)
        XCTAssertFalse(repository.wasWeeklyPixelSent)
        XCTAssertFalse(repository.wasMonthlyPixelSent)
        XCTAssertFalse(repository.wasGetLatestDailyPixelCalled)
        XCTAssertFalse(repository.wasWeeklyPixelSent)
        XCTAssertFalse(repository.wasMonthlyPixelSent)

        // The pixel should not be fired
        XCTAssertTrue(MockDataBrokerProtectionPixelsHandler.lastPixelsFired.isEmpty)
    }

    func testWhenLatestDailyPixelIsNil_thenWeFireDailyPixel() {
        database.setFetchedProfile(fakeProfile)
        repository.setLatestDailyPixel = nil
        let sut = DataBrokerProtectionEngagementPixels(database: database, handler: handler, repository: repository)

        sut.fireEngagementPixel(currentDate: Date())

        XCTAssertTrue(wasPixelFired(.dailyActiveUser))
        XCTAssertTrue(repository.wasDailyPixelSent)
    }

    func testWhenCurrentDayIsDifferentToLatestDailyPixel_thenWeFireDailyPixel() {
        database.setFetchedProfile(fakeProfile)
        repository.setLatestWeeklyPixel = dateFromString("2024-02-20")
        let sut = DataBrokerProtectionEngagementPixels(database: database, handler: handler, repository: repository)

        sut.fireEngagementPixel(currentDate: dateFromString("2024-02-21"))

        XCTAssertTrue(wasPixelFired(.dailyActiveUser))
        XCTAssertTrue(repository.wasDailyPixelSent)
    }

    func testWhenCurrentDayIsEqualToLatestDailyPixel_thenWeDoNotFireDailyPixel() {
        database.setFetchedProfile(fakeProfile)
        repository.setLatestDailyPixel = Date()
        let sut = DataBrokerProtectionEngagementPixels(database: database, handler: handler, repository: repository)

        sut.fireEngagementPixel(currentDate: Date())

        XCTAssertFalse(wasPixelFired(.dailyActiveUser))
        XCTAssertFalse(repository.wasDailyPixelSent)
    }

    func testWhenLatestWeeklyPixelIsNil_thenWeFireWeeklyPixel() {
        database.setFetchedProfile(fakeProfile)
        repository.setLatestWeeklyPixel = nil
        let sut = DataBrokerProtectionEngagementPixels(database: database, handler: handler, repository: repository)

        sut.fireEngagementPixel(currentDate: Date())

        XCTAssertTrue(wasPixelFired(.weeklyActiveUser))
        XCTAssertTrue(repository.wasWeeklyPixelSent)
    }

    func testWhenCurrentDayIsSevenDatesEqualOrGreaterThanLatestWeekly_thenWeFireWeeklyPixel() {
        database.setFetchedProfile(fakeProfile)
        repository.setLatestWeeklyPixel = dateFromString("2024-02-20")
        let sut = DataBrokerProtectionEngagementPixels(database: database, handler: handler, repository: repository)

        sut.fireEngagementPixel(currentDate: dateFromString("2024-02-27"))

        XCTAssertTrue(wasPixelFired(.weeklyActiveUser))
        XCTAssertTrue(repository.wasWeeklyPixelSent)
    }

    func testWhenCurrentDayIsSevenDatesLessThanLatestWeekly_thenWeDoNotFireWeeklyPixel() {
        database.setFetchedProfile(fakeProfile)
        repository.setLatestWeeklyPixel = dateFromString("2024-02-20")
        let sut = DataBrokerProtectionEngagementPixels(database: database, handler: handler, repository: repository)

        sut.fireEngagementPixel(currentDate: dateFromString("2024-02-26"))

        XCTAssertFalse(wasPixelFired(.weeklyActiveUser))
        XCTAssertFalse(repository.wasWeeklyPixelSent)
    }

    func testWhenLatestMonthlyPixelIsNil_thenWeFireMonthlyPixel() {
        database.setFetchedProfile(fakeProfile)
        repository.setLatestMonthlyPixel = nil
        let sut = DataBrokerProtectionEngagementPixels(database: database, handler: handler, repository: repository)

        sut.fireEngagementPixel(currentDate: Date())

        XCTAssertTrue(wasPixelFired(.monthlyActiveUser))
        XCTAssertTrue(repository.wasMonthlyPixelSent)
    }

    func testWhenCurrentMonthIs28DatesGreaterOrEqualThanLatestMonthlyPixel_thenWeFireMonthlyPixel() {
        database.setFetchedProfile(fakeProfile)
        repository.setLatestMonthlyPixel = dateFromString("2024-02-20")
        let sut = DataBrokerProtectionEngagementPixels(database: database, handler: handler, repository: repository)

        sut.fireEngagementPixel(currentDate: dateFromString("2024-03-19"))

        XCTAssertTrue(wasPixelFired(.monthlyActiveUser))
        XCTAssertTrue(repository.wasMonthlyPixelSent)
    }

    func testWhenCurrentIsNot28DatesGreaterOrEqualToLatestMonthlyPixel_thenWeDoNotFireMonthlyPixel() {
        database.setFetchedProfile(fakeProfile)
        repository.setLatestMonthlyPixel = dateFromString("2024-02-20")
        let sut = DataBrokerProtectionEngagementPixels(database: database, handler: handler, repository: repository)

        sut.fireEngagementPixel(currentDate: dateFromString("2024-03-18"))

        XCTAssertFalse(wasPixelFired(.monthlyActiveUser))
        XCTAssertFalse(repository.wasMonthlyPixelSent)
    }

    private func wasPixelFired(_ pixel: DataBrokerProtectionPixels) -> Bool {
        MockDataBrokerProtectionPixelsHandler.lastPixelsFired.contains(where: { $0.name == pixel.name })
    }

    private func dateFromString(_ string: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return dateFormatter.date(from: string)!
    }
}

final class MockDataBrokerProtectionEngagementPixelsRepository: DataBrokerProtectionEngagementPixelsRepository {
    var wasDailyPixelSent = false
    var wasWeeklyPixelSent = false
    var wasMonthlyPixelSent = false
    var wasGetLatestDailyPixelCalled = false
    var wasGetLatestWeeklyPixelCalled = false
    var wasGetLatestMonthlyPixelCalled = false
    var setLatestDailyPixel: Date?
    var setLatestWeeklyPixel: Date?
    var setLatestMonthlyPixel: Date?

    func markDailyPixelSent() {
        wasDailyPixelSent = true
    }

    func markWeeklyPixelSent() {
        wasWeeklyPixelSent = true
    }

    func markMonthlyPixelSent() {
        wasMonthlyPixelSent = true
    }

    func getLatestDailyPixel() -> Date? {
        wasGetLatestDailyPixelCalled = true
        return setLatestDailyPixel
    }

    func getLatestWeeklyPixel() -> Date? {
        wasGetLatestWeeklyPixelCalled = true
        return setLatestWeeklyPixel
    }

    func getLatestMonthlyPixel() -> Date? {
        wasGetLatestMonthlyPixelCalled = true
        return setLatestMonthlyPixel
    }

    func clear() {
        wasDailyPixelSent = false
        wasWeeklyPixelSent = false
        wasMonthlyPixelSent = false
        wasGetLatestDailyPixelCalled = false
        wasGetLatestWeeklyPixelCalled = false
        wasGetLatestMonthlyPixelCalled = false
        setLatestDailyPixel = nil
        setLatestWeeklyPixel = nil
        setLatestMonthlyPixel = nil
    }
}
