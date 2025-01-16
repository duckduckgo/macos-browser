//
//  OperationPreferredDateCalculatorTests.swift
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
@testable import DataBrokerProtection
// https://app.asana.com/0/1204586965688315/1204834439855281/f

final class OperationPreferredDateCalculatorTests: XCTestCase {

    private let schedulingConfig = DataBrokerScheduleConfig(
        retryError: 48,
        confirmOptOutScan: 72,
        maintenanceScan: 120,
        maxAttempts: 3
    )

    // SCANS

    func testNoMatchFound_thenScanDateIsMaintenance() throws {
        let expectedScanDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .noMatchFound)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    func testOptOutConfirmedOnDeprecatedProfile_thenScanDateIsNil() throws {
        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutConfirmed)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: Date(),
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig,
                                                                 isDeprecated: true)

        XCTAssertNil(actualScanDate)
    }
    /*
     If the time elapsed since the last profile removal exceeds the current date plus maintenance period (expired), we should proceed with scheduling a new opt-out request as the broker has failed to honor the previous one.
     */
    func testMatchFoundWithExpiredProfile_thenScanDateIsMaintenance() throws {
        let expiredDate = Date().addingTimeInterval(-schedulingConfig.maintenanceScan.hoursToSeconds)

        let expectedScanDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested,
                         date: expiredDate),
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .matchesFound(count: 1))]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    func testMatchFoundWithNonExpiredProfile_thenScanDateIsMaintenance() throws {
        let expectedScanDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested),
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .matchesFound(count: 1))]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    func testError_thenScanDateIsRetry() throws {
        let expectedScanDate = Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .error(error: DataBrokerProtectionError.malformedURL))]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    func testOptOutStarted_thenScanDoesNotChange() throws {
        let expectedScanDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutStarted)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    func testOptOutConfirmed_thenScanDateIsMaintenance() throws {
        let expectedScanDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutConfirmed)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    func testOptOutRequested_thenScanIsConfirmOptOut() throws {
        let expectedScanDate = Date().addingTimeInterval(schedulingConfig.confirmOptOutScan.hoursToSeconds)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    func testScanStarted_thenScanDoesNotChange() throws {
        let expectedScanDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .scanStarted)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    func testOptOutStartedWithRecentDate_thenScanDateDoesNotChange() throws {
        let expectedScanDate = Date()

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutStarted)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: Date(),
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    func testScanStartedWithRecentDate_thenScanDateDoesNotChange() throws {
        let expectedScanDate = Date()

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .scanStarted)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: Date(),
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    // OPT OUT

    func testNoMatchFound_thenOptOutDateIsNil() throws {
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .noMatchFound)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testMatchFoundWithExpiredProfile_thenOptOutDateIsNow() throws {
        let expiredDate = Date(timeIntervalSince1970: 0).addingTimeInterval(-schedulingConfig.maintenanceScan.hoursToSeconds * 2)

        let expectedOptOutDate = Date(timeIntervalSince1970: 0)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested,
                         date: expiredDate),
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .matchesFound(count: 1))]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: 1,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0,
                                                                     date: MockDate())

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testMatchFoundWithNonExpiredProfile_thenOptOutDateIsNil() throws {
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested),
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .matchesFound(count: 1))]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: 1,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testWhenOptOutFailedOnce_thenWeRetryInTwoHours() throws {
        let expectedOptOutDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date())!
        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .error(error: DataBrokerProtectionError.malformedURL))]
        let calculator = OperationPreferredDateCalculator()
        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testWhenOptOutFailedTwice_thenWeRetryInFourHours() throws {
        let expectedOptOutDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date())!
        let historyEvents: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL))
        ]
        let calculator = OperationPreferredDateCalculator()
        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testWhenOptOutFailedThreeTimes_thenWeRetryInEightHours() throws {
        let expectedOptOutDate = Calendar.current.date(byAdding: .hour, value: 8, to: Date())!
        let historyEvents: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL))
        ]
        let calculator = OperationPreferredDateCalculator()
        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testWhenOptOutFailedThreeTimes_thenWeRetryInSixteenHours() throws {
        let expectedOptOutDate = Calendar.current.date(byAdding: .hour, value: 16, to: Date())!
        let historyEvents: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL))
        ]
        let calculator = OperationPreferredDateCalculator()
        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testWhenOptOutFailedThreeTimes_thenWeRetryInThirtyTwoHours() throws {
        let expectedOptOutDate = Calendar.current.date(byAdding: .hour, value: 32, to: Date())!
        let historyEvents: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL))
        ]
        let calculator = OperationPreferredDateCalculator()
        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testWhenOptOutFailedSixTimes_thenWeRetryInTwoDays() throws {
        let expectedOptOutDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        let historyEvents: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL))
        ]
        let calculator = OperationPreferredDateCalculator()
        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testWhenOptOutFailedMoreThanTheThreshold_thenWeRetryAtTheSchedulingRetry() throws {
        let expectedOptOutDate = Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)
        let historyEvents: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)),
            .init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL))
        ]
        let calculator = OperationPreferredDateCalculator()
        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    /// https://app.asana.com/0/1204006570077678/1207642874812352/f
    /// We had a crash where the Int.max was exceeded when calculating the backoff. This checks that we are not passings that max.
    func testWhenOptOutFailedMoreThanTheThresholdAndExceedsTheMaxInt_thenWeRetryAtTheSchedulingRetryAndNotCrash() throws {
        let expectedOptOutDate = Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)

        var historyEvents = [HistoryEvent]()
        for _ in 0...1074 {
            historyEvents.append(.init(brokerId: 1, profileQueryId: 1, type: .error(error: .malformedURL)))
        }
        let calculator = OperationPreferredDateCalculator()
        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutStarted_thenOptOutDateDoesNotChange() throws {
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutStarted)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutConfirmedWithCurrentPreferredDate_thenOptOutIsNotScheduled() throws {
        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutConfirmed)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: Date(),
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertNil(actualOptOutDate)
    }

    func testOptOutConfirmedWithoutCurrentPreferredDate_thenOptOutIsNotScheduled() throws {
        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutConfirmed)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: Date(),
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertNil(actualOptOutDate)
    }

    func testOptOutRequestedWithCurrentPreferredDate_thenOptOutIsNotScheduled() throws {
        let expectedOptOutDate = MockDate().now.addingTimeInterval(schedulingConfig.hoursUntilNextOptOutAttempt.hoursToSeconds)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: Date(),
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0,
                                                                     date: MockDate())

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: actualOptOutDate, date2: expectedOptOutDate))
    }

    func testOptOutRequestedWithoutCurrentPreferredDate_thenOptOutIsNotScheduled() throws {
        let expectedOptOutDate = MockDate().now.addingTimeInterval(schedulingConfig.hoursUntilNextOptOutAttempt.hoursToSeconds)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0,
                                                                     date: MockDate())

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: actualOptOutDate, date2: expectedOptOutDate))
    }

    func testScanStarted_thenOptOutDoesNotChange() throws {
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .scanStarted)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testNoMatchFoundWithRecentDate_thenOptOutDateDoesNotChange() throws {
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .noMatchFound)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    /*
     If the time elapsed since the last profile removal exceeds the current date plus maintenance period (expired), we should proceed with scheduling a new opt-out request as the broker has failed to honor the previous one.
     */
    func testMatchFoundWithExpiredProfileWithRecentDate_thenOptOutDateDoesNotChange() throws {
        let expiredDate = Date(timeIntervalSince1970: 0).addingTimeInterval(-schedulingConfig.maintenanceScan.hoursToSeconds)

        let expectedOptOutDate = Date(timeIntervalSince1970: 0)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested,
                         date: expiredDate),
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .matchesFound(count: 1))]
        let dateProtocol = MockDate()

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: 1,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0,
                                                                     date: dateProtocol)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testMatchFoundWithRecentDate_thenOptOutDateIsScheduledIfMaxAttemptsNotExceeded() throws {
        try test(eventType: .matchesFound(count: 1))
        try test(eventType: .reAppearence)

        func test(eventType: HistoryEvent.EventType) throws {
            let expiredDate = Date(timeIntervalSince1970: 0).addingTimeInterval(-schedulingConfig.maintenanceScan.hoursToSeconds)

            let expectedOptOutDate = Date(timeIntervalSince1970: 0)

            let historyEvents = [
                HistoryEvent(extractedProfileId: 1,
                             brokerId: 1,
                             profileQueryId: 1,
                             type: .optOutRequested,
                             date: expiredDate),
                HistoryEvent(extractedProfileId: 1,
                             brokerId: 1,
                             profileQueryId: 1,
                             type: eventType)]
            let dateProtocol = MockDate()

            let calculator = OperationPreferredDateCalculator()

            let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                         historyEvents: historyEvents,
                                                                         extractedProfileID: 1,
                                                                         schedulingConfig: schedulingConfig,
                                                                         attemptCount: 2,
                                                                         date: dateProtocol)

            XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))

            let actualOptOutDateForAnotherAttempt = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                                          historyEvents: historyEvents,
                                                                                          extractedProfileID: 1,
                                                                                          schedulingConfig: schedulingConfig,
                                                                                          attemptCount: 3,
                                                                                          date: dateProtocol)

            XCTAssertNil(actualOptOutDateForAnotherAttempt)
        }
    }

    func testMatchFoundWithExpiredProfileWithRecentDate_thenOptOutDateIsScheduledIfMaxAttemptsIsNotConfigured() throws {
        let expiredDate = Date(timeIntervalSince1970: 0).addingTimeInterval(-schedulingConfig.maintenanceScan.hoursToSeconds)

        let expectedOptOutDate = Date(timeIntervalSince1970: 0)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested,
                         date: expiredDate),
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .matchesFound(count: 1))]
        let dateProtocol = MockDate()

        let calculator = OperationPreferredDateCalculator()

        let config = DataBrokerScheduleConfig(
            retryError: 48,
            confirmOptOutScan: 2000,
            maintenanceScan: 3000,
            maxAttempts: -1
        )

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: 1,
                                                                     schedulingConfig: config,
                                                                     attemptCount: 100,
                                                                     date: dateProtocol)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testMatchFoundWithRecentDate_thenOptOutDateDoesNotChange() throws {
        try test(eventType: .matchesFound(count: 1))
        try test(eventType: .reAppearence)

        func test(eventType: HistoryEvent.EventType) throws {
            let expectedOptOutDate: Date? = nil

            let historyEvents = [
                HistoryEvent(extractedProfileId: 1,
                             brokerId: 1,
                             profileQueryId: 1,
                             type: .optOutRequested),
                HistoryEvent(extractedProfileId: 1,
                             brokerId: 1,
                             profileQueryId: 1,
                             type: .matchesFound(count: 1))]

            let calculator = OperationPreferredDateCalculator()

            let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                         historyEvents: historyEvents,
                                                                         extractedProfileID: 1,
                                                                         schedulingConfig: schedulingConfig,
                                                                         attemptCount: 0)

            XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
        }
    }

    func testChildBrokerTurnsParentBroker_whenFirstOptOutSucceeds_thenOptOutDateIsNotScheduled() throws {
        let expectedOptOutDate = MockDate().now.addingTimeInterval(schedulingConfig.hoursUntilNextOptOutAttempt.hoursToSeconds)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested),
        ]
        let calculator = OperationPreferredDateCalculator()
        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: 1,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 1,
                                                                     date: MockDate())

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: actualOptOutDate, date2: expectedOptOutDate))
    }

    func testChildBrokerTurnsParentBroker_whenFirstOptOutFails_thenOptOutIsScheduled() throws {
        let expectedOptOutDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date())!

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .error(error: .malformedURL)),
        ]
        let calculator = OperationPreferredDateCalculator()
        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: 1,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 1)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testRequestedOptOut_whenProfileReappears_thenOptOutIsScheduled() throws {
        let expectedOptOutDate = Date()

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested,
                         date: .nowMinus(hours: 24*10)),
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .reAppearence),
        ]
        let calculator = OperationPreferredDateCalculator()
        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: .distantFuture,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: 1,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 1)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutStartedWithRecentDate_thenOptOutDateDoesNotChange() throws {
        let expectedOptOutDate = Date()

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutStarted)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: Date(),
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutConfirmedWithRecentDate_thenOptOutDateDoesNotChange() throws {
        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutConfirmed)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertNil(actualOptOutDate)
    }

    func testOptOutRequestedWithRecentDate_thenOutOutIsNotScheduled() throws {
        let expectedOptOutDate = MockDate().now.addingTimeInterval(schedulingConfig.hoursUntilNextOptOutAttempt.hoursToSeconds)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0,
                                                                     date: MockDate())

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: actualOptOutDate, date2: expectedOptOutDate))
    }

    func testScanStartedWithRecentDate_thenOptOutDateDoesNotChange() throws {
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .scanStarted)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig,
                                                                     attemptCount: 0)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }
}

struct MockDate: DateProtocol {
    var now: Date {
        return Date(timeIntervalSince1970: 0)
    }
}
