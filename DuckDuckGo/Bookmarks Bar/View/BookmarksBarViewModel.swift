//
//  BookmarksBarViewModel.swift
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

import AppKit
import Combine
import Foundation

protocol BookmarksBarViewModelDelegate: AnyObject {
    
    func bookmarksBarViewModelReceived(action: BookmarksBarViewModel.BookmarksBarItemAction, for item: BookmarksBarCollectionViewItem)
}

final class BookmarksBarViewModel: NSObject {
    
    // MARK: Enums
    
    enum Constants {
        static let buttonSpacing: CGFloat = 2
        static let buttonHeight: CGFloat = 30
        static let maximumButtonWidth: CGFloat = 120
        static let labelFont = NSFont.systemFont(ofSize: 12)
        
        static let additionalBookmarkWidth = 30.0
        static let additionalFolderWidth = 30.0
    }
    
    enum BookmarksBarItemAction {
        case loadURL
        case openInBackgroundTab
        case openInNewTab
        case openInNewWindow
        case toggleFavorite
        case copyURL
        case deleteEntity
    }
    
    struct BookmarksBarItem {
        let title: String
        let url: URL?
        let isFolder: Bool
        let entity: BaseBookmarkEntity
    }
    
    weak var delegate: BookmarksBarViewModelDelegate?

    private let bookmarkManager: BookmarkManager
    private var cancellables = Set<AnyCancellable>()
    
    private var existingItemDraggingIndexPath: IndexPath?
    private var collectionViewItemSizeCache: [String: CGFloat] = [:]
    private(set) var bookmarksBarItemsTotalWidth: CGFloat = 0
    
    private(set) var bookmarksBarItems: [BookmarksBarItem] = [] {
        didSet {
            let itemsWidth = bookmarksBarItems.reduce(CGFloat(0)) { total, item in
                if total == 0 {
                    return total + self.cachedWidth(buttonTitle: item.title, isFolder: item.isFolder)
                } else {
                    return total + Constants.buttonSpacing + self.cachedWidth(buttonTitle: item.title, isFolder: item.isFolder)
                }
            }
            
            self.bookmarksBarItemsTotalWidth = itemsWidth
        }
    }

    private(set) var clippedItems: [BookmarkViewModel] = []
    
    // MARK: - Initialization
    
    init(bookmarkManager: BookmarkManager) {
        self.bookmarkManager = bookmarkManager
    }
    
    // MARK: - Functions
    
    func update(from bookmarkEntities: [BaseBookmarkEntity], containerWidth: CGFloat) {
        clippedItems = []

        var currentTotalWidth: CGFloat = 0.0
        var clippedItemsStartingIndex: Int?
        var displayableItems: [BookmarksBarItem] = []

        for (index, entity) in bookmarkEntities.enumerated() {
            let width = self.cachedWidth(buttonTitle: entity.title, isFolder: entity.isFolder)
            let calculatedWidth = min(Constants.maximumButtonWidth, width)

            if currentTotalWidth == 0 {
                currentTotalWidth += calculatedWidth
            } else {
                currentTotalWidth += (Constants.buttonSpacing + calculatedWidth)
            }

            if currentTotalWidth > containerWidth {
                clippedItemsStartingIndex = index
                break
            }
            
            let item = BookmarksBarItem(title: entity.title,
                                        url: (entity as? Bookmark)?.url,
                                        isFolder: entity.isFolder,
                                        entity: entity)

            displayableItems.append(item)
        }
        
        self.bookmarksBarItems = displayableItems
        
        if let clippedItemsStartingIndex = clippedItemsStartingIndex {
            let clippedEntities = bookmarkEntities[clippedItemsStartingIndex...]
            
            for clippedEntity in clippedEntities {
                clippedItems.append(BookmarkViewModel(entity: clippedEntity))
            }
        }
    }
 
    func cachedWidth(buttonTitle: String, isFolder: Bool = false) -> CGFloat {
        if let cachedValue = collectionViewItemSizeCache[buttonTitle] {
            let additionalWidth = isFolder ? Constants.additionalFolderWidth : Constants.additionalBookmarkWidth
            return cachedValue + additionalWidth
        } else {            
            let calculationLabel = NSTextField.label(titled: buttonTitle)
            calculationLabel.sizeToFit()
            let cappedTitleWidth = min(Constants.maximumButtonWidth, calculationLabel.frame.width)

            let additionalWidth = isFolder ? Constants.additionalFolderWidth : Constants.additionalBookmarkWidth
            let calculatedWidth = min(Constants.maximumButtonWidth, calculationLabel.frame.width) + additionalWidth
            collectionViewItemSizeCache[buttonTitle] = cappedTitleWidth
            
            return calculatedWidth
        }
    }
    
    func clipLastBarItem() -> Bool {
        guard let poppedItem = bookmarksBarItems.popLast() else {
            return false
        }
        
        let viewModel = BookmarkViewModel(entity: poppedItem.entity)
        clippedItems.insert(viewModel, at: 0)
        
        return true
    }
    
    func restoreLastClippedItem() -> Bool {
        guard !clippedItems.isEmpty else {
            return false
        }
        
        let item = clippedItems.removeFirst()
        let bookmarksBarItem = BookmarksBarItem(title: item.entity.title,
                                                url: (item.entity as? Bookmark)?.url,
                                                isFolder: item.entity.isFolder,
                                                entity: item.entity)
        
        bookmarksBarItems.append(bookmarksBarItem)
        
        return true
    }
    
    func buildClippedItemsMenu() -> NSMenu {
        let menu = NSMenu()
        menu.items = bookmarksTreeMenuItems(from: clippedItems)
        return menu
    }
    
    func bookmarksTreeMenuItems(from bookmarkViewModels: [BookmarkViewModel], topLevel: Bool = true) -> [NSMenuItem] {
        var menuItems = [NSMenuItem]()

        for viewModel in bookmarkViewModels {
            let menuItem = NSMenuItem(bookmarkViewModel: viewModel)

            if let folder = viewModel.entity as? BookmarkFolder {
                let subMenu = NSMenu(title: folder.title)
                let childViewModels = folder.children.map(BookmarkViewModel.init)
                let childMenuItems = bookmarksTreeMenuItems(from: childViewModels, topLevel: false)
                subMenu.items = childMenuItems

                if !subMenu.items.isEmpty {
                    menuItem.submenu = subMenu
                }
            }

            menuItems.append(menuItem)
        }

        let showOpenInTabsItem = bookmarkViewModels.compactMap { $0.entity as? Bookmark }.count > 1
        if showOpenInTabsItem {
            menuItems.append(.separator())
            menuItems.append(NSMenuItem(bookmarkViewModels: bookmarkViewModels))
        }
        
        return menuItems
    }
    
}

extension BookmarksBarViewModel: NSCollectionViewDelegate, NSCollectionViewDataSource {

    func collectionView(_ collectionView: NSCollectionView,
                        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
                        at indexPath: IndexPath) -> NSView {
        let image = NSImage(named: "Drop-Target-Indicator-16")!
        let imageView = NSImageView(image: image)
        imageView.contentTintColor = NSColor.controlAccentColor
        
        return imageView
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return bookmarksBarItems.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let genericCollectionViewItem = collectionView.makeItem(withIdentifier: BookmarksBarCollectionViewItem.identifier, for: indexPath)
        
        guard let bookmarksCollectionViewItem = genericCollectionViewItem as? BookmarksBarCollectionViewItem else {
            return genericCollectionViewItem
        }
        
        let bookmarksBarItem = bookmarksBarItems[indexPath.item]
        bookmarksCollectionViewItem.delegate = self
        bookmarksCollectionViewItem.updateItem(from: bookmarksBarItem.entity)
        
        return bookmarksCollectionViewItem
    }
    
    func collectionView(_ collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        willBeginAt screenPoint: NSPoint,
                        forItemsAt indexPaths: Set<IndexPath>) {
        self.existingItemDraggingIndexPath = indexPaths.first
    }
    
    func collectionView(_ collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        endedAt screenPoint: NSPoint,
                        dragOperation operation: NSDragOperation) {
        self.existingItemDraggingIndexPath = nil
    }
 
    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        // TODO: Remove the hardcoded duck.com writer and replace it with a custom writer for folders.
        return bookmarksBarItems[indexPath.item].url as NSURL? ?? NSURL(string: "https://duck.com/")
    }
    
    func collectionView(_ collectionView: NSCollectionView,
                        validateDrop draggingInfo: NSDraggingInfo,
                        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        if proposedDropOperation.pointee == .on {
            proposedDropOperation.pointee = .before
        }
        
        if existingItemDraggingIndexPath != nil {
            return .move
        } else {
            return .copy
        }
    }
    
    func collectionView(_ collectionView: NSCollectionView,
                        acceptDrop draggingInfo: NSDraggingInfo,
                        indexPath newIndexPath: IndexPath,
                        dropOperation: NSCollectionView.DropOperation) -> Bool {
        if let existingIndexPath = existingItemDraggingIndexPath {
            let entityUUID = self.bookmarksBarItems[existingIndexPath.item].entity.id
            
            let item: Int
            
            if existingIndexPath.item <= newIndexPath.item {
                item = newIndexPath.item - 1
            } else {
                item = newIndexPath.item
            }

            self.bookmarksBarItems.move(fromOffsets: IndexSet(integer: existingIndexPath.item), toOffset: newIndexPath.item)
            collectionView.animator().moveItem(at: existingIndexPath, to: IndexPath(item: item, section: 0))
            existingItemDraggingIndexPath = nil
            
            self.bookmarkManager.move(objectUUID: entityUUID, toIndexWithinParentFolder: item) { _ in
                // If error, reload the bar completely?
            }

            return true
        } else {
            guard let item = draggingInfo.draggingPasteboard.pasteboardItems?.first, let draggedItemData = titleAndURL(from: item) else {
                return false
            }
            
            self.bookmarkManager.makeBookmark(for: draggedItemData.url, title: draggedItemData.title, isFavorite: false, index: newIndexPath.item)
            return true
        }
    }
    
    private func titleAndURL(from pasteboardItem: NSPasteboardItem) -> (title: String, url: URL)? {
        guard let urlString = pasteboardItem.string(forType: .URL), let url = URL(string: urlString) else {
            return nil
        }
        
        // WKWebView pasteboard items include the name of the link under the `public.url-name` type.
        let name = pasteboardItem.string(forType: NSPasteboard.PasteboardType(rawValue: "public.url-name"))
        return (title: name ?? urlString, url: url)
    }
    
}

extension BookmarksBarViewModel: BookmarksBarCollectionViewItemDelegate {

    func bookmarksBarCollectionViewItemClicked(_ item: BookmarksBarCollectionViewItem) {
        let action: BookmarksBarItemAction
        
        if NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
            action = .openInNewTab
        } else if NSApplication.shared.isCommandPressed {
            action = .openInBackgroundTab
        } else {
            action = .loadURL
        }
        
        delegate?.bookmarksBarViewModelReceived(action: action, for: item)
    }
    
    func bookmarksBarCollectionViewItemOpenInNewTabAction(_ item: BookmarksBarCollectionViewItem) {        
        delegate?.bookmarksBarViewModelReceived(action: .openInNewTab, for: item)
    }
    
    func bookmarksBarCollectionViewItemOpenInNewWindowAction(_ item: BookmarksBarCollectionViewItem) {
        delegate?.bookmarksBarViewModelReceived(action: .openInNewWindow, for: item)
    }
    
    func bookmarksBarCollectionViewItemToggleFavoriteBookmarkAction(_ item: BookmarksBarCollectionViewItem) {
        delegate?.bookmarksBarViewModelReceived(action: .toggleFavorite, for: item)
    }
    
    func bookmarksBarCollectionViewItemCopyBookmarkURLAction(_ item: BookmarksBarCollectionViewItem) {
        delegate?.bookmarksBarViewModelReceived(action: .copyURL, for: item)
    }
    
    func bookmarksBarCollectionViewItemDeleteEntityAction(_ item: BookmarksBarCollectionViewItem) {
        delegate?.bookmarksBarViewModelReceived(action: .deleteEntity, for: item)
    }
    
}
