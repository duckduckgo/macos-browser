//
//  NewTabPageConfigurationClientTests.swift
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

import AppKit
import Combine
import XCTest
@testable import NewTabPage

final class NewTabPageConfigurationClientTests: XCTestCase {
    private var client: NewTabPageConfigurationClient!
    private var sectionsAvailabilityProvider: MockNewTabPageSectionsAvailabilityProvider!
    private var sectionsVisibilityProvider: MockNewTabPageSectionsVisibilityProvider!
    private var contextMenuPresenter: CapturingNewTabPageContextMenuPresenter!
    private var userScript: NewTabPageUserScript!
    private var messageHelper: MessageHelper<NewTabPageConfigurationClient.MessageName>!
    private var eventMapper: CapturingNewTabPageConfigurationEventHandler!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sectionsAvailabilityProvider = MockNewTabPageSectionsAvailabilityProvider()
        sectionsVisibilityProvider = MockNewTabPageSectionsVisibilityProvider()
        contextMenuPresenter = CapturingNewTabPageContextMenuPresenter()
        eventMapper = CapturingNewTabPageConfigurationEventHandler()
        client = NewTabPageConfigurationClient(
            sectionsAvailabilityProvider: sectionsAvailabilityProvider,
            sectionsVisibilityProvider: sectionsVisibilityProvider,
            customBackgroundProvider: CapturingNewTabPageCustomBackgroundProvider(),
            contextMenuPresenter: contextMenuPresenter,
            linkOpener: CapturingNewTabPageLinkOpener(),
            eventMapper: eventMapper
        )

        userScript = NewTabPageUserScript()
        messageHelper = .init(userScript: userScript)
        client.registerMessageHandlers(for: userScript)
    }

    // MARK: - contextMenu

    @MainActor
    func testThatContextMenuShowsContextMenu() async throws {
        sectionsVisibilityProvider.isFavoritesVisible = true
        sectionsVisibilityProvider.isPrivacyStatsVisible = false

        let parameters = NewTabPageDataModel.ContextMenuParams(visibilityMenuItems: [
            .init(id: .favorites, title: "Favorites"),
            .init(id: .privacyStats, title: "Privacy Stats")
        ])
        try await messageHelper.handleMessageExpectingNilResponse(named: .contextMenu, parameters: parameters)

        XCTAssertEqual(contextMenuPresenter.showContextMenuCalls.count, 1)
        let menu = try XCTUnwrap(contextMenuPresenter.showContextMenuCalls.first)
        XCTAssertEqual(menu.items.count, 2)
        XCTAssertEqual(menu.items[0].title, "Favorites")
        XCTAssertEqual(menu.items[0].state, .on)
        XCTAssertEqual(menu.items[1].title, "Privacy Stats")
        XCTAssertEqual(menu.items[1].state, .off)
    }

    func testWhenContextMenuParamsIsEmptyThenContextMenuDoesNotShow() async throws {
        let parameters = NewTabPageDataModel.ContextMenuParams(visibilityMenuItems: [])
        try await messageHelper.handleMessageExpectingNilResponse(named: .contextMenu, parameters: parameters)

        XCTAssertEqual(contextMenuPresenter.showContextMenuCalls.count, 0)
    }

    // MARK: - initialSetup

    func testThatInitialSetupReturnsConfiguration() async throws {
        sectionsAvailabilityProvider.isPrivacyStatsAvailable = false
        sectionsAvailabilityProvider.isRecentActivityAvailable = false

        let configuration: NewTabPageDataModel.NewTabPageConfiguration = try await messageHelper.handleMessage(named: .initialSetup)
        XCTAssertEqual(configuration.widgets, [
            .init(id: .rmf),
            .init(id: .freemiumPIRBanner),
            .init(id: .nextSteps),
            .init(id: .favorites)
        ])
        XCTAssertEqual(configuration.widgetConfigs, [
            .init(id: .favorites, isVisible: sectionsVisibilityProvider.isFavoritesVisible)
        ])
        XCTAssertEqual(configuration.platform, .init(name: "macos"))
    }

    func testThatInitialSetupContainsPrivacyStatsWhenAvailable() async throws {
        sectionsAvailabilityProvider.isPrivacyStatsAvailable = true
        sectionsAvailabilityProvider.isRecentActivityAvailable = false

        let configuration: NewTabPageDataModel.NewTabPageConfiguration = try await messageHelper.handleMessage(named: .initialSetup)
        XCTAssertEqual(configuration.widgets, [
            .init(id: .rmf),
            .init(id: .freemiumPIRBanner),
            .init(id: .nextSteps),
            .init(id: .favorites),
            .init(id: .privacyStats)
        ])
        XCTAssertEqual(configuration.widgetConfigs, [
            .init(id: .favorites, isVisible: sectionsVisibilityProvider.isFavoritesVisible),
            .init(id: .privacyStats, isVisible: sectionsVisibilityProvider.isPrivacyStatsVisible)
        ])
        XCTAssertEqual(configuration.platform, .init(name: "macos"))
    }

    func testThatInitialSetupContainsRecentActivityWhenAvailable() async throws {
        sectionsAvailabilityProvider.isPrivacyStatsAvailable = false
        sectionsAvailabilityProvider.isRecentActivityAvailable = true

        let configuration: NewTabPageDataModel.NewTabPageConfiguration = try await messageHelper.handleMessage(named: .initialSetup)
        XCTAssertEqual(configuration.widgets, [
            .init(id: .rmf),
            .init(id: .freemiumPIRBanner),
            .init(id: .nextSteps),
            .init(id: .favorites),
            .init(id: .recentActivity)
        ])
        XCTAssertEqual(configuration.widgetConfigs, [
            .init(id: .favorites, isVisible: sectionsVisibilityProvider.isFavoritesVisible),
            .init(id: .recentActivity, isVisible: sectionsVisibilityProvider.isRecentActivityVisible)
        ])
        XCTAssertEqual(configuration.platform, .init(name: "macos"))
    }

    // MARK: - widgetsSetConfig

    func testWhenWidgetsSetConfigIsReceivedThenWidgetConfigsAreUpdated() async throws {
        let configs: [NewTabPageDataModel.NewTabPageConfiguration.WidgetConfig] = [
            .init(id: .favorites, isVisible: false),
            .init(id: .privacyStats, isVisible: true),
            .init(id: .recentActivity, isVisible: false)
        ]
        try await messageHelper.handleMessageExpectingNilResponse(named: .widgetsSetConfig, parameters: configs)
        XCTAssertEqual(sectionsVisibilityProvider.isFavoritesVisible, false)
        XCTAssertEqual(sectionsVisibilityProvider.isPrivacyStatsVisible, true)
        XCTAssertEqual(sectionsVisibilityProvider.isRecentActivityVisible, false)
    }

    func testWhenWidgetsSetConfigIsReceivedWithPartialConfigThenOnlyIncludedWidgetsConfigsAreUpdated() async throws {
        let initialIsFavoritesVisible = sectionsVisibilityProvider.isFavoritesVisible

        let configs: [NewTabPageDataModel.NewTabPageConfiguration.WidgetConfig] = [
            .init(id: .privacyStats, isVisible: false),
            .init(id: .recentActivity, isVisible: true)
        ]
        try await messageHelper.handleMessageExpectingNilResponse(named: .widgetsSetConfig, parameters: configs)
        XCTAssertEqual(sectionsVisibilityProvider.isFavoritesVisible, initialIsFavoritesVisible)
        XCTAssertEqual(sectionsVisibilityProvider.isPrivacyStatsVisible, false)
        XCTAssertEqual(sectionsVisibilityProvider.isRecentActivityVisible, true)
    }

    // MARK: - reportInitException

    func testThatReportInitExceptionForwardsEventToTheMapper() async throws {
        let exception = NewTabPageDataModel.Exception(message: "sample message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .reportInitException, parameters: exception)

        XCTAssertEqual(eventMapper.events, [.newTabPageError(message: "sample message")])
    }

    // MARK: - reportPageException

    func testThatReportPageExceptionForwardsEventToTheMapper() async throws {
        let exception = NewTabPageDataModel.Exception(message: "sample message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .reportPageException, parameters: exception)

        XCTAssertEqual(eventMapper.events, [.newTabPageError(message: "sample message")])
    }
}
