//
//  BookmarkListViewController.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

protocol BookmarkListViewControllerDelegate: AnyObject {

    func popoverShouldClose(_ bookmarkListViewController: BookmarkListViewController)

}

final class BookmarkListViewController: NSViewController {

    private enum Constants {
        static let storyboardName = "Bookmarks"
        static let identifier = "BookmarkListViewController"
    }

    static func create() -> BookmarkListViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    weak var delegate: BookmarkListViewControllerDelegate?

    @IBOutlet var outlineView: NSOutlineView!

    private var cancellables = Set<AnyCancellable>()
    private var bookmarkManager: BookmarkManager = LocalBookmarkManager.shared
    private let treeControllerDataSource = BookmarkListTreeControllerDataSource()

    private lazy var treeController: TreeController = {
        return TreeController(dataSource: treeControllerDataSource)
    }()

    private lazy var dataSource: BookmarkOutlineViewDataSource = {
        BookmarkOutlineViewDataSource(contentMode: .bookmarksAndFolders, treeController: treeController)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        outlineView.register(BookmarkOutlineViewCell.nib, forIdentifier: BookmarkOutlineViewCell.identifier)
        outlineView.dataSource = dataSource
        outlineView.delegate = dataSource
        outlineView.setDraggingSourceOperationMask([.copy], forLocal: true)
        outlineView.registerForDraggedTypes([BookmarkPasteboardWriter.bookmarkUTIInternalType,
                                             FolderPasteboardWriter.folderUTIInternalType])

        LocalBookmarkManager.shared.listPublisher.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.reloadData()
        }.store(in: &cancellables)
        
        LocalBookmarkManager.shared.topLevelItemsPublisher.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.reloadData()
        }.store(in: &cancellables)
    }

    private func reloadData() {
        treeController.rebuild()
        outlineView.reloadData()
    }

    @IBAction func newBookmarkButtonClicked(_ sender: AnyObject) {
        let newBookmarkViewController = AddBookmarkModalViewController.create()
        newBookmarkViewController.delegate = self
        presentAsModalWindow(newBookmarkViewController)
    }

    @IBAction func newFolderButtonClicked(_ sender: AnyObject) {
        let newFolderViewController = AddFolderModalViewController.create()
        newFolderViewController.delegate = self
        presentAsModalWindow(newFolderViewController)
    }

    @IBAction func openManagementInterface(_ sender: NSButton) {
        WindowControllersManager.shared.showBookmarksTab()
        delegate?.popoverShouldClose(self)
    }

    @IBAction func handleClick(_ sender: NSOutlineView) {
        guard sender.clickedRow != -1 else { return }

        if let node = sender.item(atRow: sender.clickedRow) as? BookmarkNode,
           let bookmark = node.representedObject as? Bookmark {
            WindowControllersManager.shared.show(url: bookmark.url)
            delegate?.popoverShouldClose(self)
        }
    }

}

// MARK: - Modal Delegates

extension BookmarkListViewController: AddBookmarkModalViewControllerDelegate, AddFolderModalViewControllerDelegate {

    func addBookmarkViewController(_ viewController: AddBookmarkModalViewController, addedBookmarkWithTitle title: String, url: String) {
        guard let url = URL(string: url) else { return }

        if !bookmarkManager.isUrlBookmarked(url: url) {
            bookmarkManager.makeBookmark(for: url, title: title, isFavorite: false)
        }
    }

    func addFolderViewController(_ viewController: AddFolderModalViewController, addedFolderWith name: String) {
        bookmarkManager.makeFolder(for: name, parent: nil)
    }

    func addFolderViewController(_ viewController: AddFolderModalViewController, saved folder: BookmarkFolder) {
        bookmarkManager.update(folder: folder)
    }

}

// MARK: - Menu Item Selectors

extension BookmarkListViewController: NSMenuDelegate {

    func contextualMenuForClickedRows() -> NSMenu? {
        let row = outlineView.clickedRow

        guard row != -1 else {
            return ContextualMenu.menu(for: nil)
        }

        if outlineView.selectedRowIndexes.contains(row) {
            return ContextualMenu.menu(for: outlineView.selectedItems)
        }

        if let item = outlineView.item(atRow: row) {
            return ContextualMenu.menu(for: [item])
        } else {
            return nil
        }
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        guard let contextualMenu = contextualMenuForClickedRows() else {
            return
        }

        let items = contextualMenu.items
        contextualMenu.removeAllItems()
        for menuItem in items {
            menu.addItem(menuItem)
        }
    }

}

extension BookmarkListViewController: BookmarkMenuItemSelectors {

    func openBookmarkInNewTab(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        WindowControllersManager.shared.show(url: bookmark.url, newTab: true)
    }

    func openBookmarkInNewWindow(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        WindowsManager.openNewWindow(with: bookmark.url)
    }

    func toggleBookmarkAsFavorite(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        bookmark.isFavorite.toggle()
        LocalBookmarkManager.shared.update(bookmark: bookmark)
    }

    func editBookmark(_ sender: NSMenuItem) {
        // No-op
    }

    func copyBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark, let bookmarkURL = bookmark.url as NSURL? else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.URL], owner: nil)
        bookmarkURL.write(to: pasteboard)
    }

    func deleteBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        LocalBookmarkManager.shared.remove(bookmark: bookmark)
    }

}

extension BookmarkListViewController: FolderMenuItemSelectors {

    func newFolder(_ sender: NSMenuItem) {
        newFolderButtonClicked(sender)
    }

    func renameFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Rename Folder context menu item")
            return
        }

        let addFolderViewController = AddFolderModalViewController.create()
        addFolderViewController.delegate = self
        addFolderViewController.edit(folder: folder)
        presentAsModalWindow(addFolderViewController)
    }

    func deleteFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Delete Folder context menu item")
            return
        }

        LocalBookmarkManager.shared.remove(folder: folder)
    }

}

// MARK: - BookmarkListPopover

final class BookmarkListPopover: NSPopover {

    override init() {
        super.init()

        self.animates = false
        self.behavior = .transient

        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("BookmarkListPopover: Bad initializer")
    }

    // swiftlint:disable force_cast
    var viewController: BookmarkListViewController { contentViewController as! BookmarkListViewController }
    // swiftlint:enable force_cast

    private func setupContentController() {
        let controller = BookmarkListViewController.create()
        controller.delegate = self
        contentViewController = controller
    }

}

extension BookmarkListPopover: BookmarkListViewControllerDelegate {

    func popoverShouldClose(_ bookmarkListViewController: BookmarkListViewController) {
        close()
    }

}
