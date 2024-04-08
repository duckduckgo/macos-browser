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
            menu = self.menu(for: bookmark, parent: parentFolder, isFavorite: bookmark.isFavorite)
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
        menuItems(for: nil, parent: nil, isFavorite: isFavorite)
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
        NSMenu(items: [addFolderMenuItem(folder: nil)])
    }

    static func menu(for bookmark: Bookmark?, parent: BookmarkFolder?, isFavorite: Bool) -> NSMenu {
        NSMenu(items: menuItems(for: bookmark, parent: parent, isFavorite: isFavorite))
    }

    static func menu(for folder: BookmarkFolder?, parent: BookmarkFolder?) -> NSMenu {
       NSMenu(items: menuItems(for: folder, parent: parent))
    }

    static func menuItems(for bookmark: Bookmark?, parent: BookmarkFolder?, isFavorite: Bool) -> [NSMenuItem] {
        [
            openBookmarkInNewTabMenuItem(bookmark: bookmark),
            openBookmarkInNewWindowMenuItem(bookmark: bookmark),
            NSMenuItem.separator(),
            addBookmarkToFavoritesMenuItem(isFavorite: isFavorite, bookmark: bookmark),
            NSMenuItem.separator(),
            editBookmarkMenuItem(bookmark: bookmark),
            copyBookmarkMenuItem(bookmark: bookmark),
            deleteBookmarkMenuItem(bookmark: bookmark),
            moveToEndMenuItem(entity: bookmark, parent: parent),
            NSMenuItem.separator(),
            addFolderMenuItem(folder: parent),
            manageBookmarksMenuItem()
        ]
    }

    static func menuItems(for folder: BookmarkFolder?, parent: BookmarkFolder?) -> [NSMenuItem] {
        [
            openInNewTabsMenuItem(folder: folder),
            openAllInNewWindowMenuItem(folder: folder),
            NSMenuItem.separator(),
            editFolderMenuItem(folder: folder, parent: parent),
            deleteFolderMenuItem(folder: folder),
            moveToEndMenuItem(entity: folder, parent: parent),
            NSMenuItem.separator(),
            addFolderMenuItem(folder: folder),
            manageBookmarksMenuItem()
        ]
    }

    static func menuItem(_ title: String, _ action: Selector, _ representedObject: Any? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.representedObject = representedObject
        return item
    }

    // MARK: - Single Bookmark Menu Items

    static func openBookmarkInNewTabMenuItem(bookmark: Bookmark?) -> NSMenuItem {
        menuItem(UserText.openInNewTab, #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)), bookmark)
    }

    static func openBookmarkInNewWindowMenuItem(bookmark: Bookmark?) -> NSMenuItem {
        menuItem(UserText.openInNewWindow, #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)), bookmark)
    }

    static func manageBookmarksMenuItem() -> NSMenuItem {
        menuItem(UserText.bookmarksManageBookmarks, #selector(BookmarkMenuItemSelectors.manageBookmarks(_:)))
    }

    static func addBookmarkToFavoritesMenuItem(isFavorite: Bool, bookmark: Bookmark?) -> NSMenuItem {
        let title = isFavorite ? UserText.removeFromFavorites : UserText.addToFavorites
        return menuItem(title, #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), bookmark)
    }

    static func addBookmarksToFavoritesMenuItem(bookmarks: [Bookmark], allFavorites: Bool) -> NSMenuItem {
        let title = allFavorites ? UserText.removeFromFavorites : UserText.addToFavorites
        return menuItem(title, #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), bookmarks)
    }

    static func editBookmarkMenuItem(bookmark: Bookmark?) -> NSMenuItem {
        menuItem(UserText.editBookmark, #selector(BookmarkMenuItemSelectors.editBookmark(_:)), bookmark)
    }

    static func copyBookmarkMenuItem(bookmark: Bookmark?) -> NSMenuItem {
        menuItem(UserText.copy, #selector(BookmarkMenuItemSelectors.copyBookmark(_:)), bookmark)
    }

    static func deleteBookmarkMenuItem(bookmark: Bookmark?) -> NSMenuItem {
        menuItem(UserText.bookmarksBarContextMenuDelete, #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)), bookmark)
    }

    static func moveToEndMenuItem(entity: BaseBookmarkEntity?, parent: BookmarkFolder?) -> NSMenuItem {
        let bookmarkEntityInfo = entity.flatMap { BookmarkEntityInfo(entity: $0, parent: parent) }
        return menuItem(UserText.bookmarksBarContextMenuMoveToEnd, #selector(BookmarkMenuItemSelectors.moveToEnd(_:)), bookmarkEntityInfo)
    }

    // MARK: - Bookmark Folder Menu Items

    static func openInNewTabsMenuItem(folder: BookmarkFolder?) -> NSMenuItem {
        menuItem(UserText.openAllInNewTabs, #selector(FolderMenuItemSelectors.openInNewTabs(_:)), folder)
    }

    static func openAllInNewWindowMenuItem(folder: BookmarkFolder?) -> NSMenuItem {
        menuItem(UserText.openAllTabsInNewWindow, #selector(FolderMenuItemSelectors.openAllInNewWindow(_:)), folder)
    }

    static func addFolderMenuItem(folder: BookmarkFolder?) -> NSMenuItem {
        menuItem(UserText.addFolder, #selector(FolderMenuItemSelectors.newFolder(_:)), folder)
    }

    static func editFolderMenuItem(folder: BookmarkFolder?, parent: BookmarkFolder?) -> NSMenuItem {
        let folderEntityInfo = folder.flatMap { BookmarkEntityInfo(entity: $0, parent: parent) }
        return menuItem(UserText.editBookmark, #selector(FolderMenuItemSelectors.editFolder(_:)), folderEntityInfo)
    }

    static func deleteFolderMenuItem(folder: BookmarkFolder?) -> NSMenuItem {
        menuItem(UserText.bookmarksBarContextMenuDelete, #selector(FolderMenuItemSelectors.deleteFolder(_:)), folder)
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
