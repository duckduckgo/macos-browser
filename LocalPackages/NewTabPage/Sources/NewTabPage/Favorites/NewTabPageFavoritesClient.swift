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
import WebKit

public final class NewTabPageFavoritesClient<FavoriteType, ActionHandler>: NewTabPageScriptClient where FavoriteType: NewTabPageFavorite,
                                                                                                        ActionHandler: FavoritesActionsHandling,
                                                                                                        ActionHandler.FavoriteType == FavoriteType {

    public let favoritesModel: NewTabPageFavoritesModel<FavoriteType, ActionHandler>
    public weak var userScriptsSource: NewTabPageUserScriptsSource?
    private var cancellables: Set<AnyCancellable> = []

    public init(favoritesModel: NewTabPageFavoritesModel<FavoriteType, ActionHandler>) {
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

    public enum MessageName: String, CaseIterable {
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

    public func registerMessageHandlers(for userScript: any SubfeatureWithExternalMessageHandling) {
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

    public func add(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        await favoritesModel.addNew()
        return nil
    }

    public func getConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let expansion: NewTabPageUserScript.WidgetConfig.Expansion = favoritesModel.isViewExpanded ? .expanded : .collapsed
        return NewTabPageUserScript.WidgetConfig(animation: .auto, expansion: expansion)
    }

    @MainActor
    public func setConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let config: NewTabPageUserScript.WidgetConfig = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.isViewExpanded = config.expansion == .expanded
        return nil
    }

    @MainActor
    public func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let favorites = favoritesModel.favorites.map {
            NewTabPageFavoritesClient.Favorite($0, onFaviconMissing: favoritesModel.onFaviconMissing)
        }
        return NewTabPageFavoritesClient.FavoritesData(favorites: favorites)
    }

    @MainActor
    private func notifyDataUpdated(_ favorites: [NewTabPageFavorite]) {
        let favorites = favoritesModel.favorites.map {
            NewTabPageFavoritesClient.Favorite($0, onFaviconMissing: favoritesModel.onFaviconMissing)
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
    public func move(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let action: NewTabPageFavoritesClient.FavoritesMoveAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.moveFavorite(withID: action.id, fromIndex: action.fromIndex, toIndex: action.targetIndex)
        return nil
    }

    @MainActor
    public func open(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let action: NewTabPageFavoritesClient.FavoritesOpenAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.openFavorite(withURL: action.url)
        return nil
    }

    @MainActor
    public func openContextMenu(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let contextMenuAction: NewTabPageFavoritesClient.FavoritesContextMenuAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        favoritesModel.showContextMenu(for: contextMenuAction.id)
        return nil
    }
}

public extension NewTabPageFavoritesClient {

    struct FavoritesContextMenuAction: Codable {
        public let id: String

        public init(id: String) {
            self.id = id
        }
    }

    struct FavoritesOpenAction: Codable {
        public let id: String
        public let url: String

        public init(id: String, url: String) {
            self.id = id
            self.url = url
        }
    }

    struct FavoritesMoveAction: Codable {
        public let id: String
        public let fromIndex: Int
        public let targetIndex: Int

        public init(id: String, fromIndex: Int, targetIndex: Int) {
            self.id = id
            self.fromIndex = fromIndex
            self.targetIndex = targetIndex
        }
    }

    struct FavoritesConfig: Codable {
        public let expansion: Expansion

        public init(expansion: Expansion) {
            self.expansion = expansion
        }

        public enum Expansion: String, Codable {
            case expanded, collapsed
        }
    }

    struct FavoritesData: Encodable {
        public let favorites: [Favorite]

        public init(favorites: [Favorite]) {
            self.favorites = favorites
        }
    }

    struct Favorite: Encodable, Equatable {
        public let favicon: FavoriteFavicon?
        public let id: String
        public let title: String
        public let url: String

        public init(id: String, title: String, url: String, favicon: NewTabPageFavoritesClient.FavoriteFavicon? = nil) {
            self.id = id
            self.title = title
            self.url = url
            self.favicon = favicon
        }

        @MainActor
        init(_ bookmark: NewTabPageFavorite, onFaviconMissing: () -> Void) {
            id = bookmark.id
            title = bookmark.title
            url = bookmark.url

            if let url = bookmark.urlObject, let duckFaviconURL = URL.duckFavicon(for: url) {
                // TODO: Int(Favicon.SizeCategory.medium.rawValue)
                favicon = FavoriteFavicon(maxAvailableSize: 132, src: duckFaviconURL.absoluteString)
            } else {
                onFaviconMissing()
                favicon = nil
            }
        }
    }

    struct FavoriteFavicon: Encodable, Equatable {
        public let maxAvailableSize: Int
        public let src: String

        public init(maxAvailableSize: Int, src: String) {
            self.maxAvailableSize = maxAvailableSize
            self.src = src
        }
    }
}

extension URL {
    static func duckFavicon(for faviconURL: URL) -> URL? {
        let encodedURL = faviconURL.absoluteString.percentEncoded(withAllowedCharacters: .urlPathAllowed)
        return URL(string: "duck://favicon/\(encodedURL)")
    }
}
