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
    
    private struct ButtonLayoutMetadata {
        var cumulativeButtonWidth: CGFloat = 0
        var cumulativeSpacingWidth: CGFloat = 0
        var bookmarksBarWidth: CGFloat = 0
    }
    
    private struct DraggedItemMetadata {
        let dropIndex: Int
        let proposedItemWidth: CGFloat
    }
    
    private struct BookmarkButtonData {
        let button: BookmarksBarButton
        let bookmarkViewModel: BookmarkViewModel
    }
    
    private let bookmarkManager = LocalBookmarkManager.shared
    private let viewModel = BookmarksBarViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    private var buttonData: [BookmarkButtonData] = []

    private var midpoints: [CGFloat] = []
    private var clippedButtons: [BookmarkButtonData] = [] {
        didSet {
            clippedItemsIndicator.isHidden = clippedButtons.isEmpty
        }
    }
    
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
    
    private var layoutMetadata = ButtonLayoutMetadata()
    
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
                                               selector: #selector(bookmarksBarViewFrameChanged),
                                               name: NSView.frameDidChangeNotification,
                                               object: view)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshFavicons),
                                               name: .faviconCacheUpdated,
                                               object: nil)
        
        // subscribeToViewModelState()
        subscribeToBookmarks()

        self.buttonData = createButtons(for: bookmarkManager.list?.topLevelEntities ?? [])
        addAndPositionButtonsForInitialLayout()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        layoutButtons()
        calculateFixedButtonSizingValues()
        bookmarksBarViewFrameChanged()
    }
    
//    private func subscribeToViewModelState() {
//        viewModel.$state.sink { [weak self] state in
//            guard let self = self else { return }
//
//            switch state {
//            case .idle:
//                print("Idle")
//            case .beginningDrag(originalLocation: let originalLocation):
//                print("Beginning drag")
//            case .draggingExistingItem(draggedItemData: let draggedItemData):
//                print("Dragging existing")
//            case .draggingNewItem(draggedItemData: let draggedItemData):
//                print("Dragging new")
//            }
//        }.store(in: &cancellables)
//    }

    private func subscribeToBookmarks() {
        bookmarkManager.listPublisher.sink { [weak self] list in
            guard let self = self else { return }
            self.buttonData = self.createButtons(for: list?.topLevelEntities ?? [])
            self.addAndPositionButtonsForInitialLayout()
            self.layoutButtons()
        }.store(in: &cancellables)
    }
    
    @objc
    private func bookmarksBarViewFrameChanged() {
        layoutButtons()

        let maximumWidth = layoutMetadata.bookmarksBarWidth + (BookmarksBarViewModel.Constants.buttonSpacing * 2) + clippedItemsIndicator.frame.width
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
        for view in view.subviews where view is NSButton {
            view.removeFromSuperview()
        }

        self.buttonData.map(\.button).forEach(view.addSubview)
        
        addClippedItemsIndicator()
        calculateFixedButtonSizingValues()
    }
    
    private func addClippedItemsIndicator() {
        clippedItemsIndicator.target = self
        clippedItemsIndicator.action = #selector(clippedItemsIndicatorClicked(_:))
        
        view.addSubview(clippedItemsIndicator)
    }
    
    private func tryToRestoreClippedButton() {
        guard let firstClippedButton = clippedButtons.first else {
            return
        }

        // Check if the next clipped button to restore can fit, and add it if so:
        
        let clippedButtonWidth = firstClippedButton.button.bounds.width
        
        // Button spacing * 3: Once for the padding between the last button and the new one,
        // and two to account for the spacing at the beginning and end of the list.
        if layoutMetadata.bookmarksBarWidth +
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

        lastButton.button.removeFromSuperview()
        clippedButtons.insert(lastButton, at: 0)
        
        calculateFixedButtonSizingValues()
        layoutButtons()
    }
    
    private func calculateFixedButtonSizingValues() {
        layoutMetadata.cumulativeButtonWidth = buttonData.map(\.button.bounds.size.width).reduce(0, +)
        layoutMetadata.cumulativeSpacingWidth = BookmarksBarViewModel.Constants.buttonSpacing * CGFloat(max(0, buttonData.count - 1))
        layoutMetadata.bookmarksBarWidth = layoutMetadata.cumulativeButtonWidth + layoutMetadata.cumulativeSpacingWidth
        
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
                              draggedItemMetadata: DraggedItemMetadata?,
                              animated: Bool) -> [CGFloat] {
        var midpoints: [CGFloat] = []
        var previousMaximumXValue: CGFloat
        
        // If there are any clipped buttons, the button list should always be leading-aligned.
        if hasClippedButtons {
            previousMaximumXValue = BookmarksBarViewModel.Constants.buttonSpacing
        } else {
            previousMaximumXValue = max(BookmarksBarViewModel.Constants.buttonSpacing, (containerFrame.midX) - (layoutMetadata.bookmarksBarWidth / 2))
        }
        
        let visibleButtons = buttons.filter { button in
            return !button.isHidden
        }
        
        os_log("Updating button frames, animated = %s", log: .bookmarks, type: .info, animated ? "yes" : "no")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated ? 0.35 : 0.0

            for (index, button) in visibleButtons.enumerated() {
                var updatedButtonFrame = button.frame
                
                if let metadata = draggedItemMetadata, metadata.dropIndex == index {
                    let newOffset = previousMaximumXValue + metadata.proposedItemWidth
                    updatedButtonFrame.origin = CGPoint(x: newOffset, y: containerFrame.midY - (button.frame.height / 2))
                } else {
                    updatedButtonFrame.origin = CGPoint(x: previousMaximumXValue, y: containerFrame.midY - (button.frame.height / 2))
                }
                
                button.animator().frame = updatedButtonFrame
                
                previousMaximumXValue = updatedButtonFrame.maxX + BookmarksBarViewModel.Constants.buttonSpacing
                
                if midpoints.isEmpty {
                    midpoints.append(updatedButtonFrame.minX - (BookmarksBarViewModel.Constants.buttonSpacing / 2))
                }
                
                midpoints.append(updatedButtonFrame.maxX + (BookmarksBarViewModel.Constants.buttonSpacing / 2))
            }
        }
        
        return midpoints
    }
    
    private func createButtons(for entities: [BaseBookmarkEntity]) -> [BookmarkButtonData] {
        return entities.compactMap { entity in
            let viewModel = BookmarkViewModel(entity: entity)

            if let bookmark = entity as? Bookmark {
                let button = BookmarksBarButton(bookmark: bookmark)
                configureBookmarkButton(button: button, withTitle: bookmark.title)
                
                return BookmarkButtonData(button: button, bookmarkViewModel: viewModel)
            } else if let folder = entity as? BookmarkFolder {
                let button = BookmarksBarButton(folder: folder)
                configureBookmarkButton(button: button, withTitle: folder.title)
                
                return BookmarkButtonData(button: button, bookmarkViewModel: viewModel)
            } else {
                assertionFailure("Tried to display bookmarks bar button for unsupported type: \(entity)")
                return nil
            }
        }
    }
    
    private func configureBookmarkButton(button: BookmarksBarButton, withTitle title: String) {
        // button.layerContentsRedrawPolicy = .onSetNeedsDisplay
        button.isBordered = false
        button.title = title
        button.lineBreakMode = .byTruncatingMiddle
        button.target = self
        button.sendAction(on: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .rightMouseDown])
        button.action = #selector(bookmarkButtonClicked(_:))
        button.sizeToFit()
        
        var buttonFrame = button.frame
        buttonFrame.size.width = min(BookmarksBarViewModel.Constants.maximumButtonWidth, buttonFrame.size.width)
        button.frame = buttonFrame
    }
    
    private func buttonIndex(for button: BookmarksBarButton) -> Int? {
        return buttonData.firstIndex { data in
            data.button == button
        }
    }
    
    // MARK: - Button Click Handlers
    
    private var draggedItemOriginalIndex: Int?

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
    
    private var dropIndex: Int?
    private var initialDraggingPoint: CGPoint?

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
            let metadata = DraggedItemMetadata(dropIndex: newDragIndex, proposedItemWidth: additionalWidth)
            self.midpoints = updateFrames(for: self.buttonData.map(\.button),
                                          containerFrame: view.frame,
                                          hasClippedButtons: hasClippedButtons,
                                          draggedItemMetadata: metadata,
                                          animated: true)
        } else if dropIndex == nil {
            os_log("Updating drag index with initial index: index = %d, width = %f", log: .bookmarks, type: .info, newDragIndex, additionalWidth)
            
            dropIndex = newDragIndex
            let metadata = DraggedItemMetadata(dropIndex: newDragIndex, proposedItemWidth: additionalWidth)
            self.midpoints = updateFrames(for: self.buttonData.map(\.button),
                                          containerFrame: view.frame,
                                          hasClippedButtons: hasClippedButtons,
                                          draggedItemMetadata: metadata,
                                          animated: true)
        }
    }
    
}

extension NSEvent {
    
    var isRightClick: Bool {
        let rightClick = (self.type == .rightMouseUp)
        let controlClick = self.modifierFlags.contains(.control)
        return rightClick || controlClick
    }
    
}

extension BookmarksBarViewController: BookmarksBarViewDelegate {

    func draggingEntered(draggingInfo: NSDraggingInfo) {
        os_log("Dragging entered", log: .bookmarks, type: .info)
        
        let convertedDraggingLocation = view.convert(draggingInfo.draggingLocation, from: nil)
        let horizontalOffset = convertedDraggingLocation.x
        
        let result = midpoints.nearest(to: horizontalOffset)
        let additionalWidth: CGFloat
        
        if let width = draggingInfo.width {
            additionalWidth = min(width, BookmarksBarViewModel.Constants.maximumButtonWidth) + BookmarksBarViewModel.Constants.buttonSpacing
        } else {
            print("NO WIDTH!!!")
            additionalWidth = BookmarksBarViewModel.Constants.maximumButtonWidth + BookmarksBarViewModel.Constants.buttonSpacing
        }
        
        updateNearestDragIndex(result?.offset, additionalWidth: additionalWidth)
    }
    
    func draggingExited(draggingInfo: NSDraggingInfo?) {
        os_log("Dragging exited", log: .bookmarks, type: .info)
        updateNearestDragIndex(nil, additionalWidth: 0)
    }
    
    func draggingUpdated(draggingInfo: NSDraggingInfo) {
        let convertedDraggingLocation = view.convert(draggingInfo.draggingLocation, from: nil)
        let horizontalOffset = convertedDraggingLocation.x
        
        let result = midpoints.nearest(to: horizontalOffset)
        let additionalWidth: CGFloat
        
        // TODO: Calculate width
        if draggingInfo.draggingSource is BookmarksBarViewModel, let width = draggingInfo.width {
            additionalWidth = width + BookmarksBarViewModel.Constants.buttonSpacing
        } else {
            print("NO WIDTH!!!")
            additionalWidth = 100.0
        }
        
        updateNearestDragIndex(result?.offset, additionalWidth: additionalWidth)
    }
    
    func draggingEnded(draggingInfo: NSDraggingInfo) {
        os_log("Dragging ended", log: .bookmarks, type: .info)
        self.viewModel.isDragging = false
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
            self.layoutButtons()
        }
        
        return true
    }
    
    private func titleAndURL(from pasteboardItem: NSPasteboardItem) -> (String, URL)? {
        guard let urlString = pasteboardItem.string(forType: .URL), let url = URL(string: urlString) else {
            return nil
        }
        
        // WKWebView pasteboard items include the name of the link under the `public.url-name` type.
        let name = pasteboardItem.string(forType: NSPasteboard.PasteboardType(rawValue: "public.url-name"))
        return (name ?? urlString, url)
    }
    
}
