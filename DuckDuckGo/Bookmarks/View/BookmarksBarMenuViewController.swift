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
import Combine
import Foundation

protocol BookmarksBarMenuViewControllerDelegate: AnyObject {
    func popoverShouldClose(_ sender: BookmarksBarMenuViewController)
    func popover(shouldPreventClosure: Bool)
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

        scrollDownButton = MouseOverButton(image: .expandDown, target: nil, action: nil)
        scrollDownButton.translatesAutoresizingMaskIntoConstraints = false
        scrollDownButton.bezelStyle = .shadowlessSquare
        scrollDownButton.normalTintColor = .labelColor
        scrollDownButton.backgroundColor = .clear
        scrollDownButton.mouseOverColor = .blackWhite10

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
        outlineView.registerForDraggedTypes([BookmarkPasteboardWriter.bookmarkUTIInternalType,
                                             FolderPasteboardWriter.folderUTIInternalType])
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
        // only subscribe to click outside events in root bookmarks menu
        // to close all the bookmarks menu popovers
        if !(view.window?.parent?.contentViewController is Self) {
            subscribeToClickOutsideEvents()
        }
    }

    private func subscribeToMenuPopoverEvents() {
        // show submenu for folder when dragging or hovering over it
        typealias RowEvtPub = AnyPublisher<(Int?, BookmarkFolder?), Never>
        // hover over bookmarks menu row
        outlineView.$highlightedRow
        .compactMap { [weak self] (row) -> RowEvtPub? in
            guard let self else { return nil }
            let bookmarkNode = row.flatMap { self.outlineView.item(atRow: $0) } as? BookmarkNode
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
            if isMouseMovingDownRight,
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

            } else if folder != nil {
                // delay folder expanding when hovering over a subfolder
                delay = 0.1
            } else {
                // hide submenu instantly when mouse is moved away from folder
                // unless it‘s moving down+right as handled above.
                delay = 0
            }

            let valuePublisher = Just((row, folder))
            if delay > 0 {
                return valuePublisher
                    .delay(for: delay, scheduler: RunLoop.main)
                    .eraseToAnyPublisher()
            } else {
                return valuePublisher.eraseToAnyPublisher()
            }
        }
        .switchToLatest()
        .filter { [weak outlineView] (row, _) in
            return outlineView?.highlightedRow == row
        }
        .sink { [weak self] (row, folder) in
            self?.outlineViewDidHighlight(folder, atRow: row)
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
                    // BookmarksBarViewController.popoverShouldClose
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
            self?.delegate?.popoverShouldClose(self!) // close
        }
        .store(in: &cancellables)
    }

    func reloadData(withRootFolder rootFolder: BookmarkFolder? = nil) {
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
        outlineView.reloadData()
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

    func calculatePreferredContentSize() -> NSSize {
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

    override func viewDidLayout() {
        super.viewDidLayout()

        updateScrollButtons()
    }

    @objc func handleClick(_ sender: NSOutlineView) {
        guard sender.clickedRow != -1 else { return }

        let item = sender.item(atRow: sender.clickedRow)
        guard let node = item as? BookmarkNode,
              let bookmark = node.representedObject as? Bookmark else { return }

        WindowControllersManager.shared.open(bookmark: bookmark)
        delegate?.popoverShouldClose(self)
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
        guard let row, let folder,
              let cell = outlineView.view(atColumn: 0, row: row, makeIfNecessary: false) else {
            // close submenu if shown
            guard let submenuPopover, submenuPopover.isShown else { return }
            submenuPopover.close()
            return
        }

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
            self.submenuPopover = submenuPopover
        }

        submenuPopover.show(positionedAsSubmenuAgainst: cell)
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

    func selectedItems() -> [Any] {
        guard let row = outlineView.clickedRowIfValid ?? outlineView.highlightedRow else { return [] }
        return outlineView.item(atRow: row).map { [$0] } ?? []
    }

    func closePopoverIfNeeded() {
        delegate?.popoverShouldClose(self)
    }

    func showDialog(_ view: any ModalView) {
        delegate?.popover(shouldPreventClosure: true)

        view.show(in: parent?.view.window) { [weak delegate] in
            delegate?.popover(shouldPreventClosure: false)
        }
    }

}

#if DEBUG
@available(macOS 14.0, *)
#Preview("Bookmarks Bar Menu", traits: .fixedLayout(width: 420, height: 500)) {
    BookmarksBarMenuViewController(bookmarkManager: _mockPreviewBookmarkManager(previewEmptyState: false))
        ._preview_hidingWindowControlsOnAppear()
}
#endif
