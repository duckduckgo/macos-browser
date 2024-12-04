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
import NewTabPage
import UserScript

final class NewTabPageFavoritesClient: NewTabPageScriptClient {

    let favoritesModel: NewTabPageFavoritesModel
    weak var userScriptsSource: NewTabPageUserScriptsSource?
    private var cancellables: Set<AnyCancellable> = []

    init(favoritesModel: NewTabPageFavoritesModel) {
        self.favoritesModel = favoritesModel

        favoritesModel.$favorites.dropFirst()
            .sink { [weak self] favorites in
                Task { @MainActor in
                    self?.notifyDataUpdated(favorites)
                }
            }
            .store(in: &cancellables)

        favoritesModel.$isViewExpanded.dropFirst()
            .sink { [weak self] showAllFavorites in
                Task { @MainActor in
                    self?.notifyConfigUpdated(showAllFavorites)
                }
            }
            .store(in: &cancellables)
    }

    enum MessageName: String, CaseIterable {
        case add = "favorites_add"
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
            MessageName.add.rawValue: { [weak self] in try await self?.add(params: $0, original: $1) },
            MessageName.getConfig.rawValue: { [weak self] in try await self?.getConfig(params: $0, original: $1) },
            MessageName.getData.rawValue: { [weak self] in try await self?.getData(params: $0, original: $1) },
            MessageName.move.rawValue: { [weak self] in try await self?.move(params: $0, original: $1) },
            MessageName.open.rawValue: { [weak self] in try await self?.open(params: $0, original: $1) },
            MessageName.openContextMenu.rawValue: { [weak self] in try await self?.openContextMenu(params: $0, original: $1) },
            MessageName.setConfig.rawValue: { [weak self] in try await self?.setConfig(params: $0, original: $1) }
        ])
    }

    func add(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        await favoritesModel.addNew()
        return nil
    }

    func getConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let expansion: NewTabPageUserScript.WidgetConfig.Expansion = favoritesModel.isViewExpanded ? .expanded : .collapsed
        return NewTabPageUserScript.WidgetConfig(animation: .auto, expansion: expansion)
    }

    @MainActor
    func setConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let config: NewTabPageUserScript.WidgetConfig = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.isViewExpanded = config.expansion == .expanded
        return nil
    }

    @MainActor
    func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let favorites = favoritesModel.favorites.map {
            NewTabPageFavoritesClient.Favorite($0, favoritesModel: favoritesModel)
        }
        return NewTabPageFavoritesClient.FavoritesData(favorites: favorites)
    }

    @MainActor
    private func notifyDataUpdated(_ favorites: [Bookmark]) {
        let favorites = favoritesModel.favorites.map {
            NewTabPageFavoritesClient.Favorite($0, favoritesModel: favoritesModel)
        }
        pushMessage(named: MessageName.onDataUpdate.rawValue, params: NewTabPageFavoritesClient.FavoritesData(favorites: favorites))
    }

    @MainActor
    private func notifyConfigUpdated(_ showAllFavorites: Bool) {
        let expansion: NewTabPageUserScript.WidgetConfig.Expansion = showAllFavorites ? .expanded : .collapsed
        let config = NewTabPageUserScript.WidgetConfig(animation: .auto, expansion: expansion)
        pushMessage(named: MessageName.onConfigUpdate.rawValue, params: config)
    }

    @MainActor
    func move(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let action: NewTabPageFavoritesClient.FavoritesMoveAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.moveFavorite(withID: action.id, fromIndex: action.fromIndex, toIndex: action.targetIndex)
        return nil
    }

    @MainActor
    func open(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let action: NewTabPageFavoritesClient.FavoritesOpenAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.openFavorite(withURL: action.url)
        return nil
    }

    @MainActor
    func openContextMenu(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let contextMenuAction: NewTabPageFavoritesClient.FavoritesContextMenuAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.showContextMenu(for: contextMenuAction.id)
        return nil
    }
}

extension NewTabPageFavoritesClient {

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

        @MainActor
        init(_ bookmark: Bookmark, favoritesModel: NewTabPageFavoritesModel) {
            id = bookmark.id
            title = bookmark.title
            url = bookmark.url

            if let url = bookmark.url.url, let duckFaviconURL = URL.duckFavicon(for: url) {
                favicon = FavoriteFavicon(maxAvailableSize: Int(Favicon.SizeCategory.medium.rawValue), src: duckFaviconURL.absoluteString)
            } else {
                favoritesModel.onFaviconMissing()
                favicon = nil
            }
        }

        init(id: String, title: String, url: String, favicon: NewTabPageFavoritesClient.FavoriteFavicon? = nil) {
            self.id = id
            self.title = title
            self.url = url
            self.favicon = favicon
        }
    }

    struct FavoriteFavicon: Encodable, Equatable {
        let maxAvailableSize: Int
        let src: String
    }
}
