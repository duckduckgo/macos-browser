//
//  DataBrokerTests.swift
//  DataBrokerProtection
//
//  Created by Pete Smith on 27/10/2024.
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
