//
//  OperationPreferredDateUpdaterTests.swift
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

final class OperationPreferredDateUpdaterTests: XCTestCase {

    private let databaseMock = MockDatabase()

    override func tearDown() {
        databaseMock.clear()
    }

    func testWhenParentBrokerHasChildSites_thenThoseSitesScanPreferredRunDateIsUpdatedWithConfirm() {
        let sut = OperationPreferredDateUpdaterUseCase(database: databaseMock)
        let confirmOptOutScanHours = 48
        let profileQueryId: Int64 = 11
        let expectedDate = Date().addingTimeInterval(confirmOptOutScanHours.hoursToSeconds)
        let childBroker = DataBroker(
            id: 1,
            name: "Child broker",
            url: "childbroker.com",
            steps: [Step](),
            version: "1.0",
            schedulingConfig: DataBrokerScheduleConfig(
                retryError: 1,
                confirmOptOutScan: confirmOptOutScanHours,
                maintenanceScan: 1,
                maxAttempts: -1
            ),
            optOutUrl: ""
        )
        databaseMock.childBrokers = [childBroker]

        XCTAssertNoThrow(try sut.updateChildrenBrokerForParentBroker(.mock, profileQueryId: profileQueryId))

        XCTAssertTrue(databaseMock.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertEqual(databaseMock.lastParentBrokerWhereChildSitesWhereFetched, "Test broker")
        XCTAssertEqual(databaseMock.lastProfileQueryIdOnScanUpdatePreferredRunDate, profileQueryId)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedDate, date2: databaseMock.lastPreferredRunDateOnScan))
    }

    func testWhenParentBrokerHasNoChildsites_thenNoCallsToTheDatabaseAreDone() {
        let sut = OperationPreferredDateUpdaterUseCase(database: databaseMock)

        XCTAssertNoThrow(try sut.updateChildrenBrokerForParentBroker(.mock, profileQueryId: 1))

        XCTAssertFalse(databaseMock.wasDatabaseCalled)
    }

    func testWhenOptOutSubmitted_thenSubmittedSuccessfullyDateIsUpdated() {
        // Given
        let extractedProfileId: Int64 = 1
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 11
        let createdDate = Date()
        let submittedDate = Date()

        let lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutRequested, date: submittedDate)
        databaseMock.lastHistoryEventToReturn = lastHistoryEventToReturn

        let scanJobData = ScanJobData(brokerId: brokerId, profileQueryId: profileQueryId, historyEvents: [lastHistoryEventToReturn])
        let optOutJobData = OptOutJobData(brokerId: brokerId, profileQueryId: profileQueryId, createdDate: createdDate, historyEvents: [lastHistoryEventToReturn], attemptCount: 0, extractedProfile: .mockWithoutRemovedDate)
        databaseMock.brokerProfileQueryDataToReturn = [
            BrokerProfileQueryData(dataBroker: .mock, profileQuery: .mock, scanJobData: scanJobData, optOutJobData: [optOutJobData])
        ]
        let sut = OperationPreferredDateUpdaterUseCase(database: databaseMock)

        // When
        XCTAssertNoThrow(try sut.updateOperationDataDates(origin: .optOut, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: DataBrokerScheduleConfig.mock))

        // Then
        XCTAssertTrue(databaseMock.wasUpdateSubmittedSuccessfullyDateForOptOutCalled)
        let date = databaseMock.submittedSuccessfullyDate!
        XCTAssertTrue(date >= submittedDate)
    }

    func testWhenSubittedSuccessfullyDateIsAlreadySaved_thenSubittedSuccessfullyDateDoesNotChange() {
        // Given
        let extractedProfileId: Int64 = 1
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 11
        let createdDate = Date()
        let submittedDate = Date()

        let lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutRequested, date: submittedDate)
        databaseMock.lastHistoryEventToReturn = lastHistoryEventToReturn

        let scanJobData = ScanJobData(brokerId: brokerId, profileQueryId: profileQueryId, historyEvents: [lastHistoryEventToReturn])
        let optOutJobData = OptOutJobData(brokerId: brokerId, profileQueryId: profileQueryId, createdDate: createdDate, historyEvents: [lastHistoryEventToReturn], attemptCount: 0, submittedSuccessfullyDate: submittedDate, extractedProfile: .mockWithoutRemovedDate)
        databaseMock.brokerProfileQueryDataToReturn = [
            BrokerProfileQueryData(dataBroker: .mock, profileQuery: .mock, scanJobData: scanJobData, optOutJobData: [optOutJobData])
        ]
        let sut = OperationPreferredDateUpdaterUseCase(database: databaseMock)

        // When
        XCTAssertNoThrow(try sut.updateOperationDataDates(origin: .optOut, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: DataBrokerScheduleConfig.mock))

        // Then
        XCTAssertFalse(databaseMock.wasUpdateSubmittedSuccessfullyDateForOptOutCalled)
    }
}
