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

    enum Constants {
        static let maxTitleLength = 55
    }

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
    @IBOutlet weak var recentlyClosedMenuItem: NSMenuItem!
    @IBOutlet weak var reopenLastClosedMenuItem: NSMenuItem? {
        didSet {
            reopenMenuItemKeyEquivalentManager.reopenLastClosedMenuItem = reopenLastClosedMenuItem
        }
    }
    @IBOutlet weak var reopenLastClosedWindowMenuItem: NSMenuItem!
    @IBOutlet weak var reopenAllWindowsFromLastSessionMenuItem: NSMenuItem? {
        didSet {
            reopenMenuItemKeyEquivalentManager.lastSessionMenuItem = reopenAllWindowsFromLastSessionMenuItem
        }
    }

    @IBOutlet weak var manageBookmarksMenuItem: NSMenuItem!
    @IBOutlet weak var bookmarksMenuToggleBookmarksBarMenuItem: NSMenuItem?
    @IBOutlet weak var importBookmarksMenuItem: NSMenuItem!
    @IBOutlet weak var bookmarksMenuItem: NSMenuItem?
    @IBOutlet weak var bookmarkThisPageMenuItem: NSMenuItem?
    @IBOutlet weak var favoritesMenuItem: NSMenuItem?
    @IBOutlet weak var favoriteThisPageMenuItem: NSMenuItem?
    
    @IBOutlet weak var toggleBookmarksBarMenuItem: NSMenuItem?

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
    var recentlyClosedMenu: RecentlyClosedMenu?

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

        updateRecentlyClosedMenu()
        updateReopenLastClosedMenuItem()
        updateBookmarksBarMenuItem()
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

        sendFeedbackMenuItem.isHidden = true

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

    private func updateBookmarksBarMenuItem() {
        let title = PersistentAppInterfaceSettings.shared.showBookmarksBar ? UserText.hideBookmarksBar : UserText.showBookmarksBar
        toggleBookmarksBarMenuItem?.title = title
        bookmarksMenuToggleBookmarksBarMenuItem?.title = title
    }

    // MARK: - Reopen Last Closed & Recently Closed
    
    private let reopenMenuItemKeyEquivalentManager = ReopenMenuItemKeyEquivalentManager()

    private func updateReopenLastClosedMenuItem() {
        switch RecentlyClosedCoordinator.shared.cache.last {
        case is RecentlyClosedWindow:
            reopenLastClosedMenuItem?.title = UserText.reopenLastClosedWindow
        default:
            reopenLastClosedMenuItem?.title = UserText.reopenLastClosedTab
        }

    }

    private func updateRecentlyClosedMenu() {
        recentlyClosedMenu = RecentlyClosedMenu(recentlyClosedCoordinator: RecentlyClosedCoordinator.shared)
        recentlyClosedMenuItem.submenu = recentlyClosedMenu
        recentlyClosedMenuItem.isEnabled = !(recentlyClosedMenu?.items ?? [] ).isEmpty
    }

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

extension MainMenu {
    /**
     * This class manages the shortcut assignment to either of the
     * "Reopen Last Closed Tab" or "Reopen All Windows from Last Session"
     * menu items.
     */
    final class ReopenMenuItemKeyEquivalentManager {
        weak var reopenLastClosedMenuItem: NSMenuItem?
        weak var lastWindowMenuItem: NSMenuItem?
        weak var lastSessionMenuItem: NSMenuItem?

        enum Const {
            static let keyEquivalent = "T"
            static let modifierMask = NSEvent.ModifierFlags.command
        }

        init(
            isInInitialStatePublisher: Published<Bool>.Publisher = WindowControllersManager.shared.$isInInitialState,
            canRestoreLastSessionState: @escaping @autoclosure () -> Bool = NSApp.canRestoreLastSessionState
        ) {
            self.canRestoreLastSessionState = canRestoreLastSessionState
            self.isInInitialStateCancellable = isInInitialStatePublisher
                .dropFirst()
                .removeDuplicates()
                .sink { [weak self] isInInitialState in
                    self?.updateKeyEquivalent(isInInitialState)
                }
        }

        private weak var currentlyAssignedMenuItem: NSMenuItem?
        private var isInInitialStateCancellable: AnyCancellable?
        private var canRestoreLastSessionState: () -> Bool

        private func updateKeyEquivalent(_ isInInitialState: Bool) {
            if isInInitialState && canRestoreLastSessionState() {
                assignKeyEquivalent(to: lastSessionMenuItem)
            } else {
                assignKeyEquivalent(to: reopenLastClosedMenuItem)
            }
        }

        func assignKeyEquivalent(to menuItem: NSMenuItem?) {
            currentlyAssignedMenuItem?.keyEquivalent = ""
            currentlyAssignedMenuItem?.keyEquivalentModifierMask = []
            menuItem?.keyEquivalent = Const.keyEquivalent
            menuItem?.keyEquivalentModifierMask = Const.modifierMask
            currentlyAssignedMenuItem = menuItem
        }
    }
}

private extension NSApplication {
    var canRestoreLastSessionState: Bool {
        (delegate as? AppDelegate)?.stateRestorationManager?.canRestoreLastSessionState ?? false
    }
}
