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
    var client: NewTabPageConfigurationClient!
    var sectionsVisibilityProvider: MockNewTabPageSectionsVisibilityProvider!
    var contextMenuPresenter: CapturingNewTabPageContextMenuPresenter!
    var userScript: NewTabPageUserScript!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sectionsVisibilityProvider = MockNewTabPageSectionsVisibilityProvider()
        contextMenuPresenter = CapturingNewTabPageContextMenuPresenter()
        client = NewTabPageConfigurationClient(
            sectionsVisibilityProvider: sectionsVisibilityProvider,
            customBackgroundProvider: CapturingNewTabPageCustomBackgroundProvider(),
            contextMenuPresenter: contextMenuPresenter
        )

        userScript = NewTabPageUserScript()
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
        try await sendMessageExpectingNilResponse(named: .contextMenu, parameters: parameters)

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
        try await sendMessageExpectingNilResponse(named: .contextMenu, parameters: parameters)

        XCTAssertEqual(contextMenuPresenter.showContextMenuCalls.count, 0)
    }

    // MARK: - initialSetup

    func testThatInitialSetupReturnsConfiguration() async throws {
        let configuration: NewTabPageDataModel.NewTabPageConfiguration = try await sendMessage(named: .initialSetup)
        XCTAssertEqual(configuration.widgets, [
            .init(id: .rmf),
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

    // MARK: - widgetsSetConfig

    func testWhenWidgetsSetConfigIsReceivedThenWidgetConfigsAreUpdated() async throws {
        let configs: [NewTabPageDataModel.NewTabPageConfiguration.WidgetConfig] = [
            .init(id: .favorites, isVisible: false),
            .init(id: .privacyStats, isVisible: true)
        ]
        try await sendMessageExpectingNilResponse(named: .widgetsSetConfig, parameters: configs)
        XCTAssertEqual(sectionsVisibilityProvider.isFavoritesVisible, false)
        XCTAssertEqual(sectionsVisibilityProvider.isPrivacyStatsVisible, true)
    }

    func testWhenWidgetsSetConfigIsReceivedWithPartialConfigThenOnlyIncludedWidgetsConfigsAreUpdated() async throws {
        let initialIsFavoritesVisible = sectionsVisibilityProvider.isFavoritesVisible

        let configs: [NewTabPageDataModel.NewTabPageConfiguration.WidgetConfig] = [
            .init(id: .privacyStats, isVisible: false)
        ]
        try await sendMessageExpectingNilResponse(named: .widgetsSetConfig, parameters: configs)
        XCTAssertEqual(sectionsVisibilityProvider.isFavoritesVisible, initialIsFavoritesVisible)
        XCTAssertEqual(sectionsVisibilityProvider.isPrivacyStatsVisible, false)
    }

    // MARK: - Helper functions

    func sendMessage<Response: Encodable>(named methodName: NewTabPageConfigurationClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws -> Response {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        return try XCTUnwrap(response as? Response, file: file, line: line)
    }

    func sendMessageExpectingNilResponse(named methodName: NewTabPageConfigurationClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        XCTAssertNil(response, file: file, line: line)
    }
}
