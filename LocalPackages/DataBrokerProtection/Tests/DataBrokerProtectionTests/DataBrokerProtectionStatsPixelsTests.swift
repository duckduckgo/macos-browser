//
//  DataBrokerProtectionStatsPixelsTests.swift
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
@testable import PixelKit

final class DataBrokerProtectionStatsPixelsTests: XCTestCase {

    private let handler = MockDataBrokerProtectionPixelsHandler()

    override func tearDown() {
        handler.clear()
    }

    func testNumberOfNewMatchesIsCalculatedCorrectly() {
        let historyEvents: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 2)),
            .init(brokerId: 1, profileQueryId: 1, type: .noMatchFound),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 1)),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 2)),
        ]
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: .mock,
            profileQuery: .mock,
            scanJobData: .mockWith(historyEvents: historyEvents),
            optOutJobData: [.mock(with: .mockWithoutRemovedDate)])
        let sut = DataBrokerProtectionStatsPixels(database: MockDatabase(),
                                                  handler: handler,
                                                  repository: MockDataBrokerProtectionStatsPixelsRepository())

        let result = sut.calculateNumberOfNewMatchesFound([brokerProfileQueryData])

        XCTAssertEqual(result, 2)
    }

    func testNumberOfNewMatchesIsCalculatedCorrectlyWithMirrorSites() {
        let mirrorSites: [MirrorSite] = [
            .init(name: "Mirror #1", url: "url.com", addedAt: Date()),
            .init(name: "Mirror #2", url: "url.com", addedAt: Date())
        ]
        let historyEvents: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 2)),
            .init(brokerId: 1, profileQueryId: 1, type: .noMatchFound),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 1)),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 2)),
        ]
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: .mockWith(mirroSites: mirrorSites),
            profileQuery: .mock,
            scanJobData: .mockWith(historyEvents: historyEvents),
            optOutJobData: [.mock(with: .mockWithoutRemovedDate)])
        let sut = DataBrokerProtectionStatsPixels(database: MockDatabase(),
                                                  handler: handler,
                                                  repository: MockDataBrokerProtectionStatsPixelsRepository())

        let result = sut.calculateNumberOfNewMatchesFound([brokerProfileQueryData])

        XCTAssertEqual(result, 4)
    }

    func testWhenDurationOfFirstOptOutIsLessThan24Hours_thenWeReturn1() {
        let historyEventsForScan: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: Date()),
        ]
        let historyEventsForOptOut: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .optOutRequested, date: Date()),
        ]
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: .mock,
            profileQuery: .mock,
            scanJobData: .mockWith(historyEvents: historyEventsForScan),
            optOutJobData: [.mock(with: .mockWithoutRemovedDate, historyEvents: historyEventsForOptOut)])
        let sut = DataBrokerProtectionStatsPixels(database: MockDatabase(),
                                                  handler: handler,
                                                  repository: MockDataBrokerProtectionStatsPixelsRepository())

        let result = sut.calculateDurationOfFirstOptOut([brokerProfileQueryData])

        XCTAssertEqual(result, 1)
    }

    func testWhenDateOfOptOutIsBeforeFirstScan_thenWeReturnZero() {
        let historyEventsForScan: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: Date()),
        ]
        let historyEventsForOptOut: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .optOutRequested, date: Date().yesterday!),
        ]
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: .mock,
            profileQuery: .mock,
            scanJobData: .mockWith(historyEvents: historyEventsForScan),
            optOutJobData: [.mock(with: .mockWithoutRemovedDate, historyEvents: historyEventsForOptOut)])
        let sut = DataBrokerProtectionStatsPixels(database: MockDatabase(),
                                                  handler: handler,
                                                  repository: MockDataBrokerProtectionStatsPixelsRepository())

        let result = sut.calculateDurationOfFirstOptOut([brokerProfileQueryData])

        XCTAssertEqual(result, 0)
    }

    func testWhenOptOutWasSubmitted_thenWeReturnCorrectNumberInDays() {
        var dateComponents = DateComponents()
        dateComponents.day = 3
        dateComponents.hour = 2
        let threeDaysAfterToday = Calendar.current.date(byAdding: dateComponents, to: Date())!
        let historyEventsForScan: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: Date()),
        ]
        let historyEventsForOptOut: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .optOutRequested, date: threeDaysAfterToday),
        ]
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: .mock,
            profileQuery: .mock,
            scanJobData: .mockWith(historyEvents: historyEventsForScan),
            optOutJobData: [.mock(with: .mockWithoutRemovedDate, historyEvents: historyEventsForOptOut)])
        let sut = DataBrokerProtectionStatsPixels(database: MockDatabase(),
                                                  handler: handler,
                                                  repository: MockDataBrokerProtectionStatsPixelsRepository())

        let result = sut.calculateDurationOfFirstOptOut([brokerProfileQueryData])

        XCTAssertEqual(result, 3)
    }

    /// This test data has the following parameters
    ///  - A broker that has two mirror sites but one was removed
    ///  - Four matches found
    ///  - One match was removed
    ///  - Two matches are in progress of being removed (this means we submitted the opt-out)
    ///  - One match failed to submit an opt-out
    ///  - One re-appereance of an old match after it was removed
    func testStatsByBroker_hasCorrectParams() {
        let mirrorSites: [MirrorSite] = [
            .init(name: "Mirror #1", url: "url.com", addedAt: Date()),
            .init(name: "Mirror #2", url: "url.com", addedAt: Date(), removedAt: Date().yesterday)
        ]
        let broker: DataBroker = .mockWith(mirroSites: mirrorSites)
        let historyEventsForFirstOptOutOperation: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .optOutStarted),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .unknown("Error"))),
            .init(brokerId: 1, profileQueryId: 1, type: .optOutStarted),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .unknown("Error")))
        ]
        let historyEventForOptOutWithSubmittedRequest: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .optOutStarted),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .unknown("Error"))),
            .init(brokerId: 1, profileQueryId: 1, type: .optOutStarted),
            .init(brokerId: 1, profileQueryId: 1, type: .optOutRequested)
        ]
        let historyEventsForScanOperation: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .scanStarted),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 3)),
            .init(brokerId: 1, profileQueryId: 1, type: .scanStarted),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 2)),
            .init(brokerId: 1, profileQueryId: 1, type: .scanStarted),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 3)),
            .init(brokerId: 1, profileQueryId: 1, type: .reAppearence)
        ]
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: broker,
            profileQuery: .mock,
            scanJobData: .mockWith(historyEvents: historyEventsForScanOperation),
            optOutJobData: [
                .mock(with: .mockWithoutRemovedDate, historyEvents: historyEventsForFirstOptOutOperation),
                .mock(with: .mockWithoutRemovedDate, historyEvents: historyEventForOptOutWithSubmittedRequest),
                .mock(with: .mockWithoutRemovedDate, historyEvents: historyEventForOptOutWithSubmittedRequest),
                .mock(with: .mockWithRemovedDate, historyEvents: historyEventForOptOutWithSubmittedRequest),
            ])
        let sut = DataBrokerProtectionStatsPixels(database: MockDatabase(),
                                                  handler: handler,
                                                  repository: MockDataBrokerProtectionStatsPixelsRepository())

        let result = sut.calculateByBroker(broker, data: [brokerProfileQueryData])

        XCTAssertEqual(result.numberOfProfilesFound, 8)
        XCTAssertEqual(result.numberOfOptOutsInProgress, 4)
        XCTAssertEqual(result.numberOfSuccessfulOptOuts, 2)
        XCTAssertEqual(result.numberOfFailureOptOuts, 2)
        XCTAssertEqual(result.numberOfNewMatchesFound, 2)
        XCTAssertEqual(result.numberOfReAppereances, 2)
    }

    /// This test data has the following parameters
    ///  - A broker that is a children site
    ///  - Three matches found
    ///  - One match was removed
    ///  - Two matches are in progress of being removed
    func testStatsByBrokerForChildrenSite_hasCorrectParams() {
        let broker: DataBroker = .mockWithParentOptOut
        let historyEventsForFirstOptOutOperation: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .optOutConfirmed)
        ]
        let historyEventsForScanOperation: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .scanStarted),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 3)),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 2)),
        ]
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: broker,
            profileQuery: .mock,
            scanJobData: .mockWith(historyEvents: historyEventsForScanOperation),
            optOutJobData: [
                .mock(with: .mockWithRemovedDate, historyEvents: historyEventsForFirstOptOutOperation),
                .mock(with: .mockWithoutRemovedDate, historyEvents: [HistoryEvent]()),
                .mock(with: .mockWithoutRemovedDate, historyEvents: [HistoryEvent]())
            ])
        let sut = DataBrokerProtectionStatsPixels(database: MockDatabase(),
                                                  handler: handler,
                                                  repository: MockDataBrokerProtectionStatsPixelsRepository())

        let result = sut.calculateByBroker(broker, data: [brokerProfileQueryData])

        XCTAssertEqual(result.numberOfProfilesFound, 3)
        XCTAssertEqual(result.numberOfOptOutsInProgress, 2)
        XCTAssertEqual(result.numberOfSuccessfulOptOuts, 1)
    }

    func testWhenDateOfFirstScanIsNil_thenWeDoNotFireAnyPixel() {
        let repository = MockDataBrokerProtectionStatsPixelsRepository()
        let sut = DataBrokerProtectionStatsPixels(database: MockDatabase(),
                                                  handler: handler,
                                                  repository: repository)

        sut.tryToFireStatsPixels()

        XCTAssertFalse(repository.wasMarkStatsWeeklyPixelDateCalled)
        XCTAssertFalse(repository.wasMarkStatsMonthlyPixelDateCalled)
    }

    func testWhenLastWeeklyPixelIsNilAndAWeekDidntPassSinceInitialScan_thenWeDoNotFireWeeklyPixel() {
        let database = MockDatabase()
        let historyEventsForScanOperation: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: Date().yesterday!),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 1), date: Date().yesterday!),
        ]
        database.brokerProfileQueryDataToReturn = [
            .init(dataBroker: .mock, profileQuery: .mock, scanJobData: .mockWith(historyEvents: historyEventsForScanOperation))
        ]
        let repository = MockDataBrokerProtectionStatsPixelsRepository()
        let sut = DataBrokerProtectionStatsPixels(database: database,
                                                  handler: handler,
                                                  repository: repository)

        sut.tryToFireStatsPixels()

        XCTAssertFalse(repository.wasMarkStatsWeeklyPixelDateCalled)
    }

    func testWhenAWeekDidntPassSinceLastWeeklyPixelDate_thenWeDoNotFireWeeklyPixel() {
        let database = MockDatabase()
        let historyEventsForScanOperation: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: Date().yesterday!),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 1), date: Date().yesterday!),
        ]
        database.brokerProfileQueryDataToReturn = [
            .init(dataBroker: .mock, profileQuery: .mock, scanJobData: .mockWith(historyEvents: historyEventsForScanOperation))
        ]
        let repository = MockDataBrokerProtectionStatsPixelsRepository()
        repository.latestStatsWeeklyPixelDate = Date().yesterday!
        let sut = DataBrokerProtectionStatsPixels(database: database,
                                                  handler: handler,
                                                  repository: repository)

        sut.tryToFireStatsPixels()

        XCTAssertFalse(repository.wasMarkStatsWeeklyPixelDateCalled)
    }

    func testWhenAWeekPassedSinceLastWeeklyPixelDate_thenWeFireWeeklyPixel() {
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        let database = MockDatabase()
        let historyEventsForScanOperation: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: eightDaysAgo),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 1), date: eightDaysAgo),
        ]
        database.brokerProfileQueryDataToReturn = [
            .init(dataBroker: .mock, profileQuery: .mock, scanJobData: .mockWith(historyEvents: historyEventsForScanOperation))
        ]
        let repository = MockDataBrokerProtectionStatsPixelsRepository()
        repository.latestStatsWeeklyPixelDate = eightDaysAgo
        let sut = DataBrokerProtectionStatsPixels(database: database,
                                                  handler: handler,
                                                  repository: repository)

        sut.tryToFireStatsPixels()

        XCTAssertTrue(repository.wasMarkStatsWeeklyPixelDateCalled)
    }

    func testWhenLastMonthlyPixelIsNilAnd28DaysDidntPassSinceInitialScan_thenWeDoNotFireMonthlyPixel() {
        let twentyDaysAgo = Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        let database = MockDatabase()
        let historyEventsForScanOperation: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: twentyDaysAgo),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 1), date: twentyDaysAgo),
        ]
        database.brokerProfileQueryDataToReturn = [
            .init(dataBroker: .mock, profileQuery: .mock, scanJobData: .mockWith(historyEvents: historyEventsForScanOperation))
        ]
        let repository = MockDataBrokerProtectionStatsPixelsRepository()
        let sut = DataBrokerProtectionStatsPixels(database: database,
                                                  handler: handler,
                                                  repository: repository)

        sut.tryToFireStatsPixels()

        XCTAssertFalse(repository.wasMarkStatsMonthlyPixelDateCalled)
    }

    func testWhen28DaysDidntPassSinceLastMonthlyPixelDate_thenWeDoNotFireMonthlyPixel() {
        let twentyDaysAgo = Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        let database = MockDatabase()
        let historyEventsForScanOperation: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: twentyDaysAgo),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 1), date: twentyDaysAgo),
        ]
        database.brokerProfileQueryDataToReturn = [
            .init(dataBroker: .mock, profileQuery: .mock, scanJobData: .mockWith(historyEvents: historyEventsForScanOperation))
        ]
        let repository = MockDataBrokerProtectionStatsPixelsRepository()
        repository.latestStatsMonthlyPixelDate = twentyDaysAgo
        let sut = DataBrokerProtectionStatsPixels(database: database,
                                                  handler: handler,
                                                  repository: repository)

        sut.tryToFireStatsPixels()

        XCTAssertFalse(repository.wasMarkStatsMonthlyPixelDateCalled)
    }

    func testWhen28DaysPassedSinceLastMonthlyPixelDate_thenWeFireMonthlyPixel() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let database = MockDatabase()
        let historyEventsForScanOperation: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .scanStarted, date: thirtyDaysAgo),
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 1), date: thirtyDaysAgo),
        ]
        database.brokerProfileQueryDataToReturn = [
            .init(dataBroker: .mock, profileQuery: .mock, scanJobData: .mockWith(historyEvents: historyEventsForScanOperation))
        ]
        let repository = MockDataBrokerProtectionStatsPixelsRepository()
        repository.latestStatsMonthlyPixelDate = thirtyDaysAgo
        let sut = DataBrokerProtectionStatsPixels(database: database,
                                                  handler: handler,
                                                  repository: repository)

        sut.tryToFireStatsPixels()

        XCTAssertTrue(repository.wasMarkStatsMonthlyPixelDateCalled)
    }

    func testWhen24HoursHaveNotPassed_thenWeDontFireCustomStatsPixels() {
        // Given
        let repository = MockDataBrokerProtectionStatsPixelsRepository()
        repository._customStatsPixelsLastSentTimestamp = Date.nowMinus(hours: 23)
        let database = MockDatabase()
        database.brokerProfileQueryDataToReturn = [
            .mock()
        ]
        let sut = DataBrokerProtectionStatsPixels(database: database,
                                                  handler: handler,
                                                  repository: repository)

        // When
        sut.fireCustomStatsPixelsIfNeeded()

        // Then
        XCTAssertTrue(repository.didGetCustomStatsPixelsLastSentTimestamp)
        XCTAssertFalse(repository.didSetCustomStatsPixelsLastSentTimestamp)
    }

    func testWhen24HoursHavePassed_thenWeFireCustomStatsPixels() {
        // Given
        let repository = MockDataBrokerProtectionStatsPixelsRepository()
        repository._customStatsPixelsLastSentTimestamp = Date.nowMinus(hours: 25)
        let database = MockDatabase()
        database.brokerProfileQueryDataToReturn = [
            .mock()
        ]
        let sut = DataBrokerProtectionStatsPixels(database: database,
                                                  handler: handler,
                                                  repository: repository)

        // When
        sut.fireCustomStatsPixelsIfNeeded()

        // Then
        XCTAssertTrue(repository.didGetCustomStatsPixelsLastSentTimestamp)
        XCTAssertTrue(repository.didSetCustomStatsPixelsLastSentTimestamp)
    }

    func testWhen24HoursHavePassed_andOptOutsWereRequestedWereFound_thenWeFirePixelsWithExpectedValues() {
        // Given
        let repository = MockDataBrokerProtectionStatsPixelsRepository()
        repository._customStatsPixelsLastSentTimestamp = Date.nowMinus(hours: 26)
        let database = MockDatabase()
        database.brokerProfileQueryDataToReturn = BrokerProfileQueryData.queryDataMultipleBrokersVaryingSuccessRates
        let sut = DataBrokerProtectionStatsPixels(database: database,
                                                  handler: handler,
                                                  repository: repository)
        let expectation = self.expectation(description: "Async task completion")

        // When
        sut.fireCustomStatsPixelsIfNeeded()

        // There is a 100ms delay between pixels firing, so we need a delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 4.0) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0) { error in
            if let error = error {
                XCTFail("Expectation failed with error: \(error)")
            }

            // Then
            MockDataBrokerProtectionPixelsHandler.lastPixelsFired.sort { $0.params!["optout_submit_success_rate"]! <  $1.params!["optout_submit_success_rate"]! }
            let pixel1 = MockDataBrokerProtectionPixelsHandler.lastPixelsFired[0]
            let pixel2 = MockDataBrokerProtectionPixelsHandler.lastPixelsFired[1]
            let pixel3 = MockDataBrokerProtectionPixelsHandler.lastPixelsFired[2]
            let pixel4 = MockDataBrokerProtectionPixelsHandler.lastPixelsFired[3]
            XCTAssertTrue(MockDataBrokerProtectionPixelsHandler.lastPixelsFired.count == 4)
            XCTAssertEqual(pixel1.params!["optout_submit_success_rate"], "0.5")
            XCTAssertEqual(pixel2.params!["optout_submit_success_rate"], "0.71")
            XCTAssertEqual(pixel3.params!["optout_submit_success_rate"], "0.75")
            XCTAssertEqual(pixel4.params!["optout_submit_success_rate"], "1.0")
            XCTAssertTrue(repository.didGetCustomStatsPixelsLastSentTimestamp)
            XCTAssertTrue(repository.didSetCustomStatsPixelsLastSentTimestamp)
        }
    }

    // MARK: - opt out confirmed/unconfirmed pixel tests

    private static let dataBroker = "Test broker"
    private let optOutJobAt7DaysConfirmedPixel = DataBrokerProtectionPixels.optOutJobAt7DaysConfirmed(dataBroker: dataBroker)
    private let optOutJobAt7DaysUnconfirmedPixel = DataBrokerProtectionPixels.optOutJobAt7DaysUnconfirmed(dataBroker: dataBroker)
    private let optOutJobAt14DaysConfirmedPixel = DataBrokerProtectionPixels.optOutJobAt14DaysConfirmed(dataBroker: dataBroker)
    private let optOutJobAt14DaysUnconfirmedPixel = DataBrokerProtectionPixels.optOutJobAt14DaysUnconfirmed(dataBroker: dataBroker)
    private let optOutJobAt21DaysConfirmedPixel = DataBrokerProtectionPixels.optOutJobAt21DaysConfirmed(dataBroker: dataBroker)
    private let optOutJobAt21DaysUnconfirmedPixel = DataBrokerProtectionPixels.optOutJobAt21DaysUnconfirmed(dataBroker: dataBroker)

    private func validatePixelsFired(_ pixels: [DataBrokerProtectionPixels]) {
        let pixelsFired = MockDataBrokerProtectionPixelsHandler.lastPixelsFired
        for pixel in pixels {
            let matchingPixelsFired = pixelsFired.filter { $0.name == pixel.name }
            XCTAssertEqual(matchingPixelsFired.count, 1)
            XCTAssertNotNil(matchingPixelsFired.first)
            let matchingPixelFired = matchingPixelsFired.first!
            XCTAssertEqual(matchingPixelFired.params, pixel.params)
        }
    }

    private func validatePixelsNotFired(_ pixels: [DataBrokerProtectionPixels]) {
        let pixelsFired = MockDataBrokerProtectionPixelsHandler.lastPixelsFired
        for pixel in pixels {
            let matchingPixelsFired = pixelsFired.filter { $0.name == pixel.name }
            XCTAssertEqual(matchingPixelsFired.count, 0)
        }
    }

    func testWhenSubmittedDateIs6DaysAgo_thenNoPixelsAreFired() async {
        // Given
        let mockDatabase = MockDatabase()
        let submittedDate = Calendar.current.date(byAdding: .day, value: -6, to: Date())
        let optOutJobData = OptOutJobData.mock(with: .optOutConfirmed,
                                               submittedDate: submittedDate,
                                               sevenDaysConfirmationPixelFired: false,
                                               fourteenDaysConfirmationPixelFired: false,
                                               twentyOneDaysConfirmationPixelFired: false)
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: .mock,
            profileQuery: .mock,
            scanJobData: .mockWith(historyEvents: optOutJobData.historyEvents),
            optOutJobData: [optOutJobData])

        let sut = DataBrokerProtectionStatsPixels(database: mockDatabase,
                                                  handler: handler,
                                                  repository: MockDataBrokerProtectionStatsPixelsRepository())

        // When
        sut.fireRegularIntervalConfirmationPixelsForSubmittedOptOuts(for: [brokerProfileQueryData])
        let pixels = MockDataBrokerProtectionPixelsHandler.lastPixelsFired
        print(pixels)

        // Then
        validatePixelsNotFired([optOutJobAt7DaysConfirmedPixel,
                                optOutJobAt7DaysUnconfirmedPixel,
                                optOutJobAt14DaysConfirmedPixel,
                                optOutJobAt14DaysUnconfirmedPixel,
                                optOutJobAt21DaysConfirmedPixel,
                                optOutJobAt21DaysUnconfirmedPixel
                               ])

        // Cleanup
        handler.clear()
    }

    func testWhenSubmittedDateIs15DaysAgoAndOptOutConfirmed_then7And14ConfirmedPixelsAreFiredButNoOthers() async {
        // Given
        let mockDatabase = MockDatabase()
        let submittedDate = Calendar.current.date(byAdding: .day, value: -15, to: Date())
        let optOutJobData = OptOutJobData.mock(with: .optOutConfirmed,
                                               submittedDate: submittedDate,
                                               sevenDaysConfirmationPixelFired: false,
                                               fourteenDaysConfirmationPixelFired: false,
                                               twentyOneDaysConfirmationPixelFired: false)
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: .mock,
            profileQuery: .mock,
            scanJobData: .mockWith(historyEvents: optOutJobData.historyEvents),
            optOutJobData: [optOutJobData])

        let sut = DataBrokerProtectionStatsPixels(database: mockDatabase,
                                                  handler: handler,
                                                  repository: MockDataBrokerProtectionStatsPixelsRepository())

        // When
        sut.fireRegularIntervalConfirmationPixelsForSubmittedOptOuts(for: [brokerProfileQueryData])
        let pixels = MockDataBrokerProtectionPixelsHandler.lastPixelsFired
        print(pixels)

        // Then
        validatePixelsFired([optOutJobAt7DaysConfirmedPixel,
                             optOutJobAt14DaysConfirmedPixel])
        validatePixelsNotFired([optOutJobAt7DaysUnconfirmedPixel,
                                optOutJobAt14DaysUnconfirmedPixel,
                                optOutJobAt21DaysConfirmedPixel,
                                optOutJobAt21DaysUnconfirmedPixel
                               ])

        // Cleanup
        handler.clear()
    }

    func testWhenSubmittedDateIs15DaysAgoAndOptOutNotConfirmed_then7And14UnconfirmedPixelsAreFiredButNoOthers() async {
        // Given
        let mockDatabase = MockDatabase()
        let submittedDate = Calendar.current.date(byAdding: .day, value: -15, to: Date())
        let optOutJobData = OptOutJobData.mock(with: .optOutRequested,
                                               submittedDate: submittedDate,
                                               sevenDaysConfirmationPixelFired: false,
                                               fourteenDaysConfirmationPixelFired: false,
                                               twentyOneDaysConfirmationPixelFired: false)
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: .mock,
            profileQuery: .mock,
            scanJobData: .mockWith(historyEvents: optOutJobData.historyEvents),
            optOutJobData: [optOutJobData])

        let sut = DataBrokerProtectionStatsPixels(database: mockDatabase,
                                                  handler: handler,
                                                  repository: MockDataBrokerProtectionStatsPixelsRepository())

        // When
        sut.fireRegularIntervalConfirmationPixelsForSubmittedOptOuts(for: [brokerProfileQueryData])
        let pixels = MockDataBrokerProtectionPixelsHandler.lastPixelsFired
        print(pixels)

        // Then
        validatePixelsFired([optOutJobAt7DaysUnconfirmedPixel,
                             optOutJobAt14DaysUnconfirmedPixel])
        validatePixelsNotFired([optOutJobAt7DaysConfirmedPixel,
                                optOutJobAt14DaysConfirmedPixel,
                                optOutJobAt21DaysConfirmedPixel,
                                optOutJobAt21DaysUnconfirmedPixel
                               ])

        // Cleanup
        handler.clear()
    }

    func testWhenPixelAlreadySentFlagsTrue_thenPixelsNotSent() async {
        // Given
        let mockDatabase = MockDatabase()
        let submittedDate = Calendar.current.date(byAdding: .day, value: -22, to: Date())
        let optOutJobData = OptOutJobData.mock(with: .optOutConfirmed,
                                               submittedDate: submittedDate,
                                               sevenDaysConfirmationPixelFired: true,
                                               fourteenDaysConfirmationPixelFired: true,
                                               twentyOneDaysConfirmationPixelFired: true)
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: .mock,
            profileQuery: .mock,
            scanJobData: .mockWith(historyEvents: optOutJobData.historyEvents),
            optOutJobData: [optOutJobData])

        let sut = DataBrokerProtectionStatsPixels(database: mockDatabase,
                                                  handler: handler,
                                                  repository: MockDataBrokerProtectionStatsPixelsRepository())

        // When
        sut.fireRegularIntervalConfirmationPixelsForSubmittedOptOuts(for: [brokerProfileQueryData])
        let pixels = MockDataBrokerProtectionPixelsHandler.lastPixelsFired
        print(pixels)

        // Then
        validatePixelsNotFired([optOutJobAt7DaysConfirmedPixel,
                                optOutJobAt7DaysUnconfirmedPixel,
                                optOutJobAt14DaysConfirmedPixel,
                                optOutJobAt14DaysUnconfirmedPixel,
                                optOutJobAt21DaysConfirmedPixel,
                                optOutJobAt21DaysUnconfirmedPixel
                               ])

        // Cleanup
        handler.clear()
    }

    func testWhenSomePixelAlreadySentFlagsTrue_thenPixelsSentOrNotSentAsPerFlag() async {
        // Given
        let mockDatabase = MockDatabase()
        let submittedDate = Calendar.current.date(byAdding: .day, value: -22, to: Date())
        let optOutJobData = OptOutJobData.mock(with: .optOutConfirmed,
                                               submittedDate: submittedDate,
                                               sevenDaysConfirmationPixelFired: true,
                                               fourteenDaysConfirmationPixelFired: false,
                                               twentyOneDaysConfirmationPixelFired: false)
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: .mock,
            profileQuery: .mock,
            scanJobData: .mockWith(historyEvents: optOutJobData.historyEvents),
            optOutJobData: [optOutJobData])

        let sut = DataBrokerProtectionStatsPixels(database: mockDatabase,
                                                  handler: handler,
                                                  repository: MockDataBrokerProtectionStatsPixelsRepository())

        // When
        sut.fireRegularIntervalConfirmationPixelsForSubmittedOptOuts(for: [brokerProfileQueryData])
        let pixels = MockDataBrokerProtectionPixelsHandler.lastPixelsFired
        print(pixels)

        // Then
        validatePixelsFired([optOutJobAt14DaysConfirmedPixel,
                             optOutJobAt21DaysConfirmedPixel])
        validatePixelsNotFired([optOutJobAt7DaysConfirmedPixel,
                                optOutJobAt7DaysUnconfirmedPixel,
                                optOutJobAt14DaysUnconfirmedPixel,
                                optOutJobAt21DaysUnconfirmedPixel
                               ])

        // Cleanup
        handler.clear()
    }

    func testWhenSubmittedDateIsNil_thenNoPixelsAreFired() async {
        // Migrating existing users the submitted date defaults to nil, and pixels shouldn't be fired

        // Given
        let mockDatabase = MockDatabase()
        let optOutJobData = OptOutJobData.mock(with: .optOutConfirmed,
                                               submittedDate: nil,
                                               sevenDaysConfirmationPixelFired: false,
                                               fourteenDaysConfirmationPixelFired: false,
                                               twentyOneDaysConfirmationPixelFired: false)
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: .mock,
            profileQuery: .mock,
            scanJobData: .mockWith(historyEvents: optOutJobData.historyEvents),
            optOutJobData: [optOutJobData])

        let sut = DataBrokerProtectionStatsPixels(database: mockDatabase,
                                                  handler: handler,
                                                  repository: MockDataBrokerProtectionStatsPixelsRepository())

        // When
        sut.fireRegularIntervalConfirmationPixelsForSubmittedOptOuts(for: [brokerProfileQueryData])
        let pixels = MockDataBrokerProtectionPixelsHandler.lastPixelsFired
        print(pixels)

        // Then
        validatePixelsNotFired([optOutJobAt7DaysConfirmedPixel,
                                optOutJobAt7DaysUnconfirmedPixel,
                                optOutJobAt14DaysConfirmedPixel,
                                optOutJobAt14DaysUnconfirmedPixel,
                                optOutJobAt21DaysConfirmedPixel,
                                optOutJobAt21DaysUnconfirmedPixel
                               ])

        // Cleanup
        handler.clear()
    }
}
