//
//  MapperToUITests.swift
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

final class MapperToUITests: XCTestCase {

    private let sut = MapperToUI()

    func testWhenNoScansRanYet_thenCurrentScansAndMatchesAreEmpty() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [.mock(), .mock(), .mock()]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, brokerProfileQueryData.count)
        XCTAssertEqual(result.scanProgress.currentScans, 0)
        XCTAssertTrue(result.resultsFound.isEmpty)
    }

    func testWhenAScanRan_thenCurrentScansGetsUpdated() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [.mock(), .mock(), .mock(lastRunDate: Date())]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, brokerProfileQueryData.count)
        XCTAssertEqual(result.scanProgress.currentScans, 1)
        XCTAssertTrue(result.resultsFound.isEmpty)
    }

    func testWhenAScanRanAndHasAMatch_thenResultsFoundIsUpdated() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [.mock(), .mock(), .mock(lastRunDate: Date(), extractedProfile: .mockWithRemovedDate)]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, brokerProfileQueryData.count)
        XCTAssertEqual(result.scanProgress.currentScans, 1)
        XCTAssertEqual(result.resultsFound.count, 1)
    }

    func testWhenAllScansRan_thenCurrentScansEqualsTotalScans() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [.mock(lastRunDate: Date()), .mock(lastRunDate: Date()), .mock(lastRunDate: Date())]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, result.scanProgress.currentScans)
    }

    func testInProgressAndCompletedOptOuts_areMappedCorrectly() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(extractedProfile: .mockWithRemovedDate),
            .mock(extractedProfile: .mockWithoutRemovedDate),
            .mock(extractedProfile: .mockWithoutRemovedDate)
        ]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.completedOptOuts.count, 1)
        XCTAssertEqual(result.inProgressOptOuts.count, 2)
    }

    func testSitesScannedAndCompleted_areMappedCorrectly() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1",
                  lastRunDate: Date(),
                  scanHistoryEvents: [
                    .init(brokerId: 1, profileQueryId: 1, type: .scanStarted),
                    .init(brokerId: 1, profileQueryId: 1, type: .scanStarted)]),
            .mock(dataBrokerName: "Broker #2",
                  lastRunDate: Date(),
                  scanHistoryEvents: [
                    .init(brokerId: 1, profileQueryId: 1, type: .scanStarted),
                    .init(brokerId: 1, profileQueryId: 1, type: .scanStarted)]),
            .mock(dataBrokerName: "Broker #3")
        ]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanHistory.scansCompleted, 4)
        XCTAssertEqual(result.scanHistory.sitesScanned, 2)
    }

    func testLastScans_areMappedCorrectly() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date().yesterday),
            .mock(dataBrokerName: "Broker #2", lastRunDate: Date().yesterday),
            .mock(dataBrokerName: "Broker #3")
        ]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanSchedule.lastScan.dataBrokers.count, 2)
        XCTAssertTrue(areDatesEqualsOnDayMonthAndYear(date1: Date().yesterday, date2: result.scanSchedule.lastScan.date))
    }

    func testNextScans_areMappedCorrectly() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", preferredRunDate: Date().tomorrow),
            .mock(dataBrokerName: "Broker #2", preferredRunDate: Date().tomorrow),
            .mock(dataBrokerName: "Broker #3")
        ]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanSchedule.nextScan.dataBrokers.count, 2)
        XCTAssertTrue(areDatesEqualsOnDayMonthAndYear(date1: Date().tomorrow, date2: result.scanSchedule.nextScan.date))
    }
}

extension Date {

    var yesterday: Date? {
        let calendar = Calendar.current

        return calendar.date(byAdding: .day, value: -1, to: self)
    }

    var tomorrow: Date? {
        let calendar = Calendar.current

        return calendar.date(byAdding: .day, value: 1, to: self)
    }
}
