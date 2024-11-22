//
//  NewTabPageFavoritesModelTests.swift
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
import TestUtils
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class NewTabPageFavoritesModelTests: XCTestCase {

    var model: NewTabPageFavoritesModel!
    var bookmarkManager: MockBookmarkManager!
    var settingsPersistor: UserDefaultsNewTabPageFavoritesSettingsPersistor!

    override func setUp() async throws {
        try await super.setUp()

        settingsPersistor = UserDefaultsNewTabPageFavoritesSettingsPersistor(MockKeyValueStore())

        bookmarkManager = MockBookmarkManager()
        model = NewTabPageFavoritesModel(bookmarkManager: bookmarkManager, settingsPersistor: settingsPersistor)
    }

    func testWhenBookmarkListIsUpdatedThenFavoritesListIsUpdated() async {
        let favorite1 = Bookmark(id: "1", url: "https://example.com/1", title: "1", isFavorite: true)
        let favorite2 = Bookmark(id: "2", url: "https://example.com/2", title: "2", isFavorite: true)

        var favoritesUpdateEvents = [[Bookmark]]()
        var cancellable: AnyCancellable?

        await withCheckedContinuation { continuation in
            cancellable = model.$favorites.dropFirst().removeDuplicates().prefix(3)
                .sink(receiveCompletion: { _ in
                    continuation.resume()
                }, receiveValue: {
                    favoritesUpdateEvents.append($0)
                })

            bookmarkManager.list = BookmarkList()
            bookmarkManager.list = BookmarkList(entities: [favorite1], topLevelEntities: [favorite1], favorites: [favorite1])
            bookmarkManager.list = BookmarkList(
                entities: [favorite1, favorite2],
                topLevelEntities: [favorite1, favorite2],
                favorites: [favorite1, favorite2]
            )
        }

        cancellable?.cancel()

        XCTAssertEqual(favoritesUpdateEvents, [
            [],
            [favorite1],
            [favorite1, favorite2]
        ])
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
