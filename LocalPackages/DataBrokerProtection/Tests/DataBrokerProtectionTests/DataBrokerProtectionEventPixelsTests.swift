//
//  DataBrokerProtectionEventPixelsTests.swift
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

final class DataBrokerProtectionEventPixelsTests: XCTestCase {

    let database = MockDatabase()
    let repository = MockDataBrokerProtectionEventPixelsRepository()
    let handler = MockDataBrokerProtectionPixelsHandler()
    let calendar = Calendar.current

    override func tearDown() {
        handler.clear()
        repository.clear()
    }

    func testWhenFireNewMatchEventPixelIsCalled_thenCorrectPixelIsFired() {
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)

        sut.fireNewMatchEventPixel()

        XCTAssertEqual(
            MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last!.name,
            DataBrokerProtectionPixels.scanningEventNewMatch.name
        )
    }

    func testWhenFireReAppereanceEventPixelIsCalled_thenCorrectPixelIsFired() {
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)

        sut.fireReAppereanceEventPixel()

        XCTAssertEqual(
            MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last!.name,
            DataBrokerProtectionPixels.scanningEventReAppearance.name
        )
    }

    func testWhenReportWasFiredInTheLastWeek_thenWeDoNotFireWeeklyPixels() {
        repository.customGetLatestWeeklyPixel = Date().yesterday
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)

        sut.tryToFireWeeklyPixels()

        XCTAssertFalse(repository.wasMarkWeeklyPixelSentCalled)
    }

    func testWhenReportWasNotFiredInTheLastWeek_thenWeFireWeeklyPixels() {
        guard let eightDaysSinceToday = Calendar.current.date(byAdding: .day, value: -8, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        repository.customGetLatestWeeklyPixel = eightDaysSinceToday
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)

        sut.tryToFireWeeklyPixels()

        XCTAssertTrue(repository.wasMarkWeeklyPixelSentCalled)
    }

    func testWhenLastWeeklyPixelIsNil_thenWeFireWeeklyPixels() {
        repository.customGetLatestWeeklyPixel = nil
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)

        sut.tryToFireWeeklyPixels()

        XCTAssertTrue(repository.wasMarkWeeklyPixelSentCalled)
    }

    func testWhenReAppereanceOcurredInTheLastWeek_thenReAppereanceFlagIsTrue() {
        guard let sixDaysSinceToday = Calendar.current.date(byAdding: .day, value: -6, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        let reAppereanceThisWeekEvent = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .reAppearence, date: sixDaysSinceToday)
        let dataBrokerProfileQueryWithReAppereance: [BrokerProfileQueryData] = [
            .init(dataBroker: .mock,
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [reAppereanceThisWeekEvent]))
        ]
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)
        database.brokerProfileQueryDataToReturn = dataBrokerProfileQueryWithReAppereance
        repository.customGetLatestWeeklyPixel = nil

        sut.tryToFireWeeklyPixels()

        let weeklyReportScanningPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!
        let hadReAppereance = weeklyReportScanningPixel.params!["had_re-appearance"]!

        XCTAssertEqual(hadReAppereance, "1")
    }

    func testWhenReAppereanceDidNotOcurrInTheLastWeek_thenReAppereanceFlagIsFalse() {
        guard let eighDaysSinceToday = Calendar.current.date(byAdding: .day, value: -8, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        let reAppereanceThisWeekEvent = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .reAppearence, date: eighDaysSinceToday)
        let dataBrokerProfileQueryWithReAppereance: [BrokerProfileQueryData] = [
            .init(dataBroker: .mock,
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [reAppereanceThisWeekEvent]))
        ]
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)
        database.brokerProfileQueryDataToReturn = dataBrokerProfileQueryWithReAppereance
        repository.customGetLatestWeeklyPixel = nil

        sut.tryToFireWeeklyPixels()

        let weeklyReportScanningPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!
        let hadReAppereance = weeklyReportScanningPixel.params!["had_re-appearance"]!

        XCTAssertEqual(hadReAppereance, "0")
    }

    func testWhenNoMatchesHappendInTheLastWeek_thenHadNewMatchFlagIsFalse() {
        guard let eighDaysSinceToday = Calendar.current.date(byAdding: .day, value: -8, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        let newMatchesPriorToThisWeekEvent = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 2), date: eighDaysSinceToday)
        let dataBrokerProfileQueryWithMatches: [BrokerProfileQueryData] = [
            .init(dataBroker: .mock,
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [newMatchesPriorToThisWeekEvent]))
        ]
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)
        database.brokerProfileQueryDataToReturn = dataBrokerProfileQueryWithMatches
        repository.customGetLatestWeeklyPixel = nil

        sut.tryToFireWeeklyPixels()

        let weeklyReportScanningPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!
        let hadNewMatch = weeklyReportScanningPixel.params!["had_new_match"]!

        XCTAssertEqual(hadNewMatch, "0")
    }

    func testWhenMatchesHappendInTheLastWeek_thenHadNewMatchFlagIsTrue() {
        guard let sixDaysSinceToday = Calendar.current.date(byAdding: .day, value: -6, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        let newMatchesThisWeekEvent = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 2), date: sixDaysSinceToday)
        let dataBrokerProfileQueryWithMatches: [BrokerProfileQueryData] = [
            .init(dataBroker: .mock,
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [newMatchesThisWeekEvent]))
        ]
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)
        database.brokerProfileQueryDataToReturn = dataBrokerProfileQueryWithMatches
        repository.customGetLatestWeeklyPixel = nil

        sut.tryToFireWeeklyPixels()

        let weeklyReportScanningPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!
        let hadNewMatch = weeklyReportScanningPixel.params!["had_new_match"]!

        XCTAssertEqual(hadNewMatch, "1")
    }

    func testWhenNoRemovalsHappendInTheLastWeek_thenRemovalsCountIsZero() {
        guard let eighDaysSinceToday = Calendar.current.date(byAdding: .day, value: -8, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        let removalsPriorToThisWeekEvent = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .optOutConfirmed, date: eighDaysSinceToday)
        let dataBrokerProfileQueryWithRemovals: [BrokerProfileQueryData] = [
            .init(dataBroker: .mock,
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [removalsPriorToThisWeekEvent]))
        ]
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)
        database.brokerProfileQueryDataToReturn = dataBrokerProfileQueryWithRemovals
        repository.customGetLatestWeeklyPixel = nil

        sut.tryToFireWeeklyPixels()

        let weeklyReportScanningPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last!
        let removals = weeklyReportScanningPixel.params!["removals"]!

        XCTAssertEqual("0", removals)
    }

    func testWhenRemovalsHappendInTheLastWeek_thenRemovalsCountIsCorrect() {
        guard let sixDaysSinceToday = Calendar.current.date(byAdding: .day, value: -6, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        let removalThisWeekEventOne = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .optOutConfirmed, date: sixDaysSinceToday)
        let removalThisWeekEventTwo = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .optOutConfirmed, date: sixDaysSinceToday)
        let dataBrokerProfileQueryWithRemovals: [BrokerProfileQueryData] = [
            .init(dataBroker: .mock,
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [removalThisWeekEventOne, removalThisWeekEventTwo]))
        ]
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)
        database.brokerProfileQueryDataToReturn = dataBrokerProfileQueryWithRemovals
        repository.customGetLatestWeeklyPixel = nil

        sut.tryToFireWeeklyPixels()

        let weeklyReportScanningPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last!
        let removals = weeklyReportScanningPixel.params!["removals"]!

        XCTAssertEqual("2", removals)
    }

    func testWhenNoHistoryEventsHappenedInTheLastWeek_thenBrokersScannedIsZero25Range() {
        guard let eighDaysSinceToday = Calendar.current.date(byAdding: .day, value: -8, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        let eventOne = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .optOutStarted, date: eighDaysSinceToday)
        let eventTwo = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .error(error: .cancelled), date: eighDaysSinceToday)
        let eventThree = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: eighDaysSinceToday)
        let eventFour = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .noMatchFound, date: eighDaysSinceToday)
        let dataBrokerProfileQueries: [BrokerProfileQueryData] = [
            .init(dataBroker: .mock,
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [eventOne, eventTwo, eventThree, eventFour]))
        ]
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)
        database.brokerProfileQueryDataToReturn = dataBrokerProfileQueries
        repository.customGetLatestWeeklyPixel = nil

        sut.tryToFireWeeklyPixels()

        let weeklyReportScanningPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!
        let scanCoverage = weeklyReportScanningPixel.params!["scan_coverage"]!

        XCTAssertEqual("0-25", scanCoverage)
    }

    func testWhenHistoryEventsHappenedInTheLastWeek_thenBrokersScannedIs2550Range() {
        guard let eighDaysSinceToday = Calendar.current.date(byAdding: .day, value: -8, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        guard let sixDaysSinceToday = Calendar.current.date(byAdding: .day, value: -6, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        let eventOne = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: eighDaysSinceToday)
        let eventTwo = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: sixDaysSinceToday)
        let dataBrokerProfileQueries: [BrokerProfileQueryData] = [
            .init(dataBroker: .mockWithURL("www.brokerone.com"),
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [eventOne])),
            .init(dataBroker: .mockWithURL("www.brokertwo.com"),
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [eventOne])),
            .init(dataBroker: .mockWithURL("www.brokerthree.com"),
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [eventOne])),
            .init(dataBroker: .mockWithURL("www.brokerfour.com"),
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [eventTwo]))
        ]
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)
        database.brokerProfileQueryDataToReturn = dataBrokerProfileQueries
        repository.customGetLatestWeeklyPixel = nil

        sut.tryToFireWeeklyPixels()

        let weeklyReportScanningPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!
        let scanCoverage = weeklyReportScanningPixel.params!["scan_coverage"]!

        XCTAssertEqual("25-50", scanCoverage)
    }

    func testWhenHistoryEventsHappenedInTheLastWeek_thenBrokersScannedIs5075Range() {
        guard let eighDaysSinceToday = Calendar.current.date(byAdding: .day, value: -8, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        guard let sixDaysSinceToday = Calendar.current.date(byAdding: .day, value: -6, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        let eventOne = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: eighDaysSinceToday)
        let eventTwo = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: sixDaysSinceToday)
        let dataBrokerProfileQueries: [BrokerProfileQueryData] = [
            .init(dataBroker: .mockWithURL("www.brokerone.com"),
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [eventOne])),
            .init(dataBroker: .mockWithURL("www.brokertwo.com"),
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [eventOne])),
            .init(dataBroker: .mockWithURL("www.brokerthree.com"),
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [eventTwo])),
            .init(dataBroker: .mockWithURL("www.brokerfour.com"),
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [eventTwo]))
        ]
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)
        database.brokerProfileQueryDataToReturn = dataBrokerProfileQueries
        repository.customGetLatestWeeklyPixel = nil

        sut.tryToFireWeeklyPixels()

        let weeklyReportScanningPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!
        let scanCoverage = weeklyReportScanningPixel.params!["scan_coverage"]!

        XCTAssertEqual("50-75", scanCoverage)
    }

    func testWhenHistoryEventsHappenedInTheLastWeek_thenBrokersScannedIs75100Range() {
        guard let eighDaysSinceToday = Calendar.current.date(byAdding: .day, value: -8, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        guard let sixDaysSinceToday = Calendar.current.date(byAdding: .day, value: -6, to: Date()) else {
            XCTFail("This should no throw")
            return
        }

        /*let eventOne*/ _ = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: eighDaysSinceToday)
        let eventTwo = HistoryEvent(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: sixDaysSinceToday)
        let dataBrokerProfileQueries: [BrokerProfileQueryData] = [
            .init(dataBroker: .mockWithURL("www.brokerone.com"),
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [eventTwo])),
            .init(dataBroker: .mockWithURL("www.brokertwo.com"),
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [eventTwo])),
            .init(dataBroker: .mockWithURL("www.brokerthree.com"),
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [eventTwo])),
            .init(dataBroker: .mockWithURL("www.brokerfour.com"),
                  profileQuery: .mock,
                  scanOperationData: .mockWith(historyEvents: [eventTwo]))
        ]
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)
        database.brokerProfileQueryDataToReturn = dataBrokerProfileQueries
        repository.customGetLatestWeeklyPixel = nil

        sut.tryToFireWeeklyPixels()

        let weeklyReportScanningPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!
        let scanCoverage = weeklyReportScanningPixel.params!["scan_coverage"]!

        XCTAssertEqual("75-100", scanCoverage)
    }
}

final class MockDataBrokerProtectionEventPixelsRepository: DataBrokerProtectionEventPixelsRepository {

    var wasMarkWeeklyPixelSentCalled = false
    var customGetLatestWeeklyPixel: Date?

    func markWeeklyPixelSent() {
        wasMarkWeeklyPixelSentCalled = true
    }

    func getLatestWeeklyPixel() -> Date? {
        return customGetLatestWeeklyPixel
    }

    func clear() {
        wasMarkWeeklyPixelSentCalled = false
        customGetLatestWeeklyPixel = nil
    }
}
