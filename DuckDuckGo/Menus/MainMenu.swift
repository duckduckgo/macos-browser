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

final class MainMenu: NSMenu {

    @IBOutlet weak var checkForUpdatesMenuItem: NSMenuItem?
    @IBOutlet weak var checkForUpdatesSeparatorItem: NSMenuItem?

    @IBOutlet weak var newWindowMenuItem: NSMenuItem!
    @IBOutlet weak var newTabMenuItem: NSMenuItem!
    @IBOutlet weak var openLocationMenuItem: NSMenuItem!
    @IBOutlet weak var closeWindowMenuItem: NSMenuItem!
    @IBOutlet weak var closeAllWindowsMenuItem: NSMenuItem!
    @IBOutlet weak var closeTabMenuItem: NSMenuItem!
    @IBOutlet weak var burnWebsiteDataMenuItem: NSMenuItem!
    @IBOutlet weak var printSeparatorItem: NSMenuItem?
    @IBOutlet weak var printMenuItem: NSMenuItem?
    @IBOutlet weak var shareMenuItem: NSMenuItem!
    @IBOutlet weak var importBrowserDataMenuItem: NSMenuItem!
    @IBOutlet weak var preferencesMenuItem: NSMenuItem!

    @IBOutlet weak var checkSpellingWhileTypingMenuItem: NSMenuItem?
    @IBOutlet weak var checkGrammarWithSpellingMenuItem: NSMenuItem?

    @IBOutlet weak var backMenuItem: NSMenuItem?
    @IBOutlet weak var forwardMenuItem: NSMenuItem?
    @IBOutlet weak var reloadMenuItem: NSMenuItem?
    @IBOutlet weak var stopMenuItem: NSMenuItem?
    @IBOutlet weak var homeMenuItem: NSMenuItem?
    @IBOutlet weak var reopenLastClosedTabMenuItem: NSMenuItem?

    @IBOutlet weak var manageBookmarksMenuItem: NSMenuItem!
    @IBOutlet weak var importBookmarksMenuItem: NSMenuItem!
    @IBOutlet weak var bookmarksMenuItem: NSMenuItem?
    @IBOutlet weak var bookmarkThisPageMenuItem: NSMenuItem?
    @IBOutlet weak var favoritesMenuItem: NSMenuItem?
    @IBOutlet weak var favoriteThisPageMenuItem: NSMenuItem?

    @IBOutlet weak var debugMenuItem: NSMenuItem? {
        didSet {
            #if !DEBUG && !REVIEW
            if let item = debugMenuItem {
                removeItem(item)
            }
            #endif
        }
    }

    @IBOutlet weak var helpMenuItem: NSMenuItem?
    @IBOutlet weak var helpSeparatorMenuItem: NSMenuItem?
    @IBOutlet weak var sendFeedbackMenuItem: NSMenuItem?

    @IBOutlet weak var toggleFullscreenMenuItem: NSMenuItem?
    @IBOutlet weak var zoomInMenuItem: NSMenuItem?
    @IBOutlet weak var zoomOutMenuItem: NSMenuItem?
    @IBOutlet weak var actualSizeMenuItem: NSMenuItem?

    let sharingMenu = SharingMenu()

    required init(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }
  
    override func update() {
        super.update()

        if !WKWebView.canPrint {
            printMenuItem?.removeFromParent()
            printSeparatorItem?.removeFromParent()
        }
        sharingMenu.title = shareMenuItem.title
        shareMenuItem.submenu = sharingMenu

#if !OUT_OF_APPSTORE

        checkForUpdatesMenuItem?.removeFromParent()
        checkForUpdatesSeparatorItem?.removeFromParent()

#endif
    }

    private func setup() {
        self.delegate = self
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
        bookmarkListCancellable = LocalBookmarkManager.shared.$list
            .compactMap({
                let favorites = $0?.favoriteBookmarks.compactMap(BookmarkViewModel.init(entity:)) ?? []
                let topLevelEntities = $0?.topLevelEntities.compactMap(BookmarkViewModel.init(entity:)) ?? []

                return (favorites, topLevelEntities)
            })
            .receive(on: DispatchQueue.main).sink { [weak self] favorites, topLevel in
                self?.updateBookmarksMenu(favoriteViewModels: favorites, topLevelBookmarkViewModels: topLevel)
            }
    }

    // Nested recursing functions cause body length
    // swiftlint:disable function_body_length
    func updateBookmarksMenu(favoriteViewModels: [BookmarkViewModel], topLevelBookmarkViewModels: [BookmarkViewModel]) {

        func bookmarkMenuItems(from bookmarkViewModels: [BookmarkViewModel], topLevel: Bool = true) -> [NSMenuItem] {
            var menuItems = [NSMenuItem]()

            if !topLevel {
                let showOpenInTabsItem = bookmarkViewModels.compactMap { $0.entity as? Bookmark }.count > 1
                if showOpenInTabsItem {
                    menuItems.append(NSMenuItem(bookmarkViewModels: bookmarkViewModels))
                    menuItems.append(.separator())
                }
            }

            for viewModel in bookmarkViewModels {
                let menuItem = NSMenuItem(bookmarkViewModel: viewModel)

                if let folder = viewModel.entity as? BookmarkFolder {
                    let subMenu = NSMenu(title: folder.title)
                    let childViewModels = folder.children.map(BookmarkViewModel.init)
                    let childMenuItems = bookmarkMenuItems(from: childViewModels, topLevel: false)
                    subMenu.items = childMenuItems

                    if !subMenu.items.isEmpty {
                        menuItem.submenu = subMenu
                    }
                }

                menuItems.append(menuItem)
            }

            return menuItems
        }

        func favoriteMenuItems(from bookmarkViewModels: [BookmarkViewModel]) -> [NSMenuItem] {
            bookmarkViewModels
                .filter { ($0.entity as? Bookmark)?.isFavorite ?? false }
                .enumerated()
                .map { index, bookmarkViewModel in
                    let item = NSMenuItem(bookmarkViewModel: bookmarkViewModel)
                    if index < 9 {
                        item.keyEquivalentModifierMask = [.option, .command]
                        item.keyEquivalent = String(index + 1)
                    }
                    return item
                }
        }

        guard let bookmarksMenu = bookmarksMenuItem?.submenu,
              let favoritesSeparatorIndex = bookmarksMenu.items.lastIndex(where: { $0.isSeparatorItem }),
              let favoritesMenuItem = favoritesMenuItem,
              let favoritesMenu = favoritesMenuItem.submenu,
              let favoriteThisPageSeparatorIndex = favoritesMenu.items.lastIndex(where: { $0.isSeparatorItem }) else {
            os_log("MainMenuManager: Failed to reference bookmarks menu items", type: .error)
            return
        }

        let cleanedBookmarkItems = bookmarksMenu.items.dropLast(bookmarksMenu.items.count - (favoritesSeparatorIndex + 1))
        let bookmarkItems = bookmarkMenuItems(from: topLevelBookmarkViewModels)
        bookmarksMenu.items = Array(cleanedBookmarkItems) + bookmarkItems

        let cleanedFavoriteItems = favoritesMenu.items.dropLast(favoritesMenu.items.count - (favoriteThisPageSeparatorIndex + 1))
        let favoriteItems = favoriteMenuItems(from: favoriteViewModels)
        favoritesMenu.items = Array(cleanedFavoriteItems) + favoriteItems
    }
    // swiftlint:enable function_body_length

}

extension MainMenu: NSMenuDelegate {

    func menuHasKeyEquivalent(_ menu: NSMenu,
                              for event: NSEvent,
                              target: AutoreleasingUnsafeMutablePointer<AnyObject?>,
                              action: UnsafeMutablePointer<Selector?>) -> Bool {
        sharingMenu.update()
        shareMenuItem.submenu = sharingMenu
        return false
    }

}

fileprivate extension NSMenuItem {
    
    convenience init(bookmarkViewModel: BookmarkViewModel) {
        self.init()
        
        title = bookmarkViewModel.menuTitle
        image = bookmarkViewModel.menuFavicon
        representedObject = bookmarkViewModel.entity
        action = #selector(MainViewController.openBookmark(_:))
    }

    convenience init(bookmarkViewModels: [BookmarkViewModel]) {
        self.init()

        title = UserText.bookmarksOpenInNewTabs
        representedObject = bookmarkViewModels
        action = #selector(MainViewController.openAllInTabs(_:))
    }

    func removeFromParent() {
        parent?.submenu?.removeItem(self)
    }

}
