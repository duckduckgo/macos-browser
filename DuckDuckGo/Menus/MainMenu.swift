//
//  MainMenu.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Cocoa
import os.log
import Combine

class MainMenu: NSMenu {

    required init(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }

    enum Tag: Int {
        case history = 4
        case back = 40
        case forward = 41
        case reopenLastClosedTab = 43
        case bookmarks = 5
        case bookmarkThisPage = 50
        case favorites = 52
        case favoriteThisPage = 520
        case help = 7
        case helpSeparator = 71
        case sendFeedback = 72
    }

    var backMenuItem: NSMenuItem? {
        return item(withTag: Tag.history.rawValue)?.submenu?.item(withTag: Tag.back.rawValue)
    }

    var forwardMenuItem: NSMenuItem? {
        return item(withTag: Tag.history.rawValue)?.submenu?.item(withTag: Tag.forward.rawValue)
    }

    var reopenLastClosedTabMenuItem: NSMenuItem? {
        return item(withTag: Tag.history.rawValue)?.submenu?.item(withTag: Tag.reopenLastClosedTab.rawValue)
    }

    var bookmarksMenuItem: NSMenuItem? {
        item(withTag: Tag.bookmarks.rawValue)
    }

    var bookmarkThisPageMenuItem: NSMenuItem? {
        bookmarksMenuItem?.submenu?.item(withTag: Tag.bookmarkThisPage.rawValue)
    }

    var favoritesMenuItem: NSMenuItem? {
        bookmarksMenuItem?.submenu?.item(withTag: Tag.favorites.rawValue)
    }

    var favoriteThisPageMenuItem: NSMenuItem? {
        favoritesMenuItem?.submenu?.item(withTag: Tag.favoriteThisPage.rawValue)
    }

    var helpMenuItem: NSMenuItem? {
        return item(withTag: Tag.help.rawValue)
    }

    var helpSeparatorMenuItem: NSMenuItem? {
        helpMenuItem?.submenu?.item(withTag: Tag.helpSeparator.rawValue)
    }

    var sendFeedbackMenuItem: NSMenuItem? {
        helpMenuItem?.submenu?.item(withTag: Tag.sendFeedback.rawValue)
    }

    private func setup() {

#if !FEEDBACK

        guard let helpMenuItemSubmenu = helpMenuItem?.submenu,
              let helpSeparatorMenuItem = helpSeparatorMenuItem,
              let sendFeedbackMenuItem = sendFeedbackMenuItem else {
            os_log("MainMenuManager: Failed to setup main menu", type: .error)
            return
        }

        helpMenuItemSubmenu.removeItem(helpSeparatorMenuItem)
        helpMenuItemSubmenu.removeItem(sendFeedbackMenuItem)

#endif

        subscribeToBookmarkList()
    }

    // MARK: - Bookmarks

    var bookmarkListCancellable: AnyCancellable?
    private func subscribeToBookmarkList() {
        bookmarkListCancellable = LocalBookmarksManager.shared.$list.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateBookmarks()
        }
    }

    func updateBookmarks() {
        let bookmarkList = LocalBookmarksManager.shared.list
        guard let bookmarksMenu = bookmarksMenuItem?.submenu,
              let favoritesSeparatorIndex = bookmarksMenu.items.lastIndex(where: { $0.isSeparatorItem }),
              let favoritesMenuItem = favoritesMenuItem,
              let favoritesMenu = favoritesMenuItem.submenu,
              let favoriteThisPageSeparatorIndex = favoritesMenu.items.lastIndex(where: { $0.isSeparatorItem })
        else {
            os_log("MainMenuManager: Failed to reference bookmarks menu items", type: .error)
            return
        }

        let cleanedBookmarkItems = bookmarksMenu.items.dropLast(bookmarksMenu.items.count - (favoritesSeparatorIndex + 1))
        let bookmarkItems = bookmarkList.makeMenuItems()
        bookmarksMenu.items = Array(cleanedBookmarkItems) + bookmarkItems

        let cleanedFavoriteItems = favoritesMenu.items.dropLast(favoritesMenu.items.count - (favoriteThisPageSeparatorIndex + 1))
        let favoriteItems = bookmarkList.makeFavoriteMenuItems()
        favoritesMenu.items = Array(cleanedFavoriteItems) + favoriteItems
    }

}

fileprivate extension BookmarkList {
    
    func makeMenuItems() -> [NSMenuItem] {
        return bookmarks().map { bookmark in
            return NSMenuItem(bookmark: bookmark)
        }
    }
    
    func makeFavoriteMenuItems() -> [NSMenuItem] {
        return bookmarks().filter {
            $0.isFavorite
        } .map { bookmark in
            return NSMenuItem(bookmark: bookmark)
        }
    }
    
}

fileprivate extension NSMenuItem {
    
    convenience init(bookmark: Bookmark) {
        self.init()
        
        title = bookmark.title
        image = bookmark.isFavorite ? bookmark.favicon?.makeFavoriteOverlay() : bookmark.favicon
        representedObject = bookmark.url
        action = #selector(MainViewController.navigateToBookmark(_:))
    }
    
}
