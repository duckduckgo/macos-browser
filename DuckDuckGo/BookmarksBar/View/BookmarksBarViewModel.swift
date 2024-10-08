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

    func didClick(_ item: BookmarksBarCollectionViewItem)
    func bookmarksBarViewModelWidthForContainer() -> CGFloat
    func bookmarksBarViewModelReloadedData()
    func mouseDidHover(over item: Any)
    func dragging(over item: BookmarksBarCollectionViewItem?, updatedWith info: NSDraggingInfo?)
    func showDialog(_ dialog: any ModalView)

}

final class BookmarksBarViewModel: NSObject {

    // MARK: Enums

    enum Constants {
        static let buttonSpacing: CGFloat = 2
        static let buttonHeight: CGFloat = 28
        static let maximumButtonWidth: CGFloat = 128
        static let labelFont = NSFont.systemFont(ofSize: 12)

        static let additionalItemWidth: CGFloat = 28.0
        static let ignoredXDragDistanceFromCellBorders: CGFloat = 5.0
    }

    struct BookmarksBarItem {
        let title: String
        let url: URL?
        let isFolder: Bool
        let entity: BaseBookmarkEntity

        init(entity: BaseBookmarkEntity) {
            self.title = entity.title
            self.url = (entity as? Bookmark)?.urlObject
            self.isFolder = entity.isFolder
            self.entity = entity
        }
    }

    weak var delegate: BookmarksBarViewModelDelegate?
    var isInteractionPrevented = false

    private let bookmarkManager: BookmarkManager
    private let dragDropManager: BookmarkDragDropManager
    private let tabCollectionViewModel: TabCollectionViewModel
    private var cancellables = Set<AnyCancellable>()

    private var existingItemDraggingIndexPath: IndexPath?
    private var preventClicks = false

    private var collectionViewItemSizeCache: [String: CGFloat] = [:]
    private var bookmarksBarItemsTotalWidth: CGFloat = 0

    private let textSizeCalculationLabel: NSTextField = {
        let calculationLabel = NSTextField.label(titled: "")
        calculationLabel.font = Constants.labelFont
        calculationLabel.lineBreakMode = .byTruncatingMiddle

        return calculationLabel
    }()

    @Published
    private(set) var bookmarksBarItems: [BookmarksBarItem] = [] {
        didSet {
            let itemsWidth = bookmarksBarItems.reduce(CGFloat(0)) { total, item in
                if total == 0 {
                    return total + cachedWidth(buttonTitle: item.title)
                } else {
                    return total + Constants.buttonSpacing + cachedWidth(buttonTitle: item.title)
                }
            }

            self.bookmarksBarItemsTotalWidth = itemsWidth
        }
    }

    @Published
    private(set) var clippedItems: [BookmarkViewModel] = []

    var cellSizes: [CGSize] {
        let widths = bookmarksBarItems.map { item in
            return cachedWidth(buttonTitle: item.title)
        }

        return widths.map { CGSize(width: $0, height: Constants.buttonHeight) }
    }

    // MARK: - Initialization

    init(bookmarkManager: BookmarkManager, dragDropManager: BookmarkDragDropManager = .shared, tabCollectionViewModel: TabCollectionViewModel) {
        self.bookmarkManager = bookmarkManager
        self.dragDropManager = dragDropManager
        self.tabCollectionViewModel = tabCollectionViewModel
        super.init()
        subscribeToBookmarks()
    }

    private func subscribeToBookmarks() {
        bookmarkManager.listPublisher.receive(on: RunLoop.main).sink { [weak self] list in
            let containerWidth = self?.delegate?.bookmarksBarViewModelWidthForContainer() ?? 0
            self?.update(from: list?.topLevelEntities ?? [], containerWidth: containerWidth)
            self?.delegate?.bookmarksBarViewModelReloadedData()
        }.store(in: &cancellables)
    }

    // MARK: - Functions

    func update(from bookmarkEntities: [BaseBookmarkEntity], containerWidth: CGFloat) {
        clippedItems = []

        var currentTotalWidth: CGFloat = 0.0
        var clippedItemsStartingIndex: Int?
        var displayableItems: [BookmarksBarItem] = []

        for (index, entity) in bookmarkEntities.enumerated() {
            let calculatedWidth = self.cachedWidth(buttonTitle: entity.title)

            if currentTotalWidth == 0 {
                currentTotalWidth += calculatedWidth
            } else {
                currentTotalWidth += (Constants.buttonSpacing + calculatedWidth)
            }

            if currentTotalWidth > containerWidth {
                clippedItemsStartingIndex = index
                break
            }

            let item = BookmarksBarItem(entity: entity)
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

    func clipOrRestoreBookmarksBarItems() {
        guard let clipThreshold = delegate?.bookmarksBarViewModelWidthForContainer() else {
            assertionFailure("Failed to get width of bookmarks bar container")
            return
        }

        guard !bookmarksBarItems.isEmpty else {
            return
        }

        if bookmarksBarItemsTotalWidth >= clipThreshold {
            while bookmarksBarItemsTotalWidth >= clipThreshold {
                if !clipLastBarItem() {
                    // Short circuit the while loop in the case that clipping the last item doesn't succeed.
                    break
                }
            }

            delegate?.bookmarksBarViewModelReloadedData()
        } else if !clippedItems.isEmpty {
            var restoredItem = false

            while let nextRestorableClippedItem = clippedItems.first {
                if !restoreNextClippedItemToBookmarksBarIfPossible(item: nextRestorableClippedItem) {
                    break
                }

                restoredItem = true
            }

            if restoredItem {
                delegate?.bookmarksBarViewModelReloadedData()
            }
        }
    }

    private func restoreNextClippedItemToBookmarksBarIfPossible(item: BookmarkViewModel) -> Bool {
        guard let clipThreshold = delegate?.bookmarksBarViewModelWidthForContainer() else {
            assertionFailure("Failed to get width of bookmarks bar container")
            return false
        }

        let widthOfRestorableItem = cachedWidth(buttonTitle: item.entity.title)
        let newMaximumWidth = bookmarksBarItemsTotalWidth + Constants.buttonSpacing + widthOfRestorableItem

        if newMaximumWidth < clipThreshold {
            return restoreLastClippedItem()
        }

        return false
    }

    func cachedWidth(buttonTitle: String) -> CGFloat {
        if let cachedValue = collectionViewItemSizeCache[buttonTitle] {
            return cachedValue
        } else {
            textSizeCalculationLabel.stringValue = buttonTitle
            textSizeCalculationLabel.sizeToFit()

            let calculatedWidth = min(Constants.maximumButtonWidth, ceil(textSizeCalculationLabel.frame.width) + Constants.additionalItemWidth)
            collectionViewItemSizeCache[buttonTitle] = calculatedWidth

            return ceil(calculatedWidth)
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
        let bookmarksBarItem = BookmarksBarItem(entity: item.entity)

        bookmarksBarItems.append(bookmarksBarItem)

        return true
    }

}

extension BookmarksBarViewModel: NSCollectionViewDelegate, NSCollectionViewDataSource {

    func collectionView(_ collectionView: NSCollectionView,
                        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
                        at indexPath: IndexPath) -> NSView {
        guard kind == NSCollectionView.interItemGapIndicatorIdentifier else {
            assertionFailure("Received requested for unexpected supplementary element type")
            return NSView()
        }

        let imageView = NSImageView(image: .dropTargetIndicator16)
        imageView.contentTintColor = NSColor.controlAccentColor

        return imageView
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return bookmarksBarItems.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        // swiftlint:disable:next force_cast
        let bookmarksCollectionViewItem = collectionView.makeItem(withIdentifier: BookmarksBarCollectionViewItem.identifier, for: indexPath) as! BookmarksBarCollectionViewItem

        let bookmarksBarItem = bookmarksBarItems[indexPath.item]
        bookmarksCollectionViewItem.delegate = self
        bookmarksCollectionViewItem.updateItem(from: bookmarksBarItem.entity, isInteractionPrevented: isInteractionPrevented)

        return bookmarksCollectionViewItem
    }

    // MARK: - Drag & Drop

    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItemsAt indexPaths: Set<IndexPath>) {
        assert(indexPaths.count == 1) // Only one item can be dragged from the bar at a time
        self.existingItemDraggingIndexPath = indexPaths.first
    }

    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        return true
    }

    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        return bookmarksBarItems[indexPath.item].entity.pasteboardWriter
    }

    func collectionView(_ collectionView: NSCollectionView,
                        validateDrop draggingInfo: NSDraggingInfo,
                        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        var destination: Any
        var mouseLocationInsideCell: NSPoint?
        var contractedBounds: NSRect?
        var item = collectionView.item(at: proposedDropIndexPath.pointee as IndexPath) as? BookmarksBarCollectionViewItem
        if proposedDropOperation.pointee == .on,
           let cell = item?.view {
            mouseLocationInsideCell = cell.mouseLocationInsideBounds(draggingInfo.draggingLocation)
            // ignore extra pixels at the cell borders to let to drop an item between the items
            contractedBounds = cell.bounds.insetBy(dx: Constants.ignoredXDragDistanceFromCellBorders, dy: 0)
        }
        if let mouseLocationInsideCell, let contractedBounds, contractedBounds.contains(mouseLocationInsideCell),
           let folder = bookmarksBarItems[safe: proposedDropIndexPath.pointee.item]?.entity as? BookmarkFolder {
            // dragging over a folder
            destination = folder
        } else {
            // reordering (dragging in inter-item space)
            proposedDropOperation.pointee = .before
            destination = PseudoFolder.bookmarks
            if let mouseLocationInsideCell, let contractedBounds,
               mouseLocationInsideCell.x > contractedBounds.midX {
                // when dragging closer to the cell‘s right edge – set the insertion point after the item
                proposedDropIndexPath.pointee = NSIndexPath(forItem: proposedDropIndexPath.pointee.item + 1, inSection: 0)
            }
            item = nil
        }
        delegate?.dragging(over: item, updatedWith: draggingInfo)

        return dragDropManager.validateDrop(draggingInfo, to: destination)
    }

    func collectionView(_ collectionView: NSCollectionView,
                        acceptDrop draggingInfo: NSDraggingInfo,
                        indexPath newIndexPath: IndexPath,
                        dropOperation: NSCollectionView.DropOperation) -> Bool {
        beginClickPreventionTimer()

        var destination: Any
        if dropOperation == .on,
           let folder = bookmarksBarItems[safe: newIndexPath.item]?.entity as? BookmarkFolder {
            destination = folder
        } else {
            destination = PseudoFolder.bookmarks
        }

        if let existingIndexPath = existingItemDraggingIndexPath, destination is PseudoFolder {
            let index = (existingIndexPath.item <= newIndexPath.item) ? newIndexPath.item - 1 : newIndexPath.item
            self.bookmarksBarItems.move(fromOffsets: IndexSet(integer: existingIndexPath.item), toOffset: newIndexPath.item)
            collectionView.animator().moveItem(at: existingIndexPath, to: IndexPath(item: index, section: 0))
            existingItemDraggingIndexPath = nil
        }

        // apply index change when dropping on the Bookmarks Bar (PseudoFolder.bookmarks)
        // move to a folder (index == -1) when dropping on a folder item
        let index = (destination is PseudoFolder) ? newIndexPath.item : -1
        return dragDropManager.acceptDrop(draggingInfo, to: destination, at: index)
    }

    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, dragOperation operation: NSDragOperation) {
        // `existingItemDraggingIndexPath` is reset on items reordering
        if let indexPath = existingItemDraggingIndexPath, bookmarksBarItems.indices.contains(indexPath.item) {
            // dragDropManager clears draggingPasteboard items on acceptDrop to another folder
            if (session.draggingPasteboard.pasteboardItems ?? []).isEmpty {
                bookmarksBarItems.remove(at: indexPath.item)
                collectionView.deleteItems(at: [indexPath])
            }
            self.existingItemDraggingIndexPath = nil
        }
    }

    /// On rare occasions, a click event will be sent immediately after a drag and drop operation completes.
    /// To prevent drag and drop from accidentally triggering a bookmark to load or folder to open, all click events are ignored for a short period after a drop has been accepted.
    private func beginClickPreventionTimer() {
        preventClicks = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.preventClicks = false
        }
    }

}

extension BookmarksBarViewModel: BookmarksBarCollectionViewItemDelegate {

    func bookmarksBarCollectionViewItemClicked(_ item: BookmarksBarCollectionViewItem) {
        guard !preventClicks else {
            return
        }

        delegate?.didClick(item)
    }

    func showDialog(_ dialog: any ModalView) {
        delegate?.showDialog(dialog)
    }

    func bookmarksBarCollectionViewItemMouseDidHover(_ item: BookmarksBarCollectionViewItem) {
        delegate?.mouseDidHover(over: item)
    }

}
