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
    let eightDaysSinceToday = Calendar.current.date(byAdding: .day, value: -8, to: Date())!

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
                  scanJobData: .mockWith(historyEvents: [reAppereanceThisWeekEvent]))
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
                  scanJobData: .mockWith(historyEvents: [reAppereanceThisWeekEvent]))
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
                  scanJobData: .mockWith(historyEvents: [newMatchesPriorToThisWeekEvent]))
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
                  scanJobData: .mockWith(historyEvents: [newMatchesThisWeekEvent]))
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
                  scanJobData: .mockWith(historyEvents: [removalsPriorToThisWeekEvent]))
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
                  scanJobData: .mockWith(historyEvents: [removalThisWeekEventOne, removalThisWeekEventTwo]))
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
                  scanJobData: .mockWith(historyEvents: [eventOne, eventTwo, eventThree, eventFour]))
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
                  scanJobData: .mockWith(historyEvents: [eventOne])),
            .init(dataBroker: .mockWithURL("www.brokertwo.com"),
                  profileQuery: .mock,
                  scanJobData: .mockWith(historyEvents: [eventOne])),
            .init(dataBroker: .mockWithURL("www.brokerthree.com"),
                  profileQuery: .mock,
                  scanJobData: .mockWith(historyEvents: [eventOne])),
            .init(dataBroker: .mockWithURL("www.brokerfour.com"),
                  profileQuery: .mock,
                  scanJobData: .mockWith(historyEvents: [eventTwo]))
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
                  scanJobData: .mockWith(historyEvents: [eventOne])),
            .init(dataBroker: .mockWithURL("www.brokertwo.com"),
                  profileQuery: .mock,
                  scanJobData: .mockWith(historyEvents: [eventOne])),
            .init(dataBroker: .mockWithURL("www.brokerthree.com"),
                  profileQuery: .mock,
                  scanJobData: .mockWith(historyEvents: [eventTwo])),
            .init(dataBroker: .mockWithURL("www.brokerfour.com"),
                  profileQuery: .mock,
                  scanJobData: .mockWith(historyEvents: [eventTwo]))
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
                  scanJobData: .mockWith(historyEvents: [eventTwo])),
            .init(dataBroker: .mockWithURL("www.brokertwo.com"),
                  profileQuery: .mock,
                  scanJobData: .mockWith(historyEvents: [eventTwo])),
            .init(dataBroker: .mockWithURL("www.brokerthree.com"),
                  profileQuery: .mock,
                  scanJobData: .mockWith(historyEvents: [eventTwo])),
            .init(dataBroker: .mockWithURL("www.brokerfour.com"),
                  profileQuery: .mock,
                  scanJobData: .mockWith(historyEvents: [eventTwo]))
        ]
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)
        database.brokerProfileQueryDataToReturn = dataBrokerProfileQueries
        repository.customGetLatestWeeklyPixel = nil

        sut.tryToFireWeeklyPixels()

        let weeklyReportScanningPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!
        let scanCoverage = weeklyReportScanningPixel.params!["scan_coverage"]!

        XCTAssertEqual("75-100", scanCoverage)
    }

    func testWeeklyOptOuts_whenBrokerProfileQueriesHasMixedCreatedDates_thenFilteredCorrectly() {
        // Given
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)
        let extractedProfile = ExtractedProfile.mockWithoutRemovedDate

        let optOutShouldNotInclude1 = OptOutJobData.mock(with: Calendar.current.date(byAdding: .day, value: -14, to: Date.now)!)
        let optOutShouldNotInclude2 = OptOutJobData.mock(with: Calendar.current.date(byAdding: .day, value: -21, to: Date.now)!)
        let optOutShouldNotInclude3 = OptOutJobData.mock(with: Calendar.current.date(byAdding: .day, value: -8, to: Date.now)!)
        let optOutShouldNotInclude4 = OptOutJobData.mock(with: Calendar.current.date(byAdding: .day, value: -17, to: Date.now)!)
        let optOutShouldNotInclude5 = OptOutJobData.mock(with: Calendar.current.date(byAdding: .day, value: -10, to: Date.now)!)
        let optOutShouldInclude1 = OptOutJobData.mock(with: Calendar.current.date(byAdding: .day, value: -6, to: Date.now)!)
        let optOutShouldInclude2 = OptOutJobData.mock(with: Calendar.current.date(byAdding: .day, value: -3, to: Date.now)!)
        let optOutShouldInclude3 = OptOutJobData.mock(with: Calendar.current.date(byAdding: .day, value: -1, to: Date.now)!)
        let optOutShouldInclude4 = OptOutJobData.mock(with: Calendar.current.date(byAdding: .day, value: -5, to: Date.now)!)
        let optOutShouldInclude5 = OptOutJobData.mock(with: Calendar.current.date(byAdding: .day, value: -2, to: Date.now)!)
        let brokerProfileQueryData = [BrokerProfileQueryData.mock(extractedProfile: extractedProfile,
                                                                 optOutJobData: [optOutShouldNotInclude1,
                                                                                 optOutShouldNotInclude2,
                                                                                 optOutShouldInclude1,
                                                                                 optOutShouldInclude2]),
                                      BrokerProfileQueryData.mock(extractedProfile: extractedProfile,
                                                                  optOutJobData: []),
                                      BrokerProfileQueryData.mock(extractedProfile: extractedProfile,
                                                                  optOutJobData: [optOutShouldNotInclude3,
                                                                                  optOutShouldNotInclude4]),
                                      BrokerProfileQueryData.mock(extractedProfile: extractedProfile,
                                                                  optOutJobData: [optOutShouldInclude3]),
                                      BrokerProfileQueryData.mock(extractedProfile: extractedProfile,
                                                                  optOutJobData: [optOutShouldInclude4,
                                                                                  optOutShouldNotInclude5,
                                                                                  optOutShouldInclude5])]

        // When
        let weeklyOptOuts = sut.weeklyOptOuts(for: brokerProfileQueryData)

        // Then
        XCTAssertEqual(weeklyOptOuts.count, 5)
        XCTAssertTrue(weeklyOptOuts.contains { $0.createdDate == optOutShouldInclude1.createdDate })
        XCTAssertTrue(weeklyOptOuts.contains { $0.createdDate == optOutShouldInclude2.createdDate })
        XCTAssertTrue(weeklyOptOuts.contains { $0.createdDate == optOutShouldInclude3.createdDate })
        XCTAssertTrue(weeklyOptOuts.contains { $0.createdDate == optOutShouldInclude4.createdDate })
        XCTAssertTrue(weeklyOptOuts.contains { $0.createdDate == optOutShouldInclude5.createdDate })
    }

    let extractedProfile1 = ExtractedProfile.mockWithName("Steve Jones", age: "20", addresses: [AddressCityState(city: "New York", state: "NY")])
    let extractedProfile2 = ExtractedProfile.mockWithName("The Crock Jock", age: "24", addresses: [AddressCityState(city: "New York", state: "NY")])
    let extractedProfile3 = ExtractedProfile.mockWithName("Wolfy Wolfgang", age: "40", addresses: [AddressCityState(city: "New York", state: "NY")])
    let extractedProfile4 = ExtractedProfile.mockWithName("Pigeon Boy", age: "73", addresses: [AddressCityState(city: "Miami", state: "FL")])
    let extractedProfile5 = ExtractedProfile.mockWithName("Definitely Not 20 Birds in a Trenchcoat", age: "7", addresses: [AddressCityState(city: "New York", state: "NY")])

    let parentProfileMatching1 = ExtractedProfile.mockWithName("Steve Jones", age: "20", addresses: [AddressCityState(city: "New York", state: "NY")])
    let parentProfileMatching2 = ExtractedProfile.mockWithName("The Crock Jock", age: "24", addresses: [AddressCityState(city: "New York", state: "NY")])
    let parentProfileMatching3 = ExtractedProfile.mockWithName("Wolfy Wolfgang", age: "40", addresses: [AddressCityState(city: "New York", state: "NY")])
    let parentProfileMatching4 = ExtractedProfile.mockWithName("Pigeon Boy", age: "73", addresses: [AddressCityState(city: "Miami", state: "FL")])
    let parentProfileMatching5 = ExtractedProfile.mockWithName("Definitely Not 20 Birds in a Trenchcoat", age: "7", addresses: [AddressCityState(city: "New York", state: "NY")])

    let parentProfileNotMatching1 = ExtractedProfile.mockWithName("The Phantom Oinker", age: "12", addresses: [AddressCityState(city: "New York", state: "NY")])
    let parentProfileNotMatching2 = ExtractedProfile.mockWithName("Husky Sausage Dog", age: "4", addresses: [AddressCityState(city: "Miami", state: "FL")])
    let parentProfileNotMatching3 = ExtractedProfile.mockWithName("Actually definitely 20 Birds in a Trenchcoat", age: "7", addresses: [AddressCityState(city: "New York", state: "NY")])

    func testOrphanedProfilesCount_whenChildAndParentHaveSameProfiles_thenCountIsZero() {
        // Given
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)

        let optOuts = [OptOutJobData.mock(with: extractedProfile1),
                       OptOutJobData.mock(with: extractedProfile2),
                       OptOutJobData.mock(with: extractedProfile3),
                       OptOutJobData.mock(with: extractedProfile4),
                       OptOutJobData.mock(with: extractedProfile5)]
        let parentOptOuts = [OptOutJobData.mock(with: parentProfileMatching4),
                             OptOutJobData.mock(with: parentProfileMatching2),
                             OptOutJobData.mock(with: parentProfileMatching1),
                             OptOutJobData.mock(with: parentProfileMatching3),
                             OptOutJobData.mock(with: parentProfileMatching5)]

        // When
        let count = sut.orphanedProfilesCount(with: optOuts, parentOptOuts: parentOptOuts)

        // Then
        XCTAssertEqual(count, 0)
    }

    func testOrphanedProfilesCount_whenChildAndParentHaveDifferentProfiles_thenCountIsCorrect() {
        // Given
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)

        let optOuts = [OptOutJobData.mock(with: extractedProfile1),
                       OptOutJobData.mock(with: extractedProfile2),
                       OptOutJobData.mock(with: extractedProfile3),
                       OptOutJobData.mock(with: extractedProfile4),
                       OptOutJobData.mock(with: extractedProfile5)]
        let parentOptOuts = [OptOutJobData.mock(with: parentProfileNotMatching1),
                             OptOutJobData.mock(with: parentProfileMatching2),
                             OptOutJobData.mock(with: parentProfileMatching1),
                             OptOutJobData.mock(with: parentProfileNotMatching2),
                             OptOutJobData.mock(with: parentProfileNotMatching3)]

        // When
        let count = sut.orphanedProfilesCount(with: optOuts, parentOptOuts: parentOptOuts)

        // Then
        XCTAssertEqual(count, 3)
    }

    func testOrphanedProfilesCount_whenChildHasMoreProfiles_thenCountIsCorrect() {
        // Given
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)

        let optOuts = [OptOutJobData.mock(with: extractedProfile1),
                       OptOutJobData.mock(with: extractedProfile2),
                       OptOutJobData.mock(with: extractedProfile3),
                       OptOutJobData.mock(with: extractedProfile4),
                       OptOutJobData.mock(with: extractedProfile5)]
        let parentOptOuts = [OptOutJobData.mock(with: parentProfileMatching2),
                             OptOutJobData.mock(with: parentProfileMatching1)]

        // When
        let count = sut.orphanedProfilesCount(with: optOuts, parentOptOuts: parentOptOuts)

        // Then
        XCTAssertEqual(count, 3)
    }

    func testChildBrokerURLsToOrphanedProfilesCount_whenChildAndParentHaveDifferentProfiles_thenCountIsCorrect() {
        // Given
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)

        let childURL = "child.com"
        let parentURL = "parent.com"

        let brokerProfileQueryData = [BrokerProfileQueryData.mock(url: childURL,
                                                                  parentURL: parentURL,
                                                                  optOutJobData: [OptOutJobData.mock(with: extractedProfile1),
                                                                                  OptOutJobData.mock(with: extractedProfile2),
                                                                                  OptOutJobData.mock(with: extractedProfile3)]),
                                      BrokerProfileQueryData.mock(url: childURL,
                                                                  parentURL: parentURL,
                                                                  optOutJobData: [OptOutJobData.mock(with: extractedProfile4),
                                                                                  OptOutJobData.mock(with: extractedProfile5)]),
                                      BrokerProfileQueryData.mock(url: parentURL,
                                                                  optOutJobData: [OptOutJobData.mock(with: parentProfileMatching1),
                                                                                  OptOutJobData.mock(with: parentProfileNotMatching1)]),
                                      BrokerProfileQueryData.mock(url: parentURL,
                                                                  optOutJobData: [OptOutJobData.mock(with: parentProfileMatching2),
                                                                                  OptOutJobData.mock(with: parentProfileNotMatching2),
                                                                                  OptOutJobData.mock(with: parentProfileNotMatching3)])]

        // When
        let brokerURLsToCounts = sut.childBrokerURLsToOrphanedProfilesWeeklyCount(for: brokerProfileQueryData)

        // Then
        XCTAssertEqual(brokerURLsToCounts, ["child.com": 3])
    }

    /*
     fireWeeklyChildBrokerOrphanedOptOutsPixels
     Test cases:
     - Does fire for every child broker once (and _only_ child brokers)
     */

    let pixelName = DataBrokerProtectionPixels.weeklyChildBrokerOrphanedOptOuts(dataBrokerName: "",
                                                                                childParentRecordDifference: 0,
                                                                                calculatedOrphanedRecords: 0).name

    func testFireWeeklyChildBrokerOrphanedOptOutsPixels_whenChildAndParentHaveSameProfiles_thenDoesNotFire() {
        // Given
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)

        let childURL = "child.com"
        let parentURL = "parent.com"

        let brokerProfileQueryData = [BrokerProfileQueryData.mock(url: childURL,
                                                                  parentURL: parentURL,
                                                                  optOutJobData: [OptOutJobData.mock(with: extractedProfile1),
                                                                                  OptOutJobData.mock(with: extractedProfile2),
                                                                                  OptOutJobData.mock(with: extractedProfile3)]),
                                      BrokerProfileQueryData.mock(url: childURL,
                                                                  parentURL: parentURL,
                                                                  optOutJobData: [OptOutJobData.mock(with: extractedProfile4),
                                                                                  OptOutJobData.mock(with: extractedProfile5)]),
                                      BrokerProfileQueryData.mock(url: parentURL,
                                                                  optOutJobData: [OptOutJobData.mock(with: parentProfileMatching1),
                                                                                  OptOutJobData.mock(with: parentProfileMatching4)]),
                                      BrokerProfileQueryData.mock(url: parentURL,
                                                                  optOutJobData: [OptOutJobData.mock(with: parentProfileMatching2),
                                                                                  OptOutJobData.mock(with: parentProfileMatching3),
                                                                                  OptOutJobData.mock(with: parentProfileMatching5)])]

        database.brokerProfileQueryDataToReturn = brokerProfileQueryData
        repository.customGetLatestWeeklyPixel = nil

        // When
        sut.tryToFireWeeklyPixels()

        // Then
        let pixels = MockDataBrokerProtectionPixelsHandler.lastPixelsFired
        XCTAssertFalse(pixels.contains { $0.name == pixelName })
    }

    func testFireWeeklyChildBrokerOrphanedOptOutsPixels_whenChildAndParentHaveDifferentProfiles_thenFiresCorrectly() {
        // Given
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)

        let childName = "child"
        let childURL = "child.com"
        let parentURL = "parent.com"

        let brokerProfileQueryData = [BrokerProfileQueryData.mock(dataBrokerName: childName,
                                                                  url: childURL,
                                                                  parentURL: parentURL,
                                                                  optOutJobData: [OptOutJobData.mock(with: extractedProfile1),
                                                                                  OptOutJobData.mock(with: extractedProfile2),
                                                                                  OptOutJobData.mock(with: extractedProfile3)]),
                                      BrokerProfileQueryData.mock(dataBrokerName: childName,
                                                                  url: childURL,
                                                                  parentURL: parentURL,
                                                                  optOutJobData: [OptOutJobData.mock(with: extractedProfile4),
                                                                                  OptOutJobData.mock(with: extractedProfile5)]),
                                      BrokerProfileQueryData.mock(url: parentURL,
                                                                  optOutJobData: [OptOutJobData.mock(with: parentProfileMatching1),
                                                                                  OptOutJobData.mock(with: parentProfileNotMatching1)]),
                                      BrokerProfileQueryData.mock(url: parentURL,
                                                                  optOutJobData: [OptOutJobData.mock(with: parentProfileMatching2),
                                                                                  OptOutJobData.mock(with: parentProfileNotMatching2),
                                                                                  OptOutJobData.mock(with: parentProfileNotMatching3)])]

        database.brokerProfileQueryDataToReturn = brokerProfileQueryData
        repository.customGetLatestWeeklyPixel = nil

        // When
        sut.tryToFireWeeklyPixels()

        // Then
        let pixels = MockDataBrokerProtectionPixelsHandler.lastPixelsFired
        let firedPixel = pixels.first { $0.name == pixelName }!
        let parameters = firedPixel.params
        XCTAssertEqual(parameters, [DataBrokerProtectionPixels.Consts.dataBrokerParamKey: childName,
                                    DataBrokerProtectionPixels.Consts.calculatedOrphanedRecords: "3",
                                    DataBrokerProtectionPixels.Consts.childParentRecordDifference: "0"])
    }

    func testFireWeeklyChildBrokerOrphanedOptOutsPixels_whenThereAreMultipleChildBrokers_thenFiresOnceForEach() {
        // Given
        let sut = DataBrokerProtectionEventPixels(database: database, repository: repository, handler: handler)

        let childName1 = "child1"
        let childURL1 = "child1.com"
        let parentURL1 = "parent1.com"

        let childName2 = "child2"
        let childURL2 = "child2.com"

        let childName3 = "child3"
        let childURL3 = "child3.com"
        let parentURL3 = "parent3.com"

        let brokerProfileQueryData = [BrokerProfileQueryData.mock(dataBrokerName: childName1,
                                                                  url: childURL1,
                                                                  parentURL: parentURL1,
                                                                  optOutJobData: [OptOutJobData.mock(with: extractedProfile1),
                                                                                  OptOutJobData.mock(with: extractedProfile2)]),
                                      BrokerProfileQueryData.mock(url: parentURL1,
                                                                  optOutJobData: [OptOutJobData.mock(with: parentProfileMatching1)]),
                                      BrokerProfileQueryData.mock(dataBrokerName: childName2,
                                                                  url: childURL2,
                                                                  parentURL: parentURL1,
                                                                  optOutJobData: [OptOutJobData.mock(with: extractedProfile5),
                                                                                  OptOutJobData.mock(with: extractedProfile3)]),
                                      BrokerProfileQueryData.mock(dataBrokerName: childName3,
                                                                  url: childURL3,
                                                                  parentURL: parentURL3,
                                                                  optOutJobData: [OptOutJobData.mock(with: extractedProfile4)]),
                                      BrokerProfileQueryData.mock(url: parentURL3,
                                                                  optOutJobData: [OptOutJobData.mock(with: parentProfileNotMatching3),
                                                                                  OptOutJobData.mock(with: parentProfileMatching5)])]

        database.brokerProfileQueryDataToReturn = brokerProfileQueryData
        repository.customGetLatestWeeklyPixel = nil

        // When
        sut.tryToFireWeeklyPixels()

        // Then
        let pixels = MockDataBrokerProtectionPixelsHandler.lastPixelsFired
        let firedPixels = pixels.filter { $0.name == pixelName }

        XCTAssertEqual(firedPixels.count, 3)

        let child1Pixel = firedPixels.filter { $0.params![DataBrokerProtectionPixels.Consts.dataBrokerParamKey] == childName1 }.first!
        XCTAssertEqual(child1Pixel.params, [DataBrokerProtectionPixels.Consts.dataBrokerParamKey: childName1,
                                            DataBrokerProtectionPixels.Consts.calculatedOrphanedRecords: "1",
                                            DataBrokerProtectionPixels.Consts.childParentRecordDifference: "1"])

        let child2Pixel = firedPixels.filter { $0.params![DataBrokerProtectionPixels.Consts.dataBrokerParamKey] == childName2 }.first!
        XCTAssertEqual(child2Pixel.params, [DataBrokerProtectionPixels.Consts.dataBrokerParamKey: childName2,
                                            DataBrokerProtectionPixels.Consts.calculatedOrphanedRecords: "2",
                                            DataBrokerProtectionPixels.Consts.childParentRecordDifference: "1"])

        let child3Pixel = firedPixels.filter { $0.params![DataBrokerProtectionPixels.Consts.dataBrokerParamKey] == childName3 }.first!
        XCTAssertEqual(child3Pixel.params, [DataBrokerProtectionPixels.Consts.dataBrokerParamKey: childName3,
                                            DataBrokerProtectionPixels.Consts.calculatedOrphanedRecords: "1",
                                            DataBrokerProtectionPixels.Consts.childParentRecordDifference: "-1"])
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
