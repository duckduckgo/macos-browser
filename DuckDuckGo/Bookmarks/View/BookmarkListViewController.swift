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
    func popover(shouldPreventClosure: Bool)

}

private enum EmptyStateContent {
    case noBookmarks
    case noSearchResults

    var title: String {
        switch self {
        case .noBookmarks: return UserText.bookmarksEmptyStateTitle
        case .noSearchResults: return UserText.bookmarksEmptySearchResultStateTitle
        }
    }

    var description: String {
        switch self {
        case .noBookmarks: return UserText.bookmarksEmptyStateMessage
        case .noSearchResults: return UserText.bookmarksEmptySearchResultStateMessage
        }
    }

    var image: NSImage {
        switch self {
        case .noBookmarks: return .bookmarksEmpty
        case .noSearchResults: return .bookmarkEmptySearch
        }
    }

    var shouldHideImportButton: Bool {
        switch self {
        case .noBookmarks: return false
        case .noSearchResults: return true
        }
    }
}

final class BookmarkListViewController: NSViewController {
    static let preferredContentSize = CGSize(width: 420, height: 500)

    weak var delegate: BookmarkListViewControllerDelegate?
    var currentTabWebsite: WebsiteInfo?

    private lazy var titleTextField = NSTextField(string: UserText.bookmarks)

    private lazy var stackView = NSStackView()
    private lazy var newBookmarkButton = MouseOverButton(image: .addBookmark, target: self, action: #selector(newBookmarkButtonClicked))
    private lazy var newFolderButton = MouseOverButton(image: .addFolder, target: self, action: #selector(newFolderButtonClicked))
    private lazy var searchBookmarksButton = MouseOverButton(image: .searchBookmarks, target: self, action: #selector(searchBookmarkButtonClicked))
    private var isSearchVisible = false

    private lazy var buttonsDivider = NSBox()
    private lazy var manageBookmarksButton = MouseOverButton(title: UserText.bookmarksManage, target: self, action: #selector(openManagementInterface))
    private lazy var boxDivider = NSBox()

    private lazy var scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 408))
    private lazy var outlineView = BookmarksOutlineView(frame: scrollView.frame)

    private lazy var emptyState = NSView()
    private lazy var emptyStateTitle = NSTextField()
    private lazy var emptyStateMessage = NSTextField()
    private lazy var emptyStateImageView = NSImageView(image: .bookmarksEmpty)
    private lazy var importButton = NSButton(title: UserText.importBookmarksButtonTitle, target: self, action: #selector(onImportClicked))
    private lazy var searchBar = NSSearchField()
    private var boxDividerTopConstraint = NSLayoutConstraint()

    private var cancellables = Set<AnyCancellable>()
    private let bookmarkManager: BookmarkManager
    private let treeControllerDataSource: BookmarkListTreeControllerDataSource

    private lazy var treeController = BookmarkTreeController(dataSource: treeControllerDataSource)

    private lazy var dataSource: BookmarkOutlineViewDataSource = {
        BookmarkOutlineViewDataSource(
            contentMode: .bookmarksAndFolders,
            bookmarkManager: bookmarkManager,
            treeController: treeController,
            onMenuRequestedAction: { [weak self] cell in
                self?.showContextMenu(for: cell)
            },
            presentFaviconsFetcherOnboarding: { [weak self] in
                guard let self, let window = self.view.window else {
                    return
                }
                self.faviconsFetcherOnboarding?.presentOnboardingIfNeeded(in: window)
            }
        )
    }()

    private var selectedNodes: [BookmarkNode] {
        if let nodes = outlineView.selectedItems as? [BookmarkNode] {
            return nodes
        }
        return [BookmarkNode]()
    }

    private(set) lazy var faviconsFetcherOnboarding: FaviconsFetcherOnboarding? = {
        guard let syncService = NSApp.delegateTyped.syncService, let syncBookmarksAdapter = NSApp.delegateTyped.syncDataProviders?.bookmarksAdapter else {
            assertionFailure("SyncService and/or SyncBookmarksAdapter is nil")
            return nil
        }
        return .init(syncService: syncService, syncBookmarksAdapter: syncBookmarksAdapter)
    }()

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
        self.treeControllerDataSource = BookmarkListTreeControllerDataSource(bookmarkManager: bookmarkManager)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    override func loadView() {
        view = ColorView(frame: .zero, backgroundColor: .popoverBackground)

        view.addSubview(titleTextField)
        view.addSubview(boxDivider)
        view.addSubview(stackView)
        view.addSubview(scrollView)
        view.addSubview(emptyState)

        view.autoresizesSubviews = false

        titleTextField.isEditable = false
        titleTextField.isBordered = false
        titleTextField.drawsBackground = false
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        titleTextField.font = .systemFont(ofSize: 17)
        titleTextField.textColor = .labelColor

        boxDivider.boxType = .separator
        boxDivider.setContentHuggingPriority(.defaultHigh, for: .vertical)
        boxDivider.translatesAutoresizingMaskIntoConstraints = false

        stackView.orientation = .horizontal
        stackView.spacing = 4
        stackView.setHuggingPriority(.defaultHigh, for: .horizontal)
        stackView.setHuggingPriority(.defaultHigh, for: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(newBookmarkButton)
        stackView.addArrangedSubview(newFolderButton)
        stackView.addArrangedSubview(searchBookmarksButton)
        stackView.addArrangedSubview(buttonsDivider)
        stackView.addArrangedSubview(manageBookmarksButton)

        newBookmarkButton.bezelStyle = .shadowlessSquare
        newBookmarkButton.cornerRadius = 4
        newBookmarkButton.normalTintColor = .button
        newBookmarkButton.mouseDownColor = .buttonMouseDown
        newBookmarkButton.mouseOverColor = .buttonMouseOver
        newBookmarkButton.translatesAutoresizingMaskIntoConstraints = false
        newBookmarkButton.toolTip = UserText.newBookmarkTooltip

        newFolderButton.bezelStyle = .shadowlessSquare
        newFolderButton.cornerRadius = 4
        newFolderButton.normalTintColor = .button
        newFolderButton.mouseDownColor = .buttonMouseDown
        newFolderButton.mouseOverColor = .buttonMouseOver
        newFolderButton.translatesAutoresizingMaskIntoConstraints = false
        newFolderButton.toolTip = UserText.newFolderTooltip

        searchBookmarksButton.bezelStyle = .shadowlessSquare
        searchBookmarksButton.cornerRadius = 4
        searchBookmarksButton.normalTintColor = .button
        searchBookmarksButton.mouseDownColor = .buttonMouseDown
        searchBookmarksButton.mouseOverColor = .buttonMouseOver
        searchBookmarksButton.translatesAutoresizingMaskIntoConstraints = false
        searchBookmarksButton.toolTip = UserText.bookmarksSearch

        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.delegate = self

        buttonsDivider.boxType = .separator
        buttonsDivider.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        buttonsDivider.translatesAutoresizingMaskIntoConstraints = false

        manageBookmarksButton.bezelStyle = .shadowlessSquare
        manageBookmarksButton.cornerRadius = 4
        manageBookmarksButton.normalTintColor = .button
        manageBookmarksButton.mouseDownColor = .buttonMouseDown
        manageBookmarksButton.mouseOverColor = .buttonMouseOver
        manageBookmarksButton.translatesAutoresizingMaskIntoConstraints = false
        manageBookmarksButton.font = .systemFont(ofSize: 12)
        manageBookmarksButton.toolTip = UserText.manageBookmarksTooltip
        manageBookmarksButton.image = {
            let image = NSImage.externalAppScheme
            image.alignmentRect = NSRect(x: 0, y: 0, width: image.size.width + 6, height: image.size.height)
            return image
        }()
        manageBookmarksButton.imagePosition = .imageLeading
        manageBookmarksButton.imageHugsTitle = true

        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasHorizontalScroller = false
        scrollView.usesPredominantAxisScrolling = false
        scrollView.autohidesScrollers = true
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.scrollerInsets = NSEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 12)

        let column = NSTableColumn()
        column.width = scrollView.frame.width - 32
        outlineView.addTableColumn(column)
        outlineView.translatesAutoresizingMaskIntoConstraints = true
        outlineView.autoresizesOutlineColumn = false
        outlineView.autoresizingMask = [.width, .height]
        outlineView.headerView = nil
        outlineView.allowsEmptySelection = false
        outlineView.allowsExpansionToolTips = true
        outlineView.allowsMultipleSelection = false
        outlineView.backgroundColor = .clear
        outlineView.indentationPerLevel = 13
        outlineView.rowHeight = 24
        outlineView.usesAutomaticRowHeights = true
        outlineView.target = self
        outlineView.action = #selector(handleClick)
        outlineView.menu = NSMenu()
        outlineView.menu!.delegate = self
        outlineView.dataSource = dataSource
        outlineView.delegate = dataSource

        let clipView = NSClipView(frame: scrollView.frame)
        clipView.translatesAutoresizingMaskIntoConstraints = true
        clipView.autoresizingMask = [.width, .height]
        clipView.documentView = outlineView
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        emptyState.addSubview(emptyStateImageView)
        emptyState.addSubview(emptyStateTitle)
        emptyState.addSubview(emptyStateMessage)
        emptyState.addSubview(importButton)

        emptyState.isHidden = true
        emptyState.translatesAutoresizingMaskIntoConstraints = false

        emptyStateTitle.translatesAutoresizingMaskIntoConstraints = false
        emptyStateTitle.alignment = .center
        emptyStateTitle.drawsBackground = false
        emptyStateTitle.isBordered = false
        emptyStateTitle.isEditable = false
        emptyStateTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        emptyStateTitle.textColor = .labelColor
        emptyStateTitle.attributedStringValue = NSAttributedString.make(UserText.bookmarksEmptyStateTitle,
                                                                        lineHeight: 1.14,
                                                                        kern: -0.23)

        emptyStateMessage.translatesAutoresizingMaskIntoConstraints = false
        emptyStateMessage.alignment = .center
        emptyStateMessage.drawsBackground = false
        emptyStateMessage.isBordered = false
        emptyStateMessage.isEditable = false
        emptyStateMessage.font = .systemFont(ofSize: 13)
        emptyStateMessage.textColor = .labelColor
        emptyStateMessage.attributedStringValue = NSAttributedString.make(UserText.bookmarksEmptyStateMessage,
                                                                          lineHeight: 1.05,
                                                                          kern: -0.08)

        importButton.translatesAutoresizingMaskIntoConstraints = false
        importButton.isHidden = true

        setupLayout()
    }

    private func setupLayout() {
        titleTextField.setContentHuggingPriority(.defaultHigh, for: .vertical)
        titleTextField.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        titleTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: 12).isActive = true
        titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true

        newBookmarkButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
        newBookmarkButton.widthAnchor.constraint(equalToConstant: 28).isActive = true

        newFolderButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
        newFolderButton.widthAnchor.constraint(equalToConstant: 28).isActive = true

        searchBookmarksButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
        searchBookmarksButton.widthAnchor.constraint(equalToConstant: 28).isActive = true

        buttonsDivider.widthAnchor.constraint(equalToConstant: 13).isActive = true
        buttonsDivider.heightAnchor.constraint(equalToConstant: 18).isActive = true

        manageBookmarksButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
        let titleWidth = (manageBookmarksButton.title as NSString)
            .size(withAttributes: [.font: manageBookmarksButton.font as Any]).width
        let buttonWidth = manageBookmarksButton.image!.size.height + titleWidth + 18
        manageBookmarksButton.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true

        stackView.centerYAnchor.constraint(equalTo: titleTextField.centerYAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 20).isActive = true

        boxDividerTopConstraint = boxDivider.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 12)
        boxDividerTopConstraint.isActive = true
        boxDivider.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: boxDivider.trailingAnchor).isActive = true

        scrollView.topAnchor.constraint(equalTo: boxDivider.bottomAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

        emptyState.topAnchor.constraint(equalTo: boxDivider.bottomAnchor).isActive = true
        emptyState.centerXAnchor.constraint(equalTo: boxDivider.centerXAnchor).isActive = true
        emptyState.widthAnchor.constraint(equalToConstant: 342).isActive = true
        emptyState.heightAnchor.constraint(equalToConstant: 383).isActive = true

        emptyStateImageView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateImageView.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        emptyStateImageView.setContentHuggingPriority(.init(rawValue: 251), for: .vertical)
        emptyStateImageView.topAnchor.constraint(equalTo: emptyState.topAnchor, constant: 94.5).isActive = true
        emptyStateImageView.widthAnchor.constraint(equalToConstant: 128).isActive = true
        emptyStateImageView.heightAnchor.constraint(equalToConstant: 96).isActive = true
        emptyStateImageView.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor).isActive = true

        emptyStateTitle.setContentHuggingPriority(.defaultHigh, for: .vertical)
        emptyStateTitle.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        emptyStateTitle.topAnchor.constraint(equalTo: emptyStateImageView.bottomAnchor, constant: 8).isActive = true
        emptyStateTitle.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor).isActive = true
        emptyStateTitle.widthAnchor.constraint(equalToConstant: 192).isActive = true

        emptyStateMessage.setContentHuggingPriority(.defaultHigh, for: .vertical)
        emptyStateMessage.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        emptyStateMessage.topAnchor.constraint(equalTo: emptyStateTitle.bottomAnchor, constant: 8).isActive = true
        emptyStateMessage.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor).isActive = true

        emptyStateMessage.widthAnchor.constraint(equalToConstant: 192).isActive = true

        importButton.topAnchor.constraint(equalTo: emptyStateMessage.bottomAnchor, constant: 8).isActive = true
        importButton.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor).isActive = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        preferredContentSize = Self.preferredContentSize

        outlineView.setDraggingSourceOperationMask([.move], forLocal: true)
        outlineView.registerForDraggedTypes([BookmarkPasteboardWriter.bookmarkUTIInternalType,
                                             FolderPasteboardWriter.folderUTIInternalType])

        bookmarkManager.listPublisher.receive(on: DispatchQueue.main).sink { [weak self] list in
            self?.reloadData()
            let isEmpty = list?.topLevelEntities.isEmpty ?? true

            if isEmpty {
                self?.showEmptyStateView(for: .noBookmarks)
            } else {
                self?.outlineView.isHidden = false
            }
        }.store(in: &cancellables)
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

    @objc func newBookmarkButtonClicked(_ sender: AnyObject) {
        let view = BookmarksDialogViewFactory.makeAddBookmarkView(currentTab: currentTabWebsite)
        showDialog(view: view)
    }

    @objc func newFolderButtonClicked(_ sender: AnyObject) {
        let parentFolder = sender.representedObject as? BookmarkFolder
        let view = BookmarksDialogViewFactory.makeAddBookmarkFolderView(parentFolder: parentFolder)
        showDialog(view: view)
    }

    @objc func searchBookmarkButtonClicked(_ sender: NSButton) {
        isSearchVisible.toggle()

        if isSearchVisible {
            showSearchBar()
        } else {
            hideSearchBar()
        }
    }

    private func showSearchBar() {
        view.addSubview(searchBar)

        boxDividerTopConstraint.isActive = false
        searchBar.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 8).isActive = true
        searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true
        view.trailingAnchor.constraint(equalTo: searchBar.trailingAnchor, constant: 16).isActive = true
        boxDivider.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 10).isActive = true
    }

    private func hideSearchBar() {
        searchBar.removeFromSuperview()
        boxDividerTopConstraint.isActive = true
    }

    @objc func openManagementInterface(_ sender: NSButton) {
        showManageBookmarks()
    }

    @objc func handleClick(_ sender: NSOutlineView) {
        guard sender.clickedRow != -1 else { return }

        let item = sender.item(atRow: sender.clickedRow)
        if let node = item as? BookmarkNode,
           let bookmark = node.representedObject as? Bookmark {
            onBookmarkClick(bookmark)
        } else if let node = item as? BookmarkNode, let folder = node.representedObject as? BookmarkFolder, dataSource.isSearching {
            showTreeView()
            expandFoldersUntil(folder: folder)
            outlineView.scrollTo(node)
        } else {
            handleItemClickWhenNotInSearchMode(item: item)
        }
    }

    private func onBookmarkClick(_ bookmark: Bookmark) {
        WindowControllersManager.shared.open(bookmark: bookmark)
        delegate?.popoverShouldClose(self)
    }

    private func handleItemClickWhenNotInSearchMode(item: Any?) {
        if outlineView.isItemExpanded(item) {
            outlineView.animator().collapseItem(item)
        } else {
            outlineView.animator().expandItem(item)
        }
    }

    private func expandFoldersUntil(folder: BookmarkFolder) {
        var nodes: [BookmarkNode?] = []
        let newNodePosition = dataSource.treeController.node(representing: folder)
        var parent = newNodePosition?.parent
        nodes.append(newNodePosition)

        while parent != nil {
            nodes.append(parent)
            parent = parent?.parent
        }

        while !nodes.isEmpty {
            if let current = nodes.removeLast() {
                if !current.isRoot {
                    outlineView.animator().expandItem(current)
                }
            }
        }
    }

    private func showTreeView() {
        emptyState.isHidden = true
        outlineView.isHidden = false
        dataSource.reloadData()
        outlineView.reloadData()
    }

    private func showEmptyStateView(for mode: EmptyStateContent) {
        emptyState.isHidden = false
        outlineView.isHidden = true
        emptyStateTitle.stringValue = mode.title
        emptyStateMessage.stringValue = mode.description
        emptyStateImageView.image = mode.image
        importButton.isHidden = mode.shouldHideImportButton
    }

    @objc func onImportClicked(_ sender: NSButton) {
        DataImportView().show()
    }

    // MARK: NSOutlineView Configuration

    private func expandAndRestore(selectedNodes: [BookmarkNode]) {
        treeController.visitNodes { node in
            if let objectID = (node.representedObject as? BaseBookmarkEntity)?.id {
                if dataSource.expandedNodesIDs.contains(objectID) {
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
                    if dataSource.expandedNodesIDs.contains(pseudoFolder.id) {
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

    private func showContextMenu(for cell: BookmarkOutlineCellView) {
        let row = outlineView.row(for: cell)
        guard
            let item = outlineView.item(atRow: row),
            let contextMenu = ContextualMenu.menu(for: [item], target: self)
        else {
            return
        }

        contextMenu.popUpAtMouseLocation(in: view)
    }

}

private extension BookmarkListViewController {

    func showDialog(view: any ModalView) {
        delegate?.popover(shouldPreventClosure: true)

        view.show(in: parent?.view.window) { [weak delegate] in
            delegate?.popover(shouldPreventClosure: false)
        }
    }

    func showManageBookmarks() {
        WindowControllersManager.shared.showBookmarksTab()
        delegate?.popoverShouldClose(self)
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

        WindowControllersManager.shared.show(url: bookmark.urlObject, source: .bookmark, newTab: true)
    }

    func openBookmarkInNewWindow(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }
        guard let urlObject = bookmark.urlObject else {
            return
        }
        WindowsManager.openNewWindow(with: urlObject, source: .bookmark, isBurner: false)
    }

    func toggleBookmarkAsFavorite(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        bookmark.isFavorite.toggle()
        bookmarkManager.update(bookmark: bookmark)
    }

    func editBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to retrieve Bookmark from Edit Bookmark context menu item")
            return
        }

        let view = BookmarksDialogViewFactory.makeEditBookmarkView(bookmark: bookmark)
        showDialog(view: view)
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
        guard let uuids = sender.representedObject as? [String] else {
            assertionFailure("Failed to cast menu item's represented object to UUID array")
            return
        }

        bookmarkManager.remove(objectsWithUUIDs: uuids)
    }

    func manageBookmarks(_ sender: NSMenuItem) {
        showManageBookmarks()
    }

    func moveToEnd(_ sender: NSMenuItem) {
        guard let bookmarkEntity = sender.representedObject as? BookmarksEntityIdentifiable else {
            assertionFailure("Failed to cast menu item's represented object to BookmarkEntity")
            return
        }

        let parentFolderType: ParentFolderType = bookmarkEntity.parentId.flatMap { .parent(uuid: $0) } ?? .root
        bookmarkManager.move(objectUUIDs: [bookmarkEntity.entityId], toIndex: nil, withinParentFolder: parentFolderType) { _ in }
    }

}

extension BookmarkListViewController: FolderMenuItemSelectors {

    func newFolder(_ sender: NSMenuItem) {
        newFolderButtonClicked(sender)
    }

    func editFolder(_ sender: NSMenuItem) {
        guard let bookmarkEntityInfo = sender.representedObject as? BookmarkEntityInfo,
              let folder = bookmarkEntityInfo.entity as? BookmarkFolder
        else {
            assertionFailure("Failed to retrieve Bookmark from Edit Folder context menu item")
            return
        }

        let view = BookmarksDialogViewFactory.makeEditBookmarkFolderView(folder: folder, parentFolder: bookmarkEntityInfo.parent)
        showDialog(view: view)
    }

    func deleteFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Delete Folder context menu item")
            return
        }

        bookmarkManager.remove(folder: folder)
    }

    func openInNewTabs(_ sender: NSMenuItem) {
        guard let tabCollection = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel,
              let folder = sender.representedObject as? BookmarkFolder
        else {
            assertionFailure("Cannot open all in new tabs")
            return
        }

        let tabs = Tab.withContentOfBookmark(folder: folder, burnerMode: tabCollection.burnerMode)
        tabCollection.append(tabs: tabs)
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

// MARK: - Search field delegate

extension BookmarkListViewController: NSSearchFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        if let searchField = obj.object as? NSSearchField {
            let searchQuery = searchField.stringValue

            if searchQuery.isBlank {
                showTreeView()
            } else {
                let results = bookmarkManager.search(by: searchQuery)

                if results.isEmpty {
                    showEmptyStateView(for: .noSearchResults)
                } else {
                    showSearch(for: results)
                }
            }
        }
    }

    private func showSearch(for results: [BaseBookmarkEntity]) {
        emptyState.isHidden = true
        outlineView.isHidden = false
        dataSource.reloadData(for: results)
        outlineView.reloadData()
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
        let controller = BookmarkListViewController()
        controller.delegate = self
        contentViewController = controller
    }

}

extension BookmarkListPopover: BookmarkListViewControllerDelegate {

    func popoverShouldClose(_ bookmarkListViewController: BookmarkListViewController) {
        close()
    }

    func popover(shouldPreventClosure: Bool) {
        behavior = shouldPreventClosure ? .applicationDefined : .transient
    }

}

#if DEBUG
// swiftlint:disable:next identifier_name
func _mockPreviewBookmarkManager(previewEmptyState: Bool) -> BookmarkManager {
    let bkman = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: previewEmptyState ? [] : [
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
}

@available(macOS 14.0, *)
#Preview("Test Bookmark data",
         traits: BookmarkListViewController.preferredContentSize.fixedLayout) {
    BookmarkListViewController(bookmarkManager: _mockPreviewBookmarkManager(previewEmptyState: false))
        ._preview_hidingWindowControlsOnAppear()
}

@available(macOS 14.0, *)
#Preview("Empty Scope", traits: BookmarkListViewController.preferredContentSize.fixedLayout) {
    BookmarkListViewController(bookmarkManager: _mockPreviewBookmarkManager(previewEmptyState: true))
        ._preview_hidingWindowControlsOnAppear()
}
#endif
