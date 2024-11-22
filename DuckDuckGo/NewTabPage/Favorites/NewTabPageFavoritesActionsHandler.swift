//
//  NewTabPageFavoritesActionsHandler.swift
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

protocol FavoritesActionsHandling {
    @MainActor func open(_ url: URL, target: NewTabPageFavoritesModel.OpenTarget)
    @MainActor func addNewFavorite()
    @MainActor func edit(_ bookmark: Bookmark)
    @MainActor func onFaviconMissing()

    func removeFavorite(_ bookmark: Bookmark)
    func deleteBookmark(_ bookmark: Bookmark)
    func move(_ bookmarkID: String, toIndex: Int)
}

final class DefaultFavoritesActionsHandler: FavoritesActionsHandling {
    let bookmarkManager: BookmarkManager

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
    }

    @MainActor
    func open(_ url: URL, target: NewTabPageFavoritesModel.OpenTarget) {
        guard let tabCollectionViewModel else {
            return
        }

        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()

        if target == .newWindow || NSApplication.shared.isCommandPressed && NSApplication.shared.isOptionPressed {
            WindowsManager.openNewWindow(with: url, source: .bookmark, isBurner: tabCollectionViewModel.isBurner)
        } else if target == .newTab || NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
            tabCollectionViewModel.insertOrAppendNewTab(.contentFromURL(url, source: .bookmark), selected: true)
        } else if NSApplication.shared.isCommandPressed {
            tabCollectionViewModel.insertOrAppendNewTab(.contentFromURL(url, source: .bookmark), selected: false)
        } else {
            tabCollectionViewModel.selectedTabViewModel?.tab.setContent(.contentFromURL(url, source: .bookmark))
        }
    }

    func removeFavorite(_ bookmark: Bookmark) {
        bookmark.isFavorite = false
        bookmarkManager.update(bookmark: bookmark)
    }

    func deleteBookmark(_ bookmark: Bookmark) {
        bookmarkManager.remove(bookmark: bookmark, undoManager: nil)
    }

    @MainActor
    func addNewFavorite() {
        guard let window else { return }
        BookmarksDialogViewFactory.makeAddFavoriteView().show(in: window)
    }

    @MainActor
    func edit(_ bookmark: Bookmark) {
        guard let window else { return }
        BookmarksDialogViewFactory.makeEditBookmarkView(bookmark: bookmark).show(in: window)
    }

    func move(_ bookmarkID: String, toIndex index: Int) {
        bookmarkManager.moveFavorites(with: [bookmarkID], toIndex: index) { _ in }
    }

    @MainActor
    func onFaviconMissing() {
        faviconsFetcherOnboarding?.presentOnboardingIfNeeded()
    }

    @MainActor
    private var window: NSWindow? {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.view.window
    }

    @MainActor
    private var tabCollectionViewModel: TabCollectionViewModel? {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel
    }

    private lazy var faviconsFetcherOnboarding: FaviconsFetcherOnboarding? = {
        guard let syncService = NSApp.delegateTyped.syncService, let syncBookmarksAdapter = NSApp.delegateTyped.syncDataProviders?.bookmarksAdapter else {
            assertionFailure("SyncService and/or SyncBookmarksAdapter is nil")
            return nil
        }
        return .init(syncService: syncService, syncBookmarksAdapter: syncBookmarksAdapter)
    }()
}
