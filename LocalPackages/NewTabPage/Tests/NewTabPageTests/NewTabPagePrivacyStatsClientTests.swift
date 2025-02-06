//
//  NewTabPagePrivacyStatsClientTests.swift
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

final class NewTabPagePrivacyStatsClientTests: XCTestCase {
    private var client: NewTabPagePrivacyStatsClient!
    private var model: NewTabPagePrivacyStatsModel!

    private var privacyStats: CapturingPrivacyStats!
    private var trackerDataProvider: MockPrivacyStatsTrackerDataProvider!
    private var eventMapping: CapturingNewTabPagePrivacyStatsEventHandler!
    private var settingsPersistor: UserDefaultsNewTabPagePrivacyStatsSettingsPersistor!

    private var userScript: NewTabPageUserScript!
    private var messageHelper: MessageHelper<NewTabPagePrivacyStatsClient.MessageName>!

    override func setUp() async throws {
        try await super.setUp()

        privacyStats = CapturingPrivacyStats()
        trackerDataProvider = MockPrivacyStatsTrackerDataProvider()
        eventMapping = CapturingNewTabPagePrivacyStatsEventHandler()
        settingsPersistor = UserDefaultsNewTabPagePrivacyStatsSettingsPersistor(MockKeyValueStore(), getLegacySetting: nil)

        model = NewTabPagePrivacyStatsModel(
            privacyStats: privacyStats,
            trackerDataProvider: trackerDataProvider,
            eventMapping: eventMapping,
            settingsPersistor: settingsPersistor
        )

        client = NewTabPagePrivacyStatsClient(model: model)

        userScript = NewTabPageUserScript()
        messageHelper = .init(userScript: userScript)
        client.registerMessageHandlers(for: userScript)
    }

    // MARK: - getConfig

    func testWhenPrivacyStatsViewIsExpandedThenGetConfigReturnsExpandedState() async throws {
        model.isViewExpanded = true
        let config: NewTabPageUserScript.WidgetConfig = try await messageHelper.handleMessage(named: .getConfig)
        XCTAssertEqual(config.animation, .noAnimation)
        XCTAssertEqual(config.expansion, .expanded)
    }

    func testWhenPrivacyStatsViewIsCollapsedThenGetConfigReturnsCollapsedState() async throws {
        model.isViewExpanded = false
        let config: NewTabPageUserScript.WidgetConfig = try await messageHelper.handleMessage(named: .getConfig)
        XCTAssertEqual(config.animation, .noAnimation)
        XCTAssertEqual(config.expansion, .collapsed)
    }

    // MARK: - setConfig

    func testWhenSetConfigContainsExpandedStateThenModelSettingIsSetToExpanded() async throws {
        model.isViewExpanded = false
        let config = NewTabPageUserScript.WidgetConfig(animation: .noAnimation, expansion: .expanded)
        try await messageHelper.handleMessageExpectingNilResponse(named: .setConfig, parameters: config)
        XCTAssertEqual(model.isViewExpanded, true)
    }

    func testWhenSetConfigContainsCollapsedStateThenModelSettingIsSetToCollapsed() async throws {
        model.isViewExpanded = true
        let config = NewTabPageUserScript.WidgetConfig(animation: .noAnimation, expansion: .collapsed)
        try await messageHelper.handleMessageExpectingNilResponse(named: .setConfig, parameters: config)
        XCTAssertEqual(model.isViewExpanded, false)
    }

    // MARK: - getData

    func testThatGetDataReturnsPrivacyStatsDataFromTheModel() async throws {
        let entities: [String: Entity] = [
            "A": .init(displayName: "A", domains: nil, prevalence: 6),
            "B": .init(displayName: "B", domains: nil, prevalence: 5),
            "C": .init(displayName: "C", domains: nil, prevalence: 4),
            "D": .init(displayName: "D", domains: nil, prevalence: 1),
        ]
        trackerDataProvider.trackerData = .init(trackers: [:], entities: entities, domains: [:], cnames: nil)

        // recreate the model (and client and user script) to pull in tracker data
        model = NewTabPagePrivacyStatsModel(
            privacyStats: privacyStats,
            trackerDataProvider: trackerDataProvider,
            eventMapping: eventMapping,
            settingsPersistor: settingsPersistor
        )
        privacyStats.privacyStats = ["A": 1, "B": 2, "C": 3, "D": 4, "E": 1500, "F": 100, "G": 900]

        client = NewTabPagePrivacyStatsClient(model: model)

        userScript = NewTabPageUserScript()
        messageHelper = .init(userScript: userScript)
        client.registerMessageHandlers(for: userScript)

        let data: NewTabPageDataModel.PrivacyStatsData = try await messageHelper.handleMessage(named: .getData)
        XCTAssertEqual(data, .init(totalCount: 2510, trackerCompanies: [
            .init(count: 1, displayName: "A"),
            .init(count: 2, displayName: "B"),
            .init(count: 3, displayName: "C"),
            .init(count: 4, displayName: "D"),
            .otherCompanies(count: 2500)
        ]))
    }

    func testWhenPrivacyStatsAreEmptyThenGetDataReturnsEmptyArray() async throws {
        let data: NewTabPageDataModel.PrivacyStatsData = try await messageHelper.handleMessage(named: .getData)
        XCTAssertEqual(data, .init(totalCount: 0, trackerCompanies: []))
    }

    // MARK: - showLess

    func testThatShowLessIsPassedToTheModelAndToTheEventMapping() async throws {
        try await messageHelper.handleMessageExpectingNilResponse(named: .showLess)
        XCTAssertEqual(eventMapping.events, [.showLess])
    }

    // MARK: - showMore

    func testThatShowMoreIsPassedToTheModelAndToTheEventMapping() async throws {
        try await messageHelper.handleMessageExpectingNilResponse(named: .showMore)
        XCTAssertEqual(eventMapping.events, [.showMore])
    }
}
