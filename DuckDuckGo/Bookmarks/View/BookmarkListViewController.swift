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
import Carbon
import Combine
import SwiftUI

protocol BookmarkListViewControllerDelegate: AnyObject {

    func closeBookmarksPopover(_ sender: BookmarkListViewController)
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
        .withAccessibilityIdentifier("BookmarkListViewController.newFolderButton")
    private lazy var searchBookmarksButton = MouseOverButton(image: .searchBookmarks, target: self, action: #selector(searchBookmarkButtonClicked))
        .withAccessibilityIdentifier("BookmarkListViewController.searchBookmarksButton")
    private lazy var sortBookmarksButton = MouseOverButton(image: .bookmarkSortAsc, target: self, action: #selector(sortBookmarksButtonClicked))
        .withAccessibilityIdentifier("BookmarkListViewController.sortBookmarksButton")

    private lazy var buttonsDivider = NSBox()
    private lazy var manageBookmarksButton = MouseOverButton(title: UserText.bookmarksManage, target: self, action: #selector(openManagementInterface))
    private lazy var boxDivider = NSBox()

    private lazy var scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 408))
    private lazy var outlineView = BookmarksOutlineView(frame: scrollView.frame)

    private lazy var emptyState = NSView()
    private lazy var emptyStateTitle = NSTextField()
        .withAccessibilityIdentifier(BookmarksEmptyStateContent.titleAccessibilityIdentifier)
    private lazy var emptyStateMessage = NSTextField()
        .withAccessibilityIdentifier(BookmarksEmptyStateContent.descriptionAccessibilityIdentifier)
    private lazy var emptyStateImageView = NSImageView(image: .bookmarksEmpty)
        .withAccessibilityIdentifier(BookmarksEmptyStateContent.imageAccessibilityIdentifier)
    private lazy var importButton = NSButton(title: UserText.importBookmarksButtonTitle, target: self, action: #selector(onImportClicked))
    private lazy var searchBar = NSSearchField()
        .withAccessibilityIdentifier("BookmarkListViewController.searchBar")
    private var boxDividerTopConstraint = NSLayoutConstraint()

    private let bookmarkManager: BookmarkManager
    private let dragDropManager: BookmarkDragDropManager
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
            dragDropManager: dragDropManager,
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
    private var lastOutlineScrollPosition: NSRect?

    private(set) lazy var faviconsFetcherOnboarding: FaviconsFetcherOnboarding? = {
        guard let syncService = NSApp.delegateTyped.syncService, let syncBookmarksAdapter = NSApp.delegateTyped.syncDataProviders?.bookmarksAdapter else {
            assertionFailure("SyncService and/or SyncBookmarksAdapter is nil")
            return nil
        }
        return .init(syncService: syncService, syncBookmarksAdapter: syncBookmarksAdapter)
    }()

    private var documentView = FlippedView()

    private var documentViewHeightConstraint: NSLayoutConstraint?
    private var outlineViewTopToPromoTopConstraint: NSLayoutConstraint?
    private var outlineViewTopToDocumentTopConstraint: NSLayoutConstraint?
    private var syncPromoHeightConstraint: NSLayoutConstraint?

    private lazy var syncPromoManager: SyncPromoManaging = SyncPromoManager()

    private lazy var syncPromoViewHostingView: NSHostingView<SyncPromoView> = {
        let model = SyncPromoViewModel(touchpointType: .bookmarks, primaryButtonAction: { [weak self] in
            self?.syncPromoManager.goToSyncSettings(for: .bookmarks)
        }, dismissButtonAction: { [weak self] in
            self?.syncPromoManager.dismissPromoFor(.bookmarks)
            self?.updateDocumentViewHeight()
        })

        let headerView = SyncPromoView(viewModel: model)

        let hostingController = NSHostingView(rootView: headerView)
        return hostingController
    }()

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
         dragDropManager: BookmarkDragDropManager = BookmarkDragDropManager.shared,
         metrics: BookmarksSearchAndSortMetrics = BookmarksSearchAndSortMetrics()) {
        self.bookmarkManager = bookmarkManager
        self.dragDropManager = dragDropManager
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
        let showSyncPromo = syncPromoManager.shouldPresentPromoFor(.bookmarks)
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

        // keep OutlineView menu declaration before buttons as it‘s used as target
        outlineView.menu = BookmarksContextMenu(bookmarkManager: bookmarkManager, delegate: self)

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
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.usesPredominantAxisScrolling = false
        scrollView.autohidesScrollers = true
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.scrollerInsets = NSEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 12)

        let column = NSTableColumn()
        column.width = scrollView.frame.width - (showSyncPromo ? 44 : 32)
        outlineView.addTableColumn(column)
        outlineView.translatesAutoresizingMaskIntoConstraints = showSyncPromo ? false : true
        if showSyncPromo {
            outlineView.translatesAutoresizingMaskIntoConstraints = false
        } else {
            outlineView.translatesAutoresizingMaskIntoConstraints = true
            outlineView.autoresizingMask = [.width, .height]
        }
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
        outlineView.dataSource = dataSource
        outlineView.delegate = dataSource

        if !showSyncPromo {
            let clipView = NSClipView(frame: scrollView.frame)
            clipView.translatesAutoresizingMaskIntoConstraints = true
            clipView.autoresizingMask = [.width, .height]
            clipView.documentView = outlineView
            clipView.drawsBackground = false
            scrollView.contentView = clipView
        }

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

        view.addSubview(KeyEquivalentView(keyEquivalents: [
            [.command, "f"]: { [weak self] in
                return self?.handleCmdF($0) ?? false
            }
        ]))
        if showSyncPromo {
            setupSyncPromoView()
        }

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
        outlineView.setDraggingSourceOperationMask([.move], forLocal: true)
        outlineView.registerForDraggedTypes(BookmarkDragDropManager.draggedTypes)
    }

    override func viewWillAppear() {
        subscribeToModelEvents()
        reloadData()
    }

    override func viewWillDisappear() {
        cancellables = []
    }

    func adjustPreferredContentSize(positionedRelativeTo positioningRect: NSRect,
                                    of positioningView: NSView,
                                    at preferredEdge: NSRectEdge) {
        _=view // Load view if needed

        guard let mainWindow = positioningView.window,
              let screenFrame = mainWindow.screen?.visibleFrame else { return }

        self.reloadData()

        guard outlineView.numberOfRows > 0 else {
            preferredContentSize = Constants.preferredContentSize
            return
        }

        let windowRect = positioningView.convert(positioningRect, to: nil)
        let screenPosRect = mainWindow.convertToScreen(windowRect)
        let bookmarkHeaderHeight = 48.0
        let availableHeightBelow = screenPosRect.minY - screenFrame.minY - bookmarkHeaderHeight
        let availableHeightAbove = screenFrame.maxY - screenPosRect.maxY - bookmarkHeaderHeight
        let availableHeight = max(availableHeightAbove, availableHeightBelow)

        let totalHeightForRootBookmarks = (CGFloat(outlineView.numberOfRows) * BookmarkOutlineCellView.rowHeight) + bookmarkHeaderHeight + 12.0
        var contentSize = Constants.preferredContentSize

        if totalHeightForRootBookmarks > availableHeight {
            contentSize.height = availableHeight
        } else if totalHeightForRootBookmarks > Constants.preferredContentSize.height {
            contentSize.height = totalHeightForRootBookmarks
        }

        preferredContentSize = contentSize
    }

    private func subscribeToModelEvents() {
        bookmarkManager.listPublisher.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.reloadData()
        }.store(in: &cancellables)

        sortBookmarksViewModel.$selectedSortMode.sink { [weak self] newSortMode in
            self?.setupSort(mode: newSortMode)
        }.store(in: &cancellables)

        dataSource.$isSearching.sink { [weak self] newValue in
            if !newValue {
                self?.updateDocumentViewHeight()
            }
        }.store(in: &cancellables)
    }

    private func reloadData() {
        if dataSource.isSearching {
            if let destinationFolder = dataSource.dragDestinationFolder {
                hideSearchBar()
                updateSearchAndExpand(destinationFolder)
            } else {
                dataSource.reloadData(forSearchQuery: searchBar.stringValue,
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
        self.searchBookmarksButton.isEnabled = !isEmpty
        self.sortBookmarksButton.isEnabled = !isEmpty
        self.searchBar.isEnabled = !isEmpty
        self.searchBar.isHidden = isEmpty
        self.outlineView.isHidden = isEmpty

        if isEmpty {
            self.hideSearchBar()
            self.showEmptyStateView(for: .noBookmarks)
        }
    }

    private func setupSort(mode: BookmarksSortMode) {
        hideSearchBar()
        dataSource.reloadData(with: mode)
        outlineView.reloadData()
        sortBookmarksButton.image = (mode == .nameDescending) ? .bookmarkSortDesc : .bookmarkSortAsc
        sortBookmarksButton.backgroundColor = mode.shouldHighlightButton ? .buttonMouseDown : .clear
        sortBookmarksButton.mouseOverColor = mode.shouldHighlightButton ? .buttonMouseDown : .buttonMouseOver
    }

    // MARK: Layout

    private func updateSearchAndExpand(_ folder: BookmarkFolder) {
        showTreeView()
        expandFoldersAndScrollUntil(folder)
        outlineView.scrollToAdjustedPositionInOutlineView(folder)

        guard let node = treeController.findNodeWithId(representing: folder) else { return }

        outlineView.highlight(node)
    }

    private func showSearchBar() {
        isSearchVisible = true
        view.addSubview(searchBar)
        outlineView.highlightedRow = nil

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
        outlineView.highlightedRow = nil
        if outlineView.isShown {
            outlineView.makeMeFirstResponder()
        }
        searchBar.stringValue = ""
        searchBar.removeFromSuperview()
        boxDividerTopConstraint.isActive = true
        searchBookmarksButton.backgroundColor = .clear
        searchBookmarksButton.mouseOverColor = .buttonMouseOver
    }

    private func showTreeView() {
        emptyState.isHidden = true
        outlineView.isHidden = false
        dataSource.reloadData(with: sortBookmarksViewModel.selectedSortMode)
        outlineView.reloadData()
        if !isSearchVisible {
            outlineView.makeMeFirstResponder()
        }

        let selectedNodes = self.selectedNodes
        expandAndRestore(selectedNodes: selectedNodes)
    }

    private func expandFoldersAndScrollUntil(_ folder: BookmarkFolder) {
        guard let folderNode = treeController.findNodeWithId(representing: folder) else { return }

        expandFoldersUntil(node: folderNode)
        outlineView.scrollToAdjustedPositionInOutlineView(folderNode)
    }

    private func expandFoldersUntil(node: BookmarkNode?) {
        guard let folderParent = node?.parent else { return }
        for parent in sequence(first: folderParent, next: \.parent).reversed() {
            outlineView.animator().expandItem(parent)
        }
    }

    private func showEmptyStateView(for mode: BookmarksEmptyStateContent) {
        emptyState.isHidden = false
        outlineView.isHidden = true
        if !isSearchVisible {
            view.makeMeFirstResponder()
        }
        emptyStateTitle.stringValue = mode.title
        emptyStateMessage.stringValue = mode.description
        emptyStateImageView.image = mode.image
        importButton.isHidden = mode.shouldHideImportButton
        updateDocumentViewHeight()
    }

    // MARK: Actions

    private func handleCmdF(_ event: NSEvent) -> Bool {
        // start search on cmd+f when bookmarks are available
        guard bookmarkManager.list?.totalBookmarks != 0 else {
            __NSBeep()
            return true
        }

        if isSearchVisible {
            searchBar.makeMeFirstResponder()
        } else {
            showSearchBar()
        }
        return true
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space:
            if outlineView.highlightedRow != nil {
                // submit action when there‘s a highlighted row
                handleClick(outlineView)

            } else if outlineView.numberOfRows > 0 {
                // when in child menu popover without selection: highlight first row
                outlineView.highlightedRow = 0
            }

        case kVK_Escape:
            delegate?.closeBookmarksPopover(self)

        default:
            // start search when letters are typed when bookmarks are available
            if event.deviceIndependentFlags.isEmpty,
               let characters = event.characters, !characters.isEmpty,
               bookmarkManager.list?.totalBookmarks != 0 {

                showSearchBar()
                searchBar.currentEditor()?.keyDown(with: event)
                return
            }

            super.keyDown(with: event)
        }
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

    @objc func openManagementInterface(_ sender: NSButton) {
        showManageBookmarks()
    }

    @objc func handleClick(_ sender: NSOutlineView) {
        let row = NSApp.currentEvent?.type == .keyDown ? outlineView.highlightedRow : sender.clickedRow
        guard let row, row != -1 else { return }
        let item = sender.item(atRow: row)
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
        delegate?.closeBookmarksPopover(self)
    }

    private func handleItemClickWhenNotInSearchMode(item: Any?) {
        if outlineView.isItemExpanded(item) {
            outlineView.animator().collapseItem(item)
        } else {
            outlineView.animator().expandItem(item)
        }
    }

    @objc func onImportClicked(_ sender: NSButton) {
        DataImportView().show()
    }

    private func showManageBookmarks() {
        WindowControllersManager.shared.showBookmarksTab()
        delegate?.closeBookmarksPopover(self)
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
        delegate?.closeBookmarksPopover(self)
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

                /// Reset to the last scroll position if available
                if let lastOutlineScrollPosition = self.lastOutlineScrollPosition {
                    outlineView.scrollToVisible(lastOutlineScrollPosition)
                }
            } else {
                showSearch(forSearchQuery: searchQuery)
            }

            bookmarkMetrics.fireSearchExecuted(origin: .panel)
        }
    }

    private func showSearch(forSearchQuery searchQuery: String) {
        /// Before searching for the first letter we store the current outline scroll position.
        /// This is needed because we want to maintain the scroll position in case the search is cancelled.
        if searchQuery.count == 1 {
            self.lastOutlineScrollPosition = outlineView.visibleRect
        }

        outlineView.highlightedRow = nil
        dataSource.reloadData(forSearchQuery: searchQuery, sortMode: sortBookmarksViewModel.selectedSortMode)

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

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard control === searchBar else {
            assertionFailure("Unexpected delegating control")
            return false
        }
        switch selector {
        case #selector(cancelOperation):
            // handle Esc key press while in search mode
            isSearchVisible = false

        case #selector(moveUp):
            // handle Up Arrow in search mode
            if !outlineView.highlightPreviousItem() {
                // unhighlight for the first row
                outlineView.highlightedRow = nil
            }
        case #selector(moveDown):
            // handle Down Arrow in search mode
            outlineView.highlightNextItem()

        case #selector(insertNewline) where outlineView.highlightedRow != nil:
            // handle Enter key in search mode when there‘s a highlighted row
            handleClick(outlineView)

        default:
            return false
        }
        return true
    }

}

// MARK: - Sync Promo

extension BookmarkListViewController {

    private func setupSyncPromoView() {
        documentView.addSubview(syncPromoViewHostingView)
        documentView.addSubview(outlineView)

        scrollView.documentView = documentView

        documentView.translatesAutoresizingMaskIntoConstraints = false
        syncPromoViewHostingView.translatesAutoresizingMaskIntoConstraints = false

        setupSyncPromoLayout()
    }

    private func setupSyncPromoLayout() {
        syncPromoViewHostingView.setContentHuggingPriority(.required, for: .vertical)

        NSLayoutConstraint.activate([
                                        documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
                                        documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
                                        documentView.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.contentView.trailingAnchor),
                                        documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor, constant: -12),

                                        syncPromoViewHostingView.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 8),
                                        syncPromoViewHostingView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 8),
                                        syncPromoViewHostingView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -8),

                                        outlineView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
                                        outlineView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
                                        outlineView.bottomAnchor.constraint(greaterThanOrEqualTo: documentView.bottomAnchor)
                                    ])

        outlineViewTopToDocumentTopConstraint = outlineView.topAnchor.constraint(equalTo: documentView.topAnchor)
        outlineViewTopToDocumentTopConstraint?.isActive = false

        outlineViewTopToPromoTopConstraint = outlineView.topAnchor.constraint(equalTo: syncPromoViewHostingView.bottomAnchor)
        outlineViewTopToPromoTopConstraint?.isActive = true

        let totalHeight = syncPromoViewHostingView.frame.height + outlineView.frame.height
        documentViewHeightConstraint = documentView.heightAnchor.constraint(equalToConstant: totalHeight)
        documentViewHeightConstraint?.isActive = true

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(outlineViewFrameDidChange),
                                               name: NSView.frameDidChangeNotification,
                                               object: outlineView)

        outlineView.postsFrameChangedNotifications = true
    }

    private func shouldShowSyncPromo() -> Bool {
        return emptyState.isHidden
               && !dataSource.isSearching
               && !outlineView.isHidden
               && (bookmarkManager.list?.bookmarks().count ?? 0) > 0
               && syncPromoManager.shouldPresentPromoFor(.bookmarks)
    }

    @objc private func outlineViewFrameDidChange(notification: Notification) {
        updateDocumentViewHeight()
    }

    private func updateDocumentViewHeight() {
        guard scrollView.documentView is FlippedView else { return }

        let outlineViewHeight = outlineView.intrinsicContentSize.height

        if shouldShowSyncPromo() {
            if let outlineViewTopToDocumentTopConstraint = outlineViewTopToDocumentTopConstraint, outlineViewTopToDocumentTopConstraint.isActive {
                syncPromoViewHostingView.isHidden = false
                outlineViewTopToDocumentTopConstraint.isActive = false
                outlineViewTopToPromoTopConstraint?.isActive = true
            }

            let promoHeight = syncPromoViewHostingView.intrinsicContentSize.height == 0 ? 80 : syncPromoViewHostingView.intrinsicContentSize.height
            let totalHeight = promoHeight + outlineViewHeight
            updateDocumentViewHeightIfNeeded(totalHeight)
        } else {
            if let outlineViewTopToPromoTopConstraint = outlineViewTopToPromoTopConstraint, outlineViewTopToPromoTopConstraint.isActive {
                syncPromoViewHostingView.isHidden = true
                outlineViewTopToPromoTopConstraint.isActive = false
                outlineViewTopToDocumentTopConstraint?.isActive = true
            }

            updateDocumentViewHeightIfNeeded(outlineViewHeight)
        }
    }

    private func updateDocumentViewHeightIfNeeded(_ newHeight: CGFloat) {
        guard documentViewHeightConstraint?.constant != newHeight else { return }
        documentViewHeightConstraint?.constant = newHeight
    }
}

// MARK: - Preview
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
