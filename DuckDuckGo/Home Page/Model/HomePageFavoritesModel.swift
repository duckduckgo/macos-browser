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

    enum FavoriteType {

        case bookmark(Bookmark)
        case addButton
        case ghostButton

    }

    struct FavoriteModel {

        let id: UUID
        let favoriteType: FavoriteType

    }

    final class FavoritesModel: ObservableObject {

        enum OpenTarget {

            case current, newTab, newWindow

        }

        @Published var favorites: [Bookmark] = [] {
            didSet {
                var favorites = self.favorites.map { FavoriteModel(id: $0.id, favoriteType: .bookmark($0)) }
                favorites.append(.init(id: UUID(), favoriteType: .addButton))

                let lastRowCount = favorites.count % HomePage.favoritesPerRow
                let missing = lastRowCount > 0 ? HomePage.favoritesPerRow - lastRowCount : 0

                (0 ..< missing).forEach { _ in 
                    favorites.append(FavoriteModel(id: UUID(), favoriteType: .ghostButton))
                }

                self.rows = favorites.chunked(into: HomePage.favoritesPerRow)
            }
        }

        @Published private(set) var rows: [[FavoriteModel]] = []

        let open: (Bookmark, OpenTarget) -> Void
        let remove: (Bookmark) -> Void
        let addEdit: (Bookmark?) -> Void

        init(open: @escaping (Bookmark, OpenTarget) -> Void,
             remove: @escaping (Bookmark) -> Void,
             addEdit:  @escaping (Bookmark?) -> Void) {

            self.open = open
            self.remove = remove
            self.addEdit = addEdit
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

        func edit(_ bookmark: Bookmark) {
            addEdit(bookmark)
        }

        func addNew() {
            addEdit(nil)
        }
    }
    
}
