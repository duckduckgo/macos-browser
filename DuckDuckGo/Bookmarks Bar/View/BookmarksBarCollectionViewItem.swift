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
    func bookmarksBarCollectionViewItemToggleFavoriteBookmarkAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewItemCopyBookmarkURLAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewItemDeleteEntityAction(_ item: BookmarksBarCollectionViewItem)

}

final class BookmarksBarCollectionViewItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "BookmarksBarCollectionViewItem")

    @IBOutlet var stackView: NSStackView!
    @IBOutlet private var mouseOverView: MouseOverView!
    @IBOutlet private var faviconView: NSImageView! {
        didSet {
            faviconView.setCornerRadius(3.0)
        }
    }

    @IBOutlet private var titleLabel: NSTextField!
    @IBOutlet private var mouseClickView: MouseClickView! {
        didSet {
            mouseClickView.delegate = self
        }
    }
    
    private enum EntityType {
        case bookmark(title: String, url: URL, favicon: NSImage?, isFavorite: Bool)
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
    
    /// MouseClickView is prone to sending mouseUp events without a preceding mouseDown.
    /// This tracks whether to consider a click as legitimate and use it to trigger navigation from the bookmarks bar.
    private var receivedMouseDownEvent = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureLayer()
        createMenu()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        mouseOverView.updateTrackingAreas()
    }
    
    func updateItem(from entity: BaseBookmarkEntity) {
        self.title = entity.title
        
        if let bookmark = entity as? Bookmark {
            let favicon = bookmark.favicon(.small)?.copy() as? NSImage
            favicon?.size = NSSize.faviconSize

            self.entityType = .bookmark(title: bookmark.title, url: bookmark.url, favicon: favicon, isFavorite: bookmark.isFavorite)
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
            let favicon = storedFavicon ?? FaviconManager.shared.getCachedFavicon(for: url.host ?? "", sizeCategory: .small)?.image
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

extension BookmarksBarCollectionViewItem: MouseClickViewDelegate {
    
    func mouseClickView(_ mouseClickView: MouseClickView, mouseDownEvent: NSEvent) {
        receivedMouseDownEvent = true
    }

    func mouseClickView(_ mouseClickView: MouseClickView, mouseUpEvent: NSEvent) {
        guard receivedMouseDownEvent else {
            return
        }

        receivedMouseDownEvent = false
        delegate?.bookmarksBarCollectionViewItemClicked(self)
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
        return [
            openBookmarkInNewTabMenuItem(),
            openBookmarkInNewWindowMenuItem(),
            NSMenuItem.separator(),
            toggleBookmarkAsFavoriteMenuItem(isFavorite: isFavorite),
            NSMenuItem.separator(),
            copyBookmarkURLMenuItem(),
            deleteEntityMenuItem()
        ]
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
    
    func toggleBookmarkAsFavoriteMenuItem(isFavorite: Bool) -> NSMenuItem {
        let title: String

        if isFavorite {
            title = UserText.removeFromFavorites
        } else {
            title = UserText.addToFavorites
        }

        return menuItem(title, #selector(toggleBookmarkAsFavoriteMenuItemSelected(_:)))
    }
    
    @objc
    func toggleBookmarkAsFavoriteMenuItemSelected(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemToggleFavoriteBookmarkAction(self)
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
            deleteEntityMenuItem()
        ]
    }
    
    func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        return NSMenuItem(title: title, action: action, keyEquivalent: "")
    }
    
}
