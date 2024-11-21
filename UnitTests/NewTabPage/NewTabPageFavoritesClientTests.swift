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
import TestUtils
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class CapturingNewTabPageFavoritesActionsHandler: FavoritesActionsHandling {
    struct OpenCall: Equatable {
        let url: URL
        let target: NewTabPageFavoritesModel.OpenTarget

        init(_ url: URL, _ target: NewTabPageFavoritesModel.OpenTarget) {
            self.url = url
            self.target = target
        }
    }

    struct MoveCall: Equatable {
        let id: String
        let toIndex: Int

        init(_ id: String, _ toIndex: Int) {
            self.id = id
            self.toIndex = toIndex
        }
    }

    var openCalls: [OpenCall] = []
    var addNewFavoriteCallCount: Int = 0
    var editCalls: [Bookmark] = []
    var onFaviconMissingCallCount: Int = 0
    var removeFavoriteCalls: [Bookmark] = []
    var deleteBookmarkCalls: [Bookmark] = []
    var moveCalls: [MoveCall] = []

    func open(_ url: URL, target: NewTabPageFavoritesModel.OpenTarget) {
        openCalls.append(.init(url, target))
    }

    func addNewFavorite() {
        addNewFavoriteCallCount += 1
    }

    func edit(_ bookmark: Bookmark) {
        editCalls.append(bookmark)
    }

    func onFaviconMissing() {
        onFaviconMissingCallCount += 1
    }

    func removeFavorite(_ bookmark: Bookmark) {
        removeFavoriteCalls.append(bookmark)
    }

    func deleteBookmark(_ bookmark: Bookmark) {
        deleteBookmarkCalls.append(bookmark)
    }

    func move(_ bookmarkID: String, toIndex: Int) {
        moveCalls.append(.init(bookmarkID, toIndex))
    }
}

final class NewTabPageFavoritesClientTests: XCTestCase {
    var client: NewTabPageFavoritesClient!
    var faviconManager: FaviconManagerMock!
    var contextMenuPresenter: CapturingNewTabPageContextMenuPresenter!
    var actionsHandler: CapturingNewTabPageFavoritesActionsHandler!
    var settingsPersistor: UserDefaultsNewTabPageFavoritesSettingsPersistor!
    var favoritesModel: NewTabPageFavoritesModel!
    var userScript: NewTabPageUserScript!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        contextMenuPresenter = CapturingNewTabPageContextMenuPresenter()
        faviconManager = FaviconManagerMock()
        actionsHandler = CapturingNewTabPageFavoritesActionsHandler()
        settingsPersistor = UserDefaultsNewTabPageFavoritesSettingsPersistor(MockKeyValueStore())
        favoritesModel = NewTabPageFavoritesModel(
            actionsHandler: actionsHandler,
            contextMenuPresenter: contextMenuPresenter,
            settingsPersistor: settingsPersistor
        )

        client = NewTabPageFavoritesClient(favoritesModel: favoritesModel, faviconManager: faviconManager)

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
            Bookmark(id: "1", url: "https://a.com", title: "A", isFavorite: true),
            Bookmark(id: "10", url: "https://b.com", title: "B", isFavorite: true),
            Bookmark(id: "5", url: "https://c.com", title: "C", isFavorite: true),
            Bookmark(id: "2", url: "https://d.com", title: "D", isFavorite: true),
            Bookmark(id: "3", url: "https://e.com", title: "E", isFavorite: true)
        ]
        let data: NewTabPageFavoritesClient.FavoritesData = try await handleMessage(named: .getData)
        XCTAssertEqual(data.favorites, [
            .init(id: "1", title: "A", url: "https://a.com"),
            .init(id: "10", title: "B", url: "https://b.com"),
            .init(id: "5", title: "C", url: "https://c.com"),
            .init(id: "2", title: "D", url: "https://d.com"),
            .init(id: "3", title: "E", url: "https://e.com")
        ])
    }

    func testWhenFavoritesAreEmptyThenGetDataReturnsNoFavorites() async throws {
        favoritesModel.favorites = []
        let data: NewTabPageFavoritesClient.FavoritesData = try await handleMessage(named: .getData)
        XCTAssertEqual(data.favorites, [])
    }

    // MARK: - move

    func testThatMoveActionIsForwardedToTheModel() async throws {
        let action = NewTabPageFavoritesClient.FavoritesMoveAction(id: "abcd", fromIndex: 10, targetIndex: 4)
        try await handleMessageExpectingNilResponse(named: .move, parameters: action)
        XCTAssertEqual(actionsHandler.moveCalls, [.init("abcd", 4)])
    }

    func testThatWhenFavoriteIsMovedToHigherIndexThenModelIncrementsIndex() async throws {
        let action = NewTabPageFavoritesClient.FavoritesMoveAction(id: "abcd", fromIndex: 1, targetIndex: 4)
        try await handleMessageExpectingNilResponse(named: .move, parameters: action)
        XCTAssertEqual(actionsHandler.moveCalls, [.init("abcd", 5)])
    }

    // MARK: - open

    func testThatOpenActionIsForwardedToTheModel() async throws {
        let action = NewTabPageFavoritesClient.FavoritesOpenAction(id: "abcd", url: "https://example.com")
        try await handleMessageExpectingNilResponse(named: .open, parameters: action)
        XCTAssertEqual(actionsHandler.openCalls, [.init("https://example.com".url!, .current)])
    }

    func testWhenURLIsInvalidThenOpenActionIsNotForwardedToTheModel() async throws {
        let action = NewTabPageFavoritesClient.FavoritesOpenAction(id: "abcd", url: "abcd")
        try await handleMessageExpectingNilResponse(named: .open, parameters: action)
        XCTAssertEqual(actionsHandler.openCalls, [])
    }

    // MARK: - openContextMenu

    func testThatOpenContextMenuActionForExistingFavoriteIsForwardedToTheModel() async throws {
        favoritesModel.favorites = [.init(id: "abcd", url: "https://example.com", title: "A", isFavorite: true)]
        let action = NewTabPageFavoritesClient.FavoritesContextMenuAction(id: "abcd")
        try await handleMessageExpectingNilResponse(named: .openContextMenu, parameters: action)
        XCTAssertEqual(contextMenuPresenter.showContextMenuCalls.count, 1)
    }

    func testThatOpenContextMenuActionForNotExistingFavoriteIsNotForwardedToTheModel() async throws {
        favoritesModel.favorites = []
        let action = NewTabPageFavoritesClient.FavoritesContextMenuAction(id: "abcd")
        try await handleMessageExpectingNilResponse(named: .openContextMenu, parameters: action)
        XCTAssertEqual(contextMenuPresenter.showContextMenuCalls.count, 0)
    }

    func testThatContextMenuActionsAreForwardedToTheHandler() async throws {
        favoritesModel.favorites = [.init(id: "abcd", url: "https://example.com", title: "A", isFavorite: true)]
        let action = NewTabPageFavoritesClient.FavoritesContextMenuAction(id: "abcd")
        try await handleMessageExpectingNilResponse(named: .openContextMenu, parameters: action)
        XCTAssertEqual(contextMenuPresenter.showContextMenuCalls.count, 1)

        let menu = try XCTUnwrap(contextMenuPresenter.showContextMenuCalls.first)
        XCTAssertEqual(menu.items.count, 6)
        let openInNewTab = menu.items[0]
        let openInNewWindow = menu.items[1]
        let edit = menu.items[3]
        let removeFavorite = menu.items[4]
        let deleteBookmark = menu.items[5]

        menu.performActionForItem(at: 0)
        XCTAssertEqual(actionsHandler.openCalls.last, CapturingNewTabPageFavoritesActionsHandler.OpenCall("https://example.com".url!, .newTab))

        menu.performActionForItem(at: 1)
        XCTAssertEqual(actionsHandler.openCalls.last, CapturingNewTabPageFavoritesActionsHandler.OpenCall("https://example.com".url!, .newWindow))

        menu.performActionForItem(at: 3)
        XCTAssertEqual(actionsHandler.editCalls.last, favoritesModel.favorites.first)

        menu.performActionForItem(at: 4)
        XCTAssertEqual(actionsHandler.removeFavoriteCalls.last, favoritesModel.favorites.first)

        menu.performActionForItem(at: 5)
        XCTAssertEqual(actionsHandler.deleteBookmarkCalls.last, favoritesModel.favorites.first)
    }

    // MARK: - Helper functions

    func handleMessage<Response: Encodable>(named methodName: NewTabPageFavoritesClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws -> Response {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        return try XCTUnwrap(response as? Response, file: file, line: line)
    }

    func handleMessageExpectingNilResponse(named methodName: NewTabPageFavoritesClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        XCTAssertNil(response, file: file, line: line)
    }
}
