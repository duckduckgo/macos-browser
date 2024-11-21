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
@testable import DuckDuckGo_Privacy_Browser

final class MockNewTabPageFavoritesActionsHandler: FavoritesActionsHandling {
    func open(_ url: URL, target: DuckDuckGo_Privacy_Browser.NewTabPageFavoritesModel.OpenTarget) {
    }

    func addNewFavorite() {
    }

    func edit(_ bookmark: DuckDuckGo_Privacy_Browser.Bookmark) {
    }

    func onFaviconMissing() {
    }

    func removeFavorite(_ bookmark: DuckDuckGo_Privacy_Browser.Bookmark) {
    }

    func deleteBookmark(_ bookmark: DuckDuckGo_Privacy_Browser.Bookmark) {
    }

    func move(_ bookmarkID: String, toIndex: Int) {
    }
}

final class NewTabPageFavoritesClientTests: XCTestCase {
    var client: NewTabPageFavoritesClient!
    var faviconManager: FaviconManagerMock!
    var contextMenuPresenter: CapturingNewTabPageContextMenuPresenter!
    var actionsHandler: MockNewTabPageFavoritesActionsHandler!
    var userScript: NewTabPageUserScript!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        contextMenuPresenter = CapturingNewTabPageContextMenuPresenter()
        faviconManager = FaviconManagerMock()
        actionsHandler = MockNewTabPageFavoritesActionsHandler()
        client = NewTabPageFavoritesClient(
            favoritesModel: NewTabPageFavoritesModel(actionsHandler: actionsHandler, contextMenuPresenter: contextMenuPresenter),
            faviconManager: faviconManager
            )

        userScript = NewTabPageUserScript()
        client.registerMessageHandlers(for: userScript)
    }

    // MARK: - Helper functions

    func sendMessage<Response: Encodable>(named methodName: NewTabPageFavoritesClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws -> Response {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        return try XCTUnwrap(response as? Response, file: file, line: line)
    }

    func sendMessageExpectingNilResponse(named methodName: NewTabPageFavoritesClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        XCTAssertNil(response, file: file, line: line)
    }
}
