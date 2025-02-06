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
import UserScriptActionsManager
import WebKit

public final class NewTabPageFavoritesClient<FavoriteType, ActionHandler>: NewTabPageUserScriptClient where FavoriteType: NewTabPageFavorite,
                                                                                                            ActionHandler: FavoritesActionsHandling,
                                                                                                            ActionHandler.FavoriteType == FavoriteType {

    let favoritesModel: NewTabPageFavoritesModel<FavoriteType, ActionHandler>

    private var cancellables: Set<AnyCancellable> = []
    private let preferredFaviconSize: Int

    public init(favoritesModel: NewTabPageFavoritesModel<FavoriteType, ActionHandler>, preferredFaviconSize: Int) {
        self.favoritesModel = favoritesModel
        self.preferredFaviconSize = preferredFaviconSize
        super.init()

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

    public override func registerMessageHandlers(for userScript: NewTabPageUserScript) {
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

    private func add(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        await favoritesModel.addNew()
        return nil
    }

    private func getConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let expansion: NewTabPageUserScript.WidgetConfig.Expansion = favoritesModel.isViewExpanded ? .expanded : .collapsed
        return NewTabPageUserScript.WidgetConfig(animation: .viewTransitions, expansion: expansion)
    }

    @MainActor
    private func setConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let config: NewTabPageUserScript.WidgetConfig = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.isViewExpanded = config.expansion == .expanded
        return nil
    }

    @MainActor
    private func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let favorites = favoritesModel.favorites.map {
            NewTabPageDataModel.Favorite($0, preferredFaviconSize: preferredFaviconSize)
        }
        return NewTabPageDataModel.FavoritesData(favorites: favorites)
    }

    @MainActor
    private func notifyDataUpdated(_ favorites: [NewTabPageFavorite]) {
        let favorites = favoritesModel.favorites.map {
            NewTabPageDataModel.Favorite($0, preferredFaviconSize: preferredFaviconSize)
        }
        pushMessage(named: MessageName.onDataUpdate.rawValue, params: NewTabPageDataModel.FavoritesData(favorites: favorites))
    }

    @MainActor
    private func notifyConfigUpdated(_ showAllFavorites: Bool) {
        let expansion: NewTabPageUserScript.WidgetConfig.Expansion = showAllFavorites ? .expanded : .collapsed
        let config = NewTabPageUserScript.WidgetConfig(animation: .viewTransitions, expansion: expansion)
        pushMessage(named: MessageName.onConfigUpdate.rawValue, params: config)
    }

    @MainActor
    private func move(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let action: NewTabPageDataModel.FavoritesMoveAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.moveFavorite(withID: action.id, fromIndex: action.fromIndex, toIndex: action.targetIndex)
        return nil
    }

    @MainActor
    private func open(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let action: NewTabPageDataModel.FavoritesOpenAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.openFavorite(withURL: action.url)
        return nil
    }

    @MainActor
    private func openContextMenu(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let contextMenuAction: NewTabPageDataModel.FavoritesContextMenuAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.showContextMenu(for: contextMenuAction.id)
        return nil
    }
}

public extension URL {
    static func duckFavicon(for faviconURL: URL) -> URL? {
        let encodedURL = faviconURL.absoluteString.percentEncoded(withAllowedCharacters: .urlPathAllowed)
        return URL(string: "duck://favicon/\(encodedURL)")
    }
}
