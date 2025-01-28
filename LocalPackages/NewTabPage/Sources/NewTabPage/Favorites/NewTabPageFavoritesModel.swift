//
//  NewTabPageFavoritesModel.swift
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

import AppKitExtensions
import Combine
import Foundation
import Persistence

protocol NewTabPageFavoritesSettingsPersistor: AnyObject {
    var isViewExpanded: Bool { get set }
}

final class UserDefaultsNewTabPageFavoritesSettingsPersistor: NewTabPageFavoritesSettingsPersistor {
    enum Keys {
        static let isViewExpanded = "new-tab-page.favorites.is-view-expanded"
    }

    private let keyValueStore: KeyValueStoring

    init(_ keyValueStore: KeyValueStoring = UserDefaults.standard, getLegacySetting: @autoclosure () -> Bool?) {
        self.keyValueStore = keyValueStore
        migrateFromLegacyHomePageSettings(using: getLegacySetting)
    }

    var isViewExpanded: Bool {
        get { return keyValueStore.object(forKey: Keys.isViewExpanded) as? Bool ?? true }
        set { keyValueStore.set(newValue, forKey: Keys.isViewExpanded) }
    }

    private func migrateFromLegacyHomePageSettings(using getLegacySetting: () -> Bool?) {
        guard keyValueStore.object(forKey: Keys.isViewExpanded) == nil, let legacySetting = getLegacySetting() else {
            return
        }
        isViewExpanded = legacySetting
    }
}

public final class NewTabPageFavoritesModel<FavoriteType, ActionHandler>: NSObject where FavoriteType: NewTabPageFavorite,
                                                                                         ActionHandler: FavoritesActionsHandling,
                                                                                         ActionHandler.FavoriteType == FavoriteType {

    private let actionsHandler: ActionHandler
    private let contextMenuPresenter: NewTabPageContextMenuPresenting
    private let settingsPersistor: NewTabPageFavoritesSettingsPersistor
    private var cancellables: Set<AnyCancellable> = []

    public convenience init(
        actionsHandler: ActionHandler,
        favoritesPublisher: AnyPublisher<[FavoriteType], Never>,
        contextMenuPresenter: NewTabPageContextMenuPresenting = DefaultNewTabPageContextMenuPresenter(),
        keyValueStore: KeyValueStoring = UserDefaults.standard,
        getLegacyIsViewExpandedSetting: @autoclosure () -> Bool?
    ) {
        self.init(
            actionsHandler: actionsHandler,
            favoritesPublisher: favoritesPublisher,
            contextMenuPresenter: contextMenuPresenter,
            settingsPersistor: UserDefaultsNewTabPageFavoritesSettingsPersistor(keyValueStore, getLegacySetting: getLegacyIsViewExpandedSetting())
        )
    }

    init(
        actionsHandler: ActionHandler,
        favoritesPublisher: AnyPublisher<[FavoriteType], Never>,
        contextMenuPresenter: NewTabPageContextMenuPresenting = DefaultNewTabPageContextMenuPresenter(),
        settingsPersistor: NewTabPageFavoritesSettingsPersistor
    ) {
        self.actionsHandler = actionsHandler
        self.contextMenuPresenter = contextMenuPresenter
        self.settingsPersistor = settingsPersistor

        isViewExpanded = settingsPersistor.isViewExpanded

        super.init()

        favoritesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] favorites in
                self?.favorites = favorites
            }
            .store(in: &cancellables)
    }

    @Published var isViewExpanded: Bool {
        didSet {
            settingsPersistor.isViewExpanded = self.isViewExpanded
        }
    }

    @Published var favorites: [FavoriteType] = []

    // MARK: - Actions

    @MainActor
    func openFavorite(withURL url: String) {
        guard let url = URL(string: url), url.isValid else { return }
        actionsHandler.open(url, target: .current)
    }

    @MainActor
    func moveFavorite(withID bookmarkID: String, fromIndex: Int, toIndex index: Int) {
        let targetIndex = index > fromIndex ? index + 1 : index
        actionsHandler.move(bookmarkID, toIndex: targetIndex)
    }

    @MainActor
    func addNew() {
        actionsHandler.addNewFavorite()
    }

    // MARK: Context Menu

    @MainActor
    func showContextMenu(for bookmarkID: String) {
        /**
         * This isn't very effective (may need to traverse up to entire array)
         * but it's only ever needed for context menus. I decided to skip
         * optimizing it because it's fast enough and we shouldn't have too big arrays
         * of favorites, and indexing favorites by UUID on each refresh could be too much.
         */
        guard let favorite = favorites.first(where: { $0.id == bookmarkID}) else { return }

        let menu = NSMenu()

        menu.buildItems {
            NSMenuItem(title: UserText.openInNewTab, action: #selector(openInNewTab(_:)), target: self, representedObject: favorite.urlObject)
                .withAccessibilityIdentifier("HomePage.Views.openInNewTab")
            NSMenuItem(title: UserText.openInNewWindow, action: #selector(openInNewWindow(_:)), target: self, representedObject: favorite.urlObject)
                .withAccessibilityIdentifier("HomePage.Views.openInNewWindow")

            NSMenuItem.separator()

            NSMenuItem(title: UserText.edit, action: #selector(editBookmark(_:)), target: self, representedObject: favorite)
                .withAccessibilityIdentifier("HomePage.Views.editBookmark")
            NSMenuItem(title: UserText.removeFavorite, action: #selector(removeFavorite(_:)), target: self, representedObject: favorite)
                .withAccessibilityIdentifier("HomePage.Views.removeFavorite")
            NSMenuItem(title: UserText.deleteBookmark, action: #selector(deleteBookmark(_:)), target: self, representedObject: favorite)
                .withAccessibilityIdentifier("HomePage.Views.deleteBookmark")
        }

        contextMenuPresenter.showContextMenu(menu)
    }

    @MainActor
    @objc public func openInNewTab(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        actionsHandler.open(url, target: .newTab)
    }

    @MainActor
    @objc public func openInNewWindow(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        actionsHandler.open(url, target: .newWindow)
    }

    @MainActor
    @objc public func editBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? FavoriteType else { return }
        actionsHandler.edit(bookmark)
    }

    @MainActor
    @objc public func removeFavorite(_ sender: NSMenuItem) {
        guard let favorite = sender.representedObject as? FavoriteType else { return }
        actionsHandler.removeFavorite(favorite)
    }

    @MainActor
    @objc public func deleteBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? FavoriteType else { return }
        actionsHandler.deleteBookmark(for: bookmark)
    }
}
