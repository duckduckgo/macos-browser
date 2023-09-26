//
//  UpdateChildSitesScanPreferredRunDateUseCaseTests.swift
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

final class UpdateChildSitesScanPreferredRunDateUseCaseTests: XCTestCase {

    private let databaseMock = MockDatabase()

    override func tearDown() {
        databaseMock.clear()
    }

    func testWhenParentBrokerHasChildSites_thenThoseSitesScanPreferredRunDateIsUpdatedWithConfirm() {
        let sut = UpdateChildSitesScanPreferredRunDateUseCase(database: databaseMock)
        let confirmOptOutScanHours = 48
        let profileQueryId: Int64 = 11
        let expectedDate = Date().addingTimeInterval(confirmOptOutScanHours.hoursToSeconds)
        let childBroker = DataBroker(
            id: 1,
            name: "Child broker",
            steps: [Step](),
            version: "1.0",
            schedulingConfig: DataBrokerScheduleConfig(
                retryError: 1,
                confirmOptOutScan: confirmOptOutScanHours,
                maintenanceScan: 1
            )
        )
        databaseMock.childBrokers = [childBroker]

        sut.run(parentBroker: .mock, profileQueryId: profileQueryId)

        XCTAssertTrue(databaseMock.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertEqual(databaseMock.lastParentBrokerWhereChildSitesWhereFetched, "Test broker")
        XCTAssertEqual(databaseMock.lastProfileQueryIdOnScanUpdatePreferredRunDate, profileQueryId)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedDate, date2: databaseMock.lastPreferredRunDateOnScan))
    }

    func testWhenParentBrokerHasNoChildsites_thenNoCallsToTheDatabaseAreDone() {
        let sut = UpdateChildSitesScanPreferredRunDateUseCase(database: databaseMock)

        sut.run(parentBroker: .mock, profileQueryId: 1)

        XCTAssertFalse(databaseMock.wasDatabaseCalled)
    }
}
