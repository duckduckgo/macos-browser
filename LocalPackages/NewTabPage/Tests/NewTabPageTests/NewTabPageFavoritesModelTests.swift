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
import PersistenceTestingUtils
import XCTest
@testable import NewTabPage

final class NewTabPageFavoritesModelTests: XCTestCase {

    private var model: NewTabPageFavoritesModel<MockNewTabPageFavorite, CapturingNewTabPageFavoritesActionsHandler>!
    private var settingsPersistor: UserDefaultsNewTabPageFavoritesSettingsPersistor!
    private var favoritesSubject: PassthroughSubject<[MockNewTabPageFavorite], Never>!

    override func setUp() async throws {
        try await super.setUp()

        settingsPersistor = UserDefaultsNewTabPageFavoritesSettingsPersistor(MockKeyValueStore(), getLegacySetting: nil)

        favoritesSubject = PassthroughSubject<[MockNewTabPageFavorite], Never>()
        model = NewTabPageFavoritesModel(
            actionsHandler: CapturingNewTabPageFavoritesActionsHandler(),
            favoritesPublisher: favoritesSubject.eraseToAnyPublisher(),
            settingsPersistor: settingsPersistor
        )
    }

    func testWhenBookmarkListIsUpdatedThenFavoritesListIsUpdated() async {
        let favorite1 = MockNewTabPageFavorite(id: "1", title: "1", url: "https://example.com/1")
        let favorite2 = MockNewTabPageFavorite(id: "2", title: "2", url: "https://example.com/2")

        var favoritesUpdateEvents = [[MockNewTabPageFavorite]]()
        var cancellable: AnyCancellable?

        await withCheckedContinuation { continuation in
            cancellable = model.$favorites.dropFirst().removeDuplicates().prefix(3)
                .sink(receiveCompletion: { _ in
                    continuation.resume()
                }, receiveValue: {
                    favoritesUpdateEvents.append($0)
                })

            favoritesSubject.send([])
            favoritesSubject.send([favorite1])
            favoritesSubject.send([favorite1, favorite2])
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
