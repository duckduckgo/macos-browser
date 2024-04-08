//
//  HomePageFavoritesModel.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

extension HomePage.Models {

    enum FavoriteType: Equatable {

        case bookmark(Bookmark)
        case addButton
        case ghostButton

    }

    struct FavoriteModel: Identifiable, Equatable {

        let id: String
        let favoriteType: FavoriteType

    }

    final class FavoritesModel: ObservableObject {

        enum OpenTarget {

            case current, newTab, newWindow

        }

        @UserDefaultsWrapper(key: .homePageShowAllFavorites, defaultValue: true)
        private static var showAllFavoritesSetting: Bool

        @Published var showAllFavorites: Bool {
            didSet {
                Self.showAllFavoritesSetting = showAllFavorites
                updateVisibleModels()
            }
        }

        @Published var favorites: [Bookmark] = [] {
            didSet {
                var favorites = self.favorites.map { FavoriteModel(id: $0.id, favoriteType: .bookmark($0)) }

                let numberOfRows = favorites.count / HomePage.favoritesPerRow
                if numberOfRows < 1 {
                    favorites.append(.init(id: UUID().uuidString, favoriteType: .addButton))

                    let lastRowCount = favorites.count % HomePage.favoritesPerRow
                    let missing = lastRowCount > 0 ? HomePage.favoritesPerRow - lastRowCount : 0

                    (0 ..< missing).forEach { _ in
                        favorites.append(FavoriteModel(id: UUID().uuidString, favoriteType: .ghostButton))
                    }
                }

                models = favorites
            }
        }

        @Published var models: [FavoriteModel] = [] {
            didSet {
                updateVisibleModels()
            }
        }

        @Published private(set) var visibleModels: [FavoriteModel] = []

        @Published private(set) var rows: [[FavoriteModel]] = []

        let open: (Bookmark, OpenTarget) -> Void
        let removeFavorite: (Bookmark) -> Void
        let deleteBookmark: (Bookmark) -> Void
        let add: () -> Void
        let edit: (Bookmark) -> Void
        let moveFavorite: (Bookmark, Int) -> Void
        let onFaviconMissing: () -> Void

        init(open: @escaping (Bookmark, OpenTarget) -> Void,
             removeFavorite: @escaping (Bookmark) -> Void,
             deleteBookmark: @escaping (Bookmark) -> Void,
             add: @escaping () -> Void,
             edit: @escaping (Bookmark) -> Void,
             moveFavorite: @escaping (Bookmark, Int) -> Void,
             onFaviconMissing: @escaping () -> Void
        ) {

            self.showAllFavorites = Self.showAllFavoritesSetting
            self.open = open
            self.removeFavorite = removeFavorite
            self.deleteBookmark = deleteBookmark
            self.add = add
            self.edit = edit
            self.moveFavorite = moveFavorite
            self.onFaviconMissing = onFaviconMissing
        }

        func openInNewTab(_ bookmark: Bookmark) {
            open(bookmark, .newTab)
        }

        func openInNewWindow(_ bookmark: Bookmark) {
            open(bookmark, .newWindow)
        }

        func open(_ bookmark: Bookmark) {
            open(bookmark, .current)
        }

        func editBookmark(_ bookmark: Bookmark) {
            edit(bookmark)
        }

        func addNew() {
            add()
        }

        private func updateVisibleModels() {
            if #available(macOS 12.0, *) {
                visibleModels = showAllFavorites ? models : Array(models.prefix(HomePage.favoritesRowCountWhenCollapsed * HomePage.favoritesPerRow))
            } else {
                rows = models.chunked(into: HomePage.favoritesPerRow)
            }
        }
    }

}
