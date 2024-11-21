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

import Combine
import Foundation

final class NewTabPageFavoritesModel: NSObject {

    enum OpenTarget {
        case current, newTab, newWindow
    }

    private let actionsHandler: FavoritesActionsHandling
    private let contextMenuPresenter: NewTabPageContextMenuPresenting
    private var cancellables: Set<AnyCancellable> = []

    init(actionsHandler: FavoritesActionsHandling, contextMenuPresenter: NewTabPageContextMenuPresenting = DefaultNewTabPageContextMenuPresenter()) {
        self.actionsHandler = actionsHandler
        self.contextMenuPresenter = contextMenuPresenter
        self.showAllFavorites = Self.showAllFavoritesSetting
    }

    convenience init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.init(actionsHandler: DefaultFavoritesActionsHandler(bookmarkManager: bookmarkManager))

        bookmarkManager.listPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.favorites = bookmarkManager.list?.favoriteBookmarks ?? []
            }
            .store(in: &cancellables)
    }

    @UserDefaultsWrapper(key: .homePageShowAllFavorites, defaultValue: true)
    private static var showAllFavoritesSetting: Bool

    @Published var showAllFavorites: Bool {
        didSet {
            Self.showAllFavoritesSetting = showAllFavorites
        }
    }

    @Published var favorites: [Bookmark] = []

    @MainActor
    func openFavorite(withID bookmarkID: String) {
        guard let favorite = favorites.first(where: { $0.id == bookmarkID}), let url = favorite.urlObject else { return }
        actionsHandler.open(url, target: .current)
    }

    func moveFavorite(withID bookmarkID: String, toIndex index: Int) {
        guard let currentIndex = favorites.firstIndex(where: { $0.id == bookmarkID }) else {
            return
        }
        let targetIndex = index > currentIndex ? index + 1 : index
        actionsHandler.move(bookmarkID, toIndex: targetIndex)
    }

    @MainActor
    func addNew() {
        actionsHandler.addNewFavorite()
    }

    @MainActor
    func onFaviconMissing() {
        actionsHandler.onFaviconMissing()
    }

    // MARK: Context Menu

    @MainActor
    func showContextMenu(for bookmarkID: String) {
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
                .withAccessibilityIdentifier("HomePage.Views.editBookmark")
            NSMenuItem(title: UserText.deleteBookmark, action: #selector(deleteBookmark(_:)), target: self, representedObject: favorite)
                .withAccessibilityIdentifier("HomePage.Views.deleteBookmark")
        }

        contextMenuPresenter.showContextMenu(menu)
    }

    @MainActor
    @objc func openInNewTab(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        actionsHandler.open(url, target: .newTab)
    }

    @MainActor
    @objc func openInNewWindow(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        actionsHandler.open(url, target: .newWindow)
    }

    @MainActor
    @objc func editBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else { return }
        actionsHandler.edit(bookmark)
    }

    @MainActor
    @objc func removeFavorite(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else { return }
        actionsHandler.removeFavorite(bookmark)
    }

    @MainActor
    @objc func deleteBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else { return }
        actionsHandler.deleteBookmark(bookmark)
    }
}
