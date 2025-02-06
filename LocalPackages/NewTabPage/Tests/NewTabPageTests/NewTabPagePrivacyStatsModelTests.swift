//
//  NewTabPagePrivacyStatsModelTests.swift
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

import Combine
import PrivacyStats
import PersistenceTestingUtils
import TrackerRadarKit
import XCTest
@testable import NewTabPage

final class CapturingPrivacyStats: PrivacyStatsCollecting {

    var statsUpdatePublisher: AnyPublisher<Void, Never> {
        statsUpdateSubject.eraseToAnyPublisher()
    }

    let statsUpdateSubject = PassthroughSubject<Void, Never>()

    func recordBlockedTracker(_ name: String) async {
        recordBlockedTrackerCalls.append(name)
    }

    func fetchPrivacyStats() async -> [String: Int64] {
        fetchPrivacyStatsCallCount += 1
        return privacyStats
    }

    func clearPrivacyStats() async {
        clearPrivacyStatsCallCount += 1
    }

    func handleAppTermination() async {
        handleAppTerminationCallCount += 1
    }

    var recordBlockedTrackerCalls: [String] = []
    var clearPrivacyStatsCallCount: Int = 0
    var fetchPrivacyStatsCallCount: Int = 0
    var handleAppTerminationCallCount: Int = 0
    var privacyStats: [String: Int64] = [:]
}

final class MockPrivacyStatsTrackerDataProvider: PrivacyStatsTrackerDataProviding {
    var trackerData: TrackerData = .init(trackers: [:], entities: [:], domains: [:], cnames: nil)

    var trackerDataUpdatesPublisher: AnyPublisher<Void, Never> {
        trackerDataUpdatesSubject.eraseToAnyPublisher()
    }

    let trackerDataUpdatesSubject = PassthroughSubject<Void, Never>()
}

final class NewTabPagePrivacyStatsModelTests: XCTestCase {

    private var model: NewTabPagePrivacyStatsModel!
    private var privacyStats: CapturingPrivacyStats!
    private var trackerDataProvider: MockPrivacyStatsTrackerDataProvider!
    private var settingsPersistor: UserDefaultsNewTabPagePrivacyStatsSettingsPersistor!

    override func setUp() async throws {
        try await super.setUp()

        privacyStats = CapturingPrivacyStats()
        trackerDataProvider = MockPrivacyStatsTrackerDataProvider()
        settingsPersistor = UserDefaultsNewTabPagePrivacyStatsSettingsPersistor(MockKeyValueStore(), getLegacySetting: nil)
        model = NewTabPagePrivacyStatsModel(
            privacyStats: privacyStats,
            trackerDataProvider: trackerDataProvider,
            eventMapping: nil,
            settingsPersistor: settingsPersistor
        )
    }

    func testThatPrivacyStatsUpdatePublisherIsForwardedToStatsUpdatePublisher() async {
        let expectation = expectation(description: "statsUpdate")
        let cancellable = model.statsUpdatePublisher.sink { _ in expectation.fulfill() }
        privacyStats.statsUpdateSubject.send()
        await fulfillment(of: [expectation], timeout: 1)
        cancellable.cancel()
    }

    func testThatCalculatePrivacyStatsPutsNonTopCompaniesInOtherEntry() async {
        let entities: [String: Entity] = [
            "A": .init(displayName: "A", domains: nil, prevalence: 6),
            "B": .init(displayName: "B", domains: nil, prevalence: 5),
            "C": .init(displayName: "C", domains: nil, prevalence: 4),
            "D": .init(displayName: "D", domains: nil, prevalence: 1),
        ]
        trackerDataProvider.trackerData = .init(trackers: [:], entities: entities, domains: [:], cnames: nil)

        // recreate the model to pull in tracker data
        model = NewTabPagePrivacyStatsModel(
            privacyStats: privacyStats,
            trackerDataProvider: trackerDataProvider,
            eventMapping: nil,
            settingsPersistor: settingsPersistor
        )

        privacyStats.privacyStats = ["A": 1, "B": 2, "C": 3, "D": 4, "E": 1500, "F": 100, "G": 900]

        let stats: NewTabPageDataModel.PrivacyStatsData = await model.calculatePrivacyStats()

        XCTAssertEqual(stats, .init(totalCount: 2510, trackerCompanies: [
            .init(count: 1, displayName: "A"),
            .init(count: 2, displayName: "B"),
            .init(count: 3, displayName: "C"),
            .init(count: 4, displayName: "D"),
            .otherCompanies(count: 2500)
        ]))
    }

    func testThatCalculatePrivacyStatsPutsTrackersWithoutPrevalenceInOtherEntry() async {
        let entities: [String: Entity] = [
            "A": .init(displayName: "A", domains: nil, prevalence: 6),
            "B": .init(displayName: "B", domains: nil, prevalence: nil),
            "C": .init(displayName: "C", domains: nil, prevalence: 4),
            "D": .init(displayName: "D", domains: nil, prevalence: 1),
        ]
        trackerDataProvider.trackerData = .init(trackers: [:], entities: entities, domains: [:], cnames: nil)

        // recreate the model to pull in tracker data
        model = NewTabPagePrivacyStatsModel(
            privacyStats: privacyStats,
            trackerDataProvider: trackerDataProvider,
            eventMapping: nil,
            settingsPersistor: settingsPersistor
        )

        privacyStats.privacyStats = ["A": 1, "B": 2, "C": 3, "D": 4, "E": 1500, "F": 100, "G": 900]

        let stats: NewTabPageDataModel.PrivacyStatsData = await model.calculatePrivacyStats()

        XCTAssertEqual(stats, .init(totalCount: 2510, trackerCompanies: [
            .init(count: 1, displayName: "A"),
            .init(count: 3, displayName: "C"),
            .init(count: 4, displayName: "D"),
            .otherCompanies(count: 2502)
        ]))
    }

    func testWhenIsViewExpandedIsUpdatedThenPersistorIsUpdated() {
        model.isViewExpanded = true
        XCTAssertTrue(settingsPersistor.isViewExpanded)

        model.isViewExpanded = false
        XCTAssertFalse(settingsPersistor.isViewExpanded)

        model.isViewExpanded = true
        XCTAssertTrue(settingsPersistor.isViewExpanded)
    }
}
