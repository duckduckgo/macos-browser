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
    func bookmarkManagementDetailViewControllerDidStartSearching()

}

private struct EditedBookmarkMetadata {
    let uuid: String
    let index: Int
}

final class BookmarkManagementDetailViewController: NSViewController, NSMenuItemValidation {

    private let toolbarButtonsStackView = NSStackView()
    private lazy var newBookmarkButton = MouseOverButton(title: "  " + UserText.newBookmark, target: self, action: #selector(presentAddBookmarkModal))
        .withAccessibilityIdentifier("BookmarkManagementDetailViewController.newBookmarkButton")
    private lazy var newFolderButton = MouseOverButton(title: "  " + UserText.newFolder, target: self, action: #selector(presentAddFolderModal))
        .withAccessibilityIdentifier("BookmarkManagementDetailViewController.newFolderButton")
    private lazy var deleteItemsButton = MouseOverButton(title: "  " + UserText.bookmarksBarContextMenuDelete, target: self, action: #selector(delete))
        .withAccessibilityIdentifier("BookmarkManagementDetailViewController.deleteItemsButton")

    lazy var searchBar = NSSearchField()
    private lazy var separator = NSBox()
    private lazy var scrollView = NSScrollView()
    private lazy var tableView = NSTableView()


    private lazy var emptyState = NSView()
    private lazy var emptyStateImageView = NSImageView(image: .bookmarksEmpty)
    private lazy var emptyStateTitle = NSTextField()
    private lazy var emptyStateMessage = NSTextField()
    private lazy var importButton = NSButton(title: UserText.importBookmarksButtonTitle, target: self, action: #selector(onImportClicked))

    weak var delegate: BookmarkManagementDetailViewControllerDelegate?

    private let managementDetailViewModel: BookmarkManagementDetailViewModel
    private let bookmarkManager: BookmarkManager
    private var selectionState: BookmarkManagementSidebarViewController.SelectionState = .empty {
        didSet {
            reloadData()
        }
    }

    func update(selectionState: BookmarkManagementSidebarViewController.SelectionState) {
        self.clearSearch()
        managementDetailViewModel.update(selection: selectionState)
        self.selectionState = selectionState
    }

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
        self.managementDetailViewModel = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    override func loadView() {
        view = ColorView(frame: .zero, backgroundColor: .bookmarkPageBackground)
        view.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(separator)
        view.addSubview(scrollView)
        view.addSubview(emptyState)
        view.addSubview(toolbarButtonsStackView)
        view.addSubview(searchBar)
        toolbarButtonsStackView.addArrangedSubview(newBookmarkButton)
        toolbarButtonsStackView.addArrangedSubview(newFolderButton)
        toolbarButtonsStackView.addArrangedSubview(deleteItemsButton)
        toolbarButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
        toolbarButtonsStackView.distribution = .fill

        configureToolbar(button: newBookmarkButton, image: .addBookmark, isHidden: false)
        configureToolbar(button: newFolderButton, image: .addFolder, isHidden: false)
        configureToolbar(button: deleteItemsButton, image: .trash, isHidden: true)

        emptyState.addSubview(emptyStateImageView)
        emptyState.addSubview(emptyStateTitle)
        emptyState.addSubview(emptyStateMessage)
        emptyState.addSubview(importButton)

        emptyState.isHidden = true
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        importButton.translatesAutoresizingMaskIntoConstraints = false

        configureEmptyState(
            label: emptyStateTitle,
            font: .systemFont(ofSize: 15, weight: .semibold),
            attributedTitle: .make(
                UserText.bookmarksEmptyStateTitle,
                lineHeight: 1.14,
                kern: -0.23
            )
        )

        configureEmptyState(
            label: emptyStateMessage,
            font: .systemFont(ofSize: 13),
            attributedTitle: .make(
                UserText.bookmarksEmptyStateMessage,
                lineHeight: 1.05,
                kern: -0.08
            )
        )

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
        tableView.doubleAction = #selector(handleDoubleClick)
        tableView.delegate = self
        tableView.dataSource = self

        scrollView.contentView = clipView

        separator.boxType = .separator
        separator.setContentHuggingPriority(.defaultHigh, for: .vertical)
        separator.translatesAutoresizingMaskIntoConstraints = false

        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholderString = UserText.bookmarksSearch
        searchBar.delegate = self

        setupLayout()
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            toolbarButtonsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: 48),
            separator.topAnchor.constraint(equalTo: toolbarButtonsStackView.bottomAnchor, constant: 24),
            emptyState.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 20),
            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),

            searchBar.heightAnchor.constraint(equalToConstant: 28),
            searchBar.leadingAnchor.constraint(greaterThanOrEqualTo: toolbarButtonsStackView.trailingAnchor, constant: 8),
            searchBar.widthAnchor.constraint(equalToConstant: 256),
            searchBar.centerYAnchor.constraint(equalTo: toolbarButtonsStackView.centerYAnchor),
            searchBar.trailingAnchor.constraint(equalTo: separator.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            view.trailingAnchor.constraint(greaterThanOrEqualTo: searchBar.trailingAnchor, constant: 20),
            view.trailingAnchor.constraint(equalTo: separator.trailingAnchor, constant: 58),
            emptyState.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 58),
            toolbarButtonsStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 32),
            emptyState.topAnchor.constraint(greaterThanOrEqualTo: separator.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            emptyState.centerXAnchor.constraint(equalTo: separator.centerXAnchor),

            newBookmarkButton.heightAnchor.constraint(equalToConstant: 24),
            newFolderButton.heightAnchor.constraint(equalToConstant: 24),
            deleteItemsButton.heightAnchor.constraint(equalToConstant: 24),

            emptyStateMessage.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor),

            importButton.topAnchor.constraint(equalTo: emptyStateMessage.bottomAnchor, constant: 8),
            emptyState.heightAnchor.constraint(equalToConstant: 218),
            emptyStateMessage.topAnchor.constraint(equalTo: emptyStateTitle.bottomAnchor, constant: 8),
            importButton.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor),
            emptyStateImageView.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor),
            emptyState.widthAnchor.constraint(equalToConstant: 224),
            emptyStateImageView.topAnchor.constraint(equalTo: emptyState.topAnchor),
            emptyStateTitle.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor),
            emptyStateTitle.topAnchor.constraint(equalTo: emptyStateImageView.bottomAnchor, constant: 8),

            emptyStateMessage.widthAnchor.constraint(equalToConstant: 192),

            emptyStateTitle.widthAnchor.constraint(equalToConstant: 192),

            emptyStateImageView.widthAnchor.constraint(equalToConstant: 128),
            emptyStateImageView.heightAnchor.constraint(equalToConstant: 96)
        ])

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
        reloadData()
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == String(UnicodeScalar(NSDeleteCharacter)!) {
            deleteSelectedItems()
        } else {
            let commandKeyDown = event.modifierFlags.contains(.command)
            if commandKeyDown && event.keyCode == 3 { // CMD + F
                searchBar.makeMeFirstResponder()
            }
        }
    }

    fileprivate func reloadData() {
        handleItemsVisibility()

        let scrollPosition = tableView.visibleRect.origin
        tableView.reloadData()
        tableView.scroll(scrollPosition)

        updateToolbarButtons()
    }

    private func handleItemsVisibility() {
        switch managementDetailViewModel.contentState {
        case .empty(let emptyState):
            showEmptyStateView(for: emptyState)
        case .nonEmpty:
            emptyState.isHidden = true
            tableView.isHidden = false
        }
    }

    private func showEmptyStateView(for mode: BookmarksEmptyStateContent) {
        tableView.isHidden = true
        emptyState.isHidden = false
        emptyStateTitle.stringValue = mode.title
        emptyStateMessage.stringValue = mode.description
        emptyStateImageView.image = mode.image
        importButton.isHidden = mode.shouldHideImportButton
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

        guard index != -1, let entity = fetchEntity(at: index) else {
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
            clearSearch()
            resetSelections()
            delegate?.bookmarkManagementDetailViewControllerDidSelectFolder(folder)
        }
    }

    @objc func presentAddBookmarkModal(_ sender: Any) {
        BookmarksDialogViewFactory.makeAddBookmarkView(parent: selectionState.folder)
            .show(in: view.window)
    }

    @objc func presentAddFolderModal(_ sender: Any) {
        BookmarksDialogViewFactory.makeAddBookmarkFolderView(parentFolder: selectionState.folder)
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

    private func totalRows() -> Int {
        return managementDetailViewModel.totalRows()
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

        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let entity = fetchEntity(at: row) else { return nil }

        let cell = tableView.makeView(withIdentifier: .init(BookmarkTableCellView.className()), owner: nil) as? BookmarkTableCellView
            ?? BookmarkTableCellView(identifier: .init(BookmarkTableCellView.className()))

        cell.delegate = self

        if let bookmark = entity as? Bookmark {
            cell.update(from: bookmark)

            if bookmark.favicon(.small) == nil {
                faviconsFetcherOnboarding?.presentOnboardingIfNeeded()
            }
        } else if let folder = entity as? BookmarkFolder {
            cell.update(from: folder)
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
        return managementDetailViewModel.validateDrop(pasteboardItems: info.draggingPasteboard.pasteboardItems,
                                                      proposedRow: row,
                                                      proposedDropOperation: dropOperation)
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
        return managementDetailViewModel.fetchEntity(at: row)
    }

    private func fetchEntityAndParent(at row: Int) -> (entity: BaseBookmarkEntity?, parentFolder: BookmarkFolder?) {
        return managementDetailViewModel.fetchEntityAndParent(at: row)
    }

    private func index(for entity: Bookmark) -> Int? {
        return managementDetailViewModel.index(for: entity)
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

    private func clearSearch() {
        searchBar.stringValue = ""
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        onSelectionChanged()
    }

    func onSelectionChanged() {
        func updateCellSelections() {
            resetSelections()
            tableView.selectedRowIndexes.forEach {
                let cell = self.tableView.view(atColumn: 0, row: $0, makeIfNecessary: false) as? BookmarkTableCellView
                cell?.isSelected = true
            }
        }

        updateCellSelections()
        updateToolbarButtons()
    }

    private func updateToolbarButtons() {
        let shouldShowDeleteButton = tableView.selectedRowIndexes.count > 1
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            deleteItemsButton.animator().isHidden = !shouldShowDeleteButton
            newBookmarkButton.animator().isHidden = shouldShowDeleteButton
            newFolderButton.animator().isHidden = shouldShowDeleteButton
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
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
    }
}

// MARK: - Private

private extension BookmarkManagementDetailViewController {

    func configureToolbar(button: MouseOverButton, image: NSImage, isHidden: Bool) {
        button.bezelStyle = .shadowlessSquare
        button.cornerRadius = 4
        button.normalTintColor = .button
        button.mouseDownColor = .buttonMouseDown
        button.mouseOverColor = .buttonMouseOver
        button.imageHugsTitle = true
        button.setContentHuggingPriority(.defaultHigh, for: .vertical)
        button.alignment = .center
        button.font = .systemFont(ofSize: 13)
        button.image = image
        button.imagePosition = .imageLeading
        button.isHidden = isHidden
    }

    func configureEmptyState(label: NSTextField, font: NSFont, attributedTitle: NSAttributedString) {
        label.isEditable = false
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        label.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.drawsBackground = false
        label.isBordered = false
        label.font = font
        label.textColor = .labelColor
        label.attributedStringValue = attributedTitle
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

        guard let contextMenu = ContextualMenu.menu(for: [bookmark], target: self) else { return }
        contextMenu.popUpAtMouseLocation(in: view)
    }

}

// MARK: - NSMenuDelegate

extension BookmarkManagementDetailViewController: NSMenuDelegate {

    func contextualMenuForClickedRows() -> NSMenu? {
        let row = tableView.clickedRow

        guard row != -1 else {
            return ContextualMenu.menu(for: nil)
        }

        // If only one item is selected try to get the item and its parent folder otherwise show the menu for multiple items.
        if tableView.selectedRowIndexes.contains(row), tableView.selectedRowIndexes.count > 1 {
            return ContextualMenu.menu(for: self.selectedItems())
        }

        let (item, parent) = fetchEntityAndParent(at: row)

        if let item {
            return ContextualMenu.menu(for: item, parentFolder: parent)
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

    func editFolder(_ sender: NSMenuItem) {
        guard let bookmarkEntityInfo = sender.representedObject as? BookmarkEntityInfo,
              let folder = bookmarkEntityInfo.entity as? BookmarkFolder
        else {
            assertionFailure("Failed to cast menu represented object to BookmarkFolder")
            return
        }

        BookmarksDialogViewFactory.makeEditBookmarkFolderView(folder: folder, parentFolder: bookmarkEntityInfo.parent)
            .show(in: view.window)
    }

    func deleteFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Delete Folder context menu item")
            return
        }

        bookmarkManager.remove(folder: folder)
    }

    func moveToEnd(_ sender: NSMenuItem) {
        guard let bookmarkEntity = sender.representedObject as? BookmarksEntityIdentifiable else {
            assertionFailure("Failed to cast menu item's represented object to BookmarkEntity")
            return
        }

        let parentFolderType: ParentFolderType = bookmarkEntity.parentId.flatMap { .parent(uuid: $0) } ?? .root
        bookmarkManager.move(objectUUIDs: [bookmarkEntity.entityId], toIndex: nil, withinParentFolder: parentFolderType) { _ in }
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
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
    }

    func openAllInNewWindow(_ sender: NSMenuItem) {
        guard let tabCollection = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel,
              let folder = sender.representedObject as? BookmarkFolder
        else {
            assertionFailure("Cannot open all in new window")
            return
        }

        let newTabCollection = TabCollection.withContentOfBookmark(folder: folder, burnerMode: tabCollection.burnerMode)
        WindowsManager.openNewWindow(with: newTabCollection, isBurner: tabCollection.isBurner)
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
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
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
    }

    func openBookmarkInNewWindow(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark,
        let url = bookmark.urlObject else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        WindowsManager.openNewWindow(with: url, source: .bookmark, isBurner: false)
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
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
        guard let bookmark = sender.representedObject as? Bookmark else { return }

        BookmarksDialogViewFactory.makeEditBookmarkView(bookmark: bookmark)
            .show(in: view.window)
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

// MARK: - Search field delegate

extension BookmarkManagementDetailViewController: NSSearchFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        if let searchField = obj.object as? NSSearchField {
            managementDetailViewModel.update(selection: selectionState, searchQuery: searchField.stringValue)
            delegate?.bookmarkManagementDetailViewControllerDidStartSearching()
            reloadData()
        }
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
