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
    func bookmarksBarViewModelWidthForContainer() -> CGFloat
    func bookmarksBarViewModelReloadedData()
    
}

final class BookmarksBarViewModel: NSObject {
    
    // MARK: Enums
    
    enum Constants {
        static let buttonSpacing: CGFloat = 6
        static let buttonHeight: CGFloat = 28
        static let maximumButtonWidth: CGFloat = 120
        static let labelFont = NSFont.systemFont(ofSize: 12)
        
        static let additionalItemWidth = 34.0
        
        static let interItemGapIndicatorIdentifier = "NSCollectionElementKindInterItemGapIndicator"
    }
    
    enum BookmarksBarItemAction {
        case clickItem
        case openInBackgroundTab
        case openInNewTab
        case openInNewWindow
        case addToFavorites
        case edit
        case moveToEnd
        case copyURL
        case deleteEntity
    }
    
    struct BookmarksBarItem {
        let title: String
        let url: URL?
        let isFolder: Bool
        let entity: BaseBookmarkEntity
        
        init(entity: BaseBookmarkEntity) {
            self.title = entity.title
            self.url = (entity as? Bookmark)?.url
            self.isFolder = entity.isFolder
            self.entity = entity
        }
    }
    
    weak var delegate: BookmarksBarViewModelDelegate?

    private let bookmarkManager: BookmarkManager
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
    
    private var bookmarksBarItems: [BookmarksBarItem] = [] {
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
    
    init(bookmarkManager: BookmarkManager, tabCollectionViewModel: TabCollectionViewModel) {
        self.bookmarkManager = bookmarkManager
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
            if clipLastBarItem() {
                delegate?.bookmarksBarViewModelReloadedData()
            }
        } else if let nextRestorableClippedItem = clippedItems.first {
            var restoredItem = false

            while true {
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
            return cachedValue + Constants.additionalItemWidth
        } else {            
            textSizeCalculationLabel.stringValue = buttonTitle
            textSizeCalculationLabel.sizeToFit()

            let cappedTitleWidth = min(Constants.maximumButtonWidth, textSizeCalculationLabel.frame.width)
            let calculatedWidth = min(Constants.maximumButtonWidth, textSizeCalculationLabel.frame.width) + Constants.additionalItemWidth
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
        let bookmarksBarItem = BookmarksBarItem(entity: item.entity)
        
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
        guard kind == Constants.interItemGapIndicatorIdentifier else {
            assertionFailure("Received requested for unexpected supplementary element type")
            return NSView()
        }

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
        assert(indexPaths.count == 1) // Only one item can be dragged from the bar at a time
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
        return bookmarksBarItems[indexPath.item].entity.pasteboardWriter
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
        beginClickPreventionTimer()

        if let existingIndexPath = existingItemDraggingIndexPath {
            let entityUUID = self.bookmarksBarItems[existingIndexPath.item].entity.id
            
            let index: Int
            
            if existingIndexPath.item <= newIndexPath.item {
                index = newIndexPath.item - 1
            } else {
                index = newIndexPath.item
            }

            self.bookmarksBarItems.move(fromOffsets: IndexSet(integer: existingIndexPath.item), toOffset: newIndexPath.item)
            collectionView.animator().moveItem(at: existingIndexPath, to: IndexPath(item: index, section: 0))
            existingItemDraggingIndexPath = nil
            
            bookmarkManager.move(objectUUIDs: [entityUUID], toIndex: index, withinParentFolder: .root) { error in
                if error != nil {
                    self.delegate?.bookmarksBarViewModelReloadedData()
                }
            }

            return true
        } else if let pasteboardItems = draggingInfo.draggingPasteboard.pasteboardItems {
            var currentIndexPathItem = newIndexPath.item

            for item in pasteboardItems {
                if let bookmarkEntityUUID = item.bookmarkEntityUUID {
                    bookmarkManager.move(objectUUIDs: [bookmarkEntityUUID], toIndex: currentIndexPathItem, withinParentFolder: .root) { error in
                        if error != nil {
                            self.delegate?.bookmarksBarViewModelReloadedData()
                        }
                    }
                } else if let webViewItem = item.draggedWebViewValues() {
                    let title = webViewItem.title ?? tabCollectionViewModel.title(forTabWithURL: webViewItem.url) ?? webViewItem.url.absoluteString
                    self.bookmarkManager.makeBookmark(for: webViewItem.url, title: title, isFavorite: false, index: currentIndexPathItem, parent: nil)
                } else if let draggedString = item.string(forType: .string), let draggedURL = URL(string: draggedString) {
                    let title: String

                    if let tabTitle = tabCollectionViewModel.title(forTabWithURL: draggedURL) {
                        title = tabTitle
                    } else {
                        title = draggedURL.absoluteString
                    }

                    self.bookmarkManager.makeBookmark(for: draggedURL, title: title, isFavorite: false, index: currentIndexPathItem, parent: nil)
                }
                
                currentIndexPathItem += 1
            }
            
            return true
        }
        
        return false
    }
    
    // MARK: - Drag & Drop

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

        let action: BookmarksBarItemAction
        
        if NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
            action = .openInNewTab
        } else if NSApplication.shared.isCommandPressed {
            action = .openInBackgroundTab
        } else {
            action = .clickItem
        }
        
        delegate?.bookmarksBarViewModelReceived(action: action, for: item)
    }
    
    func bookmarksBarCollectionViewItemOpenInNewTabAction(_ item: BookmarksBarCollectionViewItem) {        
        delegate?.bookmarksBarViewModelReceived(action: .openInNewTab, for: item)
    }
    
    func bookmarksBarCollectionViewItemOpenInNewWindowAction(_ item: BookmarksBarCollectionViewItem) {
        delegate?.bookmarksBarViewModelReceived(action: .openInNewWindow, for: item)
    }
    
    func bookmarksBarCollectionViewItemAddToFavoritesAction(_ item: BookmarksBarCollectionViewItem) {
        delegate?.bookmarksBarViewModelReceived(action: .addToFavorites, for: item)
    }
    
    func bookmarksBarCollectionViewEditAction(_ item: BookmarksBarCollectionViewItem) {
        delegate?.bookmarksBarViewModelReceived(action: .edit, for: item)
    }
    
    func bookmarksBarCollectionViewItemMoveToEndAction(_ item: BookmarksBarCollectionViewItem) {
        delegate?.bookmarksBarViewModelReceived(action: .moveToEnd, for: item)
    }
    
    func bookmarksBarCollectionViewItemCopyBookmarkURLAction(_ item: BookmarksBarCollectionViewItem) {
        delegate?.bookmarksBarViewModelReceived(action: .copyURL, for: item)
    }
    
    func bookmarksBarCollectionViewItemDeleteEntityAction(_ item: BookmarksBarCollectionViewItem) {
        delegate?.bookmarksBarViewModelReceived(action: .deleteEntity, for: item)
    }
    
}
