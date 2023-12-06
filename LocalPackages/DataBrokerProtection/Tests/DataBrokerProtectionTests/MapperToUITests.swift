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

        XCTAssertEqual(result.scanProgress.currentScans, 0)
        XCTAssertTrue(result.resultsFound.isEmpty)
    }

    func testWhenBrokerHasMoreThanOneProfileQuery_thenIsCountedAsOneInTotalScans() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1"),
            .mock(dataBrokerName: "Broker #1"),
            .mock(dataBrokerName: "Broker #2")
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, 2)
    }

    func testWhenAScanRanOnOneBroker_thenCurrentScansReflectsThatScansWereDoneOnThatBroker() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1"),
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #2")
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.currentScans, 1)
        XCTAssertTrue(result.resultsFound.isEmpty)
    }

    func testWhenAScanRanAndHasAMatch_thenResultsFoundIsUpdated() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [.mock(), .mock(), .mock(lastRunDate: Date(), extractedProfile: .mockWithoutRemovedDate)]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.resultsFound.count, 1)
    }

    func testWhenAScanRanAndHasAMatchForTheSameBroker_thenMatchesReflectsTheCorrectValue() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1"),
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date(), extractedProfile: .mockWithoutRemovedDate),
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date(), extractedProfile: .mockWithoutRemovedDate)
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.resultsFound.count, 2)
    }

    func testWhenAllScansRan_thenCurrentScansEqualsTotalScans() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #2", lastRunDate: Date())
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, result.scanProgress.currentScans)
    }

    func testWhenScansHaveDeprecatedProfileQueries_thenThoseAreNotTakenIntoAccount() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date(), extractedProfile: .mockWithRemovedDate),
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #2", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #3", lastRunDate: Date(), extractedProfile: .mockWithRemovedDate, deprecated: true)
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, 2)
        XCTAssertEqual(result.scanProgress.currentScans, 2)
        XCTAssertEqual(result.resultsFound.count, 1)
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

    func testSitesScanned_areMappedCorrectly() {
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
        XCTAssertTrue(areDatesEqualsOnDayMonthAndYear(date1: Date().yesterday, date2: Date(timeIntervalSince1970: result.scanSchedule.lastScan.date)))
    }

    func testNextScans_areMappedCorrectly() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", preferredRunDate: Date().tomorrow),
            .mock(dataBrokerName: "Broker #2", preferredRunDate: Date().tomorrow),
            .mock(dataBrokerName: "Broker #3")
        ]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanSchedule.nextScan.dataBrokers.count, 2)
        XCTAssertTrue(areDatesEqualsOnDayMonthAndYear(date1: Date().tomorrow, date2: Date(timeIntervalSince1970: result.scanSchedule.nextScan.date)))
    }

    func testWhenMirrorSiteIsNotInRemovedPeriod_thenItShouldBeAddedToTotalScans() {
        let brokerProfileQueryWithMirrorSite: BrokerProfileQueryData = .mock(dataBrokerName: "Broker #1", mirrorSites: [.init(name: "mirror", addedAt: Date(), removedAt: nil)])
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            brokerProfileQueryWithMirrorSite,
            brokerProfileQueryWithMirrorSite,
            brokerProfileQueryWithMirrorSite
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, 2)
    }

    func testWhenMirrorSiteIsInRemovedPeriod_thenItShouldNotBeAddedToTotalScans() {
        let brokerWithMirrorSiteThatWasRemoved = BrokerProfileQueryData.mock(dataBrokerName: "Broker #1", mirrorSites: [.init(name: "mirror", addedAt: Date(), removedAt: Date().yesterday)])
        let brokerProfileQueryData: [BrokerProfileQueryData] = [.mock(dataBrokerName: "Broker #1"), brokerWithMirrorSiteThatWasRemoved, .mock(dataBrokerName: "Broker #2")]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, 2)
    }

    func testWhenMirrorSiteIsNotInRemovedPeriod_thenItShouldBeAddedToCurrentScans() {
        let brokerWithMirrorSiteNotRemovedAndWithScan = BrokerProfileQueryData.mock(
            dataBrokerName: "Broker #1",
            lastRunDate: Date(),
            mirrorSites: [.init(name: "mirror", addedAt: Date(), removedAt: nil)]
        )
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            brokerWithMirrorSiteNotRemovedAndWithScan,
            brokerWithMirrorSiteNotRemovedAndWithScan,
            .mock(dataBrokerName: "Broker #2")
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.currentScans, 2)
    }

    func testWhenMirrorSiteIsInRemovedPeriod_thenItShouldNotBeAddedToCurrentScans() {
        let brokerWithMirrorSiteRemovedAndWithScan = BrokerProfileQueryData.mock(
            lastRunDate: Date(),
            mirrorSites: [.init(name: "mirror", addedAt: Date(), removedAt: Date().yesterday)]
        )
        let brokerProfileQueryData: [BrokerProfileQueryData] = [.mock(), .mock(), brokerWithMirrorSiteRemovedAndWithScan]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.currentScans, 1)
    }

    func testWhenMirrorSiteIsNotInRemovedPeriod_thenMatchIsAdded() {
        let brokerWithMirrorSiteNotRemovedAndWithMatch = BrokerProfileQueryData.mock(
            extractedProfile: .mockWithoutRemovedDate,
            mirrorSites: [.init(name: "mirror", addedAt: Date(), removedAt: nil)]
        )
        let brokerProfileQueryData: [BrokerProfileQueryData] = [.mock(), .mock(), brokerWithMirrorSiteNotRemovedAndWithMatch]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.resultsFound.count, 2)
    }

    func testWhenMirrorSiteIsInRemovedPeriod_thenMatchIsNotAdded() {
        let brokerWithMirrorSiteRemovedAndWithMatch = BrokerProfileQueryData.mock(
            extractedProfile: .mockWithoutRemovedDate,
            mirrorSites: [.init(name: "mirror", addedAt: Date(), removedAt: Date().yesterday)]
        )
        let brokerProfileQueryData: [BrokerProfileQueryData] = [.mock(), .mock(), brokerWithMirrorSiteRemovedAndWithMatch]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.resultsFound.count, 1)
    }

    func testMirrorSites_areCorrectlyMappedToInProgressOptOuts() {
        let scanHistoryEventsWithMatchesFound: [HistoryEvent] = [.init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 1), date: Date())]
        let mirrorSiteNotRemoved = MirrorSite(name: "mirror #1", addedAt: Date.distantPast, removedAt: nil)
        let mirrorSiteRemoved = MirrorSite(name: "mirror #2", addedAt: Date.distantPast, removedAt: Date().yesterday) // Should not be added
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(extractedProfile: .mockWithoutRemovedDate,
                  scanHistoryEvents: scanHistoryEventsWithMatchesFound,
                  mirrorSites: [mirrorSiteNotRemoved, mirrorSiteRemoved])
        ]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.inProgressOptOuts.count, 2)
    }

    func testWhenMirrorSiteRemovedIsInRangeToPastRemovedProfile_thenIsAddedToCompletedOptOuts() {
        let scanHistoryEventsWithMatchesFound: [HistoryEvent] = [.init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 1), date: Date().yesterday!)]
        let mirrorSiteRemoved = MirrorSite(name: "mirror #1", addedAt: Date.distantPast, removedAt: Date()) // Should be added
        // The next two mirror sites should not be added. New mirror sites should not count for old opt-outs
        let newMirrorSiteOne = MirrorSite(name: "mirror #2", addedAt: Date(), removedAt: nil)
        let newMirrorSiteTwo = MirrorSite(name: "mirror #3", addedAt: Date(), removedAt: nil)
        let brokerProfileQuery = BrokerProfileQueryData.mock(extractedProfile: .mockWithRemoveDate(Date().yesterday!),
                                                             scanHistoryEvents: scanHistoryEventsWithMatchesFound,
                                                             mirrorSites: [mirrorSiteRemoved, newMirrorSiteOne, newMirrorSiteTwo])
        let brokerProfileQueryData: [BrokerProfileQueryData] = [brokerProfileQuery]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.completedOptOuts.count, 2)
    }

    func testLastScansWithMirrorSites_areMappedCorrectly() {
        let includedMirrorSite = MirrorSite(name: "mirror #1", addedAt: Date.distantPast, removedAt: nil)
        let notIncludedMirrorSite = MirrorSite(name: "mirror #2", addedAt: Date(), removedAt: nil)
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date().yesterday, mirrorSites: [includedMirrorSite, notIncludedMirrorSite]),
            .mock(dataBrokerName: "Broker #2", lastRunDate: Date().yesterday),
            .mock(dataBrokerName: "Broker #3")
        ]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanSchedule.lastScan.dataBrokers.count, 3)
        XCTAssertTrue(areDatesEqualsOnDayMonthAndYear(date1: Date().yesterday, date2: Date(timeIntervalSince1970: result.scanSchedule.lastScan.date)))
    }

    func testNextScansWithMirrorSites_areMappedCorrectly() {
        let includedMirrorSite = MirrorSite(name: "mirror #1", addedAt: Date.distantPast, removedAt: nil)
        let notIncludedMirrorSite = MirrorSite(name: "mirror #2", addedAt: Date.distantPast, removedAt: Date())
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", preferredRunDate: Date().tomorrow, mirrorSites: [includedMirrorSite, notIncludedMirrorSite]),
            .mock(dataBrokerName: "Broker #2", preferredRunDate: Date().tomorrow),
            .mock(dataBrokerName: "Broker #3")
        ]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanSchedule.nextScan.dataBrokers.count, 3)
        XCTAssertTrue(areDatesEqualsOnDayMonthAndYear(date1: Date().tomorrow, date2: Date(timeIntervalSince1970: result.scanSchedule.nextScan.date)))
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
