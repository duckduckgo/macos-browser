//
//  NewTabPageFavoritesClient.swift
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

import Bookmarks
import Common
import Combine
import UserScript

final class NewTabPageFavoritesClient: NewTabPageScriptClient {

    let faviconManager: FaviconManagement
    let favoritesModel: NewTabPageFavoritesModel
    weak var userScriptsSource: NewTabPageUserScriptsSource?
    private var cancellables: Set<AnyCancellable> = []

    init(favoritesModel: NewTabPageFavoritesModel, faviconManager: FaviconManagement = FaviconManager.shared) {
        self.favoritesModel = favoritesModel
        self.faviconManager = faviconManager

        favoritesModel.$favorites.dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] favorites in
                Task { @MainActor in
                    self?.notifyDataUpdated(favorites)
                }
            }
            .store(in: &cancellables)
    }

    enum MessageName: String, CaseIterable {
        case getConfig = "favorites_getConfig"
        case getData = "favorites_getData"
        case move = "favorites_move"
        case onConfigUpdate = "favorites_onConfigUpdate"
        case onDataUpdate = "favorites_onDataUpdate"
        case open = "favorites_open"
        case openContextMenu = "favorites_openContextMenu"
        case setConfig = "favorites_setConfig"
    }

    func registerMessageHandlers(for userScript: any SubfeatureWithExternalMessageHandling) {
        userScript.registerMessageHandlers([
            MessageName.getConfig.rawValue: { [weak self] in try await self?.getConfig(params: $0, original: $1) },
            MessageName.getData.rawValue: { [weak self] in try await self?.getData(params: $0, original: $1) },
            MessageName.move.rawValue: { [weak self] in try await self?.move(params: $0, original: $1) },
            MessageName.open.rawValue: { [weak self] in try await self?.open(params: $0, original: $1) },
            MessageName.openContextMenu.rawValue: { [weak self] in try await self?.openContextMenu(params: $0, original: $1) }
        ])
    }

    func getConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        // implementation TBD
        NewTabPageUserScript.WidgetConfig(animation: .auto, expansion: .collapsed)
    }

    @MainActor
    func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let favorites = favoritesModel.favorites.map {
            NewTabPageFavoritesClient.Favorite($0, faviconManager: faviconManager, favoritesModel: favoritesModel)
        }
        return NewTabPageFavoritesClient.FavoritesData(favorites: favorites)
    }

    @MainActor
    private func notifyDataUpdated(_ favorites: [Bookmark]) {
        let favorites = favoritesModel.favorites.map {
            NewTabPageFavoritesClient.Favorite($0, faviconManager: faviconManager, favoritesModel: favoritesModel)
        }
        pushMessage(named: MessageName.onDataUpdate.rawValue, params: NewTabPageFavoritesClient.FavoritesData(favorites: favorites))
    }

    @MainActor
    func move(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let action: NewTabPageFavoritesClient.FavoritesMoveAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.moveFavorite(withID: action.id, toIndex: action.targetIndex)
        return nil
    }

    @MainActor
    func open(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let action: NewTabPageFavoritesClient.FavoritesOpenAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.openFavorite(withID: action.id)
        return nil
    }

    @MainActor
    func openContextMenu(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let openAction: NewTabPageFavoritesClient.FavoritesOpenAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.showContextMenu(for: openAction.id)
        return nil
    }
}

extension NewTabPageFavoritesClient {

    struct FavoritesOpenAction: Codable {
        let id: String
    }

    struct FavoritesMoveAction: Codable {
        let id: String
        let targetIndex: Int
    }

    struct FavoritesData: Encodable {
        let favorites: [Favorite]
    }

    struct Favorite: Encodable {
        let favicon: FavoriteFavicon?
        let id: String
        let title: String
        let url: String

        @MainActor
        init(_ bookmark: Bookmark, faviconManager: FaviconManagement, favoritesModel: NewTabPageFavoritesModel) {
            id = bookmark.id
            title = bookmark.title
            url = bookmark.url

            guard let url = bookmark.url.url,
                  faviconManager.areFaviconsLoaded,
                  let faviconURL = faviconManager.getCachedFaviconURL(for: url, sizeCategory: .medium),
                  let duckFaviconURL = URL.duckFavicon(for: faviconURL)
            else {
                favoritesModel.onFaviconMissing()
                favicon = nil
                return
            }
            favicon = FavoriteFavicon(maxAvailableSize: Int(Favicon.SizeCategory.medium.rawValue), src: duckFaviconURL.absoluteString)
        }
    }

    struct FavoriteFavicon: Encodable {
        let maxAvailableSize: Int
        let src: String
    }
}
