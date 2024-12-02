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

    @MainActor func bookmarksBarCollectionViewItemClicked(_ item: BookmarksBarCollectionViewItem)
    @MainActor func bookmarksBarCollectionViewItemMouseDidHover(_ item: BookmarksBarCollectionViewItem)

    func showDialog(_ dialog: any ModalView)

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

    var isDisplayingMouseDownState: Bool {
        get {
            mouseOverView.backgroundColor == .buttonMouseDown
        }
        set {
            mouseOverView.backgroundColor = newValue ? .buttonMouseDown : .clear
            mouseOverView.mouseOverColor = newValue ? .buttonMouseDown : .buttonMouseOver
        }
    }

    override var highlightState: NSCollectionViewItem.HighlightState {
        get { super.highlightState }
        set {
            switch newValue {
            case .asDropTarget:
                mouseOverView.isMouseOver = true
            case .forSelection, .forDeselection, .none:
                if highlightState == .asDropTarget {
                    mouseOverView.isMouseOver = false
                }
            @unknown default: break
            }
            super.highlightState = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.cornerRadius = 4.0
        view.layer?.masksToBounds = true
        view.menu = BookmarksContextMenu(delegate: self)
    }

    func updateItem(from entity: BaseBookmarkEntity, isInteractionPrevented: Bool) {
        self.representedObject = entity
        self.title = entity.title
        self.representedObject = entity

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

}
// MARK: - BookmarksContextMenuDelegate
extension BookmarksBarCollectionViewItem: BookmarksContextMenuDelegate {

    var isSearching: Bool { false }
    var parentFolder: BookmarkFolder? { nil }
    var shouldIncludeManageBookmarksItem: Bool { true }

    func selectedItems() -> [Any] {
        self.representedObject.map { [$0] } ?? []
    }

    func showDialog(_ dialog: any ModalView) {
        delegate?.showDialog(dialog)
    }

    func closePopoverIfNeeded() {}
    func showInFolder(_ sender: NSMenuItem) {
        assertionFailure("BookmarksBarCollectionViewItem does not support search")
    }

}
// MARK: - MouseOverViewDelegate
extension BookmarksBarCollectionViewItem: MouseOverViewDelegate {

    func mouseOverView(_ mouseOverView: MouseOverView, isMouseOver: Bool) {
        if isMouseOver {
            delegate?.bookmarksBarCollectionViewItemMouseDidHover(self)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        delegate?.bookmarksBarCollectionViewItemMouseDidHover(self)
    }

}
