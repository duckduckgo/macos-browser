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

final class BookmarksBarViewModel: NSObject {
    
    // MARK: Enums
    
    enum Constants {
        static let buttonSpacing: CGFloat = 8
        static let buttonHeight: CGFloat = 28
        static let maximumButtonWidth: CGFloat = 150
        static let labelFont = NSFont.systemFont(ofSize: 13)
    }
    
    struct BookmarksBarItem {
        let title: String
        let url: URL?
        let isFolder: Bool
        let cachedWidth: CGFloat
        let entity: BaseBookmarkEntity
    }

    private var cancellables = Set<AnyCancellable>()
    
    private var existingItemDraggingIndexPath: IndexPath?
    private var collectionViewItemSizeCache: [String: CGFloat] = [:]
    private(set) var bookmarksBarItemsTotalWidth: CGFloat = 0
    
    private(set) var bookmarksBarItems: [BookmarksBarItem] = [] {
        didSet {
            let itemsWidth = bookmarksBarItems.reduce(CGFloat(0)) { total, item in
                total + item.cachedWidth
            }
            
            self.bookmarksBarItemsTotalWidth = itemsWidth + (CGFloat(bookmarksBarItems.count) * max(0, Constants.buttonSpacing - 1))
        }
    }

    private(set) var clippedItems: [BookmarkViewModel] = []
    
    // MARK: Functions
    
    func update(from bookmarkEntities: [BaseBookmarkEntity], containerWidth: CGFloat) {
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
            return cachedValue + (isFolder ? 40 : 28)
        } else {            
            let calculationLabel = NSTextField.label(titled: buttonTitle)
            calculationLabel.sizeToFit()
            let cappedTitleWidth = min(Constants.maximumButtonWidth, calculationLabel.frame.width)

            let calculatedWidth = min(Constants.maximumButtonWidth, calculationLabel.frame.width) + (isFolder ? 44 : 28)
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

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return bookmarksBarItems.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let id = NSUserInterfaceItemIdentifier(rawValue: "BookmarksBarCollectionViewItem")
        let genericCollectionViewItem = collectionView.makeItem(withIdentifier: id, for: indexPath)
        
        guard let bookmarksCollectionViewItem = genericCollectionViewItem as? BookmarksBarCollectionViewItem else {
            return genericCollectionViewItem
        }
        
        let bookmarksBarItem = bookmarksBarItems[indexPath.item]
        bookmarksCollectionViewItem.delegate = self
        bookmarksCollectionViewItem.updateItem(labelText: bookmarksBarItem.title, isFolder: bookmarksBarItem.isFolder)
        
        return bookmarksCollectionViewItem
    }
    
    func collectionView(collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        endedAtPoint screenPoint: NSPoint,
                        dragOperation operation: NSDragOperation) {
        print("Dragging ended at point \(screenPoint)")
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
                        indexPath: IndexPath,
                        dropOperation: NSCollectionView.DropOperation) -> Bool {
        if let existingIndexPath = existingItemDraggingIndexPath {
            print("Accepting drop at index path \(indexPath)")
            
            self.bookmarksBarItems.rearrange(from: existingIndexPath.item, to: indexPath.item)
            collectionView.animator().moveItem(at: existingIndexPath, to: indexPath)

            existingItemDraggingIndexPath = nil

            return true
        } else {
            // self.bookmarksBarItems.insert("Dragged Item With a Super Long Title", at: indexPath.item)
            // collectionView.animator().insertItems(at: Set([indexPath]))
            
            return false
        }
    }
    
}

extension BookmarksBarViewModel: BookmarksBarCollectionViewItemDelegate {
    
    func bookmarksBarCollectionViewItemClicked(_ bookmarksBarCollectionViewItem: BookmarksBarCollectionViewItem) {
        print("Clicked!!!")
    }
    
    func bookmarksBarCollectionViewItemShowContextMenu(_ bookmarksBarCollectionViewItem: BookmarksBarCollectionViewItem) {
        print("Right Clicked!!!")
    }
    
}

extension Array {

    mutating func rearrange(from: Int, to: Int) {
        insert(remove(at: from), at: to)
    }

}
