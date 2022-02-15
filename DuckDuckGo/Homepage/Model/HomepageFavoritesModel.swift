//
//  HomepageFavoritesModel.swift
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

extension HomepageModels {

    static let favoritesPerRow = 5

    final class FavoritesModel: ObservableObject {

        enum OpenTarget {

            case current, newTab, newWindow

        }

        @Published var favorites: [Bookmark] = [] {
            didSet {
                print(#function, favorites)

                var rows = favorites.chunked(into: favoritesPerRow)
                if rows.last?.count == favoritesPerRow {
                    rows.append([])
                }

                if rows.isEmpty {
                    rows.append([])
                }
                self.rows = rows
            }
        }

        @Published private(set) var rows: [[Bookmark]] = []

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
