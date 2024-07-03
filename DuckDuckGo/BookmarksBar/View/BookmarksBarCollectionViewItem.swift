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
    func bookmarksBarCollectionViewItemToggleFavoritesAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewEditAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewItemMoveToEndAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewItemCopyBookmarkURLAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewItemDeleteEntityAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewItemAddEntityAction(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewItemManageBookmarksAction(_ item: BookmarksBarCollectionViewItem)

}

final class BookmarksBarCollectionViewItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "BookmarksBarCollectionViewItem")

    @IBOutlet private weak var mouseOverView: MouseOverView!
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

    func updateItem(from entity: BaseBookmarkEntity, isInteractionPrevented: Bool) {
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
            faviconView.image = favicon ?? .bookmark
        case .folder:
            faviconView.image = .folder16
        }
        mouseOverView.isEnabled = !isInteractionPrevented
        faviconView.isEnabled = !isInteractionPrevented
        titleLabel.isEnabled = !isInteractionPrevented
        titleLabel.alphaValue = isInteractionPrevented ? 0.3 : 1
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
            menu.items = ContextualMenu.bookmarkMenuItems(isFavorite: isFavorite)
        case .folder:
            menu.items = ContextualMenu.folderMenuItems()
        }
    }

}

extension BookmarksBarCollectionViewItem: BookmarkMenuItemSelectors {

    func openBookmarkInNewTab(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemOpenInNewTabAction(self)
    }

    func openBookmarkInNewWindow(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemOpenInNewWindowAction(self)
    }

    func toggleBookmarkAsFavorite(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemToggleFavoritesAction(self)
    }

    func editBookmark(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewEditAction(self)
    }

    func copyBookmark(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemCopyBookmarkURLAction(self)
    }

    func deleteBookmark(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemDeleteEntityAction(self)
    }

    func moveToEnd(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemMoveToEndAction(self)
    }

    func deleteEntities(_ sender: NSMenuItem) {}

    func manageBookmarks(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemManageBookmarksAction(self)
    }

}

extension BookmarksBarCollectionViewItem: FolderMenuItemSelectors {

    func newFolder(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemAddEntityAction(self)
    }

    func editFolder(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewEditAction(self)
    }

    func deleteFolder(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemDeleteEntityAction(self)
    }

    func openInNewTabs(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemOpenInNewTabAction(self)
    }

    func openAllInNewWindow(_ sender: NSMenuItem) {
        delegate?.bookmarksBarCollectionViewItemOpenInNewWindowAction(self)
    }

}
