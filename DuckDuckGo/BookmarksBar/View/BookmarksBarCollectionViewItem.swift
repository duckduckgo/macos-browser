//
//  BookmarksBarCollectionViewItem.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

protocol BookmarksBarCollectionViewItemDelegate: AnyObject {

    func bookmarksBarCollectionViewItemClicked(_ item: BookmarksBarCollectionViewItem)

    func bookmarksBarCollectionViewItemOpenInNewTabAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewItemOpenInNewWindowAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewItemAddToFavoritesAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewEditAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewItemMoveToEndAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewItemCopyBookmarkURLAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewItemDeleteEntityAction(_ item: BookmarksBarCollectionViewItem)

}

final class BookmarksBarCollectionViewItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "BookmarksBarCollectionViewItem")

    @IBOutlet var stackView: NSStackView!
    @IBOutlet private var faviconView: NSImageView! {
        didSet {
            faviconView.setCornerRadius(3.0)
        }
    }

    @IBOutlet private var titleLabel: NSTextField!

    private enum EntityType {
        case bookmark(title: String, url: String, favicon: NSImage?, isFavorite: Bool)
        case folder(title: String)

        var isFolder: Bool {
            switch self {
            case .bookmark: return false
            case .folder: return true
            }
        }
    }

    weak var delegate: BookmarksBarCollectionViewItemDelegate?
    private var entityType: EntityType?

    override func viewDidLoad() {
        super.viewDidLoad()

        configureLayer()
        createMenu()
    }

    func updateItem(from entity: BaseBookmarkEntity) {
        self.title = entity.title

        if let bookmark = entity as? Bookmark {
            let favicon = bookmark.favicon(.small)?.copy() as? NSImage
            favicon?.size = NSSize.faviconSize

            self.entityType = .bookmark(title: bookmark.title,
                                        url: bookmark.url,
                                        favicon: favicon,
                                        isFavorite: bookmark.isFavorite)
        } else if let folder = entity as? BookmarkFolder {
            self.entityType = .folder(title: folder.title)
        } else {
            fatalError("Could not cast bookmark subclass from entity")
        }

        guard let entityType = entityType else {
            assertionFailure("Failed to get entity type")
            return
        }

        self.titleLabel.stringValue = entity.title

        switch entityType {
        case .bookmark(_, let url, let storedFavicon, _):
            let host = URL(string: url)?.host ?? ""
            let favicon = storedFavicon ?? FaviconManager.shared.getCachedFavicon(for: host, sizeCategory: .small)?.image
            faviconView.image = favicon ?? NSImage(named: "Bookmark")
        case .folder:
            faviconView.image = NSImage(named: "Folder-16")
        }
    }

    private func configureLayer() {
        view.wantsLayer = true
        view.layer?.cornerRadius = 4.0
        view.layer?.masksToBounds = true
    }

    private func createMenu() {
        let menu = NSMenu()
        menu.delegate = self
        view.menu = menu
    }

}

// MARK: - NSMenu

extension BookmarksBarCollectionViewItem: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        guard let entityType = entityType else {
            return
        }

        switch entityType {
        case .bookmark(_, _, _, let isFavorite):
            menu.items = createBookmarkMenuItems(isFavorite: isFavorite)
        case .folder:
            menu.items = createFolderMenuItems()
        }
    }

}

extension BookmarksBarCollectionViewItem {

    // MARK: Bookmark Menu Items

    func createBookmarkMenuItems(isFavorite: Bool) -> [NSMenuItem] {
        let items = [
            openBookmarkInNewTabMenuItem(),
            openBookmarkInNewWindowMenuItem(),
            NSMenuItem.separator(),
            addToFavoritesMenuItem(isFavorite: isFavorite),
            editItem(),
            moveToEndMenuItem(),
            NSMenuItem.separator(),
            copyBookmarkURLMenuItem(),
            deleteEntityMenuItem()
        ].compactMap { $0 }

        return items
    }

    func openBookmarkInNewTabMenuItem() -> NSMenuItem {
        return menuItem(UserText.openInNewTab, #selector(openBookmarkInNewTabMenuItemSelected(_:)))
    }

    @objc
    func openBookmarkInNewTabMenuItemSelected(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemOpenInNewTabAction(self)
    }

    func openBookmarkInNewWindowMenuItem() -> NSMenuItem {
        return menuItem(UserText.openInNewWindow, #selector(openBookmarkInNewWindowMenuItemSelected(_:)))
    }

    @objc
    func openBookmarkInNewWindowMenuItemSelected(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemOpenInNewWindowAction(self)
    }

    func addToFavoritesMenuItem(isFavorite: Bool) -> NSMenuItem? {
        guard !isFavorite else {
            return nil
        }

        return menuItem(UserText.addToFavorites, #selector(addToFavoritesMenuItemSelected(_:)))
    }

    @objc
    func addToFavoritesMenuItemSelected(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemAddToFavoritesAction(self)
    }

    func editItem() -> NSMenuItem {
        return menuItem("Edit…", #selector(editItemSelected(_:)))
    }

    @objc
    func editItemSelected(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewEditAction(self)
    }

    func moveToEndMenuItem() -> NSMenuItem {
        return menuItem(UserText.bookmarksBarContextMenuMoveToEnd, #selector(moveToEndMenuItemSelected(_:)))
    }

    @objc
    func moveToEndMenuItemSelected(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemMoveToEndAction(self)
    }

    func copyBookmarkURLMenuItem() -> NSMenuItem {
        return menuItem(UserText.bookmarksBarContextMenuCopy, #selector(copyBookmarkURLMenuItemSelected(_:)))
    }

    @objc
    func copyBookmarkURLMenuItemSelected(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemCopyBookmarkURLAction(self)
    }

    func deleteEntityMenuItem() -> NSMenuItem {
        return menuItem(UserText.bookmarksBarContextMenuDelete, #selector(deleteMenuItemSelected(_:)))
    }

    @objc
    func deleteMenuItemSelected(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemDeleteEntityAction(self)
    }

    // MARK: Folder Menu Items

    func createFolderMenuItems() -> [NSMenuItem] {
        return [
            editItem(),
            moveToEndMenuItem(),
            NSMenuItem.separator(),
            deleteEntityMenuItem()
        ]
    }

    func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        return NSMenuItem(title: title, action: action, keyEquivalent: "")
    }

}
