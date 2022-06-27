//
//  BookmarksBarViewController.swift
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

import Foundation
import AppKit
import Combine
import os.log

final class BookmarksBarViewController: NSViewController {

    @IBOutlet private var bookmarksBarCollectionView: NSCollectionView!
    @IBOutlet private var clippedItemsIndicator: NSButton!

    private let bookmarkManager = LocalBookmarkManager.shared
    private let viewModel = BookmarksBarViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    private var clipThreshold: CGFloat {
        let viewWidthWithoutClipIndicator = view.frame.width - clippedItemsIndicator.frame.minX
        return view.frame.width - viewWidthWithoutClipIndicator - 13
    }
    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel.delegate = self

        let nib = NSNib(nibNamed: "BookmarksBarCollectionViewItem", bundle: .main)
        bookmarksBarCollectionView.register(nib, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "BookmarksBarCollectionViewItem"))
        
        bookmarksBarCollectionView.registerForDraggedTypes([.string, .URL])
        bookmarksBarCollectionView.setDraggingSourceOperationMask(.copy, forLocal: true)
        
        bookmarksBarCollectionView.delegate = viewModel
        bookmarksBarCollectionView.dataSource = viewModel
        bookmarksBarCollectionView.collectionViewLayout = createBookmarksBarCollectionViewLayout()
        
        view.postsFrameChangedNotifications = true
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(frameChangeNotification),
                                               name: NSView.frameDidChangeNotification,
                                               object: view)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshFavicons),
                                               name: .faviconCacheUpdated,
                                               object: nil)
        
        subscribeToBookmarks()
    }
    
    private func createCenteredLayout(centered: Bool) -> NSCollectionLayoutSection {
        let widths = viewModel.bookmarksBarItems.map(\.cachedWidth)
        let cellSizes = widths.map { CGSize(width: $0, height: 28) }
        
        let group = NSCollectionLayoutGroup.horizontallyCentered(cellSizes: cellSizes, centered: centered)
        let section = NSCollectionLayoutSection(group: group)

        return section
    }
    
    func createBookmarksBarCollectionViewLayout() -> NSCollectionViewLayout {
        return NSCollectionViewCompositionalLayout { [unowned self] _, _ in
            if viewModel.clippedItems.isEmpty {
                return createCenteredLayout(centered: true)
            } else {
                return createCenteredLayout(centered: false)
            }
        }
    }

    private func subscribeToBookmarks() {
        bookmarkManager.listPublisher.sink { [weak self] list in
            guard let self = self else { return }
            
            self.viewModel.update(from: list?.topLevelEntities ?? [], containerWidth: self.clipThreshold)
            self.refreshClippedIndicator()
            self.bookmarksBarCollectionView.reloadData()
        }.store(in: &cancellables)
    }
    
    @objc
    private func frameChangeNotification() {
        bookmarksBarViewFrameChanged()
        refreshClippedIndicator()
    }
    
    private func refreshClippedIndicator() {
        self.clippedItemsIndicator.isHidden = viewModel.clippedItems.isEmpty
    }
    
    private func bookmarksBarViewFrameChanged() {
        guard !viewModel.bookmarksBarItems.isEmpty else {
            return
        }
        
        let lastIndexPath = IndexPath(item: viewModel.bookmarksBarItems.count - 1, section: 0)

        if viewModel.bookmarksBarItemsTotalWidth >= clipThreshold {
            print("Removing last item")
            
            if viewModel.clipLastBarItem() {
                self.bookmarksBarCollectionView.deleteItems(at: Set([lastIndexPath]))
            }
        } else if let nextRestorableClippedItem = viewModel.clippedItems.first {
            let widthOfRestorableItem = viewModel.cachedWidth(buttonTitle: nextRestorableClippedItem.entity.title,
                                                              isFolder: nextRestorableClippedItem.entity.isFolder)
            let newMaximumWidth = viewModel.bookmarksBarItemsTotalWidth + 10 + widthOfRestorableItem

            if newMaximumWidth < clipThreshold {
                if viewModel.restoreLastClippedItem() {
                    print("Restoring clipped item")
                    self.bookmarksBarCollectionView.reloadData()
                }
            }
        }
    }
    
    @objc
    private func refreshFavicons() {        
        // update each item
    }

    @IBAction
    private func clippedItemsIndicatorClicked(_ sender: NSButton) {
        let menu = NSMenu()
        let location = NSPoint(x: 0, y: sender.frame.height + 5) // Magic number to adjust the height.

        menu.items = viewModel.clippedItems.map { NSMenuItem(bookmarkViewModel: $0) }
        menu.popUp(positioning: nil, at: location, in: sender)
    }
    
    private func bookmarkMenuItems(from bookmarkViewModels: [BookmarkViewModel], topLevel: Bool = true) -> [NSMenuItem] {
        var menuItems = [NSMenuItem]()

        for viewModel in bookmarkViewModels {
            let menuItem = NSMenuItem(bookmarkViewModel: viewModel)

            if let folder = viewModel.entity as? BookmarkFolder {
                let subMenu = NSMenu(title: folder.title)
                let childViewModels = folder.children.map(BookmarkViewModel.init)
                let childMenuItems = bookmarkMenuItems(from: childViewModels, topLevel: false)
                subMenu.items = childMenuItems

                if !subMenu.items.isEmpty {
                    menuItem.submenu = subMenu
                }
            }

            menuItems.append(menuItem)
        }

        if !topLevel {
            let showOpenInTabsItem = bookmarkViewModels.compactMap { $0.entity as? Bookmark }.count > 1
            if showOpenInTabsItem {
                menuItems.append(.separator())
                menuItems.append(NSMenuItem(bookmarkViewModels: bookmarkViewModels))
            }
        }
        
        return menuItems
    }
    
}

// MARK: - BookmarksBarViewDelegate

//extension BookmarksBarViewController: BookmarksBarViewDelegate {
//
//    func draggingEntered(draggingInfo: NSDraggingInfo) {
//        os_log("Dragging entered", log: .bookmarks, type: .info)
//        let (index, width) = calculateNearestDragIndex(draggingInfo: draggingInfo)
//        updateNearestDragIndex(index, additionalWidth: width)
//    }
//
//    func draggingExited(draggingInfo: NSDraggingInfo?) {
//        os_log("Dragging exited", log: .bookmarks, type: .info)
//        updateNearestDragIndex(nil, additionalWidth: 0)
//    }
//
//    func draggingUpdated(draggingInfo: NSDraggingInfo) {
//        let (index, width) = calculateNearestDragIndex(draggingInfo: draggingInfo)
//        updateNearestDragIndex(index, additionalWidth: width)
//    }
//
//    private func calculateNearestDragIndex(draggingInfo: NSDraggingInfo) -> (index: Int, draggedItemWidth: CGFloat) {
//        let convertedDraggingLocation = view.convert(draggingInfo.draggingLocation, from: nil)
//        let horizontalOffset = convertedDraggingLocation.x
//        let result = midpoints.nearest(to: horizontalOffset)
//        let additionalWidth: CGFloat
//
//        if draggingInfo.draggingSource is BookmarksBarViewModel, let width = draggingInfo.width {
//            additionalWidth = width + BookmarksBarViewModel.Constants.buttonSpacing
//        } else if draggingInfo.draggingSource is BookmarksBarViewModel, let index = draggedItemOriginalIndex {
//            let entityTitle = self.buttonData[index].bookmarkViewModel.entity.title
//            let renderingWidth = entityTitle.renderingWidth(with: BookmarksBarViewModel.Constants.labelFont)
//            let titleWidth = min(BookmarksBarViewModel.Constants.maximumButtonWidth, renderingWidth + 16 + 10)
//
//            additionalWidth = titleWidth + BookmarksBarViewModel.Constants.buttonSpacing
//        } else {
//            if let item = draggingInfo.draggingPasteboard.pasteboardItems?.first, let title = titleAndURL(from: item) {
//                additionalWidth = min(
//                    BookmarksBarViewModel.Constants.maximumButtonWidth,
//                    title.0.renderingWidth(with: BookmarksBarViewModel.Constants.labelFont) + 16 + 10
//                )
//            } else {
//                additionalWidth = draggingInfo.width ?? 0
//            }
//        }
//
//        return (result?.offset ?? 0, additionalWidth)
//    }
//
//    func draggingEnded(draggingInfo: NSDraggingInfo) {
//        os_log("Dragging ended", log: .bookmarks, type: .info)
//        viewModel.handle(event: .draggingEnded)
//
//        for button in buttonData {
//            button.button.isHidden = false
//        }
//
//        print("DEBUG \(Date()): LayoutButtons DraggingEnded")
//        layoutButtons()
//    }
//
//    func performDragOperation(draggingInfo: NSDraggingInfo) -> Bool {
//        os_log("Performing drag operation", log: .bookmarks, type: .info)
//        initialDraggingPoint = nil
//
//        guard let newIndex = dropIndex else {
//            os_log("Dragging ended without a drop index, returning", log: .bookmarks, type: .info)
//            return false
//        }
//
//        if let index = draggedItemOriginalIndex, let draggedItemUUID = self.bookmarkManager.list?.topLevelEntities[index].id {
//            os_log("Dragging ended with drop index = %d, moving existing bookmark", log: .bookmarks, type: .info, newIndex)
//
//            self.buttonData.move(fromOffsets: IndexSet(integer: index), toOffset: newIndex)
//            print("DEBUG \(Date()): PerformDragOperation")
//            self.layoutButtons()
//
//            bookmarkManager.move(objectUUID: draggedItemUUID, toIndexWithinParentFolder: newIndex) { _ in
//                self.dropIndex = nil
//                self.draggedItemOriginalIndex = nil
//            }
//        } else if let draggedItems = draggingInfo.draggingPasteboard.pasteboardItems {
//            os_log("Dragging ended with drop index = %d, saving new bookmark", log: .bookmarks, type: .info, newIndex)
//
//            for draggedItem in draggedItems {
//                if let (title, url) = titleAndURL(from: draggedItem) {
//                    bookmarkManager.makeBookmark(for: url, title: title, isFavorite: false, index: newIndex)
//                }
//            }
//
//            self.dropIndex = nil
//            self.draggedItemOriginalIndex = nil
//            print("DEBUG \(Date()): PerformDragOperation")
//            self.layoutButtons()
//        }
//
//        return true
//    }
//
//    private func titleAndURL(from pasteboardItem: NSPasteboardItem) -> (title: String, url: URL)? {
//        guard let urlString = pasteboardItem.string(forType: .URL), let url = URL(string: urlString) else {
//            return nil
//        }
//
//        // WKWebView pasteboard items include the name of the link under the `public.url-name` type.
//        let name = pasteboardItem.string(forType: NSPasteboard.PasteboardType(rawValue: "public.url-name"))
//        return (title: name ?? urlString, url: url)
//    }
//
//}

extension BookmarksBarViewController: BookmarksBarViewModelDelegate {
    
    func bookmarksBarViewModelReceivedLeftClick(for item: BookmarksBarCollectionViewItem) {
        guard let indexPath = bookmarksBarCollectionView.indexPath(for: item) else {
            assertionFailure("Failed to look up index path for clicked item")
            return
        }
        
        guard let entity = bookmarkManager.list?.topLevelEntities[indexPath.item] else {
            assertionFailure("Failed to get entity for clicked item")
            return
        }
        
        if let bookmark = entity as? Bookmark {
            WindowControllersManager.shared.show(url: bookmark.url, newTab: false)
        } else if let folder = entity as? BookmarkFolder {
            let childEntities = folder.children
            let viewModels = childEntities.map { BookmarkViewModel(entity: $0) }
            let menuItems = bookmarkMenuItems(from: viewModels, topLevel: true)
            let menu = NSMenu()
            
            menu.items = menuItems
            menu.popUp(positioning: nil, at: CGPoint(x: 0, y: item.view.frame.minY - 7), in: item.view)
        } else {
            assertionFailure("Failed to cast entity for clicked item")
        }
    }
    
}

extension BookmarksBarViewController: BookmarkMenuItemSelectors {
    
    func openBookmarkInNewTab(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }
        
        WindowControllersManager.shared.show(url: bookmark.url, newTab: true)
    }
    
    func openBookmarkInNewWindow(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }
        
        WindowsManager.openNewWindow(with: bookmark.url)
    }
    
    func toggleBookmarkAsFavorite(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }
        
        bookmark.isFavorite.toggle()
        LocalBookmarkManager.shared.update(bookmark: bookmark)
    }
    
    func editBookmark(_ sender: NSMenuItem) {
        // Unsupported in the list view for the initial release.
    }
    
    func copyBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark, let bookmarkURL = bookmark.url as NSURL? else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.URL], owner: nil)
        bookmarkURL.write(to: pasteboard)
        pasteboard.setString(bookmarkURL.absoluteString ?? "", forType: .string)
    }
    
    func deleteBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }
        
        LocalBookmarkManager.shared.remove(bookmark: bookmark)
    }
    
}

extension BookmarksBarViewController: FolderMenuItemSelectors {
    
    func newFolder(_ sender: NSMenuItem) {
        let addFolderViewController = AddFolderModalViewController.create()
        // TODO
        // addFolderViewController.delegate = self
        beginSheet(addFolderViewController)
    }
    
    func renameFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Rename Folder context menu item")
            return
        }
        
        let addFolderViewController = AddFolderModalViewController.create()
        // TODO
        // addFolderViewController.delegate = self
        addFolderViewController.edit(folder: folder)
        presentAsModalWindow(addFolderViewController)
    }
    
    func deleteFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Delete Folder context menu item")
            return
        }
        
        LocalBookmarkManager.shared.remove(folder: folder)
    }
    
}
