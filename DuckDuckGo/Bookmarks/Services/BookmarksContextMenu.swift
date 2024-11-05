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
    var undoManager: UndoManager? { get }

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
        self.autoenablesItems = false
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
    ///   - forSearch: Boolean that indicates if a bookmark search is currently happening.
    /// - Returns: An instance of NSMenu or nil if `objects` is not a `Bookmark` or a `Folder`.
    static func menuItems(for objects: [Any]?, target: AnyObject?, forSearch: Bool, includeManageBookmarksItem: Bool) -> [NSMenuItem] {
        guard let objects, !objects.isEmpty else {
            return [addNewFolderMenuItem(entity: nil, target: target)]
        }

        if objects.count > 1, let entities = objects as? [BaseBookmarkEntity] {
            return menuItems(for: entities, target: target)
        }

        let object: BaseBookmarkEntity
        switch objects.first {
        case let node as BookmarkNode:
            guard let entity = node.representedObject as? BaseBookmarkEntity else { return [] }
            object = entity
        case let entity as BaseBookmarkEntity:
            object = entity
        default:
            assertionFailure("Unexpected object \(objects.first!)")
            return []
        }

        let menuItems = menuItems(for: object, target: target, forSearch: forSearch, includeManageBookmarksItem: includeManageBookmarksItem)

        return menuItems
    }

    /// Creates an instance of NSMenu for the specified `BaseBookmarkEntity`and parent `BookmarkFolder`.
    ///
    /// - Parameters:
    ///   - entity: The bookmark entity to create the menu for.
    ///   - target: The target to associate to the `NSMenuItem`
    ///   - forSearch: Boolean that indicates if a bookmark search is currently happening.
    /// - Returns: An instance of NSMenu or nil if `entity` is not a `Bookmark` or a `Folder`.
    static func menuItems(for entity: BaseBookmarkEntity, target: AnyObject?, forSearch: Bool, includeManageBookmarksItem: Bool) -> [NSMenuItem] {
        switch entity {
        case let bookmark as Bookmark:
            return menuItems(for: bookmark, target: target, isFavorite: bookmark.isFavorite, forSearch: forSearch, includeManageBookmarksItem: includeManageBookmarksItem)
        case let folder as BookmarkFolder:
            return menuItems(for: folder, target: target, forSearch: forSearch, includeManageBookmarksItem: includeManageBookmarksItem)
        default:
            assertionFailure("Unexpected entity \(entity)")
            return []
        }
    }

    static func menuItems(for bookmark: Bookmark, target: AnyObject?, isFavorite: Bool, forSearch: Bool, includeManageBookmarksItem: Bool) -> [NSMenuItem] {
        var items = [
            openBookmarkInNewTabMenuItem(bookmark: bookmark, target: target),
            openBookmarkInNewWindowMenuItem(bookmark: bookmark, target: target),
            NSMenuItem.separator(),
            addBookmarkToFavoritesMenuItem(isFavorite: isFavorite, bookmark: bookmark, target: target),
            NSMenuItem.separator(),
            editBookmarkMenuItem(bookmark: bookmark, target: target),
            copyBookmarkMenuItem(bookmark: bookmark, target: target),
            deleteBookmarkMenuItem(bookmark: bookmark, target: target),
            moveToEndMenuItem(entity: bookmark, target: target),
            NSMenuItem.separator(),
            addNewFolderMenuItem(entity: bookmark, target: target),
        ]

        if includeManageBookmarksItem {
            items.append(manageBookmarksMenuItem(target: target))
        }
        if forSearch {
            let showInFolderItem = showInFolderMenuItem(bookmark: bookmark, target: target)
            items.insert(showInFolderItem, at: 5)
        }

        return items
    }

    static func menuItems(for folder: BookmarkFolder, target: AnyObject?, forSearch: Bool, includeManageBookmarksItem: Bool) -> [NSMenuItem] {
        // disable "Open All" if no Bookmarks in folder
        let hasBookmarks = folder.children.contains(where: { $0 is Bookmark })
        var items = [
            openInNewTabsMenuItem(folder: folder, target: target, enabled: hasBookmarks),
            openAllInNewWindowMenuItem(folder: folder, target: target, enabled: hasBookmarks),
            NSMenuItem.separator(),
            editFolderMenuItem(folder: folder, target: target),
            deleteFolderMenuItem(folder: folder, target: target),
            moveToEndMenuItem(entity: folder, target: target),
            NSMenuItem.separator(),
            addNewFolderMenuItem(entity: folder, target: target),
        ]

        if includeManageBookmarksItem {
            items.append(manageBookmarksMenuItem(target: target))
        }
        if forSearch {
            let showInFolderItem = showInFolderMenuItem(folder: folder, target: target)
            items.insert(showInFolderItem, at: 3)
        }

        return items
    }

    // MARK: - Single Bookmark Menu Items

    static func openBookmarkInNewTabMenuItem(bookmark: Bookmark?, target: AnyObject?) -> NSMenuItem {
        NSMenuItem(title: UserText.openInNewTab, action: #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)), target: target, representedObject: bookmark)
    }

    static func openBookmarkInNewWindowMenuItem(bookmark: Bookmark?, target: AnyObject?) -> NSMenuItem {
        NSMenuItem(title: UserText.openInNewWindow, action: #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)), target: target, representedObject: bookmark)
    }

    static func manageBookmarksMenuItem(target: AnyObject?) -> NSMenuItem {
        NSMenuItem(title: UserText.bookmarksManageBookmarks, action: #selector(BookmarkMenuItemSelectors.manageBookmarks(_:)), target: target)
    }

    static func addBookmarkToFavoritesMenuItem(isFavorite: Bool, bookmark: Bookmark?, target: AnyObject?) -> NSMenuItem {
        let title = isFavorite ? UserText.removeFromFavorites : UserText.addToFavorites
        return NSMenuItem(title: title, action: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), target: target, representedObject: bookmark)
            .withAccessibilityIdentifier(isFavorite == false ? "ContextualMenu.addBookmarkToFavoritesMenuItem" :
                "ContextualMenu.removeBookmarkFromFavoritesMenuItem")
    }

    static func addBookmarksToFavoritesMenuItem(bookmarks: [Bookmark], allFavorites: Bool, target: AnyObject?) -> NSMenuItem {
        let title = allFavorites ? UserText.removeFromFavorites : UserText.addToFavorites
        let accessibilityValue = allFavorites ? "Favorited" : "Unfavorited"
        return NSMenuItem(title: title, action: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), target: target, representedObject: bookmarks)
            .withAccessibilityIdentifier("ContextualMenu.addBookmarksToFavoritesMenuItem").withAccessibilityValue(accessibilityValue)
    }

    static func editBookmarkMenuItem(bookmark: Bookmark?, target: AnyObject?) -> NSMenuItem {
        NSMenuItem(title: UserText.editBookmark, action: #selector(BookmarkMenuItemSelectors.editBookmark(_:)), target: target, representedObject: bookmark)
    }

    static func copyBookmarkMenuItem(bookmark: Bookmark?, target: AnyObject?) -> NSMenuItem {
        NSMenuItem(title: UserText.copy, action: #selector(BookmarkMenuItemSelectors.copyBookmark(_:)), target: target, representedObject: bookmark)
    }

    static func deleteBookmarkMenuItem(bookmark: Bookmark?, target: AnyObject?) -> NSMenuItem {
        NSMenuItem(title: UserText.bookmarksBarContextMenuDelete, action: #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)), target: target, representedObject: bookmark)
            .withAccessibilityIdentifier("ContextualMenu.deleteBookmark")
    }

    static func moveToEndMenuItem(entity: BaseBookmarkEntity?, target: AnyObject?) -> NSMenuItem {
        NSMenuItem(title: UserText.bookmarksBarContextMenuMoveToEnd, action: #selector(BookmarkMenuItemSelectors.moveToEnd(_:)), target: target, representedObject: entity)
    }

    static func showInFolderMenuItem(bookmark: Bookmark?, target: AnyObject?) -> NSMenuItem {
        NSMenuItem(title: UserText.showInFolder, action: #selector(BookmarkSearchMenuItemSelectors.showInFolder(_:)), target: target, representedObject: bookmark)
    }

    // MARK: - Bookmark Folder Menu Items

    static func openInNewTabsMenuItem(folder: BookmarkFolder?, target: AnyObject?, enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: UserText.openAllInNewTabs, action: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), target: target, representedObject: folder)
        item.isEnabled = enabled
        return item
    }

    static func openAllInNewWindowMenuItem(folder: BookmarkFolder?, target: AnyObject?, enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: UserText.openAllTabsInNewWindow, action: #selector(FolderMenuItemSelectors.openAllInNewWindow(_:)), target: target, representedObject: folder)
        item.isEnabled = enabled
        return item
    }

    static func addNewFolderMenuItem(entity: BaseBookmarkEntity?, target: AnyObject?) -> NSMenuItem {
        NSMenuItem(title: UserText.addFolder, action: #selector(FolderMenuItemSelectors.newFolder(_:)), target: target, representedObject: entity)
    }

    static func showInFolderMenuItem(folder: BookmarkFolder?, target: AnyObject?) -> NSMenuItem {
        NSMenuItem(title: UserText.showInFolder, action: #selector(BookmarkSearchMenuItemSelectors.showInFolder(_:)), target: target, representedObject: folder)
    }

    static func editFolderMenuItem(folder: BookmarkFolder?, target: AnyObject?) -> NSMenuItem {
        return NSMenuItem(title: UserText.editBookmark, action: #selector(FolderMenuItemSelectors.editFolder(_:)), target: target, representedObject: folder)
    }

    static func deleteFolderMenuItem(folder: BookmarkFolder?, target: AnyObject?) -> NSMenuItem {
        NSMenuItem(title: UserText.bookmarksBarContextMenuDelete, action: #selector(FolderMenuItemSelectors.deleteFolder(_:)), target: target, representedObject: folder)
    }

    // MARK: - Multi-Item Menu Creation

    static func openBookmarksInNewTabsMenuItem(bookmarks: [Bookmark], target: AnyObject?) -> NSMenuItem {
        NSMenuItem(title: UserText.bookmarksOpenInNewTabs, action: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), target: target, representedObject: bookmarks)
    }

    static func menuItems(for entities: [BaseBookmarkEntity], target: AnyObject?) -> [NSMenuItem] {
        var menuItems: [NSMenuItem] = []

        let bookmarks = entities.compactMap({ $0 as? Bookmark })

        if !bookmarks.isEmpty {
            menuItems.append(openBookmarksInNewTabsMenuItem(bookmarks: bookmarks, target: target))

            // If all selected items are bookmarks and they all have the same favourite status, show a menu item to add/remove them all as favourites.
            if bookmarks.count == entities.count {
                if bookmarks.allSatisfy({ $0.isFavorite }) {
                    menuItems.append(addBookmarksToFavoritesMenuItem(bookmarks: bookmarks, allFavorites: true, target: target))
                } else if bookmarks.allSatisfy({ !$0.isFavorite }) {
                    menuItems.append(addBookmarksToFavoritesMenuItem(bookmarks: bookmarks, allFavorites: false, target: target))
                }
            }

            menuItems.append(NSMenuItem.separator())
        }

        let deleteItem = NSMenuItem(title: UserText.bookmarksBarContextMenuDelete, action: #selector(BookmarkMenuItemSelectors.deleteEntities(_:)), target: target, keyEquivalent: "")
        deleteItem.representedObject = entities
        menuItems.append(deleteItem)

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
        if let bookmark = sender.representedObject as? Bookmark{
            bookmark.isFavorite.toggle()
            bookmarkManager.update(bookmark: bookmark)
        } else if let bookmarks = sender.representedObject as? [Bookmark] {
            bookmarks.forEach { bookmark in
                bookmark.isFavorite.toggle()
                bookmarkManager.update(bookmark: bookmark)
            }
        } else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
        }
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

        bookmarkManager.remove(bookmark: bookmark, undoManager: bookmarksContextMenuDelegate?.undoManager)
    }

    @objc func deleteEntities(_ sender: NSMenuItem) {
        guard let uuids = sender.representedObject as? [String] ?? (sender.representedObject as? [BaseBookmarkEntity])?.map(\.id) else {
            assertionFailure("Failed to cast menu item's represented object to UUID array")
            return
        }

        bookmarkManager.remove(objectsWithUUIDs: uuids, undoManager: bookmarksContextMenuDelegate?.undoManager)
    }

    @MainActor
    @objc func manageBookmarks(_ sender: NSMenuItem) {
        windowControllersManager.showBookmarksTab()
        bookmarksContextMenuDelegate?.closePopoverIfNeeded()
    }

    @objc func moveToEnd(_ sender: NSMenuItem) {
        guard let entity = sender.representedObject as? BaseBookmarkEntity else {
            assertionFailure("Failed to cast menu item's represented object to BaseBookmarkEntity")
            return
        }

        let parentFolderType: ParentFolderType = entity.parentFolderUUID.flatMap { .parent(uuid: $0) } ?? .root
        bookmarkManager.move(objectUUIDs: [entity.id], toIndex: nil, withinParentFolder: parentFolderType) { _ in }
    }

}
// MARK: - FolderMenuItemSelectors
extension BookmarksContextMenu: FolderMenuItemSelectors {

    @MainActor
    @objc func newFolder(_ sender: Any?) {
        var representedObject: Any?
        switch sender {
        case let menuItem as NSMenuItem:
            representedObject = menuItem.representedObject
        case let button as NSControl:
            representedObject = button.cell?.representedObject
        default:
            assertionFailure("Unexpected sender \(String(describing: sender))")
        }
        var parentFolder: BookmarkFolder?
        switch representedObject {
        case let folder as BookmarkFolder:
            parentFolder = folder
        case let bookmark as Bookmark:
            parentFolder = bookmark.parentFolderUUID.flatMap(bookmarkManager.getBookmarkFolder(withId:))
        case .none:
            parentFolder = bookmarksContextMenuDelegate?.parentFolder
        case .some(let object):
            assertionFailure("Unexpected representedObject: \(object)")
        }

        let view = BookmarksDialogViewFactory.makeAddBookmarkFolderView(parentFolder: parentFolder, bookmarkManager: bookmarkManager)
        bookmarksContextMenuDelegate?.showDialog(view)
    }

    @MainActor
    @objc func editFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Edit Folder context menu item")
            return
        }
        let parent = folder.parentFolderUUID.flatMap(bookmarkManager.getBookmarkFolder(withId:))
        let view = BookmarksDialogViewFactory.makeEditBookmarkFolderView(folder: folder, parentFolder: parent, bookmarkManager: bookmarkManager)
        bookmarksContextMenuDelegate?.showDialog(view)
    }

    @objc func deleteFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Delete Folder context menu item")
            return
        }

        bookmarkManager.remove(folder: folder, undoManager: bookmarksContextMenuDelegate?.undoManager)
    }

    @MainActor
    @objc func openInNewTabs(_ sender: NSMenuItem) {
        guard let tabCollection = windowControllersManager.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel else {
            assertionFailure("Cannot open all in new tabs")
            return
        }

        if let folder = sender.representedObject as? BookmarkFolder {
            let tabs = Tab.withContentOfBookmark(folder: folder, burnerMode: tabCollection.burnerMode)
            tabCollection.append(tabs: tabs)
            PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
        } else if let bookmarks = sender.representedObject as? [Bookmark] {
            let tabs = Tab.with(contentsOf: bookmarks, burnerMode: tabCollection.burnerMode)
            tabCollection.append(tabs: tabs)
            PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
        }
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
