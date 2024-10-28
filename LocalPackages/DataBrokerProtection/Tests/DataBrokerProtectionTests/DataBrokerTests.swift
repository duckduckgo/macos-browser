//
//  DataBrokerTests.swift
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

import XCTest
@testable import DataBrokerProtection

final class DataBrokerTests: XCTestCase {

    func testOptOutUrlIsParent_whenOptOutUrlDoesNotContainUrl() {
            // Given
            let dataBroker = DataBroker(
                id: nil,
                name: "TestBroker",
                url: "https://primary-broker.com",
                steps: [],
                version: "1.0",
                schedulingConfig: DataBrokerScheduleConfig(retryError: 1, confirmOptOutScan: 1, maintenanceScan: 1),
                parent: nil,
                mirrorSites: [],
                optOutUrl: "https://parent-broker.com/optout"
            )

            // When
            let result = dataBroker.optOutUrlIsParent

            // Then
            XCTAssertTrue(result, "Expected optOutUrlIsParent to be true when optOutUrl does not contain the main url.")
        }

        func testOptOutUrlIsParent_whenOptOutUrlContainsUrl() {
            // Given
            let dataBroker = DataBroker(
                id: nil,
                name: "TestBroker",
                url: "https://primary-broker.com",
                steps: [],
                version: "1.0",
                schedulingConfig: DataBrokerScheduleConfig(retryError: 1, confirmOptOutScan: 1, maintenanceScan: 1),
                parent: nil,
                mirrorSites: [],
                optOutUrl: "https://primary-broker.com/optout"
            )

            // When
            let result = dataBroker.optOutUrlIsParent

            // Then
            XCTAssertFalse(result, "Expected optOutUrlIsParent to be false when optOutUrl contains the main url.")
        }
}
