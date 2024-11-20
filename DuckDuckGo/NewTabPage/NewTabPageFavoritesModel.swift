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

protocol FavoritesActionsHandling {
    @MainActor func open(_ bookmark: Bookmark, target: NewTabPageFavoritesModel.OpenTarget)
    @MainActor func add()
    @MainActor func edit(_ bookmark: Bookmark)
    @MainActor func onFaviconMissing()

    func removeFavorite(_ bookmark: Bookmark)
    func deleteBookmark(_ bookmark: Bookmark)
    func moveFavorite(_ bookmark: Bookmark, toIndex: Int)
}

final class DefaultFavoritesActionsHandler: FavoritesActionsHandling {
    let bookmarkManager: BookmarkManager
    private(set) lazy var faviconsFetcherOnboarding: FaviconsFetcherOnboarding? = {
        guard let syncService = NSApp.delegateTyped.syncService, let syncBookmarksAdapter = NSApp.delegateTyped.syncDataProviders?.bookmarksAdapter else {
            assertionFailure("SyncService and/or SyncBookmarksAdapter is nil")
            return nil
        }
        return .init(syncService: syncService, syncBookmarksAdapter: syncBookmarksAdapter)
    }()

    @MainActor
    private var window: NSWindow? {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.view.window
    }

    @MainActor
    private var tabCollectionViewModel: TabCollectionViewModel? {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel
    }

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
    }

    @MainActor
    func open(_ bookmark: Bookmark, target: NewTabPageFavoritesModel.OpenTarget) {
        guard let urlObject = bookmark.urlObject else { return }
        openUrl(urlObject, target: target)
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
    }

    @MainActor
    private func openUrl(_ url: URL, target: NewTabPageFavoritesModel.OpenTarget? = nil) {
        guard let tabCollectionViewModel else {
            return
        }
        if target == .newWindow || NSApplication.shared.isCommandPressed && NSApplication.shared.isOptionPressed {
            WindowsManager.openNewWindow(with: url, source: .bookmark, isBurner: tabCollectionViewModel.isBurner)
            return
        }

        if target == .newTab || NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
            tabCollectionViewModel.appendNewTab(with: .contentFromURL(url, source: .bookmark), selected: true)
            return
        }

        if NSApplication.shared.isCommandPressed {
            tabCollectionViewModel.appendNewTab(with: .contentFromURL(url, source: .bookmark), selected: false)
            return
        }

        tabCollectionViewModel.selectedTabViewModel?.tab.setContent(.contentFromURL(url, source: .bookmark))
    }

    func removeFavorite(_ bookmark: Bookmark) {
        bookmark.isFavorite = !bookmark.isFavorite
        bookmarkManager.update(bookmark: bookmark)
    }

    func deleteBookmark(_ bookmark: Bookmark) {
        bookmarkManager.remove(bookmark: bookmark, undoManager: nil)
    }

    @MainActor
    func add() {
        guard let window else { return }
        BookmarksDialogViewFactory.makeAddFavoriteView().show(in: window)
    }

    @MainActor
    func edit(_ bookmark: Bookmark) {
        guard let window else { return }
        BookmarksDialogViewFactory.makeEditBookmarkView(bookmark: bookmark).show(in: window)
    }

    func moveFavorite(_ bookmark: Bookmark, toIndex index: Int) {
        bookmarkManager.moveFavorites(with: [bookmark.id], toIndex: index) { _ in }
    }

    @MainActor
    func onFaviconMissing() {
        faviconsFetcherOnboarding?.presentOnboardingIfNeeded()
    }
}

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
    @objc func openInNewTab(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else { return }
        actionsHandler.open(bookmark, target: .newTab)
    }

    @MainActor
    @objc func openInNewWindow(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else { return }
        actionsHandler.open(bookmark, target: .newWindow)
    }

    @MainActor
    func openFavorite(withID bookmarkID: String) {
        guard let favorite = favorites.first(where: { $0.id == bookmarkID}) else { return }
        actionsHandler.open(favorite, target: .current)
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

    @MainActor
    func addNew() {
        actionsHandler.add()
    }

    @MainActor
    func onFaviconMissing() {
        actionsHandler.onFaviconMissing()
    }

    @MainActor
    func showContextMenu(for bookmarkID: String) {
        guard let favorite = favorites.first(where: { $0.id == bookmarkID}) else { return }
        let menu = NSMenu()

        menu.buildItems {
            NSMenuItem(title: UserText.openInNewTab, action: #selector(openInNewTab(_:)), target: self, representedObject: favorite)
                .withAccessibilityIdentifier("HomePage.Views.openInNewTab")
            NSMenuItem(title: UserText.openInNewWindow, action: #selector(openInNewWindow(_:)), target: self, representedObject: favorite)
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
}
