//
//  CapturingNewTabPageFavoritesActionsHandler.swift
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

import Foundation
import NewTabPage

final class CapturingNewTabPageFavoritesActionsHandler: FavoritesActionsHandling {
    typealias FavoriteType = MockNewTabPageFavorite

    struct OpenCall: Equatable {
        let url: URL
        let target: LinkOpenTarget

        init(_ url: URL, _ target: LinkOpenTarget) {
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
    var editCalls: [MockNewTabPageFavorite] = []
    var onFaviconMissingCallCount: Int = 0
    var removeFavoriteCalls: [MockNewTabPageFavorite] = []
    var deleteBookmarkCalls: [MockNewTabPageFavorite] = []
    var moveCalls: [MoveCall] = []

    func open(_ url: URL, target: LinkOpenTarget) {
        openCalls.append(.init(url, target))
    }

    func addNewFavorite() {
        addNewFavoriteCallCount += 1
    }

    func edit(_ favorite: MockNewTabPageFavorite) {
        editCalls.append(favorite)
    }

    func removeFavorite(_ favorite: MockNewTabPageFavorite) {
        removeFavoriteCalls.append(favorite)
    }

    func deleteBookmark(for favorite: MockNewTabPageFavorite) {
        deleteBookmarkCalls.append(favorite)
    }

    func move(_ bookmarkID: String, toIndex: Int) {
        moveCalls.append(.init(bookmarkID, toIndex))
    }
}
