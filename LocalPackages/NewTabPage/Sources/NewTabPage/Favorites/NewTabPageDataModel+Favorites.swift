//
//  NewTabPageDataModel+Favorites.swift
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

extension NewTabPageDataModel {

    struct FavoritesContextMenuAction: Codable {
        let id: String
    }

    struct FavoritesOpenAction: Codable {
        let id: String
        let url: String
    }

    struct FavoritesMoveAction: Codable {
        let id: String
        let fromIndex: Int
        let targetIndex: Int
    }

    struct FavoritesConfig: Codable {
        let expansion: Expansion

        enum Expansion: String, Codable {
            case expanded, collapsed
        }
    }

    struct FavoritesData: Encodable {
        let favorites: [Favorite]
    }

    struct Favorite: Encodable, Equatable {
        let favicon: FavoriteFavicon?
        let id: String
        let title: String
        let url: String

        init(id: String, title: String, url: String, favicon: NewTabPageDataModel.FavoriteFavicon? = nil) {
            self.id = id
            self.title = title
            self.url = url
            self.favicon = favicon
        }

        @MainActor
        init(_ bookmark: NewTabPageFavorite, preferredFaviconSize: Int, onFaviconMissing: () -> Void) {
            id = bookmark.id
            title = bookmark.title
            url = bookmark.url

            if let url = bookmark.urlObject, let duckFaviconURL = URL.duckFavicon(for: url) {
                favicon = FavoriteFavicon(maxAvailableSize: preferredFaviconSize, src: duckFaviconURL.absoluteString)
            } else {
                onFaviconMissing()
                favicon = nil
            }
        }
    }

    struct FavoriteFavicon: Encodable, Equatable {
        let maxAvailableSize: Int
        let src: String

        init(maxAvailableSize: Int, src: String) {
            self.maxAvailableSize = maxAvailableSize
            self.src = src
        }
    }
}
