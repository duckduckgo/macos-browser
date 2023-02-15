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
    private let viewModel: BookmarksBarViewModel
    private let tabCollectionViewModel: TabCollectionViewModel

    private var viewModelCancellable: AnyCancellable?

    fileprivate var clipThreshold: CGFloat {
        let viewWidthWithoutClipIndicator = view.frame.width - clippedItemsIndicator.frame.minX
        return view.frame.width - viewWidthWithoutClipIndicator - 3
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.viewModel = BookmarksBarViewModel(bookmarkManager: LocalBookmarkManager.shared, tabCollectionViewModel: tabCollectionViewModel)

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("TabBarViewController: Bad initializer")
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
        frameChangeNotification()
    }

    private func subscribeToViewModel() {
        guard viewModelCancellable.isNil else {
            assertionFailure("Tried to subscribe to view model while it is already subscribed")
            return
        }

        viewModelCancellable = viewModel.$clippedItems.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.refreshClippedIndicator()
        }
    }

    @objc
    private func frameChangeNotification() {
        // Wait until the frame change has taken effect for subviews before calculating changes to the list of items.
        DispatchQueue.main.async {
            self.viewModel.clipOrRestoreBookmarksBarItems()
            self.refreshClippedIndicator()
        }
    }

    override func removeFromParent() {
        super.removeFromParent()
        unsubscribeFromEvents()
    }

    private func subscribeToEvents() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(frameChangeNotification),
                                               name: NSView.frameDidChangeNotification,
                                               object: view)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshFavicons),
                                               name: .faviconCacheUpdated,
                                               object: nil)

        subscribeToViewModel()
    }

    private func unsubscribeFromEvents() {
        NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .faviconCacheUpdated, object: nil)

        viewModelCancellable?.cancel()
        viewModelCancellable = nil
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

    @objc
    private func refreshFavicons() {
        bookmarksBarCollectionView.reloadData()
    }

    @IBAction
    private func clippedItemsIndicatorClicked(_ sender: NSButton) {
        let menu = viewModel.buildClippedItemsMenu()
        let location = NSPoint(x: 0, y: sender.frame.height + 5)

        menu.popUp(positioning: nil, at: location, in: sender)
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

    // swiftlint:disable:next cyclomatic_complexity
    private func handle(_ action: BookmarksBarViewModel.BookmarksBarItemAction, for bookmark: Bookmark) {
        switch action {
        case .openInNewTab:
            guard let url = bookmark.urlObject else { return }
            tabCollectionViewModel.appendNewTab(with: .url(url), selected: true)
        case .openInNewWindow:
            guard let url = bookmark.urlObject else { return }
            WindowsManager.openNewWindow(with: url)
        case .clickItem:
            WindowControllersManager.shared.open(bookmark: bookmark)
        case .addToFavorites:
            bookmark.isFavorite = true
            bookmarkManager.update(bookmark: bookmark)
        case .edit:
            let addBookmarkViewController = AddBookmarkModalViewController.create()
            addBookmarkViewController.delegate = self
            addBookmarkViewController.edit(bookmark: bookmark)
            beginSheet(addBookmarkViewController)
        case .moveToEnd:
            bookmarkManager.move(objectUUIDs: [bookmark.id], toIndex: nil, withinParentFolder: .root) { _ in }
        case .copyURL:
            guard let url = bookmark.urlObject else { return }
            NSPasteboard.general.copy(url: url)
        case .deleteEntity:
            bookmarkManager.remove(bookmark: bookmark)
        }
    }

    private func handle(_ action: BookmarksBarViewModel.BookmarksBarItemAction, for folder: BookmarkFolder, item: BookmarksBarCollectionViewItem) {
        switch action {
        case .clickItem:
            let childEntities = folder.children
            let viewModels = childEntities.map { BookmarkViewModel(entity: $0) }
            let menuItems = viewModel.bookmarksTreeMenuItems(from: viewModels, topLevel: true)
            let menu = bookmarkFolderMenu(items: menuItems)

            menu.popUp(positioning: nil, at: CGPoint(x: 0, y: item.view.frame.minY - 7), in: item.view)
        case .edit:
            let addFolderViewController = AddFolderModalViewController.create()
            addFolderViewController.delegate = self
            addFolderViewController.edit(folder: folder)
            beginSheet(addFolderViewController)
        case .moveToEnd:
            bookmarkManager.move(objectUUIDs: [folder.id], toIndex: nil, withinParentFolder: .root) { _ in }
        case .deleteEntity:
            bookmarkManager.remove(folder: folder)
        default:
            assertionFailure("Received unexpected action for bookmark folder")
        }
    }

    private func bookmarkFolderMenu(items: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu()
        menu.items = items.isEmpty ? [NSMenuItem.empty] : items
        return menu
    }

}

// MARK: - Menu

extension BookmarksBarViewController: NSMenuDelegate {

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if PersistentAppInterfaceSettings.shared.showBookmarksBar {
            menu.addItem(withTitle: UserText.hideBookmarksBar, action: #selector(toggleBookmarksBar), keyEquivalent: "")
        } else {
            menu.addItem(withTitle: UserText.showBookmarksBar, action: #selector(toggleBookmarksBar), keyEquivalent: "")
        }
    }

    @objc
    private func toggleBookmarksBar(_ sender: NSMenuItem) {
        PersistentAppInterfaceSettings.shared.showBookmarksBar.toggle()
    }

}

// MARK: - Editing

extension BookmarksBarViewController: AddBookmarkModalViewControllerDelegate, AddFolderModalViewControllerDelegate {

    func addFolderViewController(_ viewController: AddFolderModalViewController, addedFolderWith name: String) {
        assertionFailure("Cannot add new folders to the bookmarks bar via the modal")
    }

    func addFolderViewController(_ viewController: AddFolderModalViewController, saved folder: BookmarkFolder) {
        bookmarkManager.update(folder: folder)
    }

    func addBookmarkViewController(_ viewController: AddBookmarkModalViewController, addedBookmarkWithTitle title: String, url: URL) {
        assertionFailure("Cannot add new bookmarks to the bookmarks bar via the modal")
    }

    func addBookmarkViewController(_ viewController: AddBookmarkModalViewController, saved bookmark: Bookmark, newURL: URL) {
        bookmarkManager.update(bookmark: bookmark)
        _ = bookmarkManager.updateUrl(of: bookmark, to: newURL)
    }

}
