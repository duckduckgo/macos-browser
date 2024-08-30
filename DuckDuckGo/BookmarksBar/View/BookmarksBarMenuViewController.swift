//
//  BookmarksBarMenuViewController.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Carbon
import Combine
import Foundation

protocol BookmarksBarMenuViewControllerDelegate: AnyObject {

    func closeBookmarksPopovers(_ sender: BookmarksBarMenuViewController)
    func popover(shouldPreventClosure: Bool)

    func openNextBookmarksMenu(_ sender: BookmarksBarMenuViewController)
    func openPreviousBookmarksMenu(_ sender: BookmarksBarMenuViewController)

}

final class BookmarksBarMenuViewController: NSViewController {

    fileprivate enum Constants {
        static let noContentMenuSize = CGSize(width: 8, height: 40)
        static let maxMenuPopoverContentWidth: CGFloat = 500 - 13 * 2
        static let minVisibleRows = 4
    }

    weak var delegate: BookmarksBarMenuViewControllerDelegate?

    private lazy var scrollView = SteppedScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 408),
                                                    stepSize: BookmarkOutlineCellView.rowHeight)
    private(set) lazy var outlineView = BookmarksOutlineView(frame: scrollView.frame)

    private var scrollDownButton: MouseOverButton!
    private var scrollUpButton: MouseOverButton!

    private let bookmarkManager: BookmarkManager
    private let treeControllerDataSource: BookmarkListTreeControllerDataSource

    private let treeController: BookmarkTreeController

    private var submenuPopover: BookmarksBarMenuPopover?
    private(set) var preferredContentOffset: CGPoint = .zero

    private var cancellables = Set<AnyCancellable>()

    private lazy var dataSource: BookmarkOutlineViewDataSource = {
        BookmarkOutlineViewDataSource(
            contentMode: .bookmarksMenu,
            bookmarkManager: bookmarkManager,
            treeController: treeController,
            sortMode: .manual,
            presentFaviconsFetcherOnboarding: { [weak self] in
                guard let self, let window = self.view.window else {
                    return
                }
                self.faviconsFetcherOnboarding?.presentOnboardingIfNeeded(in: window)
            }
        )
    }()

    private var selectedNodes: [BookmarkNode] {
        if let nodes = outlineView.selectedItems as? [BookmarkNode] {
            return nodes
        }
        return [BookmarkNode]()
    }

    private(set) lazy var faviconsFetcherOnboarding: FaviconsFetcherOnboarding? = {
        guard let syncService = NSApp.delegateTyped.syncService, let syncBookmarksAdapter = NSApp.delegateTyped.syncDataProviders?.bookmarksAdapter else {
            assertionFailure("SyncService and/or SyncBookmarksAdapter is nil")
            return nil
        }
        return .init(syncService: syncService, syncBookmarksAdapter: syncBookmarksAdapter)
    }()

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared, rootFolder: BookmarkFolder? = nil) {
        self.bookmarkManager = bookmarkManager
        self.treeControllerDataSource = BookmarkListTreeControllerDataSource(bookmarkManager: bookmarkManager)
        self.treeController = BookmarkTreeController(dataSource: treeControllerDataSource,
                                                     sortMode: .manual,
                                                     rootFolder: rootFolder,
                                                     isBookmarksBarMenu: true)

        super.init(nibName: nil, bundle: nil)
        self.representedObject = rootFolder
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    // MARK: View Lifecycle
    override func loadView() {
        view = NSView()
        view.autoresizesSubviews = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.usesPredominantAxisScrolling = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.borderType = .noBorder
        scrollView.scrollerInsets = NSEdgeInsetsZero
        scrollView.contentInsets = NSEdgeInsetsZero
        scrollView.hasVerticalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none

        let column = NSTableColumn()
        column.width = scrollView.frame.width - 32
        outlineView.addTableColumn(column)
        outlineView.translatesAutoresizingMaskIntoConstraints = true
        outlineView.autoresizesOutlineColumn = false
        outlineView.autoresizingMask = [.width, .height]
        outlineView.headerView = nil
        outlineView.allowsEmptySelection = false
        outlineView.allowsExpansionToolTips = true
        outlineView.allowsMultipleSelection = false
        outlineView.backgroundColor = .clear
        outlineView.usesAutomaticRowHeights = false
        outlineView.target = self
        outlineView.action = #selector(handleClick)
        outlineView.menu = BookmarksContextMenu(bookmarkManager: bookmarkManager, delegate: self)
        outlineView.dataSource = dataSource
        outlineView.delegate = dataSource
        outlineView.indentationPerLevel = 0

        let clipView = NSClipView(frame: scrollView.frame)
        clipView.translatesAutoresizingMaskIntoConstraints = true
        clipView.autoresizingMask = [.width, .height]
        clipView.documentView = outlineView
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        scrollUpButton = MouseOverButton(image: .condenseUp, target: nil, action: nil)
        scrollUpButton.translatesAutoresizingMaskIntoConstraints = false
        scrollUpButton.bezelStyle = .shadowlessSquare
        scrollUpButton.normalTintColor = .labelColor
        scrollUpButton.backgroundColor = .clear
        scrollUpButton.mouseOverColor = .blackWhite10
        scrollUpButton.delegate = self

        scrollDownButton = MouseOverButton(image: .expandDown, target: nil, action: nil)
        scrollDownButton.translatesAutoresizingMaskIntoConstraints = false
        scrollDownButton.bezelStyle = .shadowlessSquare
        scrollDownButton.normalTintColor = .labelColor
        scrollDownButton.backgroundColor = .clear
        scrollDownButton.mouseOverColor = .blackWhite10
        scrollDownButton.delegate = self

        view.addSubview(scrollView)
        scrollUpButton.map(view.addSubview)
        scrollDownButton.map(view.addSubview)

        setupLayout()
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                .priority(900),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor)
                .priority(900),
            scrollUpButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollUpButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollUpButton.topAnchor.constraint(equalTo: view.topAnchor),
            scrollUpButton.heightAnchor.constraint(equalToConstant: 16),

            scrollDownButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollDownButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollDownButton.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollDownButton.heightAnchor.constraint(equalToConstant: 16),

            scrollView.topAnchor.constraint(equalTo: scrollUpButton.bottomAnchor)
                .autoDeactivatedWhenViewIsHidden(scrollUpButton),
            scrollView.bottomAnchor.constraint(equalTo: scrollDownButton.topAnchor)
                .autoDeactivatedWhenViewIsHidden(scrollDownButton),
        ])
    }

    override func viewDidLoad() {
        outlineView.setDraggingSourceOperationMask([.move], forLocal: true)
        outlineView.registerForDraggedTypes(BookmarkDragDropManager.draggedTypes)
        // allow scroll buttons to scroll when dragging bookmark over
        scrollDownButton?.registerForDraggedTypes(BookmarkDragDropManager.draggedTypes)
        scrollUpButton?.registerForDraggedTypes(BookmarkDragDropManager.draggedTypes)
    }

    override func viewWillAppear() {
        subscribeToModelEvents()
    }

    override func viewWillDisappear() {
        cancellables = []
    }

    private func subscribeToModelEvents() {
        bookmarkManager.listPublisher
            .dropFirst() // reloadData will be called from adjustPreferredContentSize
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadData()
            }
            .store(in: &cancellables)

        subscribeToScrollingEvents()
        subscribeToMenuPopoverEvents()
        subscribeToDragDropEvents()
        // only subscribe to click outside events in root bookmarks menu
        // to close all the bookmarks menu popovers
        if !(view.window?.parent?.contentViewController is Self) {
            subscribeToClickOutsideEvents()
        }
    }

    private func subscribeToMenuPopoverEvents() {
        // show submenu for folder when dragging or hovering over it
        Publishers.Merge(
            // hover over bookmarks menu row
            outlineView.$highlightedRow.map { ($0, HighlightEvent.hover) },
            // dragging over folder
            dataSource.$dragDestinationFolder.map { [weak self] folder in
                guard let self, let folder,
                      let node = treeController.findNodeWithId(representing: folder),
                      let row = outlineView.rowIfValid(forItem: node) else {
                    return (nil, .dragging)
                }
                return (row, .dragging)
            }
        )
        .compactMap { [weak self] (row, event) in
            self?.delayedHighlightRowEventPublisher(forRow: row, on: event)
        }
        .switchToLatest()
        .filter { [weak dataSource, weak outlineView] (row, folder, event) in
            // following is valid only when dragging
            guard event == .dragging else {
                return outlineView?.highlightedRow == row
            }
            // don‘t hide subfolder menu or switch to another folder if
            // mouse cursor is outside of the view
            guard outlineView?.isMouseLocationInsideBounds() == true else { return false }
            if let folder {
                // only show submenu if cursor is still pointing to the folder
                return folder == dataSource?.dragDestinationFolder
            } else {
                // hide submenu if mouse cursor moved away from the folder
                return true
            }
        }
        .sink { [weak self] (row, folder, _) in
            self?.outlineViewDidHighlight(folder, atRow: row)
        }
        .store(in: &cancellables)
    }

    private enum HighlightEvent { case hover, dragging }
    /// Process Outline View row highlighing event on hover or drag over to expand or close a subfolder.
    /// Cances the highlight or adds a delay for the event delivery as appropriate
    /// - Returns:`BookmarkFolder?` (and row and the event kind) Publisher being currently highlighted
    ///           with delay added if needed.
    private func delayedHighlightRowEventPublisher(forRow row: Int?, on event: HighlightEvent) -> AnyPublisher<(Int?, BookmarkFolder?, HighlightEvent), Never>? {

        if let currentEvent = NSApp.currentEvent,
           currentEvent.type == .keyDown,
           currentEvent.keyCode == kVK_RightArrow {
            // don‘t expand the first highlighted folder in a submenu when it was
            // expanded using the Right arrow key
            return Empty().eraseToAnyPublisher()
        }

        let bookmarkNode = row.flatMap { outlineView.item(atRow: $0) } as? BookmarkNode
        let folder = bookmarkNode?.representedObject as? BookmarkFolder

        // prevent closing or opening another submenu when mouse is moving down+right
        let isMouseMovingDownRight: Bool = {
            if let currentEvent = NSApp.currentEvent,
               currentEvent.type == .mouseMoved,
               currentEvent.deltaY >= 0,
               currentEvent.deltaX >= currentEvent.deltaY {
                true
            } else {
                false
            }
        }()
        var delay: RunLoop.SchedulerTimeType.Stride
        // is moving down+right to a submenu?
        if event == .hover, isMouseMovingDownRight,
           let submenuPopover, submenuPopover.isShown,
           let expandedFolder = submenuPopover.rootFolder,
           let node = treeController.node(representing: expandedFolder),
           let expandedRow = outlineView.rowIfValid(forItem: node) {
            guard expandedRow != row else { return nil }

            // delay submenu hiding when cursor is moving right (to the menu)
            // over other elements that would normally hide the submenu
            delay = 0.3
            // restore the originally highlighted row for the expanded folder
            outlineView.highlightedRow = expandedRow

        } else if event == .dragging {
            // delay folder expanding when dragging over a subfolder
            delay = 0.2
        } else if folder != nil {
            // delay folder expanding when hovering over a subfolder
            delay = 0.1
        } else {
            // hide submenu instantly when mouse is moved away from folder
            // unless it‘s moving down+right as handled above.
            delay = 0
        }

        let valuePublisher = Just((row, folder, event))
        if delay > 0 {
            return valuePublisher
                .delay(for: delay, scheduler: RunLoop.main)
                .eraseToAnyPublisher()
        } else {
            return valuePublisher.eraseToAnyPublisher()
        }
    }

    private func subscribeToDragDropEvents() {
        // restore drag&drop target folder highlight on mouse out
        // when the submenu is shown
        enum DropRowEvent {
            case dropRow(Int?)
            case highlightedRow(Int?)
        }
        Publishers.Merge(
            dataSource.$targetRowForDropOperation.map(DropRowEvent.dropRow),
            outlineView.$highlightedRow.map(DropRowEvent.highlightedRow)
        )
        .sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .dropRow(let row):
                guard row == nil else { break }
                if let submenuPopover, submenuPopover.isShown,
                   let expandedFolder = submenuPopover.rootFolder,
                   let node = treeController.node(representing: expandedFolder),
                   let expandedRow = outlineView.rowIfValid(forItem: node),
                   expandedRow != outlineView.highlightedRow {
                    // restore expanded subfolder drop target row highlight
                    dataSource.targetRowForDropOperation = expandedRow
                }
            case .highlightedRow:
                // hide drop destination row highlight when drag operation ends
                if dataSource.targetRowForDropOperation != nil {
                    dataSource.targetRowForDropOperation = nil
                }
            }
        }
        .store(in: &cancellables)
    }

    private func subscribeToClickOutsideEvents() {
        Publishers.Merge(
            // close bookmarks menu when main menu is clicked
            NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification,
                                                 object: NSApp.mainMenu).asVoid(),
            // close bookmarks menu on click outside of the menu or its submenus
            NSEvent.publisher(forEvents: [.local, .global],
                              matching: [.leftMouseDown, .rightMouseDown])
            .filter { [weak self] event in
                if event.type == .leftMouseDown,
                   event.deviceIndependentFlags == .command,
                   event.window == nil {
                    // don‘t close on Cmd+click in other app
                    return false
                }
                guard let self,
                      // always close on global event
                      let eventWindow = event.window else { return true /* close */}
                // is showing submenu?
                if let popover = nextResponder as? BookmarksBarMenuPopover,
                   let positioningView = popover.positioningView,
                   positioningView.isMouseLocationInsideBounds(event.locationInWindow) {
                    // don‘t close when the button used to open the popover is
                    // clicked again, it‘ll be managed by
                    // BookmarksBarViewController.closeBookmarksPopovers
                    return false
                }
                // go up from the clicked window to figure out if the click is in a submenu
                for window in sequence(first: eventWindow, next: \.parent)
                where window === self.view.window {
                    // we found our window: the click was in the menu tree
                    return false // don‘t close
                }
                return true // close
            }.asVoid()
        )
        .sink { [weak self] _ in
            self?.delegate?.closeBookmarksPopovers(self!) // close
        }
        .store(in: &cancellables)
    }

    func reloadData(withRootFolder rootFolder: BookmarkFolder? = nil) {
        // Are we reusing the popover to present another bookmarks menu while current menu is still shown?
        // In this case `popover.isShown` would return `true` but we don‘t need to update the content size when
        // `reloadData` is called before showing another folder contents, because `adjustPreferredContentSize` will be used.
        let isChangingRootFolder = if let rootFolder, let currentFolder = representedObject as? BookmarkFolder {
            currentFolder.id != rootFolder.id
        } else {
            false
        }
        if let rootFolder {
            self.representedObject = rootFolder
        }
        // this weirdness is needed to load a new `BookmarkFolder` object on any modification
        // because `BookmarkManager.move(objectUUIDs:toIndex:withinParentFolder)` doesn‘t
        // actually move a `Bookmark` object into actual `BookmarkFolder` object
        // as well as updating a `Bookmark` doesn‘t modify it, instead
        // `BookmarkManager.loadBookmarks()` is called every time recreating the whole
        // bookmark hierarchy.
        var rootFolder = rootFolder
        if rootFolder == nil, let oldRootFolder = self.representedObject as? BookmarkFolder {
            if oldRootFolder.id == PseudoFolder.bookmarks.id {
                // reloadData for clipped Bookmarks will be triggered with updated rootFolder
                // from BookmarksBarViewController.bookmarksBarViewModelReloadedData
                return
            }
            rootFolder = bookmarkManager.getBookmarkFolder(withId: oldRootFolder.id)
        }

        dataSource.reloadData(with: BookmarksSortMode.manual,
                              withRootFolder: rootFolder ?? self.representedObject as? BookmarkFolder)
        let oldContentSize = outlineView.bounds.size
        outlineView.reloadData()

        if !isChangingRootFolder,
            let popover = nextResponder as? BookmarksBarMenuPopover, popover.isShown,
            let preferredEdge = popover.preferredEdge {

            updatePositionAndContentSize(oldContentSize: oldContentSize,
                                         popoverPositioningEdge: preferredEdge)
        }

        if outlineView.numberOfRows > 0 {
            updateHighlightedRowAfterReload(isChangingRootFolder: isChangingRootFolder)
        }
    }

    private func updateHighlightedRowAfterReload(isChangingRootFolder: Bool) {
        DispatchQueue.main.async { [outlineView, weak self] in
            if outlineView.isMouseLocationInsideBounds() {
                outlineView.updateHighlightedRowUnderCursor()
            } else if !isChangingRootFolder,
                      let submenuPopover = self?.submenuPopover,
                      submenuPopover.isShown,
                      let expandedFolder = submenuPopover.rootFolder,
                      let node = self?.treeController.findNodeWithId(representing: expandedFolder),
                      let expandedRow = outlineView.rowIfValid(forItem: node) {
                // restore current highlight on a expanded folder row
                outlineView.highlightedRow = expandedRow
            } else if !isChangingRootFolder,
                      let highlightedRow = outlineView.highlightedRow,
                      outlineView.numberOfRows > highlightedRow {
                // restore current highlight on a highlighted row
                outlineView.highlightedRow = highlightedRow
            }
        }
    }

    // MARK: Layout

    func adjustPreferredContentSize(positionedRelativeTo positioningRect: NSRect,
                                    of positioningView: NSView,
                                    at preferredEdge: NSRectEdge) {
        _=view // loadViewIfNeeded()

        guard let mainWindow = positioningView.window,
              let screenFrame = mainWindow.screen?.visibleFrame else { return }

        self.reloadData(withRootFolder: representedObject as? BookmarkFolder)
        outlineView.highlightedRow = nil
        scrollView.contentView.bounds.origin = .zero // scroll to top

        guard outlineView.numberOfRows > 0 else {
            preferredContentSize = Constants.noContentMenuSize
            preferredContentOffset.y = 0
            return
        }

        // popover borders
        let contentInsets = BookmarksBarMenuPopover.popoverInsets
        // positioning rect in Screen coordinates
        let windowRect = positioningView.convert(positioningRect, to: nil)
        let screenPosRect = mainWindow.convertToScreen(windowRect)
        // available screen space at the bottom
        let availableHeightBelow = screenPosRect.minY - screenFrame.minY - contentInsets.bottom

        // calculate size to fit all the contents
        var preferredContentSize = calculatePreferredContentSize()

        // menu expanding from the right edge (.maxX positioning)
        // expand up if available space at the bottom is less than content size
        if availableHeightBelow < preferredContentSize.height,
           preferredEdge == .maxX {
            // how much of the content height doesn‘t fit at the bottom?
            let contentHeightToExpandUp = preferredContentSize.height - (screenPosRect.minY - screenFrame.minY) - contentInsets.top - contentInsets.bottom
            // set the popover size to fit all the contents but not more than space available
            preferredContentSize.height = min(screenFrame.height - contentInsets.top - contentInsets.bottom, preferredContentSize.height)
            // shift the popover up from the positioining rect as much as needed
            if contentHeightToExpandUp > 0 {
                let availableHeightOnTop = screenFrame.maxY - screenPosRect.minY - contentInsets.top
                preferredContentOffset.y = min(availableHeightOnTop, contentHeightToExpandUp)
            } else {
                preferredContentOffset.y = 0
            }

        // menu expanding up from the bottom edge (.minY positioning)
        // if available space at the bottom is less than 4 rows
        } else if Int(availableHeightBelow / BookmarkOutlineCellView.rowHeight) < Constants.minVisibleRows {
            // expand the menu up from the bottom-most point
            let availableHeightOnTop = screenFrame.maxY - screenPosRect.minY - contentInsets.top
            // shift the popover up matching the content size but not more than space available
            preferredContentOffset.y = min(availableHeightOnTop, preferredContentSize.height) - availableHeightBelow
            // set the popover size to fit all the contents but not more than space available
            preferredContentSize.height = min(screenFrame.height - contentInsets.top - contentInsets.bottom, preferredContentSize.height)

        } else {
            // expand the menu down when space is available to fit the content
            preferredContentOffset = .zero
            preferredContentSize.height = min(availableHeightBelow, preferredContentSize.height)
        }

        self.preferredContentSize = preferredContentSize
        updateScrollButtons()
    }

    private func calculatePreferredContentSize() -> NSSize {
        let contentInsets = BookmarksBarMenuPopover.popoverInsets
        var contentSize = NSSize(width: 0, height: 20)
        for row in 0..<outlineView.numberOfRows {
            let node = outlineView.item(atRow: row) as? BookmarkNode

            // desired width (limited to maxMenuPopoverContentWidth)
            if contentSize.width < Constants.maxMenuPopoverContentWidth {
                let cellWidth = BookmarkOutlineCellView.preferredContentWidth(for: node) + contentInsets.left + contentInsets.right
                if cellWidth > contentSize.width {
                    contentSize.width = min(Constants.maxMenuPopoverContentWidth, cellWidth)
                }
            }
            // desired row height
            if node?.representedObject is SpacerNode {
                contentSize.height += OutlineSeparatorViewCell.rowHeight(for: .bookmarksMenu)
            } else {
                contentSize.height += BookmarkOutlineCellView.rowHeight
            }
        }
        return contentSize
    }

    private func updatePositionAndContentSize(oldContentSize: NSSize, popoverPositioningEdge: NSRectEdge) {

        guard let window = view.window,
              let screenFrame = window.screen?.visibleFrame else { return }

        var contentSize = calculatePreferredContentSize()
        guard contentSize != oldContentSize else { return }

        let heightChange = contentSize.height - oldContentSize.height
        let availableHeightBelow = window.frame.minY - screenFrame.minY
        let availableHeightOnTop = screenFrame.maxY - window.frame.maxY

        // growing
        if heightChange > 0 {
            // expand popover down as much as available screen space allows
            contentSize.height = preferredContentSize.height + min(availableHeightBelow, heightChange)
            // shift popover upwards if not enough space at the bottom
            if availableHeightBelow < heightChange {
                preferredContentOffset.y += min(availableHeightOnTop, heightChange - availableHeightBelow)
            }

        // collapsing
        } else if /* heightChange <= 0 && */ contentSize.height < scrollView.frame.height {
            // reduce the offset of the popover upwards relative to the presenting view
            preferredContentOffset.y = max(0, preferredContentOffset.y + heightChange)
            // contentSize.height set to preferred height calculated before
        } else {
            // don‘t reduce the popover size if the content size still needs scrolling
            contentSize.height = preferredContentSize.height
        }

        preferredContentSize = contentSize
        updateScrollButtons()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        updateScrollButtons()
    }

    private func showSubmenu(for folder: BookmarkFolder, atRow row: Int) {
        guard let cell = outlineView.view(atColumn: 0, row: row, makeIfNecessary: false) else { return }

        let submenuPopover: BookmarksBarMenuPopover
        if let popover = self.submenuPopover {
            submenuPopover = popover
            if submenuPopover.isShown {
                if submenuPopover.rootFolder?.id == folder.id {
                    // submenu for the folder is already shown
                    return
                }
                submenuPopover.close()
            }
            // reuse the popover for another folder
            submenuPopover.reloadData(withRootFolder: folder)
        } else {
            submenuPopover = BookmarksBarMenuPopover(rootFolder: folder)
            submenuPopover.delegate = self
            self.submenuPopover = submenuPopover
        }

        submenuPopover.show(positionedAsSubmenuAgainst: cell)
    }

    // MARK: - Actions

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space:
            if outlineView.highlightedRow != nil {
                // submit action when there‘s a highlighted row
                handleClick(outlineView)

            } else if outlineView.numberOfRows > 0 {
                // when in child menu popover without selection: highlight first row
                outlineView.highlightedRow = 0
            }

        case kVK_Escape:
            delegate?.closeBookmarksPopovers(self)

        case kVK_LeftArrow:
            // if in submenu: close this submenu
            if view.window?.parent?.contentViewController is Self,
               let popover = nextResponder as? NSPopover {
                popover.close()
            } else /* we‘re in root menu */ {
                // switch between bookmarks menus on left/right
                delegate?.openPreviousBookmarksMenu(self)
            }
        case kVK_RightArrow:
            // expand currently highlighted folder
            if let highlightedRow = outlineView.highlightedRow,
               let bookmarkNode = outlineView.item(atRow: highlightedRow) as? BookmarkNode,
               let folder = bookmarkNode.representedObject as? BookmarkFolder {
                showSubmenu(for: folder, atRow: highlightedRow)
                // highlight first submenu row when expanding with Right key
                submenuPopover?.viewController.outlineView.highlightFirstItem()
            } else {
                // switch between bookmarks menus on left/right
                delegate?.openNextBookmarksMenu(self)
            }

        default:
            super.keyDown(with: event)
        }
    }

    @objc func handleClick(_ sender: NSOutlineView) {
        guard sender.clickedRow != -1 else { return }

        let item = sender.item(atRow: sender.clickedRow)
        guard let node = item as? BookmarkNode else { return }

        switch node.representedObject {
        case let bookmark as Bookmark:
            WindowControllersManager.shared.open(bookmark: bookmark)
            delegate?.closeBookmarksPopovers(self)

        case let menuItem as MenuItemNode:
            if menuItem.identifier == BookmarkTreeController.openAllInNewTabsIdentifier {
                openAllInNewTabs()
            } else {
                assertionFailure("Unsupported menu item action \(menuItem.identifier)")
            }
            delegate?.closeBookmarksPopovers(self)

        default: break
        }
    }

    private func openAllInNewTabs() {
        guard let tabCollection = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel,
              let folder = self.treeController.rootNode.representedObject as? BookmarkFolder else {
            assertionFailure("Cannot open all in new tabs")
            return
        }
        delegate?.closeBookmarksPopovers(self)

        let tabs = Tab.withContentOfBookmark(folder: folder, burnerMode: tabCollection.burnerMode)
        tabCollection.append(tabs: tabs)
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
    }

    // MARK: NSOutlineView Configuration

    private func expandAndRestore(selectedNodes: [BookmarkNode]) {
        treeController.visitNodes { node in
            if let objectID = (node.representedObject as? BaseBookmarkEntity)?.id {
                if dataSource.expandedNodesIDs.contains(objectID) {
                    outlineView.expandItem(node)
                } else {
                    outlineView.collapseItem(node)
                }
            }

            // Expand the Bookmarks pseudo folder automatically, and remember the expansion state of the Favorites pseudofolder.
            if let pseudoFolder = node.representedObject as? PseudoFolder {
                if pseudoFolder == PseudoFolder.bookmarks {
                    outlineView.expandItem(node)
                } else {
                    if dataSource.expandedNodesIDs.contains(pseudoFolder.id) {
                        outlineView.expandItem(node)
                    } else {
                        outlineView.collapseItem(node)
                    }
                }
            }
        }

        restoreSelection(to: selectedNodes)
    }

    private func restoreSelection(to nodes: [BookmarkNode]) {
        guard selectedNodes != nodes else { return }

        var indexes = IndexSet()
        for node in nodes {
            // The actual instance of the Bookmark may have changed after reloading, so this is a hack to get the right one.
            let foundNode = treeController.node(representing: node.representedObject)
            let row = outlineView.row(forItem: foundNode as Any)
            if row > -1 {
                indexes.insert(row)
            }
        }

        if indexes.isEmpty {
            let node = treeController.node(representing: PseudoFolder.bookmarks)
            let row = outlineView.row(forItem: node as Any)
            indexes.insert(row)
        }

        outlineView.selectRowIndexes(indexes, byExtendingSelection: false)
    }

    /// Show or close folder submenu on row hover
    /// the method is called from `outlineView.$highlightedRow` observer after a delay as needed
    func outlineViewDidHighlight(_ folder: BookmarkFolder?, atRow row: Int?) {
        guard let row, let folder else {
            // close submenu if shown
            guard let submenuPopover, submenuPopover.isShown else { return }
            submenuPopover.close()
            // unhighlight drop destination row if highlighted
            dataSource.targetRowForDropOperation = nil
            return
        }

        showSubmenu(for: folder, atRow: row)
    }

    // MARK: Bookmarks Menu scrolling

    private func subscribeToScrollingEvents() {
        // scrollViewDidScroll
        NotificationCenter.default
            .publisher(for: NSView.boundsDidChangeNotification, object: scrollView.contentView).asVoid()
            .compactMap { [weak scrollView=scrollView] in
                scrollView?.documentVisibleRect
            }
            .scan((old: CGRect.zero, new: scrollView.documentVisibleRect)) {
                (old: $0.new, new: $1)
            }
            .sink { [weak self] change in
                self?.scrollViewDidScroll(old: change.old, new: change.new)
            }.store(in: &cancellables)

        // Scroll Up Button hover
        scrollUpButton?.publisher(for: \.isMouseOver)
            .map { [weak scrollDownButton] isMouseOver in
                guard isMouseOver,
                      NSApp.currentEvent?.type != .keyDown else {
                    if let scrollDownButton, scrollDownButton.isMouseOver {
                        // ignore mouse over change when the button appears on
                        // the Down key press
                        scrollDownButton.isMouseOver = false
                    }
                    return Empty<Void, Never>().eraseToAnyPublisher()
                }
                return Timer.publish(every: 0.1, on: .main, in: .default)
                    .autoconnect()
                    .asVoid()
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [weak outlineView] in
                guard let outlineView else { return }
                // scroll up on scrollUpButton hover on Timed events
                let newScrollOrigin = NSPoint(x: outlineView.visibleRect.origin.x, y: outlineView.visibleRect.origin.y - BookmarkOutlineCellView.rowHeight)
                outlineView.scroll(newScrollOrigin)
            }
            .store(in: &cancellables)

        // Scroll Down Button hover
        scrollDownButton?.publisher(for: \.isMouseOver)
            .map { [weak scrollDownButton] isMouseOver in
                guard isMouseOver,
                      NSApp.currentEvent?.type != .keyDown else {
                    if let scrollDownButton, scrollDownButton.isMouseOver {
                        // ignore mouse over change when the button appears on
                        // the Down key press
                        scrollDownButton.isMouseOver = false
                    }
                    return Empty<Void, Never>().eraseToAnyPublisher()
                }
                return Timer.publish(every: 0.1, on: .main, in: .default)
                    .autoconnect()
                    .asVoid()
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [weak outlineView] in
                guard let outlineView else { return }
                // scroll down on scrollDownButton hover on Timed events
                let newScrollOrigin = NSPoint(x: outlineView.visibleRect.origin.x, y: outlineView.visibleRect.origin.y + BookmarkOutlineCellView.rowHeight)
                outlineView.scroll(newScrollOrigin)
            }
            .store(in: &cancellables)
    }

    private func scrollViewDidScroll(old oldVisibleRect: NSRect, new visibleRect: NSRect) {
        guard let window = view.window, let screen = window.screen else { return }

        let availableHeight = screen.visibleFrame.maxY - window.frame.maxY
        let scrollDeltaY = visibleRect.minY - oldVisibleRect.minY
        if scrollDeltaY > 0, availableHeight > 0 {
            let contentHeight = outlineView.bounds.height
            // shift bookmarks menu popover up incrementing height if screen space is available
            var popoverHeightIncrement = min(availableHeight, scrollDeltaY)
            if preferredContentSize.height + popoverHeightIncrement > contentHeight {
                popoverHeightIncrement = contentHeight - preferredContentSize.height
            }
            if popoverHeightIncrement > 0 {
                preferredContentOffset.y = popoverHeightIncrement
                preferredContentSize.height += popoverHeightIncrement
                // decrement scrolling position
                if preferredContentSize.height + popoverHeightIncrement > contentHeight {
                    scrollView.contentView.bounds.origin.y = 0
                } else {
                    scrollView.contentView.bounds.origin.y -= popoverHeightIncrement
                }
            }
            // -> will update scroll buttons on next `viewDidLayout` pass

        } else {
            updateScrollButtons()
        }

        if let event = NSApp.currentEvent, event.type != .keyDown {
            // update current highlighted row to match cursor position
            outlineView.updateHighlightedRowUnderCursor()
        }
    }

    private func updateScrollButtons() {
        guard let scrollUpButton, let scrollDownButton else { return }
        let contentHeight = outlineView.bounds.height

        var visibleRect = scrollView.documentVisibleRect
        if scrollUpButton.isShown {
            visibleRect.size.height += scrollUpButton.frame.height
        }
        if scrollDownButton.isShown {
            visibleRect.size.height += scrollDownButton.frame.height
        }
        scrollUpButton.isShown = visibleRect.minY > 0
        scrollDownButton.isShown = visibleRect.maxY < contentHeight
    }

}
// MARK: - BookmarksContextMenuDelegate
extension BookmarksBarMenuViewController: BookmarksContextMenuDelegate {

    var isSearching: Bool { false }
    var parentFolder: BookmarkFolder? { nil }
    var shouldIncludeManageBookmarksItem: Bool { true }

    func selectedItems() -> [Any] {
        guard let row = outlineView.clickedRowIfValid ?? outlineView.highlightedRow else { return [] }
        return outlineView.item(atRow: row).map { [$0] } ?? []
    }

    func closePopoverIfNeeded() {
        delegate?.closeBookmarksPopovers(self)
    }

    func showDialog(_ view: any ModalView) {
        delegate?.popover(shouldPreventClosure: true)

        view.show(in: parent?.view.window) { [weak delegate] in
            delegate?.popover(shouldPreventClosure: false)
        }
    }

    func showInFolder(_ sender: NSMenuItem) {
        assertionFailure("BookmarksBarMenuViewController does not support search")
    }

}
// MARK: - MouseOverButtonDelegate
extension BookmarksBarMenuViewController: MouseOverButtonDelegate {

    // scroll bookmarks menu up/down on scroll buttons mouse over
    func mouseOverButton(_ sender: MouseOverButton, draggingEntered info: any NSDraggingInfo, isMouseOver: UnsafeMutablePointer<Bool>) -> NSDragOperation {

        assert(sender === scrollUpButton || sender === scrollDownButton)
        isMouseOver.pointee = true
        return .none
    }

    // scroll bookmarks menu up/down on dragging over scroll buttons
    func mouseOverButton(_ sender: MouseOverButton, draggingUpdatedWith info: any NSDraggingInfo, isMouseOver: UnsafeMutablePointer<Bool>) -> NSDragOperation {
        assert(sender === scrollUpButton || sender === scrollDownButton)
        isMouseOver.pointee = true
        return .none
    }

}
// MARK: - BookmarkListPopoverDelegate
extension BookmarksBarMenuViewController: BookmarksBarMenuPopoverDelegate {
    // pass delegate calls up when called from submenu
    func openNextBookmarksMenu(_ sender: BookmarksBarMenuPopover) {
        delegate?.openNextBookmarksMenu(self)
    }
    func openPreviousBookmarksMenu(_ sender: BookmarksBarMenuPopover) {
        delegate?.openPreviousBookmarksMenu(self)
    }
}

#if DEBUG
@available(macOS 14.0, *)
#Preview("Bookmarks Bar Menu", traits: .fixedLayout(width: 420, height: 500)) {
    BookmarksBarMenuViewController(bookmarkManager: _mockPreviewBookmarkManager(previewEmptyState: false))
        ._preview_hidingWindowControlsOnAppear()
}
#endif
