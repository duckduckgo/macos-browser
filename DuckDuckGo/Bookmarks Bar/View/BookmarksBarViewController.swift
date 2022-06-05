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

final class BookmarksBarViewController: NSViewController {
    
    private enum Constants {
        static let distanceRequiredForDragging: CGFloat = 10
        static let buttonSpacing: CGFloat = 8
        static let buttonHeight: CGFloat = 28
        static let maximumButtonWidth: CGFloat = 150
    }
    
    private struct ButtonLayoutMetadata {
        var cumulativeButtonWidth: CGFloat = 0
        var cumulativeSpacingWidth: CGFloat = 0
        var totalButtonListWidth: CGFloat = 0
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
    
    private var buttons: [BookmarkButtonData] = []

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
        return view.frame.width - (clippedItemsIndicator.frame.midX - Constants.buttonSpacing)
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

        self.view.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(bookmarksBarViewFrameChanged),
                                               name: NSView.frameDidChangeNotification,
                                               object: self.view)
        
        configureDragAndDrop()
        subscribeToBookmarks()

        self.buttons = createButtons(for: bookmarkManager.list?.topLevelEntities ?? [])
        addAndPositionButtonsForInitialLayout()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        layoutButtons()
        calculateFixedButtonSizingValues()
        bookmarksBarViewFrameChanged()
    }
    
    func subscribeToBookmarks() {
        bookmarkManager.listPublisher.sink { [weak self] list in
            guard let self = self else { return }
            self.buttons = self.createButtons(for: list?.topLevelEntities ?? [])
            self.addAndPositionButtonsForInitialLayout()
            self.layoutButtons()
        }.store(in: &cancellables)
    }
    
    @objc
    private func bookmarksBarViewFrameChanged() {
        layoutButtons()

        if view.frame.size.width <= (layoutMetadata.totalButtonListWidth + (Constants.buttonSpacing * 2) + clippedItemsIndicator.frame.size.width) {
            removeLastButton()
        } else {
            tryToRestoreClippedButton()
        }
    }
    
    private func addAndPositionButtonsForInitialLayout() {
        for view in view.subviews where view is NSButton {
            view.removeFromSuperview()
        }

        self.buttons.map(\.button).forEach(view.addSubview)
        
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
        if layoutMetadata.totalButtonListWidth +
            (Constants.buttonSpacing * 3) +
            clippedButtonWidth +
            clippedItemsIndicator.frame.width < view.bounds.width {
            let buttonToRestore = clippedButtons.removeFirst()
            buttons.append(buttonToRestore)
            view.addSubview(buttonToRestore.button)
            
            calculateFixedButtonSizingValues()
            layoutButtons()
        }
    }
    
    private func removeLastButton() {
        guard let lastButton = buttons.popLast() else {
            return
        }

        lastButton.button.removeFromSuperview()
        clippedButtons.insert(lastButton, at: 0)
        
        calculateFixedButtonSizingValues()
        layoutButtons()
    }
    
    private func calculateFixedButtonSizingValues() {
        layoutMetadata.cumulativeButtonWidth = buttons.map(\.button.bounds.size.width).reduce(0, +)
        layoutMetadata.cumulativeSpacingWidth = Constants.buttonSpacing * CGFloat(max(0, buttons.count - 1))
        layoutMetadata.totalButtonListWidth = layoutMetadata.cumulativeButtonWidth + layoutMetadata.cumulativeSpacingWidth
        
        bookmarksBarViewFrameChanged()
    }

    private func layoutButtons() {
        self.midpoints = updateFrames(for: buttons.map(\.button),
                                      containerFrame: view.frame,
                                      hasClippedButtons: hasClippedButtons,
                                      draggedItemMetadata: nil)
        
        var clippedItemsIndicatorFrame = clippedItemsIndicator.frame
        clippedItemsIndicatorFrame.origin.y = view.frame.midY - (clippedItemsIndicatorFrame.height / 2)
        clippedItemsIndicatorFrame.origin.x = view.bounds.width - clippedItemsIndicatorFrame.width - Constants.buttonSpacing
        clippedItemsIndicator.frame = clippedItemsIndicatorFrame
    }

    /// Sets frames on the button array passed in. This function modifies their origins to flow from leading to trailing, with spacing values separating them.
    /// If `draggedItemMetadata` is provided, a space will be created between the buttons on either side of the drop index.
    ///
    /// This function assumes that the buttons have already been sized, and will only update their origin.
    private func updateFrames(for buttons: [NSButton],
                              containerFrame: CGRect,
                              hasClippedButtons: Bool,
                              draggedItemMetadata: DraggedItemMetadata?) -> [CGFloat] {
        var midpoints: [CGFloat] = []
        var previousMaximumXValue: CGFloat
        
        // If there are any clipped buttons, the button list should always be leading-aligned.
        if hasClippedButtons {
            previousMaximumXValue = Constants.buttonSpacing
        } else {
            previousMaximumXValue = max(Constants.buttonSpacing, (containerFrame.midX) - (layoutMetadata.totalButtonListWidth / 2))
        }
        
        let visibleButtons = buttons.filter { button in
            return !button.isHidden
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = (draggedItemMetadata == nil) ? 0.0 : 0.5

            for (index, button) in visibleButtons.enumerated() {
                var updatedButtonFrame = button.frame
                
                if let metadata = draggedItemMetadata, metadata.dropIndex == index {
                    let newOffset = previousMaximumXValue + metadata.proposedItemWidth
                    updatedButtonFrame.origin = CGPoint(x: newOffset, y: containerFrame.midY - (button.frame.height / 2))
                } else {
                    updatedButtonFrame.origin = CGPoint(x: previousMaximumXValue, y: containerFrame.midY - (button.frame.height / 2))
                }
                
                button.animator().frame = updatedButtonFrame
                
                previousMaximumXValue = updatedButtonFrame.maxX + Constants.buttonSpacing
                
                if midpoints.isEmpty {
                    midpoints.append(updatedButtonFrame.minX - (Constants.buttonSpacing / 2))
                }
                
                midpoints.append(updatedButtonFrame.maxX + (Constants.buttonSpacing / 2))
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
        button.layerContentsRedrawPolicy = .onSetNeedsDisplay
        button.isBordered = false
        button.title = title
        button.target = self
        button.sendAction(on: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .rightMouseDown])
        button.action = #selector(bookmarkButtonClicked(_:))
        button.sizeToFit()
        
        var buttonFrame = button.frame
        buttonFrame.size.width = min(Constants.maximumButtonWidth, buttonFrame.size.width)
        button.frame = buttonFrame
        
        button.lineBreakMode = .byTruncatingMiddle
    }
    
    private func buttonIndex(for button: BookmarksBarButton) -> Int? {
        return buttons.firstIndex { data in
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
        case .leftMouseDown:
            break // Do nothing here?
        case .leftMouseDragged:
            if let initialDraggingLocation = initialDraggingLocation {
                if CGPointDistance(from: initialDraggingLocation, to: event.locationInWindow) <= Constants.distanceRequiredForDragging {
                    return
                }
            } else {
                initialDraggingLocation = event.locationInWindow
                return
            }

            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setDataProvider(viewModel, forTypes: [.URL, .string])
            
            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            draggingItem.setDraggingFrame(sender.frame, contents: sender.imageRepresentation()!)
            
            draggedItemOriginalIndex = index
            sender.isHidden = true
            self.view.beginDraggingSession(with: [draggingItem], event: event, source: sender)
        case .leftMouseUp:
            if initialDraggingLocation != nil {
                // We just ended a drag operation, don't proceed with left click logic.
                initialDraggingLocation = nil
                return
            }

            guard let index = buttonIndex(for: sender) else {
                return
            }
            
            guard let entity = bookmarkManager.list?.topLevelEntities[index] else {
                return
            }
            
            if let bookmark = entity as? Bookmark {
                WindowControllersManager.shared.show(url: bookmark.url, newTab: false)
            } else if let folder = entity as? BookmarkFolder {
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
    private var initialDraggingLocation: CGPoint?

    func updateNearestDragIndex(_ newDragIndex: Int?, additionalWidth: CGFloat) {
        guard let newDragIndex = newDragIndex else {
            print("DEBUG: Updating drag index with nil index, width \(additionalWidth)")
            self.midpoints = updateFrames(for: self.buttons.map(\.button),
                                          containerFrame: view.frame,
                                          hasClippedButtons: hasClippedButtons,
                                          draggedItemMetadata: nil)
            return
        }
        
        if let currentNearest = dropIndex, newDragIndex != dropIndex {
            print("DEBUG: Setting new drag index \(newDragIndex), width \(additionalWidth)")
            dropIndex = newDragIndex
            let metadata = DraggedItemMetadata(dropIndex: newDragIndex, proposedItemWidth: additionalWidth)
            self.midpoints = updateFrames(for: self.buttons.map(\.button),
                                          containerFrame: view.frame,
                                          hasClippedButtons: hasClippedButtons,
                                          draggedItemMetadata: metadata)
        } else if dropIndex == nil {
            print("DEBUG: Setting initial drag index \(newDragIndex), width \(additionalWidth)")
            dropIndex = newDragIndex
            let metadata = DraggedItemMetadata(dropIndex: newDragIndex, proposedItemWidth: additionalWidth)
            self.midpoints = updateFrames(for: self.buttons.map(\.button),
                                          containerFrame: view.frame,
                                          hasClippedButtons: hasClippedButtons,
                                          draggedItemMetadata: metadata)
        }
    }
    
}

extension BookmarksBarViewController {
    
    func configureDragAndDrop() {
        view.registerForDraggedTypes([.fileURL, .URL])
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
        let convertedDraggingLocation = view.convert(draggingInfo.draggingLocation, from: nil)
        let horizontalOffset = convertedDraggingLocation.x
        
        let result = midpoints.nearest(to: horizontalOffset)
        
        if let width = draggingInfo.width {
            let additionalWidth = width + Constants.buttonSpacing
            updateNearestDragIndex(result?.offset, additionalWidth: additionalWidth)
        }
    }
    
    func draggingExited(draggingInfo: NSDraggingInfo?) {
        updateNearestDragIndex(nil, additionalWidth: 0)
    }
    
    func draggingUpdated(draggingInfo: NSDraggingInfo) {
        let convertedDraggingLocation = view.convert(draggingInfo.draggingLocation, from: nil)
        let horizontalOffset = convertedDraggingLocation.x
        
        let result = midpoints.nearest(to: horizontalOffset)
        
        if let width = draggingInfo.width {
            let additionalWidth = width + Constants.buttonSpacing
            updateNearestDragIndex(result?.offset, additionalWidth: additionalWidth)
        }
    }
    
    func draggingEnded(draggingInfo: NSDraggingInfo) {
        guard let index = draggedItemOriginalIndex,
              let newIndex = dropIndex else {
            return
        }
        
        if let draggedItemUUID = self.bookmarkManager.list?.topLevelEntities[index].id {
            bookmarkManager.move(objectUUID: draggedItemUUID, toIndexWithinParentFolder: newIndex) { _ in
                self.dropIndex = nil
                self.draggedItemOriginalIndex = nil
                self.layoutButtons()
            }
        } else if let draggedURLs = draggingInfo.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [NSURL] {
            for draggedURL in draggedURLs {
                let bookmark = Bookmark(id: UUID(), url: draggedURL as URL, title: (draggedURL as URL).absoluteString, isFavorite: false)
                bookmarkManager.add(bookmark: bookmark, to: nil) { _ in }
            }

            self.dropIndex = nil
            self.draggedItemOriginalIndex = nil
            self.layoutButtons()
        }
    }
    
}

func CGPointDistance(from: CGPoint, to: CGPoint) -> CGFloat {
    let distanceSquared = (from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)
    return sqrt(distanceSquared)
}
