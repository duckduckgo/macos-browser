//
//  BookmarkManagementDetailViewController.swift
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

import Foundation
import Combine

protocol BookmarkManagementDetailViewControllerDelegate: AnyObject {

    func bookmarkManagementDetailViewControllerDidSelectFolder(_ folder: BookmarkFolder)

}

final class BookmarkManagementDetailViewController: NSViewController {

    fileprivate enum Constants {
        static let bookmarkCellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "BookmarksCellIdentifier")
        static let animationSpeed: TimeInterval = 0.3
    }

    @IBOutlet var tableView: NSTableView!

    weak var delegate: BookmarkManagementDetailViewControllerDelegate?

    private var bookmarkManager: BookmarkManager = LocalBookmarkManager.shared
    private var bookmarkListCancellable: AnyCancellable?
    private var selectionState: BookmarkManagementSidebarViewController.SelectionState = .empty {
        didSet {
            reloadData()
        }
    }

    private var editingBookmarkIndex: Int? {
        didSet {
            NSAnimationContext.runAnimationGroup { context in
                context.allowsImplicitAnimation = true
                context.duration = Constants.animationSpeed

                if editingBookmarkIndex != nil {
                    NSAppearance.withAppAppearance {
                        view.animator().layer?.backgroundColor = NSColor(named: "BackgroundSecondaryColor")!.cgColor
                    }
                } else {
                    view.animator().layer?.backgroundColor = NSColor.clear.cgColor
                }
            }
        }
    }

    func update(selectionState: BookmarkManagementSidebarViewController.SelectionState) {
        self.selectionState = selectionState
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let nib = NSNib(nibNamed: "BookmarkTableCellView", bundle: Bundle.main)
        tableView.register(nib, forIdentifier: Constants.bookmarkCellIdentifier)
        tableView.setDraggingSourceOperationMask([.copy], forLocal: true)
        tableView.registerForDraggedTypes([BookmarkPasteboardWriter.bookmarkUTIInternalType,
                                           FolderPasteboardWriter.folderUTIInternalType])

        configureTableHighlight()
        reloadData()
    }

    func configureTableHighlight() {
        tableView.selectionHighlightStyle = .none
    }

    fileprivate func reloadData() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    @IBAction func handleClick(_ sender: NSTableView) {
        let index = sender.clickedRow

        guard index != -1, let entity = fetchEntity(at: index) else {
            updateEditingState(forRowAt: index)
            return
        }

        let row = sender.view(atColumn: 0, row: index, makeIfNecessary: false) as? BookmarkTableCellView

        if row?.isEditing ?? false {
            return
        }

        // 1. Command: Open in Background Tab
        // 2. Command + Shift: Open in New Window
        // 3. Default: Open in Current Tab

        if let bookmark = entity as? Bookmark {
            if NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
                WindowsManager.openNewWindow(with: bookmark.url)
            } else if NSApplication.shared.isCommandPressed {
                WindowControllersManager.shared.show(url: bookmark.url, newTab: true)
            } else {
                WindowControllersManager.shared.show(url: bookmark.url)
                tableView.deselectAll(nil)
            }
        } else if let folder = entity as? BookmarkFolder {
            delegate?.bookmarkManagementDetailViewControllerDidSelectFolder(folder)
        } else {
            assertionFailure("\(#file): Failed to cast selected object to Folder or Bookmark")
        }
    }

    @IBAction func presentAddBookmarkModal(_ sender: Any) {
        let addBookmarkViewController = AddBookmarkModalViewController.create()
        addBookmarkViewController.delegate = self
        beginSheet(addBookmarkViewController)
    }

    @IBAction func presentAddFolderModal(_ sender: Any) {
        let addFolderViewController = AddFolderModalViewController.create()
        addFolderViewController.delegate = self
        beginSheet(addFolderViewController)
    }

    private func updateEditingState(forRowAt index: Int) {
        guard index != -1 else {
            if let expandedIndex = self.editingBookmarkIndex {
                animateEditingState(forRowAt: expandedIndex, editing: false)
                self.editingBookmarkIndex = nil
            }

            return
        }

        // Cancel the current editing state, if one exists.
        if let expandedIndex = self.editingBookmarkIndex {
            animateEditingState(forRowAt: expandedIndex, editing: false)
            self.editingBookmarkIndex = nil
        }

        // If the current expanded row matches the one that has just been double clicked, we're going to deselect it.
        if editingBookmarkIndex == index {
            editingBookmarkIndex = nil
            animateEditingState(forRowAt: index, editing: false)
        } else {
            editingBookmarkIndex = index
            animateEditingState(forRowAt: index, editing: true)
        }
    }

    private func animateEditingState(forRowAt index: Int, editing: Bool) {
        if let cell = tableView.view(atColumn: 0, row: index, makeIfNecessary: false) as? BookmarkTableCellView,
           let row = tableView.rowView(atRow: index, makeIfNecessary: false) as? BookmarkTableRowView {

            tableView.beginUpdates()
            NSAnimationContext.runAnimationGroup { context in
                context.allowsImplicitAnimation = true
                context.duration = Constants.animationSpeed

                cell.isEditing = editing
                row.editing = editing

                row.layoutSubtreeIfNeeded()
                cell.layoutSubtreeIfNeeded()
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(arrayLiteral: 0, index))
            }

            tableView.endUpdates()
        }
    }

    private func totalRows() -> Int {
        switch selectionState {
        case .empty:
            return LocalBookmarkManager.shared.topLevelItems?.count ?? 0
        case .folder(let folder):
            return folder.children.count
        case .favorites:
            return LocalBookmarkManager.shared.list?.favoriteBookmarks.count ?? 0
        }
    }

}

// MARK: - Modal Delegates

extension BookmarkManagementDetailViewController: AddBookmarkModalViewControllerDelegate, AddFolderModalViewControllerDelegate {
    
    func addBookmarkViewController(_ viewController: AddBookmarkModalViewController, addedBookmarkWithTitle title: String, url: String) {
        guard let url = URL(string: url) else { return }

        if !bookmarkManager.isUrlBookmarked(url: url) {
            bookmarkManager.makeBookmark(for: url, title: title, isFavorite: false)
        }
    }

    func addFolderViewController(_ viewController: AddFolderModalViewController, addedFolderWith name: String) {
        if case let .folder(selectedFolder) = selectionState {
            bookmarkManager.makeFolder(for: name, parent: selectedFolder)
        } else {
            bookmarkManager.makeFolder(for: name, parent: nil)
        }
    }

    func addFolderViewController(_ viewController: AddFolderModalViewController, saved folder: BookmarkFolder) {
        bookmarkManager.update(folder: folder)
    }

}

// MARK: - NSTableView

extension BookmarkManagementDetailViewController: NSTableViewDelegate, NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return totalRows()
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return fetchEntity(at: row)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = BookmarkTableRowView()

        if let index = editingBookmarkIndex, index == row {
            rowView.editing = true
        }

        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let entity = fetchEntity(at: row) else { return nil }

        if let cell = tableView.makeView(withIdentifier: Constants.bookmarkCellIdentifier, owner: nil) as? BookmarkTableCellView {
            cell.delegate = self

            if let bookmark = entity as? Bookmark {
                cell.update(from: bookmark)
            } else if let folder = entity as? BookmarkFolder {
                cell.update(from: folder)
            } else {
                assertionFailure("Failed to cast bookmark")
            }

            if let index = editingBookmarkIndex, index == row {
                cell.isEditing = true
            } else {
                cell.isEditing = false
            }

            return cell
        }

        return nil
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard let entity = fetchEntity(at: row) else { return nil }
        return entity.pasteboardWriter
    }

    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {

        guard dropOperation == .on,
              row < totalRows(),
              let proposedBookmark = fetchEntity(at: row),
              proposedBookmark.isFolder else {
            return .none
        }

        let draggedBookmarks = PasteboardBookmark.pasteboardBookmarks(with: info.draggingPasteboard) ?? Set<PasteboardBookmark>()

        let tryingToDragOntoSameFolder = draggedBookmarks.contains { folder in
            return folder.id == proposedBookmark.id.uuidString
        }

        if tryingToDragOntoSameFolder {
            return .none
        }

        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let parent = fetchEntity(at: row) as? BookmarkFolder else { return false }

        let draggedBookmarks = PasteboardBookmark.pasteboardBookmarks(with: info.draggingPasteboard) ?? Set<PasteboardBookmark>()
        let draggedFolders = PasteboardFolder.pasteboardFolders(with: info.draggingPasteboard) ?? Set<PasteboardFolder>()

        if draggedBookmarks.isEmpty && draggedFolders.isEmpty {
            return false
        }

        let draggedObjectIdentifierStrings = draggedBookmarks.map(\.id) + draggedFolders.map(\.id)
        let draggedObjectIdentifiers = draggedObjectIdentifierStrings.compactMap(UUID.init(uuidString:))

        LocalBookmarkManager.shared.add(objectsWithUUIDs: draggedObjectIdentifiers, to: parent) { _ in
            // Does anything need to happen here?
        }

        return true
    }

    private func fetchEntity(at row: Int) -> BaseBookmarkEntity? {
        switch selectionState {
        case .empty:
            return LocalBookmarkManager.shared.topLevelItems?[row]
        case .folder(let folder):
            return folder.children[row]
        case .favorites:
            return LocalBookmarkManager.shared.list?.favoriteBookmarks[row]
        }
    }

    private func index(for entity: Bookmark) -> Int? {
        switch selectionState {
        case .empty:
            return LocalBookmarkManager.shared.topLevelItems?.firstIndex(of: entity)
        case .folder(let folder):
            return folder.children.firstIndex(of: entity)
        case .favorites:
            return LocalBookmarkManager.shared.list?.favoriteBookmarks.firstIndex(of: entity)
        }
    }

    fileprivate func selectedItems() -> [AnyObject] {
        return tableView.selectedRowIndexes.compactMap { (index) -> AnyObject? in
            return fetchEntity(at: index) as AnyObject
        }
    }

}

// MARK: - BookmarkTableCellViewDelegate

extension BookmarkManagementDetailViewController: BookmarkTableCellViewDelegate {

    func bookmarkTableCellViewRequestedMenu(_ sender: NSButton, cell: BookmarkTableCellView) {
        let row = tableView.row(for: cell)

        guard let bookmark = fetchEntity(at: row) as? Bookmark else {
            assertionFailure("BookmarkManagementDetailViewController: Tried to present bookmark menu for nil bookmark or folder")
            return
        }

        if let contextMenu = ContextualMenu.menu(for: [bookmark]), let cursorLocation = self.view.window?.mouseLocationOutsideOfEventStream {
            let convertedLocation = self.view.convert(cursorLocation, from: nil)
            contextMenu.items.forEach { item in
                item.target = self
            }

            contextMenu.popUp(positioning: nil, at: convertedLocation, in: self.view)
        }
    }

    func bookmarkTableCellViewToggledFavorite(cell: BookmarkTableCellView) {
        let row = tableView.row(for: cell)

        guard let bookmark = fetchEntity(at: row) as? Bookmark else {
            assertionFailure("BookmarkManagementDetailViewController: Tried to favorite object which is not bookmark")
            return
        }

        bookmark.isFavorite.toggle()
        LocalBookmarkManager.shared.update(bookmark: bookmark)
    }

}

// MARK: - NSMenuDelegate

extension BookmarkManagementDetailViewController: NSMenuDelegate {

    func contextualMenuForClickedRows() -> NSMenu? {
        let row = tableView.clickedRow

        guard row != -1 else {
            return ContextualMenu.menu(for: nil)
        }

        if tableView.selectedRowIndexes.contains(row) {
            return ContextualMenu.menu(for: self.selectedItems())
        }

        if let item = fetchEntity(at: row) {
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

// MARK: - Menu Item Selectors

extension BookmarkManagementDetailViewController: FolderMenuItemSelectors {

    func newFolder(_ sender: NSMenuItem) {
        presentAddFolderModal(sender)
    }

    func renameFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to cast menu represented object to BookmarkFolder")
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

extension BookmarkManagementDetailViewController: BookmarkMenuItemSelectors {

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
        guard let bookmark = sender.representedObject as? Bookmark, let bookmarkIndex = index(for: bookmark) else { return }
        updateEditingState(forRowAt: bookmarkIndex)
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
