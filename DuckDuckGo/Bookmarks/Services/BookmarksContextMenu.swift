//
//  BookmarksContextMenu.swift
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

import AppKit

protocol BookmarksContextMenuDelegate: NSMenuDelegate, BookmarkSearchMenuItemSelectors {
    var isSearching: Bool { get }
    var parentFolder: BookmarkFolder? { get }
    var shouldIncludeManageBookmarksItem: Bool { get }

    func selectedItems() -> [Any]
    func showDialog(_ dialog: any ModalView)
    func closePopoverIfNeeded()
}

final class BookmarksContextMenu: NSMenu {

    let bookmarkManager: BookmarkManager
    let windowControllersManager: WindowControllersManagerProtocol

    private weak var bookmarksContextMenuDelegate: BookmarksContextMenuDelegate? {
        guard let delegate = delegate as? BookmarksContextMenuDelegate else {
            assertionFailure("BookmarksContextMenu delegate is not BookmarksContextMenuDelegate")
            return nil
        }
        return delegate
    }

    @MainActor
    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared, windowControllersManager: WindowControllersManagerProtocol? = nil, delegate: BookmarksContextMenuDelegate) {
        self.bookmarkManager = bookmarkManager
        self.windowControllersManager = windowControllersManager ?? WindowControllersManager.shared
        super.init(title: "")
        self.delegate = delegate
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update() {
        items = Self.menuItems(for: bookmarksContextMenuDelegate?.selectedItems() ?? [],
                               target: self,
                               forSearch: bookmarksContextMenuDelegate?.isSearching ?? false,
                               includeManageBookmarksItem: bookmarksContextMenuDelegate?.shouldIncludeManageBookmarksItem ?? true)
    }

}

extension BookmarksContextMenu {

    /// Creates menu items for the specified Objects and target.
    /// - Parameters:
    ///   - objects: The objects to create the menu for.
    ///   - target: The target to associate to the `NSMenuItem`
    ///   - forSearch: Boolean that indicates if a bookmark search is currently happening.
    /// - Returns: An instance of NSMenu or nil if `objects` is not a `Bookmark` or a `Folder`.
    static func menuItems(for objects: [Any]?, target: AnyObject?, forSearch: Bool, includeManageBookmarksItem: Bool) -> [NSMenuItem] {
        guard let objects, !objects.isEmpty else {
            return [addFolderMenuItem(folder: nil, target: target)]
        }

        if objects.count > 1, let entities = objects as? [BaseBookmarkEntity] {
            return menuItems(for: entities, target: target)
        }

        let node = objects.first as? BookmarkNode
        let object = node?.representedObject as? BaseBookmarkEntity ?? objects.first as? BaseBookmarkEntity
        let parentFolder = node?.parent?.representedObject as? BookmarkFolder

        guard let object else { return [] }

        let menuItems = menuItems(for: object, parentFolder: parentFolder, forSearch: forSearch, includeManageBookmarksItem: includeManageBookmarksItem)

        for item in menuItems {
            item.target = target
        }

        return menuItems
    }

    /// Creates an instance of NSMenu for the specified `BaseBookmarkEntity`and parent `BookmarkFolder`.
    ///
    /// - Parameters:
    ///   - entity: The bookmark entity to create the menu for.
    ///   - parentFolder: An optional `BookmarkFolder`.
    ///   - forSearch: Boolean that indicates if a bookmark search is currently happening.
    /// - Returns: An instance of NSMenu or nil if `entity` is not a `Bookmark` or a `Folder`.
    static func menuItems(for entity: BaseBookmarkEntity, parentFolder: BookmarkFolder?, forSearch: Bool, includeManageBookmarksItem: Bool) -> [NSMenuItem] {
        if let bookmark = entity as? Bookmark {
            return menuItems(for: bookmark, parent: parentFolder, isFavorite: bookmark.isFavorite, forSearch: forSearch, includeManageBookmarksItem: includeManageBookmarksItem)
        } else if let folder = entity as? BookmarkFolder {
            // When the user edits a folder we need to show the parent in the folder picker. Folders directly child of PseudoFolder `Bookmarks` have nil parent because their parent is not an instance of `BookmarkFolder`
            return menuItems(for: folder, parent: parentFolder, forSearch: forSearch, includeManageBookmarksItem: includeManageBookmarksItem)
        }

        return []
    }

}

private extension BookmarksContextMenu {

    static func menuItems(for bookmark: Bookmark?, parent: BookmarkFolder?, isFavorite: Bool, forSearch: Bool = false, includeManageBookmarksItem: Bool) -> [NSMenuItem] {
        var items = [
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
            addFolderMenuItem(folder: parent, target: self),
        ]

        if includeManageBookmarksItem {
            items.append(manageBookmarksMenuItem())
        }
        if forSearch {
            let showInFolderItem = showInFolderMenuItem(bookmark: bookmark, parent: parent)
            items.insert(showInFolderItem, at: 5)
        }

        return items
    }

    static func menuItems(for folder: BookmarkFolder?, parent: BookmarkFolder?, forSearch: Bool = false, includeManageBookmarksItem: Bool) -> [NSMenuItem] {
        var items = [
            openInNewTabsMenuItem(folder: folder),
            openAllInNewWindowMenuItem(folder: folder),
            NSMenuItem.separator(),
            editFolderMenuItem(folder: folder, parent: parent),
            deleteFolderMenuItem(folder: folder),
            moveToEndMenuItem(entity: folder, parent: parent),
            NSMenuItem.separator(),
            addFolderMenuItem(folder: folder, target: self),
        ]

        if includeManageBookmarksItem {
            items.append(manageBookmarksMenuItem())
        }
        if forSearch {
            let showInFolderItem = showInFolderMenuItem(folder: folder, parent: parent)
            items.insert(showInFolderItem, at: 3)
        }

        return items
    }

    // MARK: - Single Bookmark Menu Items

    static func openBookmarkInNewTabMenuItem(bookmark: Bookmark?) -> NSMenuItem {
        NSMenuItem(title: UserText.openInNewTab, action: #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)), representedObject: bookmark)
    }

    static func openBookmarkInNewWindowMenuItem(bookmark: Bookmark?) -> NSMenuItem {
        NSMenuItem(title: UserText.openInNewWindow, action: #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)), representedObject: bookmark)
    }

    static func manageBookmarksMenuItem() -> NSMenuItem {
        NSMenuItem(title: UserText.bookmarksManageBookmarks, action: #selector(BookmarkMenuItemSelectors.manageBookmarks(_:)))
    }

    static func addBookmarkToFavoritesMenuItem(isFavorite: Bool, bookmark: Bookmark?) -> NSMenuItem {
        let title = isFavorite ? UserText.removeFromFavorites : UserText.addToFavorites
        return NSMenuItem(title: title, action: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), representedObject: bookmark)
            .withAccessibilityIdentifier(isFavorite == false ? "ContextualMenu.addBookmarkToFavoritesMenuItem" :
                "ContextualMenu.removeBookmarkFromFavoritesMenuItem")
    }

    static func addBookmarksToFavoritesMenuItem(bookmarks: [Bookmark], allFavorites: Bool) -> NSMenuItem {
        let title = allFavorites ? UserText.removeFromFavorites : UserText.addToFavorites
        let accessibilityValue = allFavorites ? "Favorited" : "Unfavorited"
        return NSMenuItem(title: title, action: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), representedObject: bookmarks)
            .withAccessibilityIdentifier("ContextualMenu.addBookmarksToFavoritesMenuItem").withAccessibilityValue(accessibilityValue)
    }

    static func editBookmarkMenuItem(bookmark: Bookmark?) -> NSMenuItem {
        NSMenuItem(title: UserText.editBookmark, action: #selector(BookmarkMenuItemSelectors.editBookmark(_:)), representedObject: bookmark)
    }

    static func copyBookmarkMenuItem(bookmark: Bookmark?) -> NSMenuItem {
        NSMenuItem(title: UserText.copy, action: #selector(BookmarkMenuItemSelectors.copyBookmark(_:)), representedObject: bookmark)
    }

    static func deleteBookmarkMenuItem(bookmark: Bookmark?) -> NSMenuItem {
        NSMenuItem(title: UserText.bookmarksBarContextMenuDelete, action: #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)), representedObject: bookmark)
            .withAccessibilityIdentifier("ContextualMenu.deleteBookmark")
    }

    static func moveToEndMenuItem(entity: BaseBookmarkEntity?, parent: BookmarkFolder?) -> NSMenuItem {
        let bookmarkEntityInfo = entity.flatMap { BookmarkEntityInfo(entity: $0, parent: parent) }
        return NSMenuItem(title: UserText.bookmarksBarContextMenuMoveToEnd, action: #selector(BookmarkMenuItemSelectors.moveToEnd(_:)), representedObject: bookmarkEntityInfo)
    }

    static func showInFolderMenuItem(bookmark: Bookmark?, parent: BookmarkFolder?) -> NSMenuItem {
        NSMenuItem(title: UserText.showInFolder, action: #selector(BookmarkSearchMenuItemSelectors.showInFolder(_:)), representedObject: bookmark)
    }

    // MARK: - Bookmark Folder Menu Items

    static func openInNewTabsMenuItem(folder: BookmarkFolder?) -> NSMenuItem {
        NSMenuItem(title: UserText.openAllInNewTabs, action: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: folder)
    }

    static func openAllInNewWindowMenuItem(folder: BookmarkFolder?) -> NSMenuItem {
        NSMenuItem(title: UserText.openAllTabsInNewWindow, action: #selector(FolderMenuItemSelectors.openAllInNewWindow(_:)), representedObject: folder)
    }

    static func addFolderMenuItem(folder: BookmarkFolder?, target: AnyObject?) -> NSMenuItem {
        NSMenuItem(title: UserText.addFolder, action: #selector(FolderMenuItemSelectors.newFolder(_:)), target: target, representedObject: folder)
    }

    static func showInFolderMenuItem(folder: BookmarkFolder?, parent: BookmarkFolder?) -> NSMenuItem {
        NSMenuItem(title: UserText.showInFolder, action: #selector(BookmarkSearchMenuItemSelectors.showInFolder(_:)), representedObject: folder)
    }

    static func editFolderMenuItem(folder: BookmarkFolder?, parent: BookmarkFolder?) -> NSMenuItem {
        let folderEntityInfo = folder.flatMap { BookmarkEntityInfo(entity: $0, parent: parent) }
        return NSMenuItem(title: UserText.editBookmark, action: #selector(FolderMenuItemSelectors.editFolder(_:)), representedObject: folderEntityInfo)
    }

    static func deleteFolderMenuItem(folder: BookmarkFolder?) -> NSMenuItem {
        NSMenuItem(title: UserText.bookmarksBarContextMenuDelete, action: #selector(FolderMenuItemSelectors.deleteFolder(_:)), representedObject: folder)
    }

    // MARK: - Multi-Item Menu Creation

    static func openBookmarksInNewTabsMenuItem(bookmarks: [Bookmark]) -> NSMenuItem {
        NSMenuItem(title: UserText.bookmarksOpenInNewTabs, action: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: bookmarks)
    }

    static func menuItems(for entities: [BaseBookmarkEntity], target: AnyObject?) -> [NSMenuItem] {
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

        for menuItem in menuItems {
            menuItem.target = target
        }

        return menuItems
    }

}
// MARK: - BookmarkMenuItemSelectors
extension BookmarksContextMenu: BookmarkMenuItemSelectors {

    @MainActor
    @objc func openBookmarkInNewTab(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        windowControllersManager.show(url: bookmark.urlObject, source: .bookmark, newTab: true)
    }

    @MainActor
    @objc func openBookmarkInNewWindow(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }
        guard let urlObject = bookmark.urlObject else {
            return
        }
        let tabCollection = TabCollection(tabs: [Tab(content: .contentFromURL(urlObject, source: .bookmark))])
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection, burnerMode: .regular)
        windowControllersManager.openNewWindow(with: tabCollectionViewModel, burnerMode: .regular)
    }

    @objc func toggleBookmarkAsFavorite(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        bookmark.isFavorite.toggle()
        bookmarkManager.update(bookmark: bookmark)
    }

    @MainActor
    @objc func editBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to retrieve Bookmark from Edit Bookmark context menu item")
            return
        }

        let view = BookmarksDialogViewFactory.makeEditBookmarkView(bookmark: bookmark, bookmarkManager: bookmarkManager)
        bookmarksContextMenuDelegate?.showDialog(view)
    }

    @MainActor
    @objc func copyBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }
        bookmark.copyUrlToPasteboard()
    }

    @objc func deleteBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        bookmarkManager.remove(bookmark: bookmark)
    }

    @objc func deleteEntities(_ sender: NSMenuItem) {
        guard let uuids = sender.representedObject as? [String] ?? (sender.representedObject as? [BaseBookmarkEntity])?.map(\.id) else {
            assertionFailure("Failed to cast menu item's represented object to UUID array")
            return
        }

        bookmarkManager.remove(objectsWithUUIDs: uuids)
    }

    @MainActor
    @objc func manageBookmarks(_ sender: NSMenuItem) {
        windowControllersManager.showBookmarksTab()
        bookmarksContextMenuDelegate?.closePopoverIfNeeded()
    }

    @objc func moveToEnd(_ sender: NSMenuItem) {
        guard let bookmarkEntity = sender.representedObject as? BookmarksEntityIdentifiable else {
            assertionFailure("Failed to cast menu item's represented object to BookmarkEntity")
            return
        }

        let parentFolderType: ParentFolderType = bookmarkEntity.parentId.flatMap { .parent(uuid: $0) } ?? .root
        bookmarkManager.move(objectUUIDs: [bookmarkEntity.entityId], toIndex: nil, withinParentFolder: parentFolderType) { _ in }
    }

}
// MARK: - FolderMenuItemSelectors
extension BookmarksContextMenu: FolderMenuItemSelectors {

    @MainActor
    @objc func newFolder(_ sender: Any?) {
        let parentFolder = (sender as? NSMenuItem)?.representedObject as? BookmarkFolder
        let view = BookmarksDialogViewFactory.makeAddBookmarkFolderView(parentFolder: parentFolder, bookmarkManager: bookmarkManager)
        bookmarksContextMenuDelegate?.showDialog(view)
    }

    @MainActor
    @objc func editFolder(_ sender: NSMenuItem) {
        guard let bookmarkEntityInfo = sender.representedObject as? BookmarkEntityInfo,
              let folder = bookmarkEntityInfo.entity as? BookmarkFolder
        else {
            assertionFailure("Failed to retrieve Bookmark from Edit Folder context menu item")
            return
        }

        let view = BookmarksDialogViewFactory.makeEditBookmarkFolderView(folder: folder, parentFolder: bookmarkEntityInfo.parent, bookmarkManager: bookmarkManager)
        bookmarksContextMenuDelegate?.showDialog(view)
    }

    @objc func deleteFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Delete Folder context menu item")
            return
        }

        bookmarkManager.remove(folder: folder)
    }

    @MainActor
    @objc func openInNewTabs(_ sender: NSMenuItem) {
        guard let tabCollection = windowControllersManager.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel,
              let folder = sender.representedObject as? BookmarkFolder
        else {
            assertionFailure("Cannot open all in new tabs")
            return
        }

        let tabs = Tab.withContentOfBookmark(folder: folder, burnerMode: tabCollection.burnerMode)
        tabCollection.append(tabs: tabs)
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
    }

    @MainActor
    @objc func openAllInNewWindow(_ sender: NSMenuItem) {
        guard let tabCollection = windowControllersManager.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel,
              let folder = sender.representedObject as? BookmarkFolder
        else {
            assertionFailure("Cannot open all in new window")
            return
        }

        let newTabCollection = TabCollection.withContentOfBookmark(folder: folder, burnerMode: tabCollection.burnerMode)
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: newTabCollection, burnerMode: tabCollection.burnerMode)
        windowControllersManager.openNewWindow(with: tabCollectionViewModel, burnerMode: tabCollection.burnerMode)
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
    }

}

extension BookmarksContextMenu: BookmarkSearchMenuItemSelectors {

    func showInFolder(_ sender: NSMenuItem) {
        bookmarksContextMenuDelegate?.showInFolder(sender)
    }

}
