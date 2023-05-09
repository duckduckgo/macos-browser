//
//  ContextualMenu.swift
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

import AppKit

struct ContextualMenu {

    // Not all contexts support an editing option for bookmarks. The option is displayed by default, but `includeBookmarkEditMenu` can disable it.
    static func menu(for objects: [Any]?, includeBookmarkEditMenu: Bool = true) -> NSMenu? {
        guard let objects = objects, objects.count > 0 else {
            return menuForNoSelection()
        }

        if objects.count > 1, let entities = objects as? [BaseBookmarkEntity] {
            return menu(for: entities)
        }

        let node = objects.first as? BookmarkNode
        let object = node?.representedObject ?? objects.first as? BaseBookmarkEntity

        if let bookmark = object as? Bookmark {
            return menu(for: bookmark, includeBookmarkEditMenu: includeBookmarkEditMenu)
        } else if let folder = object as? BookmarkFolder {
            return menu(for: folder)
        } else {
            return nil
        }
    }

    // MARK: - Single Item Menu Creation

    private static func menuForNoSelection() -> NSMenu {
        let menu = NSMenu(title: "")
        menu.addItem(newFolderMenuItem())

        return menu
    }

    private static func menu(for bookmark: Bookmark, includeBookmarkEditMenu: Bool) -> NSMenu {
        let menu = NSMenu(title: "")

        menu.addItem(openBookmarkInNewTabMenuItem(bookmark: bookmark))
        menu.addItem(openBookmarkInNewWindowMenuItem(bookmark: bookmark))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(addBookmarkToFavoritesMenuItem(bookmark: bookmark))

        if includeBookmarkEditMenu {
            menu.addItem(editBookmarkMenuItem(bookmark: bookmark))
        }

        menu.addItem(NSMenuItem.separator())

        menu.addItem(copyBookmarkMenuItem(bookmark: bookmark))
        menu.addItem(deleteBookmarkMenuItem(bookmark: bookmark))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(newFolderMenuItem())

        return menu
    }

    private static func menu(for folder: BookmarkFolder) -> NSMenu {
        let menu = NSMenu(title: "")

        menu.addItem(renameFolderMenuItem(folder: folder))
        menu.addItem(deleteFolderMenuItem(folder: folder))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(openInNewTabsMenuItem(folder: folder))

        return menu
    }

    // MARK: - Menu Items

    static func newFolderMenuItem() -> NSMenuItem {
        return menuItem(UserText.newFolder, #selector(FolderMenuItemSelectors.newFolder(_:)))
    }

    static func renameFolderMenuItem(folder: BookmarkFolder) -> NSMenuItem {
        return menuItem(UserText.renameFolder, #selector(FolderMenuItemSelectors.renameFolder(_:)), folder)
    }

    static func deleteFolderMenuItem(folder: BookmarkFolder) -> NSMenuItem {
        return menuItem(UserText.deleteFolder, #selector(FolderMenuItemSelectors.deleteFolder(_:)), folder)
    }

    static func openInNewTabsMenuItem(folder: BookmarkFolder) -> NSMenuItem {
        return menuItem(UserText.bookmarksOpenInNewTabs, #selector(FolderMenuItemSelectors.openInNewTabs(_:)), folder)
    }

    static func openBookmarksInNewTabsMenuItem(bookmarks: [Bookmark]) -> NSMenuItem {
        return menuItem(UserText.bookmarksOpenInNewTabs, #selector(FolderMenuItemSelectors.openInNewTabs(_:)), bookmarks)
    }

    static func openBookmarkInNewTabMenuItem(bookmark: Bookmark) -> NSMenuItem {
        return menuItem(UserText.openInNewTab, #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)), bookmark)
    }

    static func openBookmarkInNewWindowMenuItem(bookmark: Bookmark) -> NSMenuItem {
        return menuItem(UserText.openInNewWindow, #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)), bookmark)
    }

    static func addBookmarkToFavoritesMenuItem(bookmark: Bookmark) -> NSMenuItem {
        let title: String

        if bookmark.isFavorite {
            title = UserText.removeFromFavorites
        } else {
            title = UserText.addToFavorites
        }

        return menuItem(title, #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), bookmark)
    }

    static func addBookmarksToFavoritesMenuItem(bookmarks: [Bookmark], allFavorites: Bool) -> NSMenuItem {
        let title: String

        if allFavorites {
            title = UserText.removeFromFavorites
        } else {
            title = UserText.addToFavorites
        }

        return menuItem(title, #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), bookmarks)
    }

    static func editBookmarkMenuItem(bookmark: Bookmark) -> NSMenuItem {
        let title = NSLocalizedString("Edit…", comment: "Command")
        return menuItem(title, #selector(BookmarkMenuItemSelectors.editBookmark(_:)), bookmark)
    }

    static func copyBookmarkMenuItem(bookmark: Bookmark) -> NSMenuItem {
        let title = NSLocalizedString("Copy", comment: "Command")
        return menuItem(title, #selector(BookmarkMenuItemSelectors.copyBookmark(_:)), bookmark)
    }

    static func deleteBookmarkMenuItem(bookmark: Bookmark) -> NSMenuItem {
        let title = NSLocalizedString("Delete", comment: "Command")
        return menuItem(title, #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)), bookmark)
    }

    static func menuItem(_ title: String, _ action: Selector, _ representedObject: Any? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.representedObject = representedObject
        return item
    }

    // MARK: - Multi-Item Menu Creation

    private static func menu(for entities: [BaseBookmarkEntity]) -> NSMenu {
        let menu = NSMenu(title: "")
        var menuItems: [NSMenuItem] = []

        let bookmarks = entities.compactMap({ $0 as? Bookmark })

        if !bookmarks.isEmpty {
            menuItems.append(openBookmarksInNewTabsMenuItem(bookmarks: bookmarks))

            // If all selected items are bookmarks and they all have the same favourite status, show a menu item to add/remove them all as favourites.
            if bookmarks.count == entities.count {
                if bookmarks.allSatisfy({ $0.isFavorite }) {
                    menuItems.append(addBookmarksToFavoritesMenuItem(bookmarks: bookmarks, allFavorites: true))
                } else if bookmarks.allSatisfy({ !$0.isFavorite }) {
                    menuItems.append(addBookmarksToFavoritesMenuItem(bookmarks: bookmarks, allFavorites: false))
                }
            }

            menuItems.append(NSMenuItem.separator())
        }

        let title = NSLocalizedString("Delete", comment: "Command")
        let deleteItem = NSMenuItem(title: title, action: #selector(BookmarkMenuItemSelectors.deleteEntities(_:)), keyEquivalent: "")
        deleteItem.representedObject = entities
        menuItems.append(deleteItem)

        menu.items = menuItems

        return menu
    }

}
