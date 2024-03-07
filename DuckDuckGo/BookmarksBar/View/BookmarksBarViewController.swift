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

    @IBOutlet private var bookmarksBarCollectionView: NSCollectionView!
    @IBOutlet private var clippedItemsIndicator: NSButton!
    @IBOutlet private var promptAnchor: NSView!

    private let bookmarkManager = LocalBookmarkManager.shared
    private let viewModel: BookmarksBarViewModel
    private let tabCollectionViewModel: TabCollectionViewModel

    private var cancellables = Set<AnyCancellable>()

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

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel, bookmarkManager: BookmarkManager) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.viewModel = BookmarksBarViewModel(bookmarkManager: bookmarkManager, tabCollectionViewModel: tabCollectionViewModel)

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("BookmarksBarViewController: Bad initializer")
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        addContextMenu()

        viewModel.delegate = self

        let nib = NSNib(nibNamed: "BookmarksBarCollectionViewItem", bundle: .main)
        bookmarksBarCollectionView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        bookmarksBarCollectionView.register(nib, forItemWithIdentifier: BookmarksBarCollectionViewItem.identifier)
        bookmarksBarCollectionView.registerForDraggedTypes([
            .string,
            .URL,
            BookmarkPasteboardWriter.bookmarkUTIInternalType,
            FolderPasteboardWriter.folderUTIInternalType
        ])

        bookmarksBarCollectionView.delegate = viewModel
        bookmarksBarCollectionView.dataSource = viewModel
        bookmarksBarCollectionView.collectionViewLayout = createCenteredCollectionViewLayout()

        view.postsFrameChangedNotifications = true
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
    }

    private func unsubscribeFromEvents() {
        cancellables.removeAll()
    }

    // MARK: - Layout

    private func createCenteredLayout(centered: Bool) -> NSCollectionLayoutSection {
        let group = NSCollectionLayoutGroup.horizontallyCentered(cellSizes: viewModel.cellSizes, centered: centered)
        return NSCollectionLayoutSection(group: group)
    }

    func createCenteredCollectionViewLayout() -> NSCollectionViewLayout {
        return NSCollectionViewCompositionalLayout { [unowned self] _, _ in
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

    @IBAction
    private func clippedItemsIndicatorClicked(_ sender: NSButton) {
        let menu = viewModel.buildClippedItemsMenu()
        let location = NSPoint(x: 0, y: sender.frame.height + 5)

        menu.popUp(positioning: nil, at: location, in: sender)
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
            showDialog(view: BookmarksDialogViewFactory.makeAddBookmarkFolderView(parentFolder: nil))
        case .manageBookmarks:
            manageBookmarks()
        }
    }

    func handle(_ action: BookmarksBarViewModel.BookmarksBarItemAction, for folder: BookmarkFolder, item: BookmarksBarCollectionViewItem) {
        switch action {
        case .clickItem:
            showSubmenuFor(folder: folder, fromView: item.view)
        case .edit:
            showDialog(view: BookmarksDialogViewFactory.makeEditBookmarkFolderView(folder: folder, parentFolder: nil))
        case .moveToEnd:
            bookmarkManager.move(objectUUIDs: [folder.id], toIndex: nil, withinParentFolder: .root) { _ in }
        case .deleteEntity:
            bookmarkManager.remove(folder: folder)
        case .addFolder:
            showDialog(view: BookmarksDialogViewFactory.makeAddBookmarkFolderView(parentFolder: folder))
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
    }

    func openInNewWindow(bookmark: Bookmark) {
        guard let url = bookmark.urlObject else { return }
        WindowsManager.openNewWindow(with: url, source: .bookmark, isBurner: false)
    }

    func openAllInNewTabs(folder: BookmarkFolder) {
        let tabs = Tab.withContentOfBookmark(folder: folder, burnerMode: tabCollectionViewModel.burnerMode)
        tabCollectionViewModel.append(tabs: tabs)
    }

    func openAllInNewWindow(folder: BookmarkFolder) {
        let tabCollection = TabCollection.withContentOfBookmark(folder: folder, burnerMode: tabCollectionViewModel.burnerMode)
        WindowsManager.openNewWindow(with: tabCollection, isBurner: tabCollectionViewModel.isBurner)
    }

    func showSubmenuFor(folder: BookmarkFolder, fromView view: NSView) {
        let childEntities = folder.children
        let viewModels = childEntities.map { BookmarkViewModel(entity: $0) }
        let menuItems = viewModel.bookmarksTreeMenuItems(from: viewModels, topLevel: true)
        let menu = bookmarkFolderMenu(items: menuItems)

        menu.popUp(positioning: nil, at: CGPoint(x: 0, y: view.frame.minY - 7), in: view)
    }

    func showDialog(view: any ModalView) {
        view.show(in: self.view.window)
    }

    func manageBookmarks() {
        WindowControllersManager.shared.showBookmarksTab()
    }

}

// MARK: - Menu

extension BookmarksBarViewController: NSMenuDelegate {

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        BookmarksBarMenuFactory.addToMenu(menu)
    }

}

extension Notification.Name {

    static let bookmarkPromptShouldShow = Notification.Name(rawValue: "bookmarkPromptShouldShow")

}
