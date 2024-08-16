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

import AppKit
import Combine
import Common
import Foundation

final class BookmarksBarViewController: NSViewController {

    @IBOutlet weak var importBookmarksButton: NSView!
    @IBOutlet weak var importBookmarksMouseOverView: MouseOverView!
    @IBOutlet weak var importBookmarksLabel: NSTextField!
    @IBOutlet weak var importBookmarksIcon: NSImageView!
    @IBOutlet private var bookmarksBarCollectionView: NSCollectionView!
    @IBOutlet private var clippedItemsIndicator: MouseOverButton!
    @IBOutlet private var promptAnchor: NSView!

    private var bookmarkListPopover: BookmarkListPopover?

    private let bookmarkManager: BookmarkManager
    private let dragDropManager: BookmarkDragDropManager
    private let viewModel: BookmarksBarViewModel
    private let tabCollectionViewModel: TabCollectionViewModel

    private var cancellables = Set<AnyCancellable>()

    private static let maxDragDistanceToExpandHoveredFolder: CGFloat = 4
    private static let dragOverFolderExpandDelay: TimeInterval = 0.3
    private var dragDestination: (folder: BookmarkFolder, mouseLocation: NSPoint, hoverStarted: Date)?

    fileprivate var clipThreshold: CGFloat {
        let viewWidthWithoutClipIndicator = view.frame.width - clippedItemsIndicator.frame.minX
        return view.frame.width - viewWidthWithoutClipIndicator - 3
    }

    @UserDefaultsWrapper(key: .bookmarksBarPromptShown, defaultValue: false)
    var bookmarksBarPromptShown: Bool

    static func create(tabCollectionViewModel: TabCollectionViewModel, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) -> BookmarksBarViewController {
        NSStoryboard(name: "BookmarksBar", bundle: nil).instantiateInitialController { coder in
            self.init(coder: coder, tabCollectionViewModel: tabCollectionViewModel, bookmarkManager: bookmarkManager)
        }!
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared, dragDropManager: BookmarkDragDropManager = BookmarkDragDropManager.shared) {
        self.bookmarkManager = bookmarkManager
        self.dragDropManager = dragDropManager

        self.tabCollectionViewModel = tabCollectionViewModel
        self.viewModel = BookmarksBarViewModel(bookmarkManager: bookmarkManager, dragDropManager: dragDropManager, tabCollectionViewModel: tabCollectionViewModel)

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("BookmarksBarViewController: Bad initializer")
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpImportBookmarksButton()

        addContextMenu()

        viewModel.delegate = self

        let nib = NSNib(nibNamed: "BookmarksBarCollectionViewItem", bundle: .main)
        bookmarksBarCollectionView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        bookmarksBarCollectionView.register(nib, forItemWithIdentifier: BookmarksBarCollectionViewItem.identifier)

        bookmarksBarCollectionView.registerForDraggedTypes(BookmarkDragDropManager.draggedTypes)

        clippedItemsIndicator.registerForDraggedTypes(BookmarkDragDropManager.draggedTypes)
        clippedItemsIndicator.delegate = self
        clippedItemsIndicator.sendAction(on: .leftMouseDown)

        importBookmarksLabel.stringValue = UserText.importBookmarks

        bookmarksBarCollectionView.delegate = viewModel
        bookmarksBarCollectionView.dataSource = viewModel
        bookmarksBarCollectionView.collectionViewLayout = createCenteredCollectionViewLayout()

        view.postsFrameChangedNotifications = true
        bookmarksBarCollectionView.setAccessibilityIdentifier("BookmarksBarViewController.bookmarksBarCollectionView")
    }

    private func setUpImportBookmarksButton() {
        importBookmarksIcon.image = NSImage(named: "Import-16D")
        importBookmarksButton.isHidden = true
    }

    private func addContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        self.view.menu = menu
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        subscribeToEvents()
        refreshFavicons()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        frameDidChangeNotification()
    }

    func showBookmarksBarPrompt() {
        BookmarksBarPromptPopover().show(relativeTo: promptAnchor.bounds, of: promptAnchor, preferredEdge: .minY)
        self.bookmarksBarPromptShown = true
    }

    func userInteraction(prevented: Bool) {
        bookmarksBarCollectionView.isSelectable = !prevented
        clippedItemsIndicator.isEnabled = !prevented
        viewModel.isInteractionPrevented = prevented
        bookmarksBarCollectionView.reloadData()
    }

    private func frameDidChangeNotification() {
        self.viewModel.clipOrRestoreBookmarksBarItems()
        self.refreshClippedIndicator()
    }

    override func removeFromParent() {
        super.removeFromParent()
        unsubscribeFromEvents()
    }

    private func subscribeToEvents() {
        guard cancellables.isEmpty else { return }

        NotificationCenter.default.publisher(for: NSView.frameDidChangeNotification, object: view)
            // Wait until the frame change has taken effect for subviews before calculating changes to the list of items.
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.frameDidChangeNotification()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .faviconCacheUpdated)
            .sink { [weak self] _ in
                self?.refreshFavicons()
            }
            .store(in: &cancellables)

        viewModel.$clippedItems
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshClippedIndicator()
            }
            .store(in: &cancellables)

        viewModel.$bookmarksBarItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                if self?.bookmarkManager.list != nil {
                    self?.importBookmarksButton.isHidden = !items.isEmpty
                }
            }
            .store(in: &cancellables)

        clippedItemsIndicator.publisher(for: \.isMouseOver)
            .sink { [weak self] isMouseOver in
                guard isMouseOver, let self, let clippedItemsIndicator else { return }
                mouseDidHover(over: clippedItemsIndicator)
            }
            .store(in: &cancellables)
    }

    private func unsubscribeFromEvents() {
        cancellables.removeAll()
    }

    /// Open bookmarks submenu after delay when dragging an item over a Folder (or cancel when dragging out of it)
    /// - Returns: was submenu shown?
    @discardableResult
    private func dragging(over view: NSView?, representing folder: BookmarkFolder?, updatedWith info: NSDraggingInfo?) -> Bool {
        guard let view, let folder, let cursorPosition = info?.draggingLocation else {
            dragDestination = nil
            // close all Bookmarks popovers including the Bookmarks Button popover
            BookmarkListPopover.closeBookmarkListPopovers(shownIn: self.view.window)
            return false
        }
        if let bookmarkListPopover, bookmarkListPopover.isShown,
           bookmarkListPopover.rootFolder?.id == folder.id {
            // folder menu already shown
            return true
        }

        // show folder bookmarks menu after delay
        if let dragDestination,
           dragDestination.folder.id == folder.id,
           dragDestination.mouseLocation.distance(to: cursorPosition) < Self.maxDragDistanceToExpandHoveredFolder {

            if Date().timeIntervalSince(dragDestination.hoverStarted) >= Self.dragOverFolderExpandDelay {
                showSubmenu(for: folder, fromView: view)
                return true
            }
        } else {
            self.dragDestination = (folder: folder, mouseLocation: cursorPosition, hoverStarted: Date())
        }
        return false
    }

    // MARK: - Layout

    private func createCenteredLayout(centered: Bool) -> NSCollectionLayoutSection {
        let group = NSCollectionLayoutGroup.horizontallyCentered(cellSizes: viewModel.cellSizes, interItemSpacing: BookmarksBarViewModel.Constants.buttonSpacing, centered: centered)
        return NSCollectionLayoutSection(group: group)
    }

    func createCenteredCollectionViewLayout() -> NSCollectionViewLayout {
        return BookmarksBarCenteredLayout { [unowned self] _, _ in
            return createCenteredLayout(centered: viewModel.clippedItems.isEmpty)
        }
    }

    private func refreshClippedIndicator() {
        self.clippedItemsIndicator.isHidden = viewModel.clippedItems.isEmpty
    }

    private func refreshFavicons() {
        dispatchPrecondition(condition: .onQueue(.main))
        bookmarksBarCollectionView.reloadData()
    }
    @IBAction func importBookmarksClicked(_ sender: Any) {
        DataImportView().show()
    }

    @IBAction private func clippedItemsIndicatorClicked(_ sender: NSButton) {
        showSubmenu(for: clippedItemsBookmarkFolder(), fromView: sender)
    }

    private func clippedItemsBookmarkFolder() -> BookmarkFolder {
        BookmarkFolder(id: PseudoFolder.bookmarks.id, title: PseudoFolder.bookmarks.name, children: viewModel.clippedItems.map(\.entity))
    }

    @IBAction func mouseClickViewMouseUp(_ sender: MouseClickView) {
        // when collection view reloaded we may receive mouseUp event from a wrong bookmarks bar item
        // get actual item based on the event coordinates
        guard let indexPath = bookmarksBarCollectionView.withMouseLocationInViewCoordinates(convert: { point in
            self.bookmarksBarCollectionView.indexPathForItem(at: point)
        }),
              let item = bookmarksBarCollectionView.item(at: indexPath.item) as? BookmarksBarCollectionViewItem else {
            os_log("Item at mouseUp point not found.", type: .error)
            return
        }

        viewModel.bookmarksBarCollectionViewItemClicked(item)
    }

}

extension BookmarksBarViewController: BookmarksBarViewModelDelegate {

    func bookmarksBarViewModelReceived(action: BookmarksBarViewModel.BookmarksBarItemAction, for item: BookmarksBarCollectionViewItem) {
        guard let indexPath = bookmarksBarCollectionView.indexPath(for: item) else {
            assertionFailure("Failed to look up index path for clicked item")
            return
        }

        guard let entity = bookmarkManager.list?.topLevelEntities[indexPath.item] else {
            assertionFailure("Failed to get entity for clicked item")
            return
        }

        if let bookmark = entity as? Bookmark {
            handle(action, for: bookmark)
        } else if let folder = entity as? BookmarkFolder {
            handle(action, for: folder, item: item)
        } else {
            assertionFailure("Failed to cast entity for clicked item")
        }
    }

    func bookmarksBarViewModelWidthForContainer() -> CGFloat {
        return clipThreshold
    }

    func bookmarksBarViewModelReloadedData() {
        bookmarksBarCollectionView.reloadData()

        if let bookmarkListPopover, bookmarkListPopover.isShown,
           bookmarkListPopover.rootFolder?.id == PseudoFolder.bookmarks.id /* clipped items folder has id of the root */ {
            bookmarkListPopover.reloadData(withRootFolder: clippedItemsBookmarkFolder())
        }
    }

    func mouseDidHover(over sender: Any) {
        guard let bookmarkListPopover, bookmarkListPopover.isShown else { return }
        var bookmarkFolder: BookmarkFolder?
        var view: NSView?
        if let item = sender as? BookmarksBarCollectionViewItem {
            bookmarkFolder = item.representedObject as? BookmarkFolder
            view = item.view
        } else if let button = sender as? NSButton, button === clippedItemsIndicator {
            bookmarkFolder = clippedItemsBookmarkFolder()
            view = button
        }
        if let bookmarkFolder, let view {
            // already shown?
            guard bookmarkListPopover.rootFolder?.id != bookmarkFolder.id else { return }
            showSubmenu(for: bookmarkFolder, fromView: view)
        } else {
            bookmarkListPopover.close()
        }
    }

    func dragging(over item: BookmarksBarCollectionViewItem?, updatedWith info: (any NSDraggingInfo)?) {
        guard let info, let item = item,
              let folder = item.representedObject as? BookmarkFolder else {
            info?.draggingInfoUpdatedTimerCancellable = nil

            self.dragging(over: nil, representing: nil, updatedWith: info)
            return
        }

        let submenuShown = self.dragging(over: item.view, representing: folder, updatedWith: info)
        if !submenuShown {
            let draggingLocation = info.draggingLocation
            // NSCollectionView doesn‘t send extra `draggingUpdated` events when cursor stays at the same point
            // here we simulate the standard `NSView.draggingUpdated` behavior sent continuously while dragging
            // to open the Folder submenu after a delay while dragging over it.
            Task { @MainActor [weak self, weak info] in
                while let self, let info, info.draggingLocation == draggingLocation {
                    if self.dragging(over: item.view, representing: folder, updatedWith: info) == true {
                        return
                    }
                    try await Task.sleep(interval: 0.05)
                }
            }
        }
    }

}

private let draggingInfoUpdatedTimerKey = UnsafeRawPointer(bitPattern: "draggingInfoUpdatedTimerKey".hashValue)!
extension NSDraggingInfo {
    var draggingInfoUpdatedTimerCancellable: AnyCancellable? {
        get {
            objc_getAssociatedObject(self, draggingInfoUpdatedTimerKey) as? AnyCancellable
        }
        set {
            objc_setAssociatedObject(self, draggingInfoUpdatedTimerKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

}

// MARK: - Drag&Drop over Clipped Items indicator
extension BookmarksBarViewController: MouseOverButtonDelegate {

    func mouseOverButton(_ sender: MouseOverButton, draggingEntered info: any NSDraggingInfo, isMouseOver: UnsafeMutablePointer<Bool>) -> NSDragOperation {
        guard sender === clippedItemsIndicator else { return .none }
        let operation = dragDropManager.validateDrop(info, to: clippedItemsBookmarkFolder())
        isMouseOver.pointee = (operation != .none)
        return operation
    }

    func mouseOverButton(_ sender: MouseOverButton, draggingUpdatedWith info: any NSDraggingInfo, isMouseOver: UnsafeMutablePointer<Bool>) -> NSDragOperation {
        guard sender === clippedItemsIndicator else { return .none }
        let clippedItemsBookmarkFolder = clippedItemsBookmarkFolder()
        self.dragging(over: sender, representing: clippedItemsBookmarkFolder, updatedWith: info)
        let operation = dragDropManager.validateDrop(info, to: clippedItemsBookmarkFolder)
        isMouseOver.pointee = (operation != .none)
        return operation
    }

    func mouseOverButton(_ sender: MouseOverButton, performDragOperation info: any NSDraggingInfo) -> Bool {
        guard sender === clippedItemsIndicator else { return false }
        return dragDropManager.acceptDrop(info, to: clippedItemsBookmarkFolder(), at: -1)
    }

}

// MARK: - Private

private extension BookmarksBarViewController {

    func handle(_ action: BookmarksBarViewModel.BookmarksBarItemAction, for bookmark: Bookmark) {
        switch action {
        case .openInNewTab:
            openInNewTab(bookmark: bookmark)
        case .openInNewWindow:
            openInNewWindow(bookmark: bookmark)
        case .clickItem:
            WindowControllersManager.shared.open(bookmark: bookmark)
            PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
        case .toggleFavorites:
            bookmark.isFavorite.toggle()
            bookmarkManager.update(bookmark: bookmark)
        case .edit:
            showDialog(view: BookmarksDialogViewFactory.makeEditBookmarkView(bookmark: bookmark))
        case .moveToEnd:
            bookmarkManager.move(objectUUIDs: [bookmark.id], toIndex: nil, withinParentFolder: .root) { _ in }
        case .copyURL:
            bookmark.copyUrlToPasteboard()
        case .deleteEntity:
            bookmarkManager.remove(bookmark: bookmark)
        case .addFolder:
            addFolder(inParent: nil)
        case .manageBookmarks:
            manageBookmarks()
        }
    }

    func handle(_ action: BookmarksBarViewModel.BookmarksBarItemAction, for folder: BookmarkFolder, item: BookmarksBarCollectionViewItem) {
        switch action {
        case .clickItem:
            showSubmenu(for: folder, fromView: item.view)
        case .edit:
            showDialog(view: BookmarksDialogViewFactory.makeEditBookmarkFolderView(folder: folder, parentFolder: nil))
        case .moveToEnd:
            bookmarkManager.move(objectUUIDs: [folder.id], toIndex: nil, withinParentFolder: .root) { _ in }
        case .deleteEntity:
            bookmarkManager.remove(folder: folder)
        case .addFolder:
            addFolder(inParent: folder)
        case .openInNewTab:
            openAllInNewTabs(folder: folder)
        case .openInNewWindow:
            openAllInNewWindow(folder: folder)
        case .manageBookmarks:
            manageBookmarks()
        default:
            assertionFailure("Received unexpected action for bookmark folder")
        }
    }

    func bookmarkFolderMenu(items: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu()
        menu.items = items.isEmpty ? [NSMenuItem.empty] : items
        menu.autoenablesItems = false
        return menu
    }

    func openInNewTab(bookmark: Bookmark) {
        guard let url = bookmark.urlObject else { return }
        tabCollectionViewModel.appendNewTab(with: .url(url, source: .bookmark), selected: true)
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
    }

    func openInNewWindow(bookmark: Bookmark) {
        guard let url = bookmark.urlObject else { return }
        WindowsManager.openNewWindow(with: url, source: .bookmark, isBurner: false)
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
    }

    func openAllInNewTabs(folder: BookmarkFolder) {
        let tabs = Tab.withContentOfBookmark(folder: folder, burnerMode: tabCollectionViewModel.burnerMode)
        tabCollectionViewModel.append(tabs: tabs)
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
    }

    func openAllInNewWindow(folder: BookmarkFolder) {
        let tabCollection = TabCollection.withContentOfBookmark(folder: folder, burnerMode: tabCollectionViewModel.burnerMode)
        WindowsManager.openNewWindow(with: tabCollection, isBurner: tabCollectionViewModel.isBurner)
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
    }

    private func showSubmenu(for folder: BookmarkFolder, fromView view: NSView) {
        let bookmarkListPopover: BookmarkListPopover
        if let popover = self.bookmarkListPopover {
            bookmarkListPopover = popover
            if bookmarkListPopover.isShown {
                bookmarkListPopover.close()
                if bookmarkListPopover.rootFolder?.id == folder.id {
                    return // close popover on 2nd click on the same folder
                }
            }
            bookmarkListPopover.reloadData(withRootFolder: folder)
        } else {
            bookmarkListPopover = BookmarkListPopover(mode: .bookmarkBarMenu, rootFolder: folder)
            bookmarkListPopover.delegate = self
            self.bookmarkListPopover = bookmarkListPopover
        }

        bookmarkListPopover.show(positionedBelow: view)

        if view === clippedItemsIndicator {
            // display pressed state
            clippedItemsIndicator.backgroundColor = .buttonMouseDown
            clippedItemsIndicator.mouseOverColor = .buttonMouseDown
        } else if let collectionViewItem = view.nextResponder as? BookmarksBarCollectionViewItem {
            collectionViewItem.isDisplayingMouseDownState = true
        }
    }

    func addFolder(inParent parent: BookmarkFolder?) {
        showDialog(view: BookmarksDialogViewFactory.makeAddBookmarkFolderView(parentFolder: parent))
    }

    func showDialog(view: any ModalView) {
        view.show(in: self.view.window)
    }

    @objc func manageBookmarks() {
        WindowControllersManager.shared.showBookmarksTab()
    }

    @objc func addFolder(sender: NSMenuItem) {
        addFolder(inParent: nil)
    }

}

// MARK: - Menu

extension BookmarksBarViewController: NSMenuDelegate {

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        BookmarksBarMenuFactory.addToMenuWithManageBookmarksSection(
            menu,
            target: self,
            addFolderSelector: #selector(addFolder(sender:)),
            manageBookmarksSelector: #selector(manageBookmarks)
        )
    }

}

extension BookmarksBarViewController: BookmarkListPopoverDelegate {

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        if NSApp.currentEvent?.type == .leftMouseUp {
           if let point = bookmarksBarCollectionView.mouseLocationInsideBounds(),
              let indexPath = bookmarksBarCollectionView.indexPathForItem(at: point),
              bookmarkManager.list?.topLevelEntities[safe: indexPath.item] is BookmarkFolder {
               // we‘ll close the popover inside the click handler calling `showSubmenu`
               return false
           } else if clippedItemsIndicator.mouseLocationInsideBounds() != nil {
               // same
               return false
           }
        }
        return true
    }

    func popoverDidClose(_ notification: Notification) {
        guard let bookmarkListPopover = notification.object as? BookmarkListPopover,
              let positioningView = bookmarkListPopover.positioningView else { return }

        if positioningView === clippedItemsIndicator {
            clippedItemsIndicator.backgroundColor = .clear
            clippedItemsIndicator.mouseOverColor = .buttonMouseOver
        } else if let collectionViewItem = positioningView.nextResponder as? BookmarksBarCollectionViewItem {
            collectionViewItem.isDisplayingMouseDownState = false
        }
    }

    func openNextBookmarksMenu(_ sender: BookmarkListPopover) {
        guard let folder = sender.rootFolder else {
            assertionFailure("No root folder set in BookmarkListPopover")
            return
        }
        let folderIdx: Int?
        if folder.id == PseudoFolder.bookmarks.id {
            // clipped items folder has id of the root
            folderIdx = nil
        } else if let idx = viewModel.bookmarksBarItems.firstIndex(where: { $0.entity.id == folder.id }) {
            folderIdx = idx
        } else {
            assertionFailure("Could not find currently open folder in the Bookmarks Bar")
            return
        }
        if let folderIdx, folderIdx + 1 < viewModel.bookmarksBarItems.count {
            // switch to next folder in the Bookmarks Bar on Right arrow press
            for idx in viewModel.bookmarksBarItems.indices[(folderIdx + 1)...] {
                guard let folder = viewModel.bookmarksBarItems[idx].entity as? BookmarkFolder,
                      let cell = bookmarksBarCollectionView.item(at: idx)?.view else { continue }
                showSubmenu(for: folder, fromView: cell)
                return
            }
        }
        // next folder not found: open clipped items menu (if not switching from it: folderIdx != nil)
        if folderIdx != nil, !viewModel.clippedItems.isEmpty {
            showSubmenu(for: clippedItemsBookmarkFolder(), fromView: clippedItemsIndicator)
            return
        }
        // switch to 1st folder in the Bookmarks Bar after the Clipped Items menu or after last folder if no clipped items
        for (idx, item) in viewModel.bookmarksBarItems.enumerated() {
            guard let folder = item.entity as? BookmarkFolder, let cell = bookmarksBarCollectionView.item(at: idx)?.view else { continue }
            showSubmenu(for: folder, fromView: cell)
            return
        }
    }

    func openPreviousBookmarksMenu(_ sender: BookmarkListPopover) {
        guard let folder = sender.rootFolder else {
            assertionFailure("No root folder set in BookmarkListPopover")
            return
        }
        let folderIdx: Int
        if folder.id == PseudoFolder.bookmarks.id {
            // clipped items folder has id of the root
            folderIdx = viewModel.bookmarksBarItems.count
        } else if let idx = viewModel.bookmarksBarItems.firstIndex(where: { $0.entity.id == folder.id }) {
            folderIdx = idx
        } else {
            assertionFailure("Could not find currently open folder in the Bookmarks Bar")
            return
        }
        if folderIdx > 0, !viewModel.bookmarksBarItems.isEmpty {
            // switch to previous folder in the Bookmarks Bar on Left arrow press
            for idx in viewModel.bookmarksBarItems.indices[..<folderIdx].reversed() {
                guard let folder = viewModel.bookmarksBarItems[idx].entity as? BookmarkFolder,
                      let cell = bookmarksBarCollectionView.item(at: idx)?.view else { continue }
                showSubmenu(for: folder, fromView: cell)
                return
            }
        }
        // previous folder not found: open clipped items menu (if not switching from it: folderIdx != nil)
        if !viewModel.clippedItems.isEmpty {
            guard folderIdx != viewModel.bookmarksBarItems.count else { return } // if already in the clipped items menu
            showSubmenu(for: clippedItemsBookmarkFolder(), fromView: clippedItemsIndicator)
            return
        }
        // switch to last folder in the Bookmarks Bar before the Clipped Items menu or after last folder if no clipped items
        for (idx, item) in viewModel.bookmarksBarItems.enumerated().reversed() {
            guard let folder = item.entity as? BookmarkFolder, let cell = bookmarksBarCollectionView.item(at: idx)?.view else { continue }
            showSubmenu(for: folder, fromView: cell)
            return
        }
    }

}

extension Notification.Name {

    static let bookmarkPromptShouldShow = Notification.Name(rawValue: "bookmarkPromptShouldShow")

}
