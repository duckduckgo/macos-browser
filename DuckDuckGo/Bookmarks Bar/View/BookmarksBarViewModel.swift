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
    
    func bookmarksBarViewModelReceivedLeftClick(for item: BookmarksBarCollectionViewItem)
    
}

final class BookmarksBarViewModel: NSObject {
    
    // MARK: Enums
    
    enum Constants {
        static let buttonSpacing: CGFloat = 8
        static let buttonHeight: CGFloat = 30
        static let maximumButtonWidth: CGFloat = 200
        static let labelFont = NSFont.systemFont(ofSize: 13)
    }
    
    struct BookmarksBarItem {
        let title: String
        let url: URL?
        let isFolder: Bool
        let cachedWidth: CGFloat
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
            print("Got new items: \(bookmarksBarItems.map(\.title))")
            let itemsWidth = bookmarksBarItems.reduce(CGFloat(0)) { total, item in
                if total == 0 {
                    return total + item.cachedWidth
                } else {
                    return total + Constants.buttonSpacing + item.cachedWidth
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
                print("Adding the new item would break the container width, stop creating items and put the remainder in the overflow menu")
                clippedItemsStartingIndex = index
                break
            }
            
            let item = BookmarksBarItem(title: entity.title,
                                        url: (entity as? Bookmark)?.url,
                                        isFolder: entity.isFolder,
                                        cachedWidth: calculatedWidth,
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
            let width = cachedValue + (isFolder ? 46 : 30)
            return width
        } else {            
            let calculationLabel = NSTextField.label(titled: buttonTitle)
            calculationLabel.sizeToFit()
            let cappedTitleWidth = min(Constants.maximumButtonWidth, calculationLabel.frame.width)

            let calculatedWidth = min(Constants.maximumButtonWidth, calculationLabel.frame.width) + (isFolder ? 46 : 30)
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
                                                cachedWidth: cachedWidth(buttonTitle: item.entity.title, isFolder: item.entity.isFolder),
                                                entity: item.entity)
        
        bookmarksBarItems.append(bookmarksBarItem)
        
        return true
    }
    
}

extension BookmarksBarViewModel: NSCollectionViewDelegate, NSCollectionViewDataSource {

    func collectionView(_ collectionView: NSCollectionView,
                        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
                        at indexPath: IndexPath) -> NSView {
        let image = NSImage(named: "Drop-Target-Indicator-16")!
        let imageView = NSImageView(image: image)
        imageView.contentTintColor = NSColor.systemMint
        
        return imageView
    }
    
    func collectionView(_ collectionView: NSCollectionView, draggingImageForItemsAt indexes: IndexSet, with event: NSEvent, offset dragImageOffset: NSPointPointer) -> NSImage {
        return NSImage()
    }
    
    func collectionView(
        _ collectionView: NSCollectionView,
        draggingImageForItemsAt indexPaths: Set<IndexPath>,
        with event: NSEvent,
        offset dragImageOffset: NSPointPointer
    ) -> NSImage {
        return NSImage(named: "Bookmark")!
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
        print("Dragging ended at point \(screenPoint)")
        self.existingItemDraggingIndexPath = nil
    }
 
    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        return NSURL(string: "https://example.com")
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

            let existingItem = self.bookmarksBarItems[existingIndexPath.item].title
            let itemAtCurrentSpot = self.bookmarksBarItems[item].title
            
            self.bookmarksBarItems.rearrange(from: existingIndexPath.item, to: newIndexPath.item)
            collectionView.animator().moveItem(at: existingIndexPath, to: IndexPath(item: item, section: 0))
            existingItemDraggingIndexPath = nil
            
            self.bookmarkManager.move(objectUUID: entityUUID, toIndexWithinParentFolder: item) { _ in
                // TODO: If error, reload the bar completely?
            }

            return true
        } else {
            print("Adding new bookmark")
            
            return false
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
    
    func bookmarksBarCollectionViewItemClicked(_ bookmarksBarCollectionViewItem: BookmarksBarCollectionViewItem) {
        print("Clicked item!")
        delegate?.bookmarksBarViewModelReceivedLeftClick(for: bookmarksBarCollectionViewItem)
    }
    
}

extension Array {

    mutating func rearrange(from currentIndex: Int, to newIndex: Int) {
        print("Moving from \(currentIndex) to \(newIndex)")
        move(fromOffsets: IndexSet(integer: currentIndex), toOffset: newIndex)
    }

}
