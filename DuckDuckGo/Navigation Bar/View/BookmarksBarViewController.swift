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
        static let buttonSpacing: CGFloat = 12
        static let buttonHeight: CGFloat = 28
        static let maximumButtonWidth: CGFloat = 150
    }
    
    private let bookmarkManager = LocalBookmarkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var buttons: [NSButton] = []
    private var clippedButtons: [NSButton] = [] {
        didSet {
            clippedItemsIndicator.isHidden = clippedButtons.isEmpty
        }
    }
    private var hasClippedButtons: Bool {
        !clippedButtons.isEmpty
    }
    
    private let clippedItemsIndicator: NSButton = {
        let indicator = NSButton(frame: .zero)
    
        indicator.image = NSImage(systemSymbolName: "chevron.forward.2", accessibilityDescription: nil)
        indicator.isBordered = false
        indicator.isHidden = true
        indicator.sizeToFit()
    
        return indicator
    }()
    
    private var clipThreshold: CGFloat {
        return view.frame.width - (clippedItemsIndicator.frame.midX - Constants.buttonSpacing)
    }
    
    // MARK: - Layout Calculation
    
    private var cumulativeButtonWidth: CGFloat = 0
    private var cumulativeSpacingWidth: CGFloat = 0
    private var totalButtonListWidth: CGFloat = 0
    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(frameChanged),
                                               name: NSView.frameDidChangeNotification,
                                               object: self.view)
        
        subscribeToBookmarks()

        self.buttons = createButtons(for: bookmarkManager.list?.topLevelEntities ?? [])
        positionButtonsForInitialLayout()
        layoutButtons()
    }
    
    func subscribeToBookmarks() {
        bookmarkManager.listPublisher.receive(on: RunLoop.main).sink { [weak self] list in
            guard let self = self else { return }
            self.buttons = self.createButtons(for: list?.topLevelEntities ?? [])
            self.positionButtonsForInitialLayout()
            self.layoutButtons()
        }.store(in: &cancellables)
    }
    
    @objc
    private func frameChanged() {
        if view.frame.size.width <= (totalButtonListWidth + (Constants.buttonSpacing * 2) + clippedItemsIndicator.frame.size.width) {
            removeLastButton()
        } else {
            tryToRestoreClippedButton()
        }
    }
    
    override func viewWillLayout() {
        super.viewWillLayout()
        layoutButtons()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
    }
    
    private func positionButtonsForInitialLayout() {
        for view in view.subviews where view is NSButton {
            view.removeFromSuperview()
        }

        for button in buttons {
            view.addSubview(button)
        }
        
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
        
        let clippedButtonWidth = firstClippedButton.bounds.width
        
        // Button spacing * 3: Once for the padding between the last button and the new one,
        // and two to account for the spacing at the beginning and end of the list.
        if totalButtonListWidth + (Constants.buttonSpacing * 3) + clippedButtonWidth + clippedItemsIndicator.frame.width < view.bounds.width {
            let buttonToRestore = clippedButtons.removeFirst()
            buttons.append(buttonToRestore)
            view.addSubview(buttonToRestore)
            
            calculateFixedButtonSizingValues()
            layoutButtons()
        }
    }
    
    private func removeLastButton() {
        guard let lastButton = buttons.popLast() else {
            return
        }

        lastButton.removeFromSuperview()
        clippedButtons.insert(lastButton, at: 0)
        
        calculateFixedButtonSizingValues()
        layoutButtons()
    }
    
    private func calculateFixedButtonSizingValues() {
        self.cumulativeButtonWidth = buttons.map(\.bounds.size.width).reduce(0, +)
        self.cumulativeSpacingWidth = Constants.buttonSpacing * CGFloat(max(0, buttons.count - 1))
        self.totalButtonListWidth = cumulativeButtonWidth + cumulativeSpacingWidth
    }

    private func layoutButtons() {
        var previousMaximumXValue: CGFloat
        
        // If there are any clipped buttons, the button list should always be leading-aligned.
        if hasClippedButtons {
            previousMaximumXValue = Constants.buttonSpacing
        } else {
            previousMaximumXValue = max(Constants.buttonSpacing, (view.bounds.midX) - (self.totalButtonListWidth / 2))
        }

        for button in buttons {
            var updatedButtonFrame = button.frame
            updatedButtonFrame.origin = CGPoint(x: previousMaximumXValue, y: view.frame.midY - (button.frame.height / 2))
            button.frame = updatedButtonFrame
            
            previousMaximumXValue = updatedButtonFrame.maxX + Constants.buttonSpacing
        }
        
        var clippedItemsIndicatorFrame = clippedItemsIndicator.frame
        clippedItemsIndicatorFrame.origin.y = view.frame.midY - (clippedItemsIndicatorFrame.height / 2)
        clippedItemsIndicatorFrame.origin.x = view.bounds.width - clippedItemsIndicatorFrame.width - Constants.buttonSpacing
        clippedItemsIndicator.frame = clippedItemsIndicatorFrame
    }
    
    private func createButtons(for entities: [BaseBookmarkEntity]) -> [NSButton] {
        return entities.compactMap { entity in
            if let bookmark = entity as? Bookmark {
                return bookmarkButton(titled: entity.title, url: bookmark.url)
            } else if let folder = entity as? BookmarkFolder {
                return folderButton(titled: folder.title)
            } else {
                assertionFailure("Tried to display bookmarks bar button for unsupported type: \(entity)")
                return nil
            }
        }
    }
    
    private func bookmarkButton(titled title: String, url: URL) -> NSButton {
        let button = BookmarksBarButton(frame: .zero)
        button.isBordered = false
        button.title = title
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        button.target = self
        button.action = #selector(bookmarkButtonClicked(_:))
        // button.image = FaviconManager.shared.getCachedFavicon(for: url, sizeCategory: .small)?.image
        // button.imageScaling = .scaleProportionallyDown
        // button.imagePosition = .imageLeading
        button.sizeToFit()
        
        var buttonFrame = button.frame
        buttonFrame.size.width = min(Constants.maximumButtonWidth, buttonFrame.size.width)
        button.frame = buttonFrame
        
        button.lineBreakMode = .byTruncatingMiddle

        return button
    }
    
    private func folderButton(titled title: String) -> NSButton {
        let button = BookmarksBarButton(frame: .zero)
        button.isBordered = false
        button.title = title
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        button.target = self
        button.action = #selector(bookmarkButtonClicked(_:))
//        button.image = NSImage(named: "Folder")
//        button.imagePosition = .imageLeading
        button.sizeToFit()
        
        var buttonFrame = button.frame
        buttonFrame.size.width = min(Constants.maximumButtonWidth, buttonFrame.size.width)
        button.frame = buttonFrame
        
        button.lineBreakMode = .byTruncatingTail

        return button
    }
    
    // MARK: - Button Click Handlers
    
    @objc
    private func bookmarkButtonClicked(_ sender: NSButton) {
        if let event = NSApp.currentEvent, event.isRightClick {
            print("Right click")
        } else {
            guard let index = buttons.firstIndex(of: sender) else {
                return
            }
            
            guard let entity = bookmarkManager.list?.topLevelEntities[index] else {
                return
            }
            
            if let bookmark = entity as? Bookmark {
                WindowControllersManager.shared.show(url: bookmark.url, newTab: false)
            } else if let folder = entity as? BookmarkFolder {
                let viewModel = BookmarkViewModel(entity: entity)
                
                let menu = NSMenu(title: folder.title)
                let childViewModels = folder.children.map(BookmarkViewModel.init)
                let childMenuItems = bookmarkMenuItems(from: childViewModels, topLevel: false)
                menu.items = childMenuItems
                
                let location = NSPoint(x: 0, y: sender.frame.height + 5) // Magic number to adjust the height.
                menu.popUp(positioning: nil, at: location, in: sender)
            }
        }
    }
    
    @objc
    private func bookmarkMenuItemClicked(_ sender: NSButton) {
        print("Left click")
    }
    
    @objc
    private func clippedItemsIndicatorClicked(_ sender: NSButton) {
        let menu = NSMenu()
        menu.items = clippedButtons.map {
            NSMenuItem(title: $0.title, action: #selector(bookmarkMenuItemClicked(_:)), target: self, keyEquivalent: "")
        }
        
        let location = NSPoint(x: 0, y: sender.frame.height + 5) // Magic number to adjust the height.
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

extension NSEvent {
    var isRightClick: Bool {
        let rightClick = (self.type == .rightMouseDown)
        let controlClick = self.modifierFlags.contains(.control)
        return rightClick || controlClick
    }
}
