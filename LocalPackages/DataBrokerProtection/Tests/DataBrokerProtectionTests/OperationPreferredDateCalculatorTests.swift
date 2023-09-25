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
        retryError: 1000,
        confirmOptOutScan: 2000,
        maintenanceScan: 3000
    )

    func testNoMatchFound() throws {
        let expectedScanDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)
        let expectedOptOutDate: Date? = nil

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

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    /*
     If the last time we removed the profile has a bigger time difference than the current date + maintenance (expired) we should schedule for a new optout because the broker didn't honor the request
     */
    func testMatchFoundProfileRemovalExpired() throws {
        let expiredDate = Date().addingTimeInterval(-schedulingConfig.maintenanceScan.hoursToSeconds)

        let expectedScanDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)
        let expectedOptOutDate = Date()

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested,
                         date: expiredDate),
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .matchesFound)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: nil,
                                                             historyEvents: historyEvents,
                                                             extractedProfileID: nil,
                                                             schedulingConfig: schedulingConfig)

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: 1,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testMatchFoundProfileRemovalNotExpired() throws {
        let expectedScanDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested),
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .matchesFound)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: nil,
                                                             historyEvents: historyEvents,
                                                             extractedProfileID: nil,
                                                             schedulingConfig: schedulingConfig)

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: 1,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))}

    func testError() throws {
        let expectedScanDate = Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)
        let expectedOptOutDate = Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)

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

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutStarted() throws { 
        let expectedScanDate: Date? = nil
        let expectedOptOutDate: Date? = nil

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

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutConfirmed() throws {
        let expectedScanDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)
        let expectedOptOutDate: Date? = nil

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

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutRequested() throws {
        let expectedScanDate = Date().addingTimeInterval(schedulingConfig.confirmOptOutScan.hoursToSeconds)
        let expectedOptOutDate: Date? = nil

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

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testScanStarted() throws {
        let expectedScanDate: Date? = nil
        let expectedOptOutDate: Date? = nil

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

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    // If we have a most recent date saved, the calculator should not change it no matter the case.

    func testNoMatchFoundWithMostRecentDate() {
        let expectedScanDate = Date()
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .noMatchFound)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try! calculator.dateForScanOperation(currentPreferredRunDate: Date(),
                                                             historyEvents: historyEvents,
                                                             extractedProfileID: nil,
                                                             schedulingConfig: schedulingConfig)

        let actualOptOutDate = try! calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    /*
     If the last time we removed the profile has a bigger time difference than the current date + maintenance (expired) we should schedule for a new optout because the broker didn't honor the request
     */
    func testMatchFoundProfileRemovalExpiredWithMostRecentDate() throws {
        let expiredDate = Date().addingTimeInterval(-schedulingConfig.maintenanceScan.hoursToSeconds)

        let expectedScanDate = Date()
        let expectedOptOutDate = Date()

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested,
                         date: expiredDate),
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .matchesFound)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: Date(),
                                                             historyEvents: historyEvents,
                                                             extractedProfileID: nil,
                                                             schedulingConfig: schedulingConfig)

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: 1,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testMatchFoundProfileRemovalNotExpiredWithMostRecentDate() throws {
        let expectedScanDate = Date()
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested),
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .matchesFound)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: Date(),
                                                             historyEvents: historyEvents,
                                                             extractedProfileID: nil,
                                                             schedulingConfig: schedulingConfig)

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: 1,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))}

    func testErrorWithMostRecentDate() throws {
        let expectedScanDate = Date()
        let expectedOptOutDate = Date()

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .error(error: DataBrokerProtectionError.malformedURL))]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: Date(),
                                                             historyEvents: historyEvents,
                                                             extractedProfileID: nil,
                                                             schedulingConfig: schedulingConfig)

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: Date(),
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutStartedWithMostRecentDate() throws {
        let expectedScanDate = Date()
        let expectedOptOutDate = Date()

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

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: Date(),
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutConfirmedWithMostRecentDate() throws {
        let expectedScanDate = Date()
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutConfirmed)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try! calculator.dateForScanOperation(currentPreferredRunDate: Date(),
                                                             historyEvents: historyEvents,
                                                             extractedProfileID: nil,
                                                             schedulingConfig: schedulingConfig)

        let actualOptOutDate = try! calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutRequestedWithMostRecentDate() throws {
        let expectedScanDate = Date()
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested)]

        let calculator = OperationPreferredDateCalculator()

        let actualScanDate = try calculator.dateForScanOperation(currentPreferredRunDate: Date(),
                                                             historyEvents: historyEvents,
                                                             extractedProfileID: nil,
                                                             schedulingConfig: schedulingConfig)

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testScanStartedWithMostRecentDate() throws {
        let expectedScanDate = Date()
        let expectedOptOutDate: Date? = nil

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

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                 historyEvents: historyEvents,
                                                                 extractedProfileID: nil,
                                                                 schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }
}
