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

    /*
     If the last time we removed the profile has a bigger time difference than the current date + maintenance (expired) we should schedule for a new optout because the broker didn't honor the request
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
                         type: .matchesFound)]

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
                         type: .matchesFound)]

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

    // If we have a most recent date saved, the calculator should not change it no matter the case.

    func testNoMatchFoundWithRecentDate_thenScanDateDoesNotChange() {
        let expectedScanDate = Date()

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


        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    /*
     If the last time we removed the profile has a bigger time difference than the current date + maintenance (expired) we should schedule for a new optout because the broker didn't honor the request
     */
    func testMatchFoundWithExpiredProfileWithRecentDate_thenScanDateDoesNotChange() throws {
        let expiredDate = Date().addingTimeInterval(-schedulingConfig.maintenanceScan.hoursToSeconds)

        let expectedScanDate = Date()

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


        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    func testMatchFoundWithoutExpiredProfileWithRecentDate_thenScanDateDoesNotChange() throws {
        let expectedScanDate = Date()

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


        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    func testErrorWithRecentDate_thenScanDateDoesNotChange() throws {
        let expectedScanDate = Date()

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

    func testOptOutConfirmedWithRecentDate_thenScanDateDoesNotChange() throws {
        let expectedScanDate = Date()

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


        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: actualScanDate))
    }

    func testOptOutRequestedWithRecentDate_thenScanDateDoesNotChange() throws {
        let expectedScanDate = Date()

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
                                                                     schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testMatchFoundWithExpiredProfile_thenOptOutDateIsNow() throws {
        let expiredDate = Date().addingTimeInterval(-schedulingConfig.maintenanceScan.hoursToSeconds)

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

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: 1,
                                                                     schedulingConfig: schedulingConfig)

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
                         type: .matchesFound)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: 1,
                                                                     schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testError_thenOptOutDateIsRetry() throws {
        let expectedOptOutDate = Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .error(error: DataBrokerProtectionError.malformedURL))]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig)

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
                                                                     schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutConfirmed_thenOptOutIsNil() throws {
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutConfirmed)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutRequested_thenOptOutIsNil() throws {
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
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
                                                                     schedulingConfig: schedulingConfig)

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


        let actualOptOutDate = try! calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                      historyEvents: historyEvents,
                                                                      extractedProfileID: nil,
                                                                      schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    /*
     If the last time we removed the profile has a bigger time difference than the current date + maintenance (expired) we should schedule for a new optout because the broker didn't honor the request
     */
    func testMatchFoundWithExpiredProfileWithRecentDate_thenOptOutDateDoesNotChange() throws {
        let expiredDate = Date().addingTimeInterval(-schedulingConfig.maintenanceScan.hoursToSeconds)

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

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: 1,
                                                                     schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testMatchFoundWithoutExpiredProfileWithRecentDate_thenOptOutDateDoesNotChange() throws {
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


        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: 1,
                                                                     schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testErrorWithRecentDate_thenOptOutDateDoesNotChange() throws {
        let expectedOptOutDate = Date()

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .error(error: DataBrokerProtectionError.malformedURL))]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: Date(),
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig)

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
                                                                     schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutConfirmedWithRecentDate_thenOptOutDateDoesNotChange() throws {
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutConfirmed)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try! calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                      historyEvents: historyEvents,
                                                                      extractedProfileID: nil,
                                                                      schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }

    func testOptOutRequestedWithRecentDate_thenOptOutDateDoesNotChange() throws {
        let expectedOptOutDate: Date? = nil

        let historyEvents = [
            HistoryEvent(extractedProfileId: 1,
                         brokerId: 1,
                         profileQueryId: 1,
                         type: .optOutRequested)]

        let calculator = OperationPreferredDateCalculator()

        let actualOptOutDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: nil,
                                                                     historyEvents: historyEvents,
                                                                     extractedProfileID: nil,
                                                                     schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
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
                                                                     schedulingConfig: schedulingConfig)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedOptOutDate, date2: actualOptOutDate))
    }
}
