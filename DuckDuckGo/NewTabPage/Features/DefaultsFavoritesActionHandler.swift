//
//  DefaultsFavoritesActionHandler.swift
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
import NewTabPage

final class DefaultFavoritesActionsHandler: FavoritesActionsHandling {
    typealias Favorite = Bookmark

    let bookmarkManager: BookmarkManager

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
    }

    @MainActor
    func open(_ url: URL, target: LinkOpenTarget) {
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

    func removeFavorite(_ favorite: Bookmark) {
        favorite.isFavorite = false
        bookmarkManager.update(bookmark: favorite)
    }

    func deleteBookmark(for favorite: Bookmark) {
        bookmarkManager.remove(bookmark: favorite, undoManager: nil)
    }

    @MainActor
    func addNewFavorite() {
        guard let window else { return }
        BookmarksDialogViewFactory.makeAddFavoriteView().show(in: window)
    }

    @MainActor
    func edit(_ favorite: Bookmark) {
        guard let window else { return }
        BookmarksDialogViewFactory.makeEditBookmarkView(bookmark: favorite).show(in: window)
    }

    func move(_ bookmarkID: String, toIndex index: Int) {
        bookmarkManager.moveFavorites(with: [bookmarkID], toIndex: index) { _ in }
    }

    @MainActor
    private var window: NSWindow? {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.view.window
    }

    @MainActor
    private var tabCollectionViewModel: TabCollectionViewModel? {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel
    }
}

extension Bookmark: NewTabPageFavorite {
    private enum Const {
        static let wwwPrefix = "www."
    }

    var etldPlusOne: String? {
        guard let domain = urlObject?.host else {
            return nil
        }
        return ContentBlocking.shared.tld.eTLDplus1(domain)?.dropping(prefix: Const.wwwPrefix)
    }
}
