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
    var currentTabWebsite: AddBookmarkModalViewController.WebsiteInfo?

    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet var contextMenu: NSMenu!
    @IBOutlet var emptyState: NSView!
    @IBOutlet var emptyStateTitle: NSTextField!
    @IBOutlet var emptyStateMessage: NSTextField!

    private var cancellables = Set<AnyCancellable>()
    private var bookmarkManager: BookmarkManager = LocalBookmarkManager.shared
    private let treeControllerDataSource = BookmarkListTreeControllerDataSource()
    
    private var mouseUpEventsMonitor: Any?
    private var mouseDownEventsMonitor: Any?
    private var appObserver: Any?
    
    private lazy var treeController: BookmarkTreeController = {
        return BookmarkTreeController(dataSource: treeControllerDataSource)
    }()
    
    private lazy var dataSource: BookmarkOutlineViewDataSource = {
        BookmarkOutlineViewDataSource(contentMode: .bookmarksAndFolders, treeController: treeController)
    }()
    
    private var selectedNodes: [BookmarkNode] {
        if let nodes = outlineView.selectedItems as? [BookmarkNode] {
            return nodes
        }
        return [BookmarkNode]()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.subscribeForAppApperanceUpdates()?.store(in: &cancellables)
        preferredContentSize = CGSize(width: 420, height: 500)
        
        outlineView.register(BookmarkOutlineViewCell.nib, forIdentifier: BookmarkOutlineViewCell.identifier)
        outlineView.dataSource = dataSource
        outlineView.delegate = dataSource
        outlineView.setDraggingSourceOperationMask([.move], forLocal: true)
        outlineView.registerForDraggedTypes([BookmarkPasteboardWriter.bookmarkUTIInternalType,
                                             FolderPasteboardWriter.folderUTIInternalType])
        
        LocalBookmarkManager.shared.listPublisher.receive(on: DispatchQueue.main).sink { [weak self] list in
            self?.reloadData()
            let isEmpty = list?.topLevelEntities.isEmpty ?? true
            self?.emptyState.isHidden = !isEmpty
            self?.outlineView.isHidden = isEmpty
        }.store(in: &cancellables)

        emptyStateTitle.attributedStringValue = NSAttributedString.make(emptyStateTitle.stringValue, lineHeight: 1.14, kern: -0.23)
        emptyStateMessage.attributedStringValue = NSAttributedString.make(emptyStateMessage.stringValue, lineHeight: 1.05, kern: -0.08)
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        reloadData()
    }

    private func reloadData() {
        let selectedNodes = self.selectedNodes
        
        dataSource.reloadData()
        outlineView.reloadData()
        
        expandAndRestore(selectedNodes: selectedNodes)
    }
    
    @IBAction func newBookmarkButtonClicked(_ sender: AnyObject) {
        let newBookmarkViewController = AddBookmarkModalViewController.create()
        newBookmarkViewController.currentTabWebsite = currentTabWebsite
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
        Pixel.fire(.manageBookmarks(source: .button))
    }
    
    @IBAction func handleClick(_ sender: NSOutlineView) {
        guard sender.clickedRow != -1 else { return }

        let item = sender.item(atRow: sender.clickedRow)
        if let node = item as? BookmarkNode,
           let bookmark = node.representedObject as? Bookmark {
            WindowControllersManager.shared.open(bookmark: bookmark)
            delegate?.popoverShouldClose(self)
            Pixel.fire(.navigation(kind: .bookmark(isFavorite: bookmark.isFavorite), source: .listInterface))
        } else {
            if outlineView.isItemExpanded(item) {
                outlineView.animator().collapseItem(item)
            } else {
                outlineView.animator().expandItem(item)
            }
        }
    }

    @IBAction func onImportClicked(_ sender: NSButton) {
        DataImportViewController.show()
    }

    // MARK: NSOutlineView Configuration
    
    private func expandAndRestore(selectedNodes: [BookmarkNode]) {
        treeController.visitNodes { node in
            if let objectID = (node.representedObject as? BaseBookmarkEntity)?.id {
                if dataSource.expandedNodes.contains(objectID) {
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
                    if dataSource.expandedNodes.contains(pseudoFolder.id) {
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
    
}

// MARK: - Modal Delegates

extension BookmarkListViewController: AddBookmarkModalViewControllerDelegate, AddFolderModalViewControllerDelegate {
    
    func addBookmarkViewController(_ viewController: AddBookmarkModalViewController, addedBookmarkWithTitle title: String, url: URL) {
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
            return ContextualMenu.menu(for: outlineView.selectedItems, includeBookmarkEditMenu: false)
        }
        
        if let item = outlineView.item(atRow: row) {
            return ContextualMenu.menu(for: [item], includeBookmarkEditMenu: false)
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
        // Unsupported in the list view for the initial release.
    }
    
    func copyBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark, let bookmarkURL = bookmark.url as NSURL? else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.URL], owner: nil)
        bookmarkURL.write(to: pasteboard)
        pasteboard.setString(bookmarkURL.absoluteString ?? "", forType: .string)
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

    // swiftlint:disable:next force_cast
    var viewController: BookmarkListViewController { contentViewController as! BookmarkListViewController }

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
