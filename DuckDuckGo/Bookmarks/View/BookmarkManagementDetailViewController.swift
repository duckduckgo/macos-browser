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

import AppKit
import Combine

protocol BookmarkManagementDetailViewControllerDelegate: AnyObject {

    func bookmarkManagementDetailViewControllerDidSelectFolder(_ folder: BookmarkFolder)

}

private struct EditedBookmarkMetadata {
    let uuid: String
    let index: Int
}

final class BookmarkManagementDetailViewController: NSViewController, NSMenuItemValidation {

    fileprivate enum Constants {
        static let animationSpeed: TimeInterval = 0.3
    }

    private lazy var newBookmarkButton = MouseOverButton(title: "  " + UserText.newBookmark, target: self, action: #selector(presentAddBookmarkModal))
    private lazy var newFolderButton = MouseOverButton(title: "  " + UserText.newFolder, target: self, action: #selector(presentAddFolderModal))

    private lazy var separator = NSBox()
    private lazy var scrollView = NSScrollView()
    private lazy var tableView = NSTableView()

    private lazy var emptyState = NSView()
    private lazy var emptyStateImageView = NSImageView(image: .bookmarksEmpty)
    private lazy var emptyStateTitle = NSTextField()
    private lazy var emptyStateMessage = NSTextField()
    private lazy var importButton = NSButton(title: UserText.importBookmarksButtonTitle, target: self, action: #selector(onImportClicked))

    weak var delegate: BookmarkManagementDetailViewControllerDelegate?

    private let bookmarkManager: BookmarkManager
    private var selectionState: BookmarkManagementSidebarViewController.SelectionState = .empty {
        didSet {
            editingBookmarkIndex = nil
            reloadData()
        }
    }

    private var isEditing: Bool {
        return editingBookmarkIndex != nil
    }

    private var editingBookmarkIndex: EditedBookmarkMetadata? {
        didSet {
            NSAnimationContext.runAnimationGroup { context in
                context.allowsImplicitAnimation = true
                context.duration = Constants.animationSpeed

                NSAppearance.withAppAppearance {
                    if editingBookmarkIndex != nil {
                        view.animator().layer?.backgroundColor = NSColor.backgroundSecondaryColor.cgColor
                    } else {
                        view.animator().layer?.backgroundColor = NSColor.interfaceBackgroundColor.cgColor
                    }
                }
            }
        }
    }

    func update(selectionState: BookmarkManagementSidebarViewController.SelectionState) {
        self.selectionState = selectionState
    }

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    // swiftlint:disable:next function_body_length
    override func loadView() {
        view = ColorView(frame: .zero, backgroundColor: .interfaceBackgroundColor)
        view.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(separator)
        view.addSubview(scrollView)
        view.addSubview(emptyState)
        view.addSubview(newBookmarkButton)
        view.addSubview(newFolderButton)

        newBookmarkButton.bezelStyle = .shadowlessSquare
        newBookmarkButton.cornerRadius = 4
        newBookmarkButton.normalTintColor = .button
        newBookmarkButton.mouseDownColor = .buttonMouseDownColor
        newBookmarkButton.mouseOverColor = .buttonMouseOverColor
        newBookmarkButton.imageHugsTitle = true
        newBookmarkButton.setContentHuggingPriority(.defaultHigh, for: .vertical)
        newBookmarkButton.translatesAutoresizingMaskIntoConstraints = false
        newBookmarkButton.alignment = .center
        newBookmarkButton.font = .systemFont(ofSize: 13)
        newBookmarkButton.image = .addBookmark
        newBookmarkButton.imagePosition = .imageLeading

        newFolderButton.bezelStyle = .shadowlessSquare
        newFolderButton.cornerRadius = 4
        newFolderButton.normalTintColor = .button
        newFolderButton.mouseDownColor = .buttonMouseDownColor
        newFolderButton.mouseOverColor = .buttonMouseOverColor
        newFolderButton.imageHugsTitle = true
        newFolderButton.setContentHuggingPriority(.defaultHigh, for: .vertical)
        newFolderButton.translatesAutoresizingMaskIntoConstraints = false
        newFolderButton.alignment = .center
        newFolderButton.font = .systemFont(ofSize: 13)
        newFolderButton.image = .addFolder
        newFolderButton.imagePosition = .imageLeading

        emptyState.addSubview(emptyStateImageView)
        emptyState.addSubview(emptyStateTitle)
        emptyState.addSubview(emptyStateMessage)
        emptyState.addSubview(importButton)

        emptyState.isHidden = true
        emptyState.translatesAutoresizingMaskIntoConstraints = false

        emptyStateTitle.isEditable = false
        emptyStateTitle.setContentHuggingPriority(.defaultHigh, for: .vertical)
        emptyStateTitle.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        emptyStateTitle.translatesAutoresizingMaskIntoConstraints = false
        emptyStateTitle.alignment = .center
        emptyStateTitle.drawsBackground = false
        emptyStateTitle.isBordered = false
        emptyStateTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        emptyStateTitle.textColor = .labelColor
        emptyStateTitle.attributedStringValue = NSAttributedString.make(UserText.bookmarksEmptyStateTitle,
                                                                        lineHeight: 1.14,
                                                                        kern: -0.23)

        emptyStateMessage.isEditable = false
        emptyStateMessage.setContentHuggingPriority(.defaultHigh, for: .vertical)
        emptyStateMessage.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        emptyStateMessage.translatesAutoresizingMaskIntoConstraints = false
        emptyStateMessage.alignment = .center
        emptyStateMessage.drawsBackground = false
        emptyStateMessage.isBordered = false
        emptyStateMessage.font = .systemFont(ofSize: 13)
        emptyStateMessage.textColor = .labelColor
        emptyStateMessage.attributedStringValue = NSAttributedString.make(UserText.bookmarksEmptyStateMessage,
                                                                          lineHeight: 1.05,
                                                                          kern: -0.08)

        emptyStateImageView.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        emptyStateImageView.setContentHuggingPriority(.init(rawValue: 251), for: .vertical)
        emptyStateImageView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateImageView.imageScaling = .scaleProportionallyDown

        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.usesPredominantAxisScrolling = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 22, left: 0, bottom: 22, right: 0)
        scrollView.menu = NSMenu()
        scrollView.menu!.delegate = self

        let clipView = NSClipView()
        clipView.documentView = tableView

        clipView.autoresizingMask = [.width, .height]
        clipView.backgroundColor = .clear
        clipView.drawsBackground = false
        clipView.frame = CGRect(x: 0, y: 0, width: 640, height: 601)

        tableView.addTableColumn(NSTableColumn())

        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        tableView.style = .plain
        tableView.selectionHighlightStyle = .none
        tableView.allowsMultipleSelection = true
        tableView.usesAutomaticRowHeights = true
        tableView.action = #selector(handleClick)
        tableView.doubleAction = #selector(handleDoubleClick)
        tableView.delegate = self
        tableView.dataSource = self

        scrollView.contentView = clipView

        separator.boxType = .separator
        separator.setContentHuggingPriority(.defaultHigh, for: .vertical)
        separator.translatesAutoresizingMaskIntoConstraints = false
        setupLayout()
    }

    private func setupLayout() {
        newBookmarkButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48).isActive = true
        view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: 48).isActive = true
        separator.topAnchor.constraint(equalTo: newBookmarkButton.bottomAnchor, constant: 24).isActive = true
        emptyState.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 20).isActive = true
        scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor).isActive = true

        view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
        view.trailingAnchor.constraint(greaterThanOrEqualTo: newFolderButton.trailingAnchor, constant: 20).isActive = true
        view.trailingAnchor.constraint(equalTo: separator.trailingAnchor, constant: 58).isActive = true
        newFolderButton.leadingAnchor.constraint(equalTo: newBookmarkButton.trailingAnchor, constant: 16).isActive = true
        emptyState.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        newFolderButton.centerYAnchor.constraint(equalTo: newBookmarkButton.centerYAnchor).isActive = true
        separator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 58).isActive = true
        newBookmarkButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 32).isActive = true
        emptyState.topAnchor.constraint(greaterThanOrEqualTo: separator.bottomAnchor, constant: 8).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48).isActive = true
        emptyState.centerXAnchor.constraint(equalTo: separator.centerXAnchor).isActive = true

        newBookmarkButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        newBookmarkButton.widthAnchor.constraint(equalToConstant: 130).isActive = true

        newFolderButton.widthAnchor.constraint(equalToConstant: 110).isActive = true
        newFolderButton.heightAnchor.constraint(equalToConstant: 24).isActive = true

        emptyStateMessage.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor).isActive = true

        importButton.translatesAutoresizingMaskIntoConstraints = false
        importButton.topAnchor.constraint(equalTo: emptyStateMessage.bottomAnchor, constant: 8).isActive = true
        emptyState.heightAnchor.constraint(equalToConstant: 218).isActive = true
        emptyStateMessage.topAnchor.constraint(equalTo: emptyStateTitle.bottomAnchor, constant: 8).isActive = true
        importButton.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor).isActive = true
        emptyStateImageView.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor).isActive = true
        emptyState.widthAnchor.constraint(equalToConstant: 224).isActive = true
        emptyStateImageView.topAnchor.constraint(equalTo: emptyState.topAnchor).isActive = true
        emptyStateTitle.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor).isActive = true
        emptyStateTitle.topAnchor.constraint(equalTo: emptyStateImageView.bottomAnchor, constant: 8).isActive = true

        emptyStateMessage.widthAnchor.constraint(equalToConstant: 192).isActive = true

        emptyStateTitle.widthAnchor.constraint(equalToConstant: 192).isActive = true

        emptyStateImageView.widthAnchor.constraint(equalToConstant: 128).isActive = true
        emptyStateImageView.heightAnchor.constraint(equalToConstant: 96).isActive = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.setDraggingSourceOperationMask([.move], forLocal: true)
        tableView.registerForDraggedTypes([BookmarkPasteboardWriter.bookmarkUTIInternalType,
                                           FolderPasteboardWriter.folderUTIInternalType])

        reloadData()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        editingBookmarkIndex = nil
        reloadData()
    }

    override func mouseUp(with event: NSEvent) {
        // Clicking anywhere outside of the table view should end editing mode for a given cell.
        updateEditingState(forRowAt: -1)
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == String(UnicodeScalar(NSDeleteCharacter)!) {
            deleteSelectedItems()
        }
    }

    fileprivate func reloadData() {
        guard editingBookmarkIndex == nil else {
            // If the table view is editing, the reload will be deferred until after the cell animation has completed.
            return
        }
        emptyState.isHidden = !(bookmarkManager.list?.topLevelEntities.isEmpty ?? true)

        let scrollPosition = tableView.visibleRect.origin
        tableView.reloadData()
        tableView.scroll(scrollPosition)
    }

    @objc func onImportClicked(_ sender: NSButton) {
        DataImportView().show()
    }

    @objc func handleDoubleClick(_ sender: NSTableView) {
        if sender.selectedRowIndexes.count > 1 {
            let entities = sender.selectedRowIndexes.map { fetchEntity(at: $0) }
            let bookmarks = entities.compactMap { $0 as? Bookmark }
            openBookmarksInNewTabs(bookmarks)

            return
        }

        let index = sender.clickedRow

        guard index != -1, editingBookmarkIndex?.index != index, let entity = fetchEntity(at: index) else {
            return
        }

        if let url = (entity as? Bookmark)?.urlObject {
            if NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
                WindowsManager.openNewWindow(with: url, source: .bookmark, isBurner: false)
            } else if NSApplication.shared.isCommandPressed {
                WindowControllersManager.shared.show(url: url, source: .bookmark, newTab: true)
            } else {
                WindowControllersManager.shared.show(url: url, source: .bookmark, newTab: true)
            }
        } else if let folder = entity as? BookmarkFolder {
            resetSelections()
            delegate?.bookmarkManagementDetailViewControllerDidSelectFolder(folder)
        }
    }

    @objc func handleClick(_ sender: NSTableView) {
        let index = sender.clickedRow

        if index != editingBookmarkIndex?.index {
            endEditing()
        }
    }

    @objc func presentAddBookmarkModal(_ sender: Any) {
        AddBookmarkModalView(model: AddBookmarkModalViewModel(parent: selectionState.folder))
            .show(in: view.window)
    }

    @objc func presentAddFolderModal(_ sender: Any) {
        AddBookmarkFolderModalView(model: AddBookmarkFolderModalViewModel(parent: selectionState.folder))
            .show(in: view.window)
    }

    @objc func delete(_ sender: AnyObject) {
        deleteSelectedItems()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(BookmarkManagementDetailViewController.delete(_:)) {
            return !tableView.selectedRowIndexes.isEmpty
        }

        return true
    }

    private func endEditing() {
        if let editingIndex = editingBookmarkIndex?.index {
            self.editingBookmarkIndex = nil
            animateEditingState(forRowAt: editingIndex, editing: false)
        }
    }

    private func updateEditingState(forRowAt index: Int) {
        guard index != -1 else {
            endEditing()
            return
        }

        if editingBookmarkIndex?.index == nil || editingBookmarkIndex?.index != index {
            endEditing()
        }

        if let entity = fetchEntity(at: index) {
            editingBookmarkIndex = EditedBookmarkMetadata(uuid: entity.id, index: index)
            animateEditingState(forRowAt: index, editing: true)
        } else {
            assertionFailure("\(#file): Failed to find entity when updating editing state")
        }
    }

    private func animateEditingState(forRowAt index: Int, editing: Bool, completion: (() -> Void)? = nil) {
        if let cell = tableView.view(atColumn: 0, row: index, makeIfNecessary: false) as? BookmarkTableCellView,
           let row = tableView.rowView(atRow: index, makeIfNecessary: false) as? BookmarkTableRowView {

            tableView.beginUpdates()
            NSAnimationContext.runAnimationGroup { context in
                context.allowsImplicitAnimation = true
                context.duration = Constants.animationSpeed
                context.completionHandler = completion

                cell.editing = editing
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
            return bookmarkManager.list?.topLevelEntities.count ?? 0
        case .folder(let folder):
            return folder.children.count
        case .favorites:
            return bookmarkManager.list?.favoriteBookmarks.count ?? 0
        }
    }

    private func deleteSelectedItems() {
        let entities = tableView.selectedRowIndexes.compactMap { fetchEntity(at: $0) }
        let entityUUIDs = entities.map(\.id)

        bookmarkManager.remove(objectsWithUUIDs: entityUUIDs)
    }

    private(set) lazy var faviconsFetcherOnboarding: FaviconsFetcherOnboarding? = {
        guard let syncService = NSApp.delegateTyped.syncService, let syncBookmarksAdapter = NSApp.delegateTyped.syncDataProviders?.bookmarksAdapter else {
            assertionFailure("SyncService and/or SyncBookmarksAdapter is nil")
            return nil
        }
        return .init(syncService: syncService, syncBookmarksAdapter: syncBookmarksAdapter)
    }()
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
        rowView.onSelectionChanged = onSelectionChanged

        let entity = fetchEntity(at: row)

        if let uuid = editingBookmarkIndex?.uuid, uuid == entity?.id {
            rowView.editing = true
        }

        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let entity = fetchEntity(at: row) else { return nil }

        let cell = tableView.makeView(withIdentifier: .init(BookmarkTableCellView.className()), owner: nil) as? BookmarkTableCellView
            ?? BookmarkTableCellView(identifier: .init(BookmarkTableCellView.className()))

        cell.delegate = self

        if let bookmark = entity as? Bookmark {
            cell.update(from: bookmark)
            cell.editing = bookmark.id == editingBookmarkIndex?.uuid

            if bookmark.favicon(.small) == nil {
                faviconsFetcherOnboarding?.presentOnboardingIfNeeded()
            }
        } else if let folder = entity as? BookmarkFolder {
            cell.update(from: folder)
            cell.editing = folder.id == editingBookmarkIndex?.uuid
        } else {
            assertionFailure("Failed to cast bookmark")
        }
        cell.isSelected = tableView.selectedRowIndexes.contains(row)

        return cell
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard let entity = fetchEntity(at: row) else { return nil }
        return entity.pasteboardWriter
    }

    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {

        if let proposedDestination = fetchEntity(at: row), proposedDestination.isFolder {
            if let bookmarks = PasteboardBookmark.pasteboardBookmarks(with: info.draggingPasteboard) {
                return validateDrop(for: bookmarks, destination: proposedDestination)
            }

            if let folders = PasteboardFolder.pasteboardFolders(with: info.draggingPasteboard) {
                return validateDrop(for: folders, destination: proposedDestination)
            }

            return .none
        } else {
            if dropOperation == .above {
                return .move
            } else {
                return .none
            }
        }
    }

    private func validateDrop(for draggedBookmarks: Set<PasteboardBookmark>, destination: BaseBookmarkEntity) -> NSDragOperation {
        guard destination is BookmarkFolder else {
            return .none
        }

        return .move
    }

    private func validateDrop(for draggedFolders: Set<PasteboardFolder>, destination: BaseBookmarkEntity) -> NSDragOperation {
        guard let destinationFolder = destination as? BookmarkFolder else {
            return .none
        }

        for folderID in draggedFolders.map(\.id) where !bookmarkManager.canMoveObjectWithUUID(objectUUID: folderID, to: destinationFolder) {
            return .none
        }

        let tryingToDragOntoSameFolder = draggedFolders.contains { folder in
            return folder.id == destination.id
        }

        if tryingToDragOntoSameFolder {
            return .none
        }

        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let draggedItemIdentifiers = info.draggingPasteboard.pasteboardItems?.compactMap(\.bookmarkEntityUUID),
              !draggedItemIdentifiers.isEmpty else {
            return false
        }

        if let parent = fetchEntity(at: row) as? BookmarkFolder, dropOperation == .on {
            bookmarkManager.add(objectsWithUUIDs: draggedItemIdentifiers, to: parent) { _ in }
            return true
        } else if let currentFolderUUID = selectionState.selectedFolderUUID {
            bookmarkManager.move(objectUUIDs: draggedItemIdentifiers,
                                 toIndex: row,
                                 withinParentFolder: .parent(uuid: currentFolderUUID)) { _ in }
            return true
        } else {
            if selectionState == .favorites {
                bookmarkManager.moveFavorites(with: draggedItemIdentifiers, toIndex: row) { _ in }
            } else {
                bookmarkManager.move(objectUUIDs: draggedItemIdentifiers,
                                     toIndex: row,
                                     withinParentFolder: .root) { _ in }
            }
            return true
        }
    }

    private func fetchEntity(at row: Int) -> BaseBookmarkEntity? {
        switch selectionState {
        case .empty:
            return bookmarkManager.list?.topLevelEntities[safe: row]
        case .folder(let folder):
            return folder.children[safe: row]
        case .favorites:
            return bookmarkManager.list?.favoriteBookmarks[safe: row]
        }
    }

    private func index(for entity: Bookmark) -> Int? {
        switch selectionState {
        case .empty:
            return bookmarkManager.list?.topLevelEntities.firstIndex(of: entity)
        case .folder(let folder):
            return folder.children.firstIndex(of: entity)
        case .favorites:
            return bookmarkManager.list?.favoriteBookmarks.firstIndex(of: entity)
        }
    }

    fileprivate func selectedItems() -> [AnyObject] {
        return tableView.selectedRowIndexes.compactMap { (index) -> AnyObject? in
            return fetchEntity(at: index) as AnyObject
        }
    }

    /// Updates the next/previous selection state of each row, and clears the selection flag.
    fileprivate func resetSelections() {
        guard totalRows() > 0 else { return }

        let indexes = tableView.selectedRowIndexes
        for index in 0 ..< totalRows() {
            let row = self.tableView.rowView(atRow: index, makeIfNecessary: false) as? BookmarkTableRowView
            row?.hasPrevious = indexes.contains(index - 1)
            row?.hasNext = indexes.contains(index + 1)

            let cell = self.tableView.view(atColumn: 0, row: index, makeIfNecessary: false) as? BookmarkTableCellView
            cell?.isSelected = false
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        onSelectionChanged()
    }

    func onSelectionChanged() {
        resetSelections()
        let indexes = tableView.selectedRowIndexes
        indexes.forEach {
            let cell = self.tableView.view(atColumn: 0, row: $0, makeIfNecessary: false) as? BookmarkTableCellView
            cell?.isSelected = true
        }
    }

    fileprivate func openBookmarksInNewTabs(_ bookmarks: [Bookmark]) {
        guard let tabCollection = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel else {
            assertionFailure("Cannot open in new tabs")
            return
        }

        let tabs = bookmarks.compactMap { $0.urlObject }.map {
            Tab(content: .url($0, source: .bookmark),
                shouldLoadInBackground: true,
                burnerMode: tabCollection.burnerMode)
        }
        tabCollection.append(tabs: tabs)
    }
}

// MARK: - BookmarkTableCellViewDelegate

extension BookmarkManagementDetailViewController: BookmarkTableCellViewDelegate {

    func bookmarkTableCellViewRequestedMenu(_ sender: NSButton, cell: BookmarkTableCellView) {
        guard !isEditing else { return }

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
        bookmarkManager.update(bookmark: bookmark)
    }

    func bookmarkTableCellView(_ cell: BookmarkTableCellView, updatedBookmarkWithUUID uuid: String, newTitle: String, newUrl: String) {
        let row = tableView.row(for: cell)
        defer {
            endEditing()
        }
        guard var bookmark = fetchEntity(at: row) as? Bookmark, bookmark.id == uuid else {
            return
        }

        if let url = newUrl.url, url.absoluteString != bookmark.url {
            bookmark = bookmarkManager.updateUrl(of: bookmark, to: url) ?? bookmark
        }
        let bookmarkTitle = newTitle.isEmpty ? bookmark.title : newTitle
        if bookmark.title != bookmarkTitle {
            bookmark.title = bookmarkTitle
            bookmarkManager.update(bookmark: bookmark)
        }
    }

}

// MARK: - NSMenuDelegate

extension BookmarkManagementDetailViewController: NSMenuDelegate {

    func contextualMenuForClickedRows() -> NSMenu? {
        guard !isEditing else { return nil }

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

        AddBookmarkFolderModalView(model: AddBookmarkFolderModalViewModel(folder: folder))
            .show(in: view.window)
    }

    func deleteFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Delete Folder context menu item")
            return
        }

        bookmarkManager.remove(folder: folder)
    }

    func openInNewTabs(_ sender: NSMenuItem) {
        if let children = (sender.representedObject as? BookmarkFolder)?.children {
            let bookmarks = children.compactMap { $0 as? Bookmark }
            openBookmarksInNewTabs(bookmarks)
        } else if let bookmarks = sender.representedObject as? [Bookmark] {
            openBookmarksInNewTabs(bookmarks)
        } else {
            assertionFailure("Failed to open entity in new tabs")
        }
    }

}

extension BookmarkManagementDetailViewController: BookmarkMenuItemSelectors {

    func openBookmarkInNewTab(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark,
        let url = bookmark.urlObject else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        WindowControllersManager.shared.show(url: url, source: .bookmark, newTab: true)
    }

    func openBookmarkInNewWindow(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark,
        let url = bookmark.urlObject else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        WindowsManager.openNewWindow(with: url, source: .bookmark, isBurner: false)
    }

    func toggleBookmarkAsFavorite(_ sender: NSMenuItem) {
        if let bookmark = sender.representedObject as? Bookmark {
            bookmark.isFavorite.toggle()
            bookmarkManager.update(bookmark: bookmark)
        } else if let bookmarks = sender.representedObject as? [Bookmark] {
            let bookmarkIdentifiers = bookmarks.map(\.id)
            bookmarkManager.update(objectsWithUUIDs: bookmarkIdentifiers, update: { entity in
                (entity as? Bookmark)?.isFavorite.toggle()
            }, completion: { error in
                if error != nil {
                    assertionFailure("Failed to update bookmarks: ")
                }
            })
        } else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
        }
    }

    func editBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark, let bookmarkIndex = index(for: bookmark) else { return }
        updateEditingState(forRowAt: bookmarkIndex)
    }

    func copyBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        bookmark.copyUrlToPasteboard()
    }

    func deleteBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        bookmarkManager.remove(bookmark: bookmark)
    }

    func deleteEntities(_ sender: NSMenuItem) {
        let uuids: [String]

        if let array = sender.representedObject as? [String] {
            uuids = array
        } else if let objects = sender.representedObject as? [BaseBookmarkEntity] {
            uuids = objects.map(\.id)
        } else {
            assertionFailure("Failed to cast menu item's represented object to UUID array")
            return
        }

        bookmarkManager.remove(objectsWithUUIDs: uuids)
    }

}

#if DEBUG
@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 700, height: 660)) {

    return BookmarkManagementDetailViewController(bookmarkManager: {
        let bkman = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [
            BookmarkFolder(id: "1", title: "Folder 1", children: [
                BookmarkFolder(id: "2", title: "Nested Folder", children: [
                    Bookmark(id: "b1", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: false, parentFolderUUID: "2")
                ])
            ]),
            BookmarkFolder(id: "3", title: "Another Folder", children: [
                BookmarkFolder(id: "4", title: "Nested Folder", children: [
                    BookmarkFolder(id: "5", title: "Another Nested Folder", children: [
                        Bookmark(id: "b2", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: false, parentFolderUUID: "5")
                    ])
                ])
            ]),
            Bookmark(id: "b3", url: URL.duckDuckGo.absoluteString, title: "Bookmark 1", isFavorite: false, parentFolderUUID: ""),
            Bookmark(id: "b4", url: URL.duckDuckGo.absoluteString, title: "Bookmark 2", isFavorite: false, parentFolderUUID: ""),
            Bookmark(id: "b5", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: false, parentFolderUUID: "")
        ]))
        bkman.loadBookmarks()
        customAssertionFailure = { _, _, _ in }

        return bkman
    }())

}
#endif
