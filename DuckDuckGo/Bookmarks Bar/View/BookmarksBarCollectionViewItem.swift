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

    func bookmarksBarCollectionViewItemClicked(_ bookmarksBarCollectionViewItem: BookmarksBarCollectionViewItem)

}

final class BookmarksBarCollectionViewItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "BookmarksBarCollectionViewItem")

    @IBOutlet var stackView: NSStackView!
    @IBOutlet private var faviconView: NSImageView!
    @IBOutlet private var titleLabel: NSTextField!
    @IBOutlet private var disclosureIndicatorImageView: NSImageView!
    @IBOutlet private var mouseClickView: MouseClickView! {
        didSet {
            mouseClickView.delegate = self
        }
    }
    
    private enum EntityType {
        case bookmark(title: String, url: URL, isFavorite: Bool)
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
        
        self.view.wantsLayer = true
        self.view.layer?.cornerRadius = 4.0
        self.view.layer?.masksToBounds = true
        
        createMenu()
    }
    
    func updateItem(from entity: BaseBookmarkEntity) {
        self.title = entity.title
        
        if let bookmark = entity as? Bookmark {
            self.entityType = .bookmark(title: bookmark.title, url: bookmark.url, isFavorite: bookmark.isFavorite)
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
        self.disclosureIndicatorImageView.isHidden = !entityType.isFolder
        
        switch entityType {
        case .bookmark(_, let url, _):
            let favicon = FaviconManager.shared.getCachedFavicon(for: url.host ?? "", sizeCategory: .small)
            faviconView.image = favicon?.image ?? NSImage(named: "Bookmark")
        case .folder:
            faviconView.image = NSImage(named: "Folder-16")
        }
    }
    
    private func createMenu() {
        let menu = NSMenu()
        menu.delegate = self
        view.menu = menu
    }
    
}

extension BookmarksBarCollectionViewItem: MouseClickViewDelegate {
    
    func mouseClickView(_ mouseClickView: MouseClickView, mouseUpEvent: NSEvent) {
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
        case .bookmark(_, _, let isFavorite):
            menu.items = createBookmarkMenuItems(isFavorite: isFavorite)
        case .folder:
            menu.items = createFolderMenuItems()
        }
    }
    
}

extension BookmarksBarCollectionViewItem {
    
    func createBookmarkMenuItems(isFavorite: Bool) -> [NSMenuItem] {
        return [
            openBookmarkInNewTabMenuItem(),
            openBookmarkInNewWindowMenuItem(),
            NSMenuItem.separator(),
            toggleBookmarkAsFavoriteMenuItem(isFavorite: isFavorite)
        ]
        
//
//        if includeBookmarkEditMenu {
//            menu.addItem(editBookmarkMenuItem(bookmark: bookmark))
//        }
//
//        menu.addItem(NSMenuItem.separator())
//
//        menu.addItem(copyBookmarkMenuItem(bookmark: bookmark))
//        menu.addItem(deleteBookmarkMenuItem(bookmark: bookmark))
//        menu.addItem(NSMenuItem.separator())
//
//        menu.addItem(newFolderMenuItem())
    }
    
    func openBookmarkInNewTabMenuItem() -> NSMenuItem {
        return menuItem(UserText.openInNewTab, #selector(openBookmarkInNewTabMenuItemSelected(_:)))
    }
    
    @objc
    func openBookmarkInNewTabMenuItemSelected(_ sender: NSMenuItem) {
        print("Open in new tab")
    }

    func openBookmarkInNewWindowMenuItem() -> NSMenuItem {
        return menuItem(UserText.openInNewWindow, #selector(openBookmarkInNewWindowMenuItemSelected(_:)))
    }
    
    @objc
    func openBookmarkInNewWindowMenuItemSelected(_ sender: NSMenuItem) {
        print("Open in new window")
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
        print("Toggle favorite")
    }
    
    func createFolderMenuItems() -> [NSMenuItem] {
        return []
    }
    
    func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        return NSMenuItem(title: title, action: action, keyEquivalent: "")
    }
    
}
