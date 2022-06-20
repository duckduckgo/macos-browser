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

// swiftlint:disable:next type_body_length
final class BookmarksBarViewController: NSViewController {
    
    private struct DraggedItemLayoutData {
        let dropIndex: Int
        let proposedItemWidth: CGFloat
    }
    
    private let bookmarkManager = LocalBookmarkManager.shared
    private let viewModel = BookmarksBarViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    private var hasClippedButtons: Bool {
        !clippedButtons.isEmpty
    }
    
    private let clippedItemsIndicator: NSButton = {
        let indicator = NSButton(frame: .zero)
    
        indicator.image = NSImage(named: "Chevron-Double-Right-16")
        indicator.isBordered = false
        indicator.isHidden = true
        indicator.sizeToFit()
    
        return indicator
    }()
    
    private var clipThreshold: CGFloat {
        return view.frame.width - (clippedItemsIndicator.frame.midX - BookmarksBarViewModel.Constants.buttonSpacing)
    }
    
    // MARK: - Layout Calculation
    
    private var buttonData: [BookmarksBarViewModel.BookmarkButtonData] = []
    private var midpoints: [CGFloat] = []
    
    private var clippedButtons: [BookmarksBarViewModel.BookmarkButtonData] = [] {
        didSet {
            clippedItemsIndicator.isHidden = clippedButtons.isEmpty
        }
    }
    
    private var bookmarksBarWidth: CGFloat = 0
    
    private var draggedItemOriginalIndex: Int?
    private var dropIndex: Int?
    private var initialDraggingPoint: CGPoint?
    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let bookmarksBarView = self.view as? BookmarksBarView {
            bookmarksBarView.delegate = self
        } else {
            assertionFailure()
        }

        view.registerForDraggedTypes([.string, .URL])
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

        self.buttonData = viewModel.createButtons(for: bookmarkManager.list?.topLevelEntities ?? [])
        self.buttonData.forEach {
            $0.button.target = self
            $0.button.sendAction(on: [.leftMouseDown, .leftMouseDragged, .leftMouseUp])
            $0.button.action = #selector(bookmarkButtonClicked(_:))
            $0.button.menu = ContextualMenu.menu(for: [$0.bookmarkViewModel.entity], includeBookmarkEditMenu: false)
        }
        
        addAndPositionButtonsForInitialLayout()
    }

    private func subscribeToBookmarks() {
        bookmarkManager.listPublisher.sink { [weak self] list in
            guard let self = self else { return }
            
            print("Bookmarks Changed")
            self.buttonData = self.viewModel.createButtons(for: list?.topLevelEntities ?? [])
            self.buttonData.forEach {
                $0.button.target = self
                $0.button.sendAction(on: [.leftMouseDown, .leftMouseDragged, .leftMouseUp])
                $0.button.action = #selector(self.bookmarkButtonClicked(_:))
                $0.button.menu = ContextualMenu.menu(for: [$0.bookmarkViewModel.entity], includeBookmarkEditMenu: false)
            }

            self.addAndPositionButtonsForInitialLayout()
        }.store(in: &cancellables)
    }
    
    @objc
    private func frameChangeNotification() {
        print(#function)
        bookmarksBarViewFrameChanged()
    }
    
    private func bookmarksBarViewFrameChanged() {
        print(#function)
        layoutButtons()

        let maximumWidth = bookmarksBarWidth + (BookmarksBarViewModel.Constants.buttonSpacing * 2) + clippedItemsIndicator.frame.width
        
        if view.frame.size.width <= maximumWidth {
            removeLastButton()
        } else {
            tryToRestoreClippedButton()
        }
    }
    
    @objc
    private func refreshFavicons() {        
        for data in buttonData {
            data.button.refreshFaviconIfNeeded()
        }
    }
    
    private func addAndPositionButtonsForInitialLayout() {
        print(#function)
        
        for view in view.subviews where view is NSButton {
            view.removeFromSuperview()
        }

        self.buttonData.map(\.button).forEach(view.addSubview)
        
        clippedButtons = []
        addClippedItemsIndicator()

        calculateFixedButtonSizingValues()
        
        print("DEBUG \(Date()): LayoutButtons AddAndPosition")
        layoutButtons()
    }
    
    private func addClippedItemsIndicator() {
        clippedItemsIndicator.target = self
        clippedItemsIndicator.action = #selector(clippedItemsIndicatorClicked(_:))
        
        view.addSubview(clippedItemsIndicator)
    }
    
    private func tryToRestoreClippedButton() {
        print(#function)

        guard let firstClippedButton = clippedButtons.first else {
            return
        }

        // Check if the next clipped button to restore can fit, and add it if so:
        
        let clippedButtonWidth = firstClippedButton.button.bounds.width
        
        // Button spacing * 3: Once for the padding between the last button and the new one,
        // and two to account for the spacing at the beginning and end of the list.
        if bookmarksBarWidth +
            (BookmarksBarViewModel.Constants.buttonSpacing * 3) +
            clippedButtonWidth +
            clippedItemsIndicator.frame.width < view.bounds.width {
            let buttonToRestore = clippedButtons.removeFirst()
            buttonData.append(buttonToRestore)
            view.addSubview(buttonToRestore.button)
            
            calculateFixedButtonSizingValues()
            layoutButtons()
        }
    }
    
    private func removeLastButton() {
        guard let lastButton = buttonData.popLast() else {
            return
        }
        
        print("Popped button: \(lastButton.button.title)")

        lastButton.button.removeFromSuperview()
        clippedButtons.insert(lastButton, at: 0)
        
        calculateFixedButtonSizingValues()
        layoutButtons()
    }
    
    private func calculateFixedButtonSizingValues() {
        print(#function)
        let cumulativeButtonWidth = buttonData.map(\.button.bounds.size.width).reduce(0, +)
        let cumulativeSpacingWidth = BookmarksBarViewModel.Constants.buttonSpacing * CGFloat(max(0, buttonData.count - 1))
        bookmarksBarWidth = cumulativeButtonWidth + cumulativeSpacingWidth
        bookmarksBarViewFrameChanged()
    }

    private func layoutButtons() {
        self.midpoints = updateFrames(for: buttonData.map(\.button),
                                      containerFrame: view.frame,
                                      hasClippedButtons: hasClippedButtons,
                                      draggedItemMetadata: nil,
                                      animated: false)
        
        var clippedItemsIndicatorFrame = clippedItemsIndicator.frame
        clippedItemsIndicatorFrame.origin.y = view.frame.midY - (clippedItemsIndicatorFrame.height / 2)
        clippedItemsIndicatorFrame.origin.x = view.bounds.width - clippedItemsIndicatorFrame.width - BookmarksBarViewModel.Constants.buttonSpacing
        clippedItemsIndicator.frame = clippedItemsIndicatorFrame
    }

    /// Sets frames on the button array passed in. This function modifies their origins to flow from leading to trailing, with spacing values separating them.
    /// If `draggedItemMetadata` is provided, a space will be created between the buttons on either side of the drop index.
    ///
    /// This function assumes that the buttons have already been sized, and will only update their origin.
    private func updateFrames(for buttons: [NSButton],
                              containerFrame: CGRect,
                              hasClippedButtons: Bool,
                              draggedItemMetadata: DraggedItemLayoutData?,
                              animated: Bool) -> [CGFloat] {
        let visibleButtons = buttons.filter { button in
            return !button.isHidden
        }
        
        let (frames, midpoints) = calculateUpdatedFrames(buttons: visibleButtons,
                                                         within: containerFrame,
                                                         forceLeftAlignedButtons: hasClippedButtons,
                                                         draggedItemMetadata: draggedItemMetadata)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated ? 0.35 : 0.0

            for (index, button) in visibleButtons.enumerated() {
                button.animator().frame = frames[index]
            }
        }
        
        return midpoints
    }
    
    private func calculateUpdatedFrames(buttons: [NSButton],
                                        within containerFrame: CGRect,
                                        forceLeftAlignedButtons: Bool,
                                        draggedItemMetadata: DraggedItemLayoutData?) -> (buttonFrames: [CGRect], midpoints: [CGFloat]) {
        var updatedFrames: [CGRect] = []
        var midpoints: [CGFloat] = []
        var previousMaximumXValue: CGFloat
        
        if forceLeftAlignedButtons {
            previousMaximumXValue = BookmarksBarViewModel.Constants.buttonSpacing
        } else {
            previousMaximumXValue = max(BookmarksBarViewModel.Constants.buttonSpacing, (containerFrame.midX - (bookmarksBarWidth / 2)))
        }

        for (index, button) in buttons.enumerated() {
            var updatedButtonFrame = button.frame
            
            if let metadata = draggedItemMetadata, metadata.dropIndex == index {
                let newOffset = previousMaximumXValue + metadata.proposedItemWidth
                updatedButtonFrame.origin = CGPoint(x: newOffset, y: containerFrame.midY - (button.frame.height / 2))
            } else {
                updatedButtonFrame.origin = CGPoint(x: previousMaximumXValue, y: containerFrame.midY - (button.frame.height / 2))
            }
            
            updatedFrames.append(updatedButtonFrame)
            
            previousMaximumXValue = updatedButtonFrame.maxX + BookmarksBarViewModel.Constants.buttonSpacing
            
            if midpoints.isEmpty {
                midpoints.append(updatedButtonFrame.minX - (BookmarksBarViewModel.Constants.buttonSpacing / 2))
            }
            
            midpoints.append(updatedButtonFrame.maxX + (BookmarksBarViewModel.Constants.buttonSpacing / 2))
        }
        
        return (buttonFrames: updatedFrames, midpoints: midpoints)
    }
    
    private func buttonIndex(for button: BookmarksBarButton) -> Int? {
        return buttonData.firstIndex { data in
            data.button == button
        }
    }
    
    // MARK: - Button Click Handlers

    @objc
    private func bookmarkButtonClicked(_ sender: NSButton) {
        guard let event = NSApp.currentEvent, let sender = sender as? BookmarksBarButton, let index = buttonIndex(for: sender) else {
            return
        }
        
        switch event.type {
        case .leftMouseDragged:
            viewModel.handle(event: .mouseDragged(buttonIndex: index, location: event.locationInWindow))
            
            if let initialDraggingLocation = initialDraggingPoint {
                let distance = initialDraggingLocation.distance(to: event.locationInWindow)
                if distance <= BookmarksBarViewModel.Constants.distanceRequiredForDragging {
                    os_log("Received leftMouseDragged event, but haven't dragged far enough", log: .bookmarks, type: .info)
                    
                    return
                }
            } else {
                initialDraggingPoint = event.locationInWindow
                os_log("Received leftMouseDragged event, setting initial drag location", log: .bookmarks, type: .info)
                return
            }
            
            os_log("Received leftMouseDragged event, starting drag session", log: .bookmarks, type: .info)

//            let draggedEntity = self.buttonData[index].bookmarkViewModel.entity
//            let draggedItemData = BookmarksBarViewModel.ExistingDraggedItemData(originalIndex: index, title: draggedEntity.title)

            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setDataProvider(viewModel, forTypes: [.URL, .string])
            
            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            draggingItem.setDraggingFrame(sender.frame, contents: sender.imageRepresentation()!)
            
            draggedItemOriginalIndex = index
            sender.isHidden = true
            
            self.viewModel.isDragging = true
            self.view.beginDraggingSession(with: [draggingItem], event: event, source: viewModel)
        case .leftMouseUp:
            initialDraggingPoint = nil

            guard let index = buttonIndex(for: sender) else {
                return
            }
            
            guard let entity = bookmarkManager.list?.topLevelEntities[index] else {
                return
            }
            
            if let bookmark = entity as? Bookmark {
                os_log("Received leftMouseUp event, loading bookmark", log: .bookmarks, type: .info)
                print("isDragging = \(self.viewModel.isDragging)")
                WindowControllersManager.shared.show(url: bookmark.url, newTab: false)
            } else if let folder = entity as? BookmarkFolder {
                os_log("Received leftMouseUp event, showing folder contents", log: .bookmarks, type: .info)
                let menu = NSMenu(title: folder.title)
                let childViewModels = folder.children.map(BookmarkViewModel.init)
                let childMenuItems = bookmarkMenuItems(from: childViewModels, topLevel: false)
                menu.items = childMenuItems
                
                let location = NSPoint(x: 0, y: sender.frame.height + 5) // Magic number to adjust the height.
                menu.popUp(positioning: nil, at: location, in: sender)
            }
        default:
            break
        }
    }
    
    @objc
    private func clippedItemsIndicatorClicked(_ sender: NSButton) {
        let menu = NSMenu()
        let location = NSPoint(x: 0, y: sender.frame.height + 5) // Magic number to adjust the height.

        menu.items = clippedButtons.map { NSMenuItem(bookmarkViewModel: $0.bookmarkViewModel) }
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

    func updateNearestDragIndex(_ newDragIndex: Int?, additionalWidth: CGFloat) {
        guard let newDragIndex = newDragIndex else {
            os_log("Updating drag index: index = nil, width = %f", log: .bookmarks, type: .info, additionalWidth)
            
            self.dropIndex = nil
            self.midpoints = updateFrames(for: self.buttonData.map(\.button),
                                          containerFrame: view.frame,
                                          hasClippedButtons: hasClippedButtons,
                                          draggedItemMetadata: nil,
                                          animated: true)
            return
        }
        
        if let currentNearest = dropIndex, newDragIndex != dropIndex {
            os_log("Updating drag index with new index: index = %d, width = %f", log: .bookmarks, type: .info, newDragIndex, additionalWidth)

            dropIndex = newDragIndex
            let metadata = DraggedItemLayoutData(dropIndex: newDragIndex, proposedItemWidth: additionalWidth)
            self.midpoints = updateFrames(for: self.buttonData.map(\.button),
                                          containerFrame: view.frame,
                                          hasClippedButtons: hasClippedButtons,
                                          draggedItemMetadata: metadata,
                                          animated: true)
        } else if dropIndex == nil {
            os_log("Updating drag index with initial index: index = %d, width = %f", log: .bookmarks, type: .info, newDragIndex, additionalWidth)
            
            dropIndex = newDragIndex
            let metadata = DraggedItemLayoutData(dropIndex: newDragIndex, proposedItemWidth: additionalWidth)
            self.midpoints = updateFrames(for: self.buttonData.map(\.button),
                                          containerFrame: view.frame,
                                          hasClippedButtons: hasClippedButtons,
                                          draggedItemMetadata: metadata,
                                          animated: true)
        }
    }
    
}

// MARK: - BookmarksBarViewDelegate

extension BookmarksBarViewController: BookmarksBarViewDelegate {

    func draggingEntered(draggingInfo: NSDraggingInfo) {
        os_log("Dragging entered", log: .bookmarks, type: .info)
        let (index, width) = calculateNearestDragIndex(draggingInfo: draggingInfo)
        updateNearestDragIndex(index, additionalWidth: width)
    }
    
    func draggingExited(draggingInfo: NSDraggingInfo?) {
        os_log("Dragging exited", log: .bookmarks, type: .info)
        updateNearestDragIndex(nil, additionalWidth: 0)
    }
    
    func draggingUpdated(draggingInfo: NSDraggingInfo) {
        let (index, width) = calculateNearestDragIndex(draggingInfo: draggingInfo)
        updateNearestDragIndex(index, additionalWidth: width)
    }
    
    private func calculateNearestDragIndex(draggingInfo: NSDraggingInfo) -> (index: Int, draggedItemWidth: CGFloat) {
        let convertedDraggingLocation = view.convert(draggingInfo.draggingLocation, from: nil)
        let horizontalOffset = convertedDraggingLocation.x
        let result = midpoints.nearest(to: horizontalOffset)
        let additionalWidth: CGFloat
        
        if draggingInfo.draggingSource is BookmarksBarViewModel, let width = draggingInfo.width {
            additionalWidth = width + BookmarksBarViewModel.Constants.buttonSpacing
        } else if draggingInfo.draggingSource is BookmarksBarViewModel, let index = draggedItemOriginalIndex {
            let entityTitle = self.buttonData[index].bookmarkViewModel.entity.title
            let renderingWidth = entityTitle.renderingWidth(with: BookmarksBarViewModel.Constants.labelFont)
            let titleWidth = min(BookmarksBarViewModel.Constants.maximumButtonWidth, renderingWidth + 16 + 10)
            
            additionalWidth = titleWidth + BookmarksBarViewModel.Constants.buttonSpacing
        } else {
            if let item = draggingInfo.draggingPasteboard.pasteboardItems?.first, let title = titleAndURL(from: item) {
                additionalWidth = min(
                    BookmarksBarViewModel.Constants.maximumButtonWidth,
                    title.0.renderingWidth(with: BookmarksBarViewModel.Constants.labelFont) + 16 + 10
                )
            } else {
                additionalWidth = draggingInfo.width ?? 0
            }
        }
        
        return (result?.offset ?? 0, additionalWidth)
    }
    
    func draggingEnded(draggingInfo: NSDraggingInfo) {
        os_log("Dragging ended", log: .bookmarks, type: .info)        
        viewModel.handle(event: .draggingEnded)
        
        for button in buttonData {
            button.button.isHidden = false
        }
        
        print("DEBUG \(Date()): LayoutButtons DraggingEnded")
        layoutButtons()
    }
    
    func performDragOperation(draggingInfo: NSDraggingInfo) -> Bool {
        os_log("Performing drag operation", log: .bookmarks, type: .info)
        initialDraggingPoint = nil

        guard let newIndex = dropIndex else {
            os_log("Dragging ended without a drop index, returning", log: .bookmarks, type: .info)
            return false
        }
        
        if let index = draggedItemOriginalIndex, let draggedItemUUID = self.bookmarkManager.list?.topLevelEntities[index].id {
            os_log("Dragging ended with drop index = %d, moving existing bookmark", log: .bookmarks, type: .info, newIndex)
            
            self.buttonData.move(fromOffsets: IndexSet(integer: index), toOffset: newIndex)
            print("DEBUG \(Date()): PerformDragOperation")
            self.layoutButtons()
            
            bookmarkManager.move(objectUUID: draggedItemUUID, toIndexWithinParentFolder: newIndex) { _ in
                self.dropIndex = nil
                self.draggedItemOriginalIndex = nil
            }
        } else if let draggedItems = draggingInfo.draggingPasteboard.pasteboardItems {
            os_log("Dragging ended with drop index = %d, saving new bookmark", log: .bookmarks, type: .info, newIndex)
            
            for draggedItem in draggedItems {
                if let (title, url) = titleAndURL(from: draggedItem) {
                    bookmarkManager.makeBookmark(for: url, title: title, isFavorite: false, index: newIndex)
                }
            }

            self.dropIndex = nil
            self.draggedItemOriginalIndex = nil
            print("DEBUG \(Date()): PerformDragOperation")
            self.layoutButtons()
        }
        
        return true
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
