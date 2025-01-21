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

    func testWhenAScanRanOnAllProfileQueriesOnTheSameBroker_thenScannedBrokersAndCurrentScansReflectsThat() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #2")
        ]

        let expected: [DBPUIScanProgress.ScannedBroker] = [
            .mock("Broker #1", status: .completed),
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.currentScans, brokerProfileQueryData.legacyCurrentScans)
        XCTAssertEqual(result.scanProgress.currentScans, expected.completeBrokerScansCount)
        XCTAssertEqual(result.scanProgress.scannedBrokers.count, expected.count)
        XCTAssertEqual(result.scanProgress.scannedBrokers.first!.name, expected.first!.name)
        XCTAssertTrue(result.resultsFound.isEmpty)
    }

    func testWhenAScanRanOnOneProfileQueryOnTheSameBroker_thenScannedBrokersAndCurrentScansReflectsThat() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #1"),
            .mock(dataBrokerName: "Broker #2")
        ]

        let expected: [DBPUIScanProgress.ScannedBroker] = [
            .mock("Broker #1", status: .inProgress),
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.currentScans, brokerProfileQueryData.legacyCurrentScans)
        XCTAssertEqual(result.scanProgress.currentScans, expected.completeBrokerScansCount)
        XCTAssertEqual(result.scanProgress.scannedBrokers.count, expected.count)
        XCTAssertEqual(result.scanProgress.scannedBrokers.first!.name, expected.first!.name)
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

    func testWhenAllScansRan_thenScannedBrokersAndCurrentScansEqualsTotalScans() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #2", lastRunDate: Date())
        ]

        let expected: [DBPUIScanProgress.ScannedBroker] = [
            .mock("Broker #1", status: .completed),
            .mock("Broker #2", status: .completed),
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, result.scanProgress.currentScans)
        XCTAssertEqual(result.scanProgress.currentScans, brokerProfileQueryData.legacyCurrentScans)
        XCTAssertEqual(result.scanProgress.currentScans, expected.completeBrokerScansCount)
        XCTAssertEqual(result.scanProgress.scannedBrokers.count, expected.count)
        XCTAssertEqual(result.scanProgress.scannedBrokers.map{ $0.name }.sorted(), expected.map(\.name))
    }

    func testWhenScansHaveDeprecatedProfileQueries_thenThoseAreNotTakenIntoAccount() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date(), extractedProfile: .mockWithRemovedDate),
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #2", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #3", lastRunDate: Date(), extractedProfile: .mockWithRemovedDate, deprecated: true)
        ]

        let expected: [DBPUIScanProgress.ScannedBroker] = [
            .mock("Broker #1", status: .completed),
            .mock("Broker #2", status: .completed),
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, 2)
        XCTAssertEqual(result.scanProgress.currentScans, brokerProfileQueryData.legacyCurrentScans)
        XCTAssertEqual(result.scanProgress.currentScans, expected.completeBrokerScansCount)
        XCTAssertEqual(result.scanProgress.scannedBrokers.count, expected.count)
        XCTAssertEqual(result.scanProgress.scannedBrokers.map{ $0.name }.sorted(), expected.map(\.name))
        XCTAssertEqual(result.resultsFound.count, 1)
    }

    func testWhenScansHaveDeprecatedProfileQueriesThatDidNotRun_thenThoseAreNotTakenIntoAccount() {
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date(), extractedProfile: .mockWithRemovedDate),
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #1", lastRunDate: nil, deprecated: true),
            .mock(dataBrokerName: "Broker #2", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #3", lastRunDate: Date(), extractedProfile: .mockWithRemovedDate, deprecated: true)
        ]

        let expected: [DBPUIScanProgress.ScannedBroker] = [
            .mock("Broker #1", status: .completed),
            .mock("Broker #2", status: .completed),
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, 2)
        XCTAssertEqual(result.scanProgress.currentScans, brokerProfileQueryData.legacyCurrentScans)
        XCTAssertEqual(result.scanProgress.currentScans, expected.completeBrokerScansCount)
        XCTAssertEqual(result.scanProgress.scannedBrokers.count, expected.count)
        XCTAssertEqual(result.scanProgress.scannedBrokers.map{ $0.name }.sorted(), expected.map(\.name))
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
        var dateComponent = DateComponents()
        dateComponent.day = -10
        let date10daysAgo = Calendar.current.date(byAdding: dateComponent, to: Date())!

        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", url: "broker1.com", lastRunDate: Date().yesterday),
            .mock(dataBrokerName: "Broker #2", url: "broker2.com", lastRunDate: Date().yesterday),
            .mock(dataBrokerName: "Broker #3", url: "broker3.com", lastRunDate: date10daysAgo),
            .mock(dataBrokerName: "Broker #4", url: "broker4.com")
        ]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanSchedule.lastScan.dataBrokers.count, 2)
        XCTAssertTrue(areDatesEqualsOnDayMonthAndYear(date1: Date().yesterday, date2: Date(timeIntervalSince1970: result.scanSchedule.lastScan.date)))
    }

    func testNextScans_areMappedCorrectly() {
        var dateComponent = DateComponents()
        dateComponent.day = 10
        let date10daysFromNow = Calendar.current.date(byAdding: dateComponent, to: Date())!

        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", url: "broker1.com", preferredRunDate: Date().tomorrow),
            .mock(dataBrokerName: "Broker #2", url: "broker2.com", preferredRunDate: Date().tomorrow),
            .mock(dataBrokerName: "Broker #3", url: "broker3.com", preferredRunDate: date10daysFromNow),
            .mock(dataBrokerName: "Broker #4", url: "broker4.com")
        ]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanSchedule.nextScan.dataBrokers.count, 2)
        XCTAssertTrue(areDatesEqualsOnDayMonthAndYear(date1: Date().tomorrow, date2: Date(timeIntervalSince1970: result.scanSchedule.nextScan.date)))
    }

    func testWhenMirrorSiteIsNotInRemovedPeriod_thenItShouldBeAddedToTotalScans() {
        let brokerProfileQueryWithMirrorSite: BrokerProfileQueryData = .mock(dataBrokerName: "Broker #1", mirrorSites: [.init(name: "mirror", url: "mirror1.com", addedAt: Date(), removedAt: nil)])
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            brokerProfileQueryWithMirrorSite,
            brokerProfileQueryWithMirrorSite,
            brokerProfileQueryWithMirrorSite
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, 2)
    }

    func testWhenMirrorSiteIsInRemovedPeriod_thenItShouldNotBeAddedToTotalScans() {
        let brokerWithMirrorSiteThatWasRemoved = BrokerProfileQueryData.mock(dataBrokerName: "Broker #1", mirrorSites: [.init(name: "mirror", url: "mirror1.com", addedAt: Date(), removedAt: Date().yesterday)])
        let brokerProfileQueryData: [BrokerProfileQueryData] = [.mock(dataBrokerName: "Broker #1"), brokerWithMirrorSiteThatWasRemoved, .mock(dataBrokerName: "Broker #2")]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.totalScans, 2)
    }

    func testWhenMirrorSiteIsNotInRemovedPeriod_thenItShouldBeAddedToScannedBrokersAndCurrentScans() {
        let brokerWithMirrorSiteNotRemovedAndWithScan = BrokerProfileQueryData.mock(
            dataBrokerName: "Broker #1",
            lastRunDate: Date(),
            mirrorSites: [.init(name: "mirror", url: "mirror.com", addedAt: Date(), removedAt: nil)]
        )
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            brokerWithMirrorSiteNotRemovedAndWithScan,
            brokerWithMirrorSiteNotRemovedAndWithScan,
            .mock(dataBrokerName: "Broker #2")
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.currentScans, 2)
        XCTAssertEqual(result.scanProgress.scannedBrokers.count, result.scanProgress.currentScans)
        XCTAssertEqual(result.scanProgress.scannedBrokers.map{ $0.name }.sorted(), ["Broker #1", "mirror"])
    }

    func testWhenMirrorSiteIsInRemovedPeriod_thenItShouldNotBeAddedToScannedBrokersCurrentScans() {
        let brokerWithMirrorSiteRemovedAndWithScan = BrokerProfileQueryData.mock(
            dataBrokerName: "Broker #2",
            lastRunDate: Date(),
            mirrorSites: [.init(name: "mirror", url: "mirror1.com", addedAt: Date(), removedAt: Date().yesterday)]
        )
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1"),
            .mock(dataBrokerName: "Broker #1"),
            brokerWithMirrorSiteRemovedAndWithScan
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.currentScans, 1)
        XCTAssertEqual(result.scanProgress.scannedBrokers.count, result.scanProgress.currentScans)
        XCTAssertEqual(result.scanProgress.scannedBrokers.map{ $0.name }.sorted(), ["Broker #2"])
    }

    func testWhenMirrorSiteIsNotInRemovedPeriod_thenMatchIsAdded() {
        let brokerWithMirrorSiteNotRemovedAndWithMatch = BrokerProfileQueryData.mock(
            extractedProfile: .mockWithoutRemovedDate,
            mirrorSites: [.init(name: "mirror", url: "mirror1.com", addedAt: Date(), removedAt: nil)]
        )
        let brokerProfileQueryData: [BrokerProfileQueryData] = [.mock(), .mock(), brokerWithMirrorSiteNotRemovedAndWithMatch]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.resultsFound.count, 2)
    }

    func testWhenMirrorSiteIsInRemovedPeriod_thenMatchIsNotAdded() {
        let brokerWithMirrorSiteRemovedAndWithMatch = BrokerProfileQueryData.mock(
            extractedProfile: .mockWithoutRemovedDate,
            mirrorSites: [.init(name: "mirror", url: "mirror1.com", addedAt: Date(), removedAt: Date().yesterday)]
        )
        let brokerProfileQueryData: [BrokerProfileQueryData] = [.mock(), .mock(), brokerWithMirrorSiteRemovedAndWithMatch]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.resultsFound.count, 1)
    }

    func testMirrorSites_areCorrectlyMappedToInProgressOptOuts() {
        let scanHistoryEventsWithMatchesFound: [HistoryEvent] = [.init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 1), date: Date())]
        let mirrorSiteNotRemoved = MirrorSite(name: "mirror #1", url: "mirror1.com", addedAt: Date.distantPast, removedAt: nil)
        let mirrorSiteRemoved = MirrorSite(name: "mirror #2", url: "mirror2.com", addedAt: Date.distantPast, removedAt: Date().yesterday) // Should not be added
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
        let mirrorSiteRemoved = MirrorSite(name: "mirror #1", url: "mirror1.com", addedAt: Date.distantPast, removedAt: Date()) // Should be added
        // The next two mirror sites should not be added. New mirror sites should not count for old opt-outs
        let newMirrorSiteOne = MirrorSite(name: "mirror #2", url: "mirror2.com", addedAt: Date(), removedAt: nil)
        let newMirrorSiteTwo = MirrorSite(name: "mirror #3", url: "mirror3.com", addedAt: Date(), removedAt: nil)
        let brokerProfileQuery = BrokerProfileQueryData.mock(extractedProfile: .mockWithRemoveDate(Date().yesterday!),
                                                             scanHistoryEvents: scanHistoryEventsWithMatchesFound,
                                                             mirrorSites: [mirrorSiteRemoved, newMirrorSiteOne, newMirrorSiteTwo])
        let brokerProfileQueryData: [BrokerProfileQueryData] = [brokerProfileQuery]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.completedOptOuts.count, 2)
    }

    func testLastScansWithMirrorSites_areMappedCorrectly() {
        let includedMirrorSite = MirrorSite(name: "mirror #1", url: "mirror1.com", addedAt: Date.distantPast, removedAt: nil)
        let notIncludedMirrorSite = MirrorSite(name: "mirror #2", url: "mirror2.com", addedAt: Date(), removedAt: nil)
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", url: "broker1.com", lastRunDate: Date().yesterday, mirrorSites: [includedMirrorSite, notIncludedMirrorSite]),
            .mock(dataBrokerName: "Broker #2", url: "broker2.com", lastRunDate: Date().yesterday),
            .mock(dataBrokerName: "Broker #3", url: "broker3.com")
        ]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanSchedule.lastScan.dataBrokers.count, 3)
        XCTAssertTrue(areDatesEqualsOnDayMonthAndYear(date1: Date().yesterday, date2: Date(timeIntervalSince1970: result.scanSchedule.lastScan.date)))
    }

    func testNextScansWithMirrorSites_areMappedCorrectly() {
        let includedMirrorSite = MirrorSite(name: "mirror #1", url: "mirror1.com", addedAt: Date.distantPast, removedAt: nil)
        let notIncludedMirrorSite = MirrorSite(name: "mirror #2", url: "mirror2.com", addedAt: Date.distantPast, removedAt: Date())
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", url: "broker1.com", preferredRunDate: Date().tomorrow, mirrorSites: [includedMirrorSite, notIncludedMirrorSite]),
            .mock(dataBrokerName: "Broker #2", url: "broker2.com", preferredRunDate: Date().tomorrow),
            .mock(dataBrokerName: "Broker #3", url: "broker3.com")
        ]

        let result = sut.maintenanceScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanSchedule.nextScan.dataBrokers.count, 3)
        XCTAssertTrue(areDatesEqualsOnDayMonthAndYear(date1: Date().tomorrow, date2: Date(timeIntervalSince1970: result.scanSchedule.nextScan.date)))
    }

    func testBrokersWithMixedScanProgress_areOrderedByLastRunDate_andHaveCorrectStatus() {

        // Given
        let minusTwoHours = Date.minusTwoHours
        let minusThreeHours = Date.minusThreeHours
        let brokerProfileQueryData: [BrokerProfileQueryData] = [
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #1", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #1", lastRunDate: minusTwoHours),
            .mock(dataBrokerName: "Broker #2"),
            .mock(dataBrokerName: "Broker #2", lastRunDate: .minusOneHour),
            .mock(dataBrokerName: "Broker #2", lastRunDate: minusThreeHours),
            .mock(dataBrokerName: "Broker #3", lastRunDate: minusTwoHours),
            .mock(dataBrokerName: "Broker #3"),
            .mock(dataBrokerName: "Broker #3", lastRunDate: Date()),
            .mock(dataBrokerName: "Broker #4"),
            .mock(dataBrokerName: "Broker #5"),
            .mock(dataBrokerName: "Broker #7", lastRunDate: minusThreeHours),
            .mock(dataBrokerName: "Broker #6", lastRunDate: minusThreeHours)
        ]

        let expected: [DBPUIScanProgress.ScannedBroker] = [
            .mock("Broker #2", status: .inProgress),
            .mock("Broker #6", status: .completed),
            .mock("Broker #7", status: .completed),
            .mock("Broker #1", status: .completed),
            .mock("Broker #3", status: .inProgress)
        ]

        let result = sut.initialScanState(brokerProfileQueryData)

        XCTAssertEqual(result.scanProgress.currentScans, 3)
        XCTAssertEqual(result.scanProgress.scannedBrokers, expected)
    }

    // MARK: - `maintenanceScanState` Broker OptOut URL & Name tests

    func testMaintenanceScanState_childBrokerWithOwnOptOutUrl() {
        // Given
        let extractedProfile = ExtractedProfile(id: 2, name: "Another Sample", profileUrl: "anotherprofile.com", removedDate: nil)

        let childBroker = BrokerProfileQueryData.mock(
            dataBrokerName: "ChildBrokerWithOwnOptOut",
            url: "child.com",
            parentURL: "parent.com",
            optOutUrl: "child.com/optout",
            extractedProfile: extractedProfile
        )

        let parentBroker = BrokerProfileQueryData.mock(
            dataBrokerName: "ParentBroker",
            url: "parent.com",
            optOutUrl: "parent.com/optout",
            extractedProfile: extractedProfile
        )

        // When
        let state = sut.maintenanceScanState([childBroker, parentBroker])

        // Then
        XCTAssertEqual(state.inProgressOptOuts.count, 2)
        XCTAssertEqual(state.completedOptOuts.count, 0)

        let childProfile = state.inProgressOptOuts.first { $0.dataBroker.name == "ChildBrokerWithOwnOptOut" }
        XCTAssertEqual(childProfile?.dataBroker.optOutUrl, "child.com/optout")

        let parentProfile = state.inProgressOptOuts.first { $0.dataBroker.name == "ParentBroker" }
        XCTAssertEqual(parentProfile?.dataBroker.optOutUrl, "parent.com/optout")
    }

    func testMaintenanceScanState_childBrokerWithParentOptOutUrl() {
        // Given
        let extractedProfile = ExtractedProfile(id: 1, name: "Sample Name", profileUrl: "profile.com", removedDate: nil)

        let childBroker = BrokerProfileQueryData.mock(
            dataBrokerName: "ChildBroker",
            url: "child.com",
            parentURL: "parent.com",
            optOutUrl: "parent.com/optout",
            extractedProfile: extractedProfile
        )

        let parentBroker = BrokerProfileQueryData.mock(
            dataBrokerName: "ParentBroker",
            url: "parent.com",
            optOutUrl: "parent.com/optout",
            extractedProfile: extractedProfile
        )

        // When
        let state = sut.maintenanceScanState([childBroker, parentBroker])

        // Then
        XCTAssertEqual(state.inProgressOptOuts.count, 2)
        XCTAssertEqual(state.completedOptOuts.count, 0)

        let childProfile = state.inProgressOptOuts.first { $0.dataBroker.name == "ChildBroker" }
        XCTAssertEqual(childProfile?.dataBroker.optOutUrl, "parent.com/optout")

        let parentProfile = state.inProgressOptOuts.first { $0.dataBroker.name == "ParentBroker" }
        XCTAssertEqual(childProfile?.dataBroker.optOutUrl, "parent.com/optout")
    }
}

extension DBPUIScanProgress.ScannedBroker {
    static func mock(_ name: String, status: Self.Status) -> DBPUIScanProgress.ScannedBroker {
        .init(name: name, url: "test.com", status: status)
    }
}

extension Array where Element == BrokerProfileQueryData {
    /// Number of completed broker scans, the way it was calculated prior to the introduction of scannedBrokers (1.94.0)
    fileprivate var legacyCurrentScans: Int {
        filteredProfileQueriesGroupedByBroker.reduce(0) { accumulator, element in
            return accumulator + element.value.currentScans
        }
    }

    private var filteredProfileQueriesGroupedByBroker: [String: [BrokerProfileQueryData]] {
        let profileQueriesGroupedByBroker = Dictionary(grouping: self, by: { $0.dataBroker.name })
        return profileQueriesGroupedByBroker.mapValues { queries in
            queries.filter { !$0.profileQuery.deprecated }
        }
    }

    private var currentScans: Int {
        guard let broker = self.first?.dataBroker else { return 0 }

        let didAllQueriesFinished = allSatisfy { $0.scanJobData.lastRunDate != nil }

        if !didAllQueriesFinished {
            return 0
        } else {
            return 1 + broker.mirrorSites.filter { $0.shouldWeIncludeMirrorSite() }.count
        }
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

    static var minusOneHour: Date? {
        nowMinusHour(1)
    }

    static var minusTwoHours: Date? {
        nowMinusHour(2)
    }

    static var minusThreeHours: Date? {
        nowMinusHour(3)
    }

    private static func nowMinusHour(_ hour: Int) -> Date? {
        let calendar = Calendar.current
        return calendar.date(byAdding: .hour, value: -hour, to: Date())
    }
}
