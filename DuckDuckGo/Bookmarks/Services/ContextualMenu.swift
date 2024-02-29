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

enum ContextualMenu {

    static func menu(for objects: [Any]?) -> NSMenu? {
        menu(for: objects, target: nil)
    }

    /// Creates an instance of NSMenu for the specified Objects and target.
    /// - Parameters:
    ///   - objects: The objects to create the menu for.
    ///   - target: The target to associate to the `NSMenuItem`
    /// - Returns: An instance of NSMenu or nil if `objects` is not a `Bookmark` or a `Folder`.
    static func menu(for objects: [Any]?, target: AnyObject?) -> NSMenu? {

        guard let objects = objects, objects.count > 0 else {
            return menuForNoSelection()
        }

        if objects.count > 1, let entities = objects as? [BaseBookmarkEntity] {
            return menu(for: entities)
        }

        let node = objects.first as? BookmarkNode
        let object = node?.representedObject as? BaseBookmarkEntity ?? objects.first as? BaseBookmarkEntity
        let parentFolder = node?.parent?.representedObject as? BookmarkFolder

        guard let object else { return nil }

        let menu = menu(for: object, parentFolder: parentFolder)

        menu?.items.forEach { item in
            item.target = target
        }

        return menu
    }

    /// Creates an instance of NSMenu for the specified `BaseBookmarkEntity`and parent `BookmarkFolder`.
    ///
    /// - Parameters:
    ///   - entity: The bookmark entity to create the menu for.
    ///   - parentFolder: An optional `BookmarkFolder`.
    /// - Returns: An instance of NSMenu or nil if `entity` is not a `Bookmark` or a `Folder`.
    static func menu(for entity: BaseBookmarkEntity, parentFolder: BookmarkFolder?) -> NSMenu? {
        let menu: NSMenu?
        if let bookmark = entity as? Bookmark {
            menu = self.menu(for: bookmark, isFavorite: bookmark.isFavorite)
        } else if let folder = entity as? BookmarkFolder {
            // When the user edits a folder we need to show the parent in the folder picker. Folders directly child of PseudoFolder `Bookmarks` have nil parent because their parent is not an instance of `BookmarkFolder`
            menu = self.menu(for: folder, parent: parentFolder)
        } else {
            menu = nil
        }

        return menu
    }

    /// Returns an array of `NSMenuItem` to show for a bookmark.
    ///
    ///  - Important: The `representedObject` for the `NSMenuItem` returned is `nil`. This function is meant to be used for scenarios where the model is not available at the time of creating the `NSMenu` such as from the BookmarkBarCollectionViewItem.
    ///
    /// - Parameter isFavorite: True if the menu item should contain a menu item to add to favorites. False to contain a menu item to remove from favorites.
    /// - Returns: An array of `NSMenuItem`
    static func bookmarkMenuItems(isFavorite: Bool) -> [NSMenuItem] {
        menuItems(for: nil, isFavorite: isFavorite)
    }

    /// Returns an array of `NSMenuItem` to show for a bookmark folder.
    ///
    ///  - Important: The `representedObject` for the `NSMenuItem` returned is `nil`. This function is meant to be used for scenarios where the model is not available at the time of creating the `NSMenu` such as from the BookmarkBarCollectionViewItem.
    ///
    /// - Returns: An array of `NSMenuItem`
    static func folderMenuItems() -> [NSMenuItem] {
       menuItems(for: nil, parent: nil)
    }

}

private extension ContextualMenu {

    static func menuForNoSelection() -> NSMenu {
        NSMenu(items: [addFolderMenuItem()])
    }

    static func menu(for bookmark: Bookmark?, isFavorite: Bool) -> NSMenu {
        NSMenu(items: menuItems(for: bookmark, isFavorite: isFavorite))
    }

    static func menu(for folder: BookmarkFolder?, parent: BookmarkFolder?) -> NSMenu {
       NSMenu(items: menuItems(for: folder, parent: parent))
    }

    static func menuItems(for bookmark: Bookmark?, isFavorite: Bool) -> [NSMenuItem] {
        [
            openBookmarkInNewTabMenuItem().bookmark(bookmark),
            openBookmarkInNewWindowMenuItem().bookmark(bookmark),
            NSMenuItem.separator(),
            addBookmarkToFavoritesMenuItem(isFavorite: isFavorite).bookmark(bookmark),
            NSMenuItem.separator(),
            editBookmarkMenuItem().bookmark(bookmark),
            copyBookmarkMenuItem().bookmark(bookmark),
            deleteBookmarkMenuItem().bookmark(bookmark),
            NSMenuItem.separator(),
            addFolderMenuItem(),
            manageBookmarksMenuItem(),
        ]
    }

    static func menuItems(for folder: BookmarkFolder?, parent: BookmarkFolder?) -> [NSMenuItem] {
        [
            openInNewTabsMenuItem().folder(folder),
            openAllInNewWindowMenuItem().folder(folder),
            NSMenuItem.separator(),
            editFolderMenuItem().folder(folder, parent: parent),
            deleteFolderMenuItem().folder(folder),
            NSMenuItem.separator(),
            addFolderMenuItem().folder(folder),
            manageBookmarksMenuItem(),
        ]
    }

    static func menuItem(_ title: String, _ action: Selector, _ representedObject: Any? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.representedObject = representedObject
        return item
    }

    // MARK: - Single Bookmark Menu Items

    static func openBookmarkInNewTabMenuItem() -> NSMenuItem {
        menuItem(UserText.openInNewTab, #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)))
    }

    static func openBookmarkInNewWindowMenuItem() -> NSMenuItem {
        menuItem(UserText.openInNewWindow, #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)))
    }

    static func manageBookmarksMenuItem() -> NSMenuItem {
        menuItem(UserText.bookmarksManageBookmarks, #selector(BookmarkMenuItemSelectors.manageBookmarks(_:)))
    }

    static func addBookmarkToFavoritesMenuItem(isFavorite: Bool) -> NSMenuItem {
        let title = isFavorite ? UserText.removeFromFavorites : UserText.addToFavorites
        return menuItem(title, #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)))
    }

    static func addBookmarksToFavoritesMenuItem(bookmarks: [Bookmark], allFavorites: Bool) -> NSMenuItem {
        let title = allFavorites ? UserText.removeFromFavorites : UserText.addToFavorites
        return menuItem(title, #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), bookmarks)
    }

    static func editBookmarkMenuItem() -> NSMenuItem {
        menuItem(UserText.editBookmark, #selector(BookmarkMenuItemSelectors.editBookmark(_:)))
    }

    static func copyBookmarkMenuItem() -> NSMenuItem {
        menuItem(UserText.copy, #selector(BookmarkMenuItemSelectors.copyBookmark(_:)))
    }

    static func deleteBookmarkMenuItem() -> NSMenuItem {
        menuItem(UserText.bookmarksBarContextMenuDelete, #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)))
    }

    // MARK: - Bookmark Folder Menu Items

    static func openInNewTabsMenuItem() -> NSMenuItem {
        menuItem(UserText.openAllInNewTabs, #selector(FolderMenuItemSelectors.openInNewTabs(_:)))
    }

    static func openAllInNewWindowMenuItem() -> NSMenuItem {
        menuItem(UserText.openAllTabsInNewWindow, #selector(FolderMenuItemSelectors.openAllInNewWindow(_:)))
    }

    static func addFolderMenuItem() -> NSMenuItem {
        menuItem(UserText.addFolder, #selector(FolderMenuItemSelectors.newFolder(_:)))
    }

    static func editFolderMenuItem() -> NSMenuItem {
        menuItem(UserText.editBookmark, #selector(FolderMenuItemSelectors.editFolder(_:)))
    }

    static func deleteFolderMenuItem() -> NSMenuItem {
        menuItem(UserText.bookmarksBarContextMenuDelete, #selector(FolderMenuItemSelectors.deleteFolder(_:)))
    }

    // MARK: - Multi-Item Menu Creation

    static func openBookmarksInNewTabsMenuItem(bookmarks: [Bookmark]) -> NSMenuItem {
        menuItem(UserText.bookmarksOpenInNewTabs, #selector(FolderMenuItemSelectors.openInNewTabs(_:)), bookmarks)
    }

    static func menu(for entities: [BaseBookmarkEntity]) -> NSMenu {
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

        let deleteItem = NSMenuItem(title: UserText.bookmarksBarContextMenuDelete, action: #selector(BookmarkMenuItemSelectors.deleteEntities(_:)), keyEquivalent: "")
        deleteItem.representedObject = entities
        menuItems.append(deleteItem)

        menu.items = menuItems

        return menu
    }

}

private extension NSMenuItem {

    func bookmark(_ bookmark: Bookmark?) -> NSMenuItem {
        representedObject = bookmark
        return self
    }

    func folder(_ folder: BookmarkFolder?) -> NSMenuItem {
        representedObject = folder
        return self
    }

    func folder(_ folder: BookmarkFolder?, parent: BookmarkFolder?) -> NSMenuItem {
        guard let folder else { return self }
        representedObject = BookmarkFolderInfo(parent: parent, folder: folder)
        return self
    }

}
