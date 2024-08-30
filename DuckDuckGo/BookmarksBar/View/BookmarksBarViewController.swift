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
import os.log

final class BookmarksBarViewController: NSViewController {

    @IBOutlet weak var importBookmarksButton: NSView!
    @IBOutlet weak var importBookmarksMouseOverView: MouseOverView!
    @IBOutlet weak var importBookmarksLabel: NSTextField!
    @IBOutlet weak var importBookmarksIcon: NSImageView!
    @IBOutlet private var bookmarksBarCollectionView: NSCollectionView!
    @IBOutlet private var clippedItemsIndicator: NSButton!
    @IBOutlet private var promptAnchor: NSView!

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
            Logger.bookmarks.error("Item at mouseUp point not found.")
            return
        }

        viewModel.bookmarksBarCollectionViewItemClicked(item)
    }

}

extension BookmarksBarViewController: BookmarksBarViewModelDelegate {

    func didClick(_ item: BookmarksBarCollectionViewItem) {
        guard let indexPath = bookmarksBarCollectionView.indexPath(for: item) else {
            assertionFailure("Failed to look up index path for clicked item")
            return
        }

        guard let entity = bookmarkManager.list?.topLevelEntities[indexPath.item] else {
            assertionFailure("Failed to get entity for clicked item")
            return
        }

        switch entity {
        case let bookmark as Bookmark:
            WindowControllersManager.shared.open(bookmark: bookmark)
            PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
        case let folder as BookmarkFolder:
            showSubmenu(for: folder, from: item.view)
        default:
            assertionFailure("Failed to cast entity for clicked item")
        }
    }

    func bookmarksBarViewModelWidthForContainer() -> CGFloat {
        return clipThreshold
    }

    func bookmarksBarViewModelReloadedData() {
        bookmarksBarCollectionView.reloadData()
    }

    func showDialog(_ dialog: any ModalView) {
        dialog.show(in: view.window)
    }

}

// MARK: - Private

private extension BookmarksBarViewController {

    func bookmarkFolderMenu(items: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu()
        menu.items = items.isEmpty ? [NSMenuItem.empty] : items
        menu.autoenablesItems = false
        return menu
    }

    func showSubmenu(for folder: BookmarkFolder, from view: NSView) {
        let childEntities = folder.children
        let viewModels = childEntities.map { BookmarkViewModel(entity: $0) }
        let menuItems = viewModel.bookmarksTreeMenuItems(from: viewModels, topLevel: true)
        let menu = bookmarkFolderMenu(items: menuItems)

        menu.popUp(positioning: nil, at: CGPoint(x: 0, y: view.frame.minY - 7), in: view)
    }

    @objc func manageBookmarks() {
        WindowControllersManager.shared.showBookmarksTab()
    }

    @objc func addFolder(sender: NSMenuItem) {
        showDialog(BookmarksDialogViewFactory.makeAddBookmarkFolderView(parentFolder: nil))
    }

}
// MARK: - NSMenuDelegate
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

extension Notification.Name {

    static let bookmarkPromptShouldShow = Notification.Name(rawValue: "bookmarkPromptShouldShow")

}
