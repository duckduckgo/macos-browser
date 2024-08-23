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

final class BookmarkListViewController: NSViewController {

    fileprivate enum Constants {
        static let preferredContentSize = CGSize(width: 420, height: 500)
    }

    weak var delegate: BookmarkListViewControllerDelegate?
    var currentTabWebsite: WebsiteInfo?

    private lazy var titleTextField = NSTextField(string: UserText.bookmarks)

    private lazy var stackView = NSStackView()
    private lazy var newBookmarkButton = MouseOverButton(image: .addBookmark, target: self, action: #selector(newBookmarkButtonClicked))
    private lazy var newFolderButton = MouseOverButton(image: .addFolder, target: outlineView.menu, action: #selector(FolderMenuItemSelectors.newFolder))
    private lazy var searchBookmarksButton = MouseOverButton(image: .searchBookmarks, target: self, action: #selector(searchBookmarkButtonClicked))
    private lazy var sortBookmarksButton = MouseOverButton(image: .bookmarkSortAsc, target: self, action: #selector(sortBookmarksButtonClicked))

    private lazy var buttonsDivider = NSBox()
    private lazy var manageBookmarksButton = MouseOverButton(title: UserText.bookmarksManage, target: self, action: #selector(BookmarkMenuItemSelectors.manageBookmarks))
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

    private let bookmarkManager: BookmarkManager
    private let treeControllerDataSource: BookmarkListTreeControllerDataSource
    private let treeControllerSearchDataSource: BookmarkListTreeControllerSearchDataSource
    private let sortBookmarksViewModel: SortBookmarksViewModel
    private let bookmarkMetrics: BookmarksSearchAndSortMetrics

    private let treeController: BookmarkTreeController

    private var isSearchVisible = false {
        didSet {
            switch (oldValue, isSearchVisible) {
            case (false, true):
                showSearchBar()
            case (true, false):
                hideSearchBar()
                showTreeView()
            default: break
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private lazy var dataSource: BookmarkOutlineViewDataSource = {
        BookmarkOutlineViewDataSource(
            contentMode: .bookmarksAndFolders,
            bookmarkManager: bookmarkManager,
            treeController: treeController,
            sortMode: sortBookmarksViewModel.selectedSortMode,
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

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
         metrics: BookmarksSearchAndSortMetrics = BookmarksSearchAndSortMetrics()) {
        self.bookmarkManager = bookmarkManager
        self.treeControllerDataSource = BookmarkListTreeControllerDataSource(bookmarkManager: bookmarkManager)
        self.treeControllerSearchDataSource = BookmarkListTreeControllerSearchDataSource(bookmarkManager: bookmarkManager)
        self.bookmarkMetrics = metrics
        self.sortBookmarksViewModel = SortBookmarksViewModel(manager: bookmarkManager, metrics: metrics, origin: .panel)
        self.treeController = BookmarkTreeController(dataSource: treeControllerDataSource,
                                                     sortMode: sortBookmarksViewModel.selectedSortMode,
                                                     searchDataSource: treeControllerSearchDataSource,
                                                     isBookmarksBarMenu: false)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    // MARK: View Lifecycle
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
        stackView.addArrangedSubview(sortBookmarksButton)
        stackView.addArrangedSubview(searchBookmarksButton)
        stackView.addArrangedSubview(buttonsDivider)
        stackView.addArrangedSubview(manageBookmarksButton)

        // keep OutlineView menu declaration before the buttons as it‘s their target
        outlineView.menu = BookmarksContextMenu(bookmarkManager: bookmarkManager, delegate: self)

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

        sortBookmarksButton.bezelStyle = .shadowlessSquare
        sortBookmarksButton.cornerRadius = 4
        sortBookmarksButton.normalTintColor = .button
        sortBookmarksButton.mouseDownColor = .buttonMouseDown
        sortBookmarksButton.mouseOverColor = .buttonMouseOver
        sortBookmarksButton.translatesAutoresizingMaskIntoConstraints = false
        sortBookmarksButton.toolTip = UserText.bookmarksSort

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
        outlineView.menu = BookmarksContextMenu(bookmarkManager: bookmarkManager, delegate: self)
        outlineView.dataSource = dataSource
        outlineView.delegate = dataSource

        let clipView = NSClipView(frame: scrollView.frame)
        clipView.translatesAutoresizingMaskIntoConstraints = true
        clipView.autoresizingMask = [.width, .height]
        clipView.documentView = outlineView
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        emptyStateImageView.translatesAutoresizingMaskIntoConstraints = false
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

        emptyStateImageView.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        emptyStateImageView.setContentHuggingPriority(.init(rawValue: 251), for: .vertical)

        emptyStateTitle.setContentHuggingPriority(.defaultHigh, for: .vertical)
        emptyStateTitle.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)

        emptyStateMessage.setContentHuggingPriority(.defaultHigh, for: .vertical)
        emptyStateMessage.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)

        NSLayoutConstraint.activate([
            titleTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            newBookmarkButton.heightAnchor.constraint(equalToConstant: 28),
            newBookmarkButton.widthAnchor.constraint(equalToConstant: 28),

            newFolderButton.heightAnchor.constraint(equalToConstant: 28),
            newFolderButton.widthAnchor.constraint(equalToConstant: 28),

            searchBookmarksButton.heightAnchor.constraint(equalToConstant: 28),
            searchBookmarksButton.widthAnchor.constraint(equalToConstant: 28),

            sortBookmarksButton.heightAnchor.constraint(equalToConstant: 28),
            sortBookmarksButton.widthAnchor.constraint(equalToConstant: 28),

            buttonsDivider.widthAnchor.constraint(equalToConstant: 13),
            buttonsDivider.heightAnchor.constraint(equalToConstant: 18),

            manageBookmarksButton.heightAnchor.constraint(equalToConstant: 28),
            manageBookmarksButton.widthAnchor.constraint(equalToConstant: {
                let titleWidth = (manageBookmarksButton.title as NSString)
                    .size(withAttributes: [.font: manageBookmarksButton.font as Any]).width
                let buttonWidth = manageBookmarksButton.image!.size.height + titleWidth + 18
                return buttonWidth
            }()),

            stackView.centerYAnchor.constraint(equalTo: titleTextField.centerYAnchor),
            view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 20),

            {
                boxDividerTopConstraint = boxDivider.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 12)
                return boxDividerTopConstraint
            }(),
            boxDivider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: boxDivider.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: boxDivider.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            emptyState.topAnchor.constraint(equalTo: boxDivider.bottomAnchor),
            emptyState.centerXAnchor.constraint(equalTo: boxDivider.centerXAnchor),
            emptyState.widthAnchor.constraint(equalToConstant: 342),
            emptyState.heightAnchor.constraint(equalToConstant: 383),

            emptyStateImageView.topAnchor.constraint(equalTo: emptyState.topAnchor, constant: 94.5),
            emptyStateImageView.widthAnchor.constraint(equalToConstant: 128),
            emptyStateImageView.heightAnchor.constraint(equalToConstant: 96),
            emptyStateImageView.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor),

            emptyStateTitle.topAnchor.constraint(equalTo: emptyStateImageView.bottomAnchor, constant: 8),
            emptyStateTitle.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor),
            emptyStateTitle.widthAnchor.constraint(equalToConstant: 192),

            emptyStateMessage.topAnchor.constraint(equalTo: emptyStateTitle.bottomAnchor, constant: 8),
            emptyStateMessage.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor),

            emptyStateMessage.widthAnchor.constraint(equalToConstant: 192),

            importButton.topAnchor.constraint(equalTo: emptyStateMessage.bottomAnchor, constant: 8),
            importButton.centerXAnchor.constraint(equalTo: emptyState.centerXAnchor),
        ])
    }

    override func viewDidLoad() {
        preferredContentSize = Constants.preferredContentSize

        outlineView.setDraggingSourceOperationMask([.move], forLocal: true)
        outlineView.registerForDraggedTypes([BookmarkPasteboardWriter.bookmarkUTIInternalType,
                                             FolderPasteboardWriter.folderUTIInternalType])
    }

    override func viewWillAppear() {
        subscribeToModelEvents()
        reloadData()
    }

    override func viewWillDisappear() {
        cancellables = []
    }

    private func subscribeToModelEvents() {
        bookmarkManager.listPublisher.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.reloadData()
        }.store(in: &cancellables)

        sortBookmarksViewModel.$selectedSortMode.sink { [weak self] newSortMode in
            guard let self else { return }

            switch newSortMode {
            case .nameDescending:
                self.sortBookmarksButton.image = .bookmarkSortDesc
            default:
                self.sortBookmarksButton.image = .bookmarkSortAsc
            }

            self.setupSort(mode: newSortMode)
        }.store(in: &cancellables)
    }

    override func keyDown(with event: NSEvent) {
        let commandKeyDown = event.modifierFlags.contains(.command)
        if commandKeyDown && event.keyCode == 3 { // CMD + F
            if isSearchVisible {
                searchBar.makeMeFirstResponder()
            } else {
                showSearchBar()
            }
        } else {
            super.keyDown(with: event)
        }
    }

    private func reloadData() {
        if dataSource.isSearching {
            if let destinationFolder = dataSource.dragDestinationFolderInSearchMode {
                hideSearchBar()
                updateSearchAndExpand(destinationFolder)
            } else {
                dataSource.reloadData(for: searchBar.stringValue,
                                      sortMode: sortBookmarksViewModel.selectedSortMode)
                outlineView.reloadData()
            }
        } else {
            let selectedNodes = self.selectedNodes

            dataSource.reloadData(with: sortBookmarksViewModel.selectedSortMode)
            outlineView.reloadData()

            expandAndRestore(selectedNodes: selectedNodes)
        }

        let isEmpty = (outlineView.numberOfRows == 0)
        self.emptyState.isHidden = !isEmpty
        self.searchBookmarksButton.isHidden = isEmpty
        self.outlineView.isHidden = isEmpty

        if isEmpty {
            self.showEmptyStateView(for: .noBookmarks)
        }
    }

    // MARK: Layout

    private func updateSearchAndExpand(_ folder: BookmarkFolder) {
        showTreeView()
        expandFoldersAndScrollUntil(folder)
        outlineView.scrollToAdjustedPositionInOutlineView(folder)

        guard let node = treeController.node(representing: folder) else { return }

        outlineView.highlight(node)
    }

    @objc func newBookmarkButtonClicked(_ sender: AnyObject) {
        let view = BookmarksDialogViewFactory.makeAddBookmarkView(currentTab: currentTabWebsite)
        showDialog(view)
    }

    @objc func searchBookmarkButtonClicked(_ sender: NSButton) {
        isSearchVisible.toggle()
    }

    @objc func sortBookmarksButtonClicked(_ sender: NSButton) {
        let menu = sortBookmarksViewModel.menu
        bookmarkMetrics.fireSortButtonClicked(origin: .panel)
        menu.popUpAtMouseLocation(in: sender)
    }

    private func showSearchBar() {
        isSearchVisible = true
        view.addSubview(searchBar)

        boxDividerTopConstraint.isActive = false
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            view.trailingAnchor.constraint(equalTo: searchBar.trailingAnchor, constant: 16),
            boxDivider.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 10),
        ])
        searchBar.makeMeFirstResponder()
        searchBookmarksButton.backgroundColor = .buttonMouseDown
        searchBookmarksButton.mouseOverColor = .buttonMouseDown
    }

    private func hideSearchBar() {
        isSearchVisible = false
        searchBar.stringValue = ""
        searchBar.removeFromSuperview()
        boxDividerTopConstraint.isActive = true
        searchBookmarksButton.backgroundColor = .clear
        searchBookmarksButton.mouseOverColor = .buttonMouseOver
    }

    private func setupSort(mode: BookmarksSortMode) {
        hideSearchBar()
        dataSource.reloadData(with: mode)
        outlineView.reloadData()
        sortBookmarksButton.image = (mode == .nameDescending) ? .bookmarkSortDesc : .bookmarkSortAsc
        sortBookmarksButton.backgroundColor = mode.shouldHighlightButton ? .buttonMouseDown : .clear
        sortBookmarksButton.mouseOverColor = mode.shouldHighlightButton ? .buttonMouseDown : .buttonMouseOver
    }

    @objc func handleClick(_ sender: NSOutlineView) {
        guard sender.clickedRow != -1 else { return }

        let item = sender.item(atRow: sender.clickedRow)
        guard let node = item as? BookmarkNode else { return }

        switch node.representedObject {
        case let bookmark as Bookmark:
            onBookmarkClick(bookmark)

        case let folder as BookmarkFolder where dataSource.isSearching:
            bookmarkMetrics.fireSearchResultClicked(origin: .panel)
            hideSearchBar()
            updateSearchAndExpand(folder)

        default:
            handleItemClickWhenNotInSearchMode(item: item)
        }
    }

    private func onBookmarkClick(_ bookmark: Bookmark) {
        if dataSource.isSearching {
            bookmarkMetrics.fireSearchResultClicked(origin: .panel)
        }

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

    private func expandFoldersAndScrollUntil(_ folder: BookmarkFolder) {
        guard let folderNode = treeController.findNodeWithId(representing: folder) else {
            return
        }

        expandFoldersUntil(node: folderNode)
        outlineView.scrollToAdjustedPositionInOutlineView(folderNode)
    }

    private func expandFoldersUntil(node: BookmarkNode?) {
        var nodes: [BookmarkNode?] = []
        var parent = node?.parent
        nodes.append(node)

        while parent != nil {
            nodes.append(parent)
            parent = parent?.parent
        }

        while !nodes.isEmpty {
            if let current = nodes.removeLast() {
                outlineView.animator().expandItem(current)
            }
        }
    }

    private func showTreeView() {
        emptyState.isHidden = true
        outlineView.isHidden = false
        dataSource.reloadData(with: sortBookmarksViewModel.selectedSortMode)
        outlineView.reloadData()
    }

    private func showEmptyStateView(for mode: BookmarksEmptyStateContent) {
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

}
// MARK: - BookmarksContextMenuDelegate
extension BookmarkListViewController: BookmarksContextMenuDelegate {

    var isSearching: Bool { dataSource.isSearching }
    var parentFolder: BookmarkFolder? { nil }
    var shouldIncludeManageBookmarksItem: Bool { true }

    func selectedItems() -> [Any] {
        guard let row = outlineView.clickedRowIfValid else { return [] }

        if outlineView.selectedRowIndexes.contains(row) {
            return outlineView.selectedItems
        }

        return outlineView.item(atRow: row).map { [$0] } ?? []
    }

    func showDialog(_ dialog: any ModalView) {
        delegate?.popover(shouldPreventClosure: true)
        dialog.show(in: parent?.view.window) { [weak delegate] in
            delegate?.popover(shouldPreventClosure: false)
        }
    }

    func closePopoverIfNeeded() {
        delegate?.popoverShouldClose(self)
    }

}
// MARK: - BookmarkSearchMenuItemSelectors
extension BookmarkListViewController: BookmarkSearchMenuItemSelectors {
    func showInFolder(_ sender: NSMenuItem) {
        guard let baseBookmark = sender.representedObject as? BaseBookmarkEntity else {
            assertionFailure("Failed to retrieve Bookmark from Show in Folder context menu item")
            return
        }

        hideSearchBar()
        showTreeView()

        guard let node = treeController.node(representing: baseBookmark) else { return }

        expandFoldersUntil(node: node)
        outlineView.scrollToAdjustedPositionInOutlineView(node)
        outlineView.highlight(node)
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
                showSearch(for: searchQuery)
            }

            bookmarkMetrics.fireSearchExecuted(origin: .panel)
        }
    }

    private func showSearch(for searchQuery: String) {
        dataSource.reloadData(for: searchQuery, sortMode: sortBookmarksViewModel.selectedSortMode)

        if treeController.rootNode.childNodes.isEmpty {
            showEmptyStateView(for: .noSearchResults)
        } else {
            emptyState.isHidden = true
            outlineView.isHidden = false
            outlineView.reloadData()

            if let firstNode = treeController.rootNode.childNodes.first {
                outlineView.scrollTo(firstNode)
            }
        }
    }
}

#if DEBUG
// swiftlint:disable:next identifier_name
func _mockPreviewBookmarkManager(previewEmptyState: Bool) -> BookmarkManager {
    let bookmarks: [BaseBookmarkEntity]
    if previewEmptyState {
        bookmarks = []
    } else {
        bookmarks = (1..<100).map { _ in [
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
        ] }.flatMap { $0 }
    }
    let bkman = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: bookmarks))

    bkman.loadBookmarks()
    customAssertionFailure = { _, _, _ in }

    return bkman
}

@available(macOS 14.0, *)
#Preview("Test Bookmark data",
         traits: BookmarkListViewController.Constants.preferredContentSize.fixedLayout) {
    BookmarkListViewController(bookmarkManager: _mockPreviewBookmarkManager(previewEmptyState: false))
        ._preview_hidingWindowControlsOnAppear()
}

@available(macOS 14.0, *)
#Preview("Empty Scope", traits: BookmarkListViewController.Constants.preferredContentSize.fixedLayout) {
    BookmarkListViewController(bookmarkManager: _mockPreviewBookmarkManager(previewEmptyState: true))
        ._preview_hidingWindowControlsOnAppear()
}
#endif
