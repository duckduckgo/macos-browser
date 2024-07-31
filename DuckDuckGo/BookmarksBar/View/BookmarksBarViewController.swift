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

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
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

        setUpImportBookmarksButton()

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

        clippedItemsIndicator.$isMouseOver
            .sink { [weak self] isMouseOver in
                guard isMouseOver, let self, let clippedItemsIndicator else { return }
                mouseDidHover(over: clippedItemsIndicator)
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
           bookmarkListPopover.rootFolder?.id == PseudoFolder.bookmarks.id {
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
            guard (bookmarkListPopover.viewController.representedObject as? BookmarkFolder)?.id != bookmarkFolder.id else { return }
            showSubmenu(for: bookmarkFolder, fromView: view)
        } else {
            bookmarkListPopover.close()
        }
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
                if (bookmarkListPopover.viewController.representedObject as? BookmarkFolder)?.id == folder.id {
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

extension BookmarksBarViewController: NSPopoverDelegate {

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        if NSApp.currentEvent?.type == .leftMouseUp {
           if let point = bookmarksBarCollectionView.mouseLocationInsideBounds(),
              let indexPath = bookmarksBarCollectionView.indexPathForItem(at: point),
              let _ = bookmarkManager.list?.topLevelEntities[safe: indexPath.item] as? BookmarkFolder {
               // we‘ll close the popover inside the click handler calling `showSubmenu`
               return false
           } else if clippedItemsIndicator.mouseLocationInsideBounds() != nil {
               // same
               return false
           }
        }

        return true
    }

}

extension Notification.Name {

    static let bookmarkPromptShouldShow = Notification.Name(rawValue: "bookmarkPromptShouldShow")

}
