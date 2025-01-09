//
//  NewTabPageFavoritesClientTests.swift
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
import RemoteMessaging
import XCTest
@testable import NewTabPage
import PersistenceTestingUtils

final class NewTabPageFavoritesClientTests: XCTestCase {
    typealias NewTabPageFavoritesClientUnderTest = NewTabPageFavoritesClient<MockNewTabPageFavorite, CapturingNewTabPageFavoritesActionsHandler>

    var client: NewTabPageFavoritesClientUnderTest!
    var contextMenuPresenter: CapturingNewTabPageContextMenuPresenter!
    var actionsHandler: CapturingNewTabPageFavoritesActionsHandler!
    var favoritesModel: NewTabPageFavoritesModel<MockNewTabPageFavorite, CapturingNewTabPageFavoritesActionsHandler>!
    var userScript: NewTabPageUserScript!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        contextMenuPresenter = CapturingNewTabPageContextMenuPresenter()
        actionsHandler = CapturingNewTabPageFavoritesActionsHandler()
        favoritesModel = NewTabPageFavoritesModel(
            actionsHandler: actionsHandler,
            favoritesPublisher: Empty().eraseToAnyPublisher(),
            contextMenuPresenter: contextMenuPresenter,
            settingsPersistor: UserDefaultsNewTabPageFavoritesSettingsPersistor(MockKeyValueStore(), getLegacySetting: nil)
        )

        client = NewTabPageFavoritesClient(favoritesModel: favoritesModel, preferredFaviconSize: 100)

        userScript = NewTabPageUserScript()
        client.registerMessageHandlers(for: userScript)
    }

    // MARK: - add

    func testThatAddCallsAddAction() async throws {
        try await handleMessageExpectingNilResponse(named: .add)
        XCTAssertEqual(actionsHandler.addNewFavoriteCallCount, 1)
    }

    // MARK: - getConfig

    func testWhenFavoritesViewIsExpandedThenGetConfigReturnsExpandedState() async throws {
        favoritesModel.isViewExpanded = true
        let config: NewTabPageUserScript.WidgetConfig = try await handleMessage(named: .getConfig)
        XCTAssertEqual(config.animation, .auto)
        XCTAssertEqual(config.expansion, .expanded)
    }

    func testWhenFavoritesViewIsCollapsedThenGetConfigReturnsCollapsedState() async throws {
        favoritesModel.isViewExpanded = false
        let config: NewTabPageUserScript.WidgetConfig = try await handleMessage(named: .getConfig)
        XCTAssertEqual(config.animation, .auto)
        XCTAssertEqual(config.expansion, .collapsed)
    }

    // MARK: - setConfig

    func testWhenSetConfigContainsExpandedStateThenFavoritesModelSettingIsSetToExpanded() async throws {
        favoritesModel.isViewExpanded = false
        let config = NewTabPageUserScript.WidgetConfig(animation: .auto, expansion: .expanded)
        try await handleMessageExpectingNilResponse(named: .setConfig, parameters: config)
        XCTAssertEqual(favoritesModel.isViewExpanded, true)
    }

    func testWhenSetConfigContainsCollapsedStateThenFavoritesModelSettingIsSetToCollapsed() async throws {
        favoritesModel.isViewExpanded = true
        let config = NewTabPageUserScript.WidgetConfig(animation: .auto, expansion: .collapsed)
        try await handleMessageExpectingNilResponse(named: .setConfig, parameters: config)
        XCTAssertEqual(favoritesModel.isViewExpanded, false)
    }

    // MARK: - getData

    func testThatGetDataReturnsFavoritesFromTheModel() async throws {
        favoritesModel.favorites = [
            MockNewTabPageFavorite(id: "1", title: "A", url: "https://a.com"),
            MockNewTabPageFavorite(id: "10", title: "B", url: "https://b.com"),
            MockNewTabPageFavorite(id: "5", title: "C", url: "https://c.com"),
            MockNewTabPageFavorite(id: "2", title: "D", url: "https://d.com"),
            MockNewTabPageFavorite(id: "3", title: "E", url: "https://e.com")
        ]
        let data: NewTabPageFavoritesClientUnderTest.FavoritesData = try await handleMessage(named: .getData)
        XCTAssertEqual(data.favorites, [
            .init(id: "1", title: "A", url: "https://a.com", favicon: .init(maxAvailableSize: 100, src: "duck://favicon/https%3A//a.com")),
            .init(id: "10", title: "B", url: "https://b.com", favicon: .init(maxAvailableSize: 100, src: "duck://favicon/https%3A//b.com")),
            .init(id: "5", title: "C", url: "https://c.com", favicon: .init(maxAvailableSize: 100, src: "duck://favicon/https%3A//c.com")),
            .init(id: "2", title: "D", url: "https://d.com", favicon: .init(maxAvailableSize: 100, src: "duck://favicon/https%3A//d.com")),
            .init(id: "3", title: "E", url: "https://e.com", favicon: .init(maxAvailableSize: 100, src: "duck://favicon/https%3A//e.com"))
        ])
    }

    func testWhenFavoritesAreEmptyThenGetDataReturnsNoFavorites() async throws {
        favoritesModel.favorites = []
        let data: NewTabPageFavoritesClientUnderTest.FavoritesData = try await handleMessage(named: .getData)
        XCTAssertEqual(data.favorites, [])
    }

    // MARK: - move

    func testThatMoveActionIsForwardedToTheModel() async throws {
        let action = NewTabPageFavoritesClientUnderTest.FavoritesMoveAction(id: "abcd", fromIndex: 10, targetIndex: 4)
        try await handleMessageExpectingNilResponse(named: .move, parameters: action)
        XCTAssertEqual(actionsHandler.moveCalls, [.init("abcd", 4)])
    }

    func testThatWhenFavoriteIsMovedToHigherIndexThenModelIncrementsIndex() async throws {
        let action = NewTabPageFavoritesClientUnderTest.FavoritesMoveAction(id: "abcd", fromIndex: 1, targetIndex: 4)
        try await handleMessageExpectingNilResponse(named: .move, parameters: action)
        XCTAssertEqual(actionsHandler.moveCalls, [.init("abcd", 5)])
    }

    // MARK: - open

    func testThatOpenActionIsForwardedToTheModel() async throws {
        let action = NewTabPageFavoritesClientUnderTest.FavoritesOpenAction(id: "abcd", url: "https://example.com")
        try await handleMessageExpectingNilResponse(named: .open, parameters: action)
        XCTAssertEqual(actionsHandler.openCalls, [.init(URL(string: "https://example.com")!, .current)])
    }

    func testWhenURLIsInvalidThenOpenActionIsNotForwardedToTheModel() async throws {
        let action = NewTabPageFavoritesClientUnderTest.FavoritesOpenAction(id: "abcd", url: "abcd")
        try await handleMessageExpectingNilResponse(named: .open, parameters: action)
        XCTAssertEqual(actionsHandler.openCalls, [])
    }

    // MARK: - openContextMenu

    func testThatOpenContextMenuActionForExistingFavoriteIsForwardedToTheModel() async throws {
        favoritesModel.favorites = [.init(id: "abcd", title: "A", url: "https://example.com")]
        let action = NewTabPageFavoritesClientUnderTest.FavoritesContextMenuAction(id: "abcd")
        try await handleMessageExpectingNilResponse(named: .openContextMenu, parameters: action)
        XCTAssertEqual(contextMenuPresenter.showContextMenuCalls.count, 1)
    }

    func testThatOpenContextMenuActionForNotExistingFavoriteIsNotForwardedToTheModel() async throws {
        favoritesModel.favorites = []
        let action = NewTabPageFavoritesClientUnderTest.FavoritesContextMenuAction(id: "abcd")
        try await handleMessageExpectingNilResponse(named: .openContextMenu, parameters: action)
        XCTAssertEqual(contextMenuPresenter.showContextMenuCalls.count, 0)
    }

    // MARK: - Helper functions

    func handleMessage<Response: Encodable>(named methodName: NewTabPageFavoritesClientUnderTest.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws -> Response {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        return try XCTUnwrap(response as? Response, file: file, line: line)
    }

    func handleMessageExpectingNilResponse(named methodName: NewTabPageFavoritesClientUnderTest.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        XCTAssertNil(response, file: file, line: line)
    }
}
