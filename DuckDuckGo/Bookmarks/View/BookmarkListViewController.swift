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

protocol BookmarkListViewControllerDelegate: AnyObject {

    func closeBookmarksPopovers(_ sender: BookmarkListViewController)
    func popover(shouldPreventClosure: Bool)

    func openNextBookmarksMenu(_ sender: BookmarkListViewController)
    func openPreviousBookmarksMenu(_ sender: BookmarkListViewController)

}

final class BookmarkListViewController: NSViewController {

    enum Mode { case popover, bookmarkBarMenu }
    let mode: Mode

    fileprivate enum Constants {
        static let preferredContentSize = CGSize(width: 420, height: 500)
        static let noContentMenuSize = CGSize(width: 8, height: 40)
        static let maxMenuPopoverContentWidth: CGFloat = 500 - 13 * 2
        static let minVisibleRows = 4
    }

    weak var delegate: BookmarkListViewControllerDelegate?
    var currentTabWebsite: WebsiteInfo?

    private var titleTextField: NSTextField?

    private var newBookmarkButton: MouseOverButton?
    private var newFolderButton: MouseOverButton?
    private var manageBookmarksButton: MouseOverButton?
    private var searchBookmarksButton: MouseOverButton?
    private var sortBookmarksButton: MouseOverButton?

    private var boxDivider: NSBox?
    private var boxDividerTopConstraint: NSLayoutConstraint?

    private lazy var searchBar = {
        let searchBar = NSSearchField()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.delegate = self
        return searchBar
    }()

    private lazy var scrollView = SteppedScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 408),
                                                    stepSize: BookmarkOutlineCellView.rowHeight)
    private lazy var outlineView = BookmarksOutlineView(frame: scrollView.frame)

    private var scrollDownButton: MouseOverButton?
    private var scrollUpButton: MouseOverButton?

    private var emptyState: NSView?
    private var emptyStateTitle: NSTextField?
    private var emptyStateMessage: NSTextField?
    private var emptyStateImageView: NSImageView?
    private var importButton: NSButton?

    private let bookmarkManager: BookmarkManager
    private let dragDropManager: BookmarkDragDropManager
    private let treeControllerDataSource: BookmarkListTreeControllerDataSource
    private let treeControllerSearchDataSource: BookmarkListTreeControllerSearchDataSource
    private let sortBookmarksViewModel: SortBookmarksViewModel
    private let bookmarkMetrics: BookmarksSearchAndSortMetrics

    private let treeController: BookmarkTreeController

    private var bookmarkListPopover: BookmarkListPopover?
    private(set) var preferredContentOffset: CGPoint = .zero

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
            contentMode: mode == .bookmarkBarMenu ? .bookmarksMenu : .bookmarksAndFolders,
            bookmarkManager: bookmarkManager,
            treeController: treeController,
            dragDropManager: dragDropManager,
            sortMode: sortBookmarksViewModel.selectedSortMode,
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

    init(mode: Mode = .popover,
         bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
         dragDropManager: BookmarkDragDropManager = BookmarkDragDropManager.shared,
         rootFolder: BookmarkFolder? = nil,
         metrics: BookmarksSearchAndSortMetrics = BookmarksSearchAndSortMetrics()) {

        self.mode = mode
        self.bookmarkManager = bookmarkManager
        self.dragDropManager = dragDropManager
        self.bookmarkMetrics = metrics
        self.sortBookmarksViewModel = SortBookmarksViewModel(manager: bookmarkManager, metrics: metrics, origin: .panel)
        self.treeControllerDataSource = BookmarkListTreeControllerDataSource(bookmarkManager: bookmarkManager)
        self.treeControllerSearchDataSource = BookmarkListTreeControllerSearchDataSource(bookmarkManager: bookmarkManager)
        self.treeController = BookmarkTreeController(dataSource: treeControllerDataSource,
                                                     sortMode: sortBookmarksViewModel.selectedSortMode,
                                                     searchDataSource: treeControllerSearchDataSource,
                                                     rootFolder: rootFolder,
                                                     isBookmarksBarMenu: mode == .bookmarkBarMenu)

        super.init(nibName: nil, bundle: nil)
        self.representedObject = rootFolder
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    // MARK: View Lifecycle

    override func loadView() {
        view = NSView()
        view.autoresizesSubviews = false

        titleTextField = (mode == .bookmarkBarMenu) ? nil : {
            let titleTextField = NSTextField(string: UserText.bookmarks)

            titleTextField.isEditable = false
            titleTextField.isBordered = false
            titleTextField.drawsBackground = false
            titleTextField.translatesAutoresizingMaskIntoConstraints = false
            titleTextField.font = .systemFont(ofSize: 17)
            titleTextField.textColor = .labelColor
            titleTextField.setContentHuggingPriority(.defaultHigh, for: .vertical)
            titleTextField.setContentHuggingPriority(.init(251), for: .horizontal)

            return titleTextField
        }()

        boxDivider = (mode == .bookmarkBarMenu) ? nil : {
            let boxDivider = NSBox()
            boxDivider.boxType = .separator
            boxDivider.setContentHuggingPriority(.defaultHigh, for: .vertical)
            boxDivider.translatesAutoresizingMaskIntoConstraints = false
            return boxDivider
        }()

        newBookmarkButton = (mode == .bookmarkBarMenu) ? nil : {
            let newBookmarkButton = MouseOverButton(image: .addBookmark, target: self,
                                                    action: #selector(newBookmarkButtonClicked))
            newBookmarkButton.bezelStyle = .shadowlessSquare
            newBookmarkButton.cornerRadius = 4
            newBookmarkButton.normalTintColor = .button
            newBookmarkButton.mouseDownColor = .buttonMouseDown
            newBookmarkButton.mouseOverColor = .buttonMouseOver
            newBookmarkButton.translatesAutoresizingMaskIntoConstraints = false
            newBookmarkButton.toolTip = UserText.newBookmarkTooltip
            return newBookmarkButton
        }()

        newFolderButton = (mode == .bookmarkBarMenu) ? nil : {
            let newFolderButton = MouseOverButton(image: .addFolder, target: self,
                                                  action: #selector(newFolderButtonClicked))
            newFolderButton.bezelStyle = .shadowlessSquare
            newFolderButton.cornerRadius = 4
            newFolderButton.normalTintColor = .button
            newFolderButton.mouseDownColor = .buttonMouseDown
            newFolderButton.mouseOverColor = .buttonMouseOver
            newFolderButton.translatesAutoresizingMaskIntoConstraints = false
            newFolderButton.toolTip = UserText.newFolderTooltip
            return newFolderButton
        }()

        searchBookmarksButton = (mode == .bookmarkBarMenu) ? nil : {
            let searchBookmarksButton = MouseOverButton(image: .searchBookmarks, target: self,
                                                        action: #selector(searchBookmarksButtonClicked))
            searchBookmarksButton.bezelStyle = .shadowlessSquare
            searchBookmarksButton.cornerRadius = 4
            searchBookmarksButton.normalTintColor = .button
            searchBookmarksButton.mouseDownColor = .buttonMouseDown
            searchBookmarksButton.mouseOverColor = .buttonMouseOver
            searchBookmarksButton.translatesAutoresizingMaskIntoConstraints = false
            searchBookmarksButton.toolTip = UserText.bookmarksSearch
            return searchBookmarksButton
        }()

        sortBookmarksButton = (mode == .bookmarkBarMenu) ? nil : {
            let sortBookmarksButton = MouseOverButton(image: .bookmarkSortAsc, target: self, action: #selector(sortBookmarksButtonClicked))
            sortBookmarksButton.bezelStyle = .shadowlessSquare
            sortBookmarksButton.cornerRadius = 4
            sortBookmarksButton.normalTintColor = .button
            sortBookmarksButton.mouseDownColor = .buttonMouseDown
            sortBookmarksButton.mouseOverColor = .buttonMouseOver
            sortBookmarksButton.translatesAutoresizingMaskIntoConstraints = false
            sortBookmarksButton.toolTip = UserText.bookmarksSort
            return sortBookmarksButton
        }()

        let buttonsDivider = (mode == .bookmarkBarMenu) ? nil : {
            let buttonsDivider = NSBox()
            buttonsDivider.boxType = .separator
            buttonsDivider.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            buttonsDivider.translatesAutoresizingMaskIntoConstraints = false
            return buttonsDivider
        }()

        manageBookmarksButton = (mode == .bookmarkBarMenu) ? nil : {
            let manageBookmarksButton = MouseOverButton(title: UserText.bookmarksManage, target: self,
                                                        action: #selector(openManagementInterface))
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
            return manageBookmarksButton
        }()

        let stackView = (mode == .bookmarkBarMenu) ? nil : {
            let stackView = NSStackView()
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
            return stackView
        }()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.usesPredominantAxisScrolling = false
        scrollView.automaticallyAdjustsContentInsets = false
        if mode == .popover {
            scrollView.borderType = .noBorder
            scrollView.autohidesScrollers = true
            scrollView.scrollerInsets = NSEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
            scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        } else {
            scrollView.borderType = .noBorder
            scrollView.scrollerInsets = NSEdgeInsetsZero
            scrollView.contentInsets = NSEdgeInsetsZero
            scrollView.hasVerticalScroller = false
            scrollView.scrollerStyle = .overlay
            scrollView.verticalScrollElasticity = .none
            scrollView.horizontalScrollElasticity = .none
        }

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
        outlineView.usesAutomaticRowHeights = false
        outlineView.target = self
        outlineView.action = #selector(handleClick)
        outlineView.menu = NSMenu()
        outlineView.menu!.delegate = self
        outlineView.dataSource = dataSource
        outlineView.delegate = dataSource
        if mode == .popover {
            outlineView.indentationPerLevel = 13
        } else {
            outlineView.indentationPerLevel = 0
        }

        let clipView = NSClipView(frame: scrollView.frame)
        clipView.translatesAutoresizingMaskIntoConstraints = true
        clipView.autoresizingMask = [.width, .height]
        clipView.documentView = outlineView
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        scrollUpButton = mode == .popover ? nil : {
            let scrollUpButton = MouseOverButton(image: .condenseUp, target: nil, action: nil)
            scrollUpButton.translatesAutoresizingMaskIntoConstraints = false
            scrollUpButton.bezelStyle = .shadowlessSquare
            scrollUpButton.normalTintColor = .labelColor
            scrollUpButton.backgroundColor = .clear
            scrollUpButton.mouseOverColor = .blackWhite10
            scrollUpButton.delegate = self
            return scrollUpButton
        }()

        scrollDownButton = mode == .popover ? nil : {
            let scrollDownButton = MouseOverButton(image: .expandDown, target: nil, action: nil)
            scrollDownButton.translatesAutoresizingMaskIntoConstraints = false
            scrollDownButton.bezelStyle = .shadowlessSquare
            scrollDownButton.normalTintColor = .labelColor
            scrollDownButton.backgroundColor = .clear
            scrollDownButton.mouseOverColor = .blackWhite10
            scrollDownButton.delegate = self
            return scrollDownButton
        }()

        titleTextField.map(view.addSubview)
        boxDivider.map(view.addSubview)
        stackView.map(view.addSubview)
        view.addSubview(scrollView)
        scrollUpButton.map(view.addSubview)
        scrollDownButton.map(view.addSubview)

        setupEmptyStateView()
        setupLayout(stackView: stackView, buttonsDivider: buttonsDivider)
    }

    private func setupEmptyStateView() {
        guard mode == .popover else { return }

        let emptyStateImageView =  {
            let emptyStateImageView = NSImageView(image: .bookmarksEmpty)
            emptyStateImageView.translatesAutoresizingMaskIntoConstraints = false
            emptyStateImageView.setContentHuggingPriority(.init(251), for: .horizontal)
            emptyStateImageView.setContentHuggingPriority(.init(251), for: .vertical)
            return emptyStateImageView
        }()
        self.emptyStateImageView = emptyStateImageView

        let emptyStateTitle = {
            let emptyStateTitle = NSTextField()
            emptyStateTitle.translatesAutoresizingMaskIntoConstraints = false
            emptyStateTitle.setContentHuggingPriority(.defaultHigh, for: .vertical)
            emptyStateTitle.setContentHuggingPriority(.init(251), for: .horizontal)
            emptyStateTitle.alignment = .center
            emptyStateTitle.drawsBackground = false
            emptyStateTitle.isBordered = false
            emptyStateTitle.isEditable = false
            emptyStateTitle.font = .systemFont(ofSize: 15, weight: .semibold)
            emptyStateTitle.textColor = .labelColor
            emptyStateTitle.attributedStringValue = NSAttributedString.make(UserText.bookmarksEmptyStateTitle,
                                                                            lineHeight: 1.14,
                                                                            kern: -0.23)
            return emptyStateTitle
        }()
        self.emptyStateTitle = emptyStateTitle

        let emptyStateMessage = {
            let emptyStateMessage = NSTextField()
            emptyStateMessage.translatesAutoresizingMaskIntoConstraints = false
            emptyStateMessage.setContentHuggingPriority(.defaultHigh, for: .vertical)
            emptyStateMessage.setContentHuggingPriority(.init(251), for: .horizontal)
            emptyStateMessage.alignment = .center
            emptyStateMessage.drawsBackground = false
            emptyStateMessage.isBordered = false
            emptyStateMessage.isEditable = false
            emptyStateMessage.font = .systemFont(ofSize: 13)
            emptyStateMessage.textColor = .labelColor
            emptyStateMessage.attributedStringValue = NSAttributedString.make(UserText.bookmarksEmptyStateMessage,
                                                                              lineHeight: 1.05,
                                                                              kern: -0.08)
            return emptyStateMessage
        }()
        self.emptyStateMessage = emptyStateMessage

        let importButton = {
            let importButton = NSButton(title: UserText.importBookmarksButtonTitle, target: self,
                                action: #selector(onImportClicked))
            importButton.translatesAutoresizingMaskIntoConstraints = false
            importButton.isHidden = true
                return importButton
        }()
        self.importButton = importButton

        emptyState = {
            let emptyState = NSView()
            emptyState.addSubview(emptyStateImageView)
            emptyState.addSubview(emptyStateTitle)
            emptyState.addSubview(emptyStateMessage)
            emptyState.addSubview(importButton)

            emptyState.isHidden = true
            emptyState.translatesAutoresizingMaskIntoConstraints = false

            view.addSubview(emptyState)

            return emptyState
        }()
        setupEmptyStateLayout()
    }

    private func setupLayout(stackView: NSStackView?, buttonsDivider: NSBox?) {
        var constraints = [
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                .priority(900),
        ]

        if let titleTextField, let boxDivider, let stackView {
            let boxDividerTopConstraint = boxDivider.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 12)
            self.boxDividerTopConstraint = boxDividerTopConstraint
            constraints += [
                titleTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
                titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

                stackView.centerYAnchor.constraint(equalTo: titleTextField.centerYAnchor),
                view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 20),

                boxDividerTopConstraint,
                boxDivider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: boxDivider.trailingAnchor),

                scrollView.topAnchor.constraint(equalTo: boxDivider.bottomAnchor),
            ]
        } else {
            constraints += [
                scrollView.topAnchor.constraint(equalTo: view.topAnchor)
                    .priority(900),
            ]
        }
        if let scrollUpButton, let scrollDownButton {
            constraints += [
                scrollUpButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrollUpButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollUpButton.topAnchor.constraint(equalTo: view.topAnchor),
                scrollUpButton.heightAnchor.constraint(equalToConstant: 16),

                scrollDownButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrollDownButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollDownButton.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                scrollDownButton.heightAnchor.constraint(equalToConstant: 16),

                scrollView.topAnchor.constraint(equalTo: scrollUpButton.bottomAnchor)
                    .autoDeactivatedWhenViewIsHidden(scrollUpButton),
                scrollView.bottomAnchor.constraint(equalTo: scrollDownButton.topAnchor)
                    .autoDeactivatedWhenViewIsHidden(scrollDownButton),
            ]
        }
        constraints += newBookmarkButton.map { newBookmarkButton in
            [
                newBookmarkButton.heightAnchor.constraint(equalToConstant: 28),
                newBookmarkButton.widthAnchor.constraint(equalToConstant: 28),
            ]
        } ?? []
        constraints += newFolderButton.map { newFolderButton in
            [
                newFolderButton.heightAnchor.constraint(equalToConstant: 28),
                newFolderButton.widthAnchor.constraint(equalToConstant: 28),
            ]
        } ?? []
        constraints += buttonsDivider.map { buttonsDivider in
            [
                buttonsDivider.widthAnchor.constraint(equalToConstant: 13),
                buttonsDivider.heightAnchor.constraint(equalToConstant: 18),
            ]
        } ?? []
        constraints += manageBookmarksButton.map { manageBookmarksButton in
            [
                manageBookmarksButton.heightAnchor.constraint(equalToConstant: 28),
                manageBookmarksButton.widthAnchor.constraint(equalToConstant: {
                    let titleWidth = (manageBookmarksButton.title as NSString)
                        .size(withAttributes: [.font: manageBookmarksButton.font as Any]).width
                    let buttonWidth = manageBookmarksButton.image!.size.height + titleWidth + 18
                    return buttonWidth
                }()),
            ]
        } ?? []
        constraints += searchBookmarksButton.map { searchBookmarksButton in
            [
                searchBookmarksButton.heightAnchor.constraint(equalToConstant: 28),
                searchBookmarksButton.widthAnchor.constraint(equalToConstant: 28),
            ]
        } ?? []
        constraints += sortBookmarksButton.map { sortBookmarksButton in
            [
                sortBookmarksButton.heightAnchor.constraint(equalToConstant: 28),
                sortBookmarksButton.widthAnchor.constraint(equalToConstant: 28),
            ]
        } ?? []

        NSLayoutConstraint.activate(constraints)
    }

    private func setupEmptyStateLayout() {
        guard let emptyState, let emptyStateImageView, let emptyStateTitle,
              let emptyStateMessage, let importButton, let boxDivider else { return }

        NSLayoutConstraint.activate([
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
        outlineView.registerForDraggedTypes(BookmarkDragDropManager.draggedTypes)
        // allow scroll buttons to scroll when dragging bookmark over
        scrollDownButton?.registerForDraggedTypes(BookmarkDragDropManager.draggedTypes)
        scrollUpButton?.registerForDraggedTypes(BookmarkDragDropManager.draggedTypes)
    }

    override func viewWillAppear() {
        subscribeToModelEvents()
    }

    override func viewWillDisappear() {
        cancellables = []
    }

    private func subscribeToModelEvents() {
        bookmarkManager.listPublisher
            .dropFirst() // reloadData will be called from adjustPreferredContentSize
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadData()
            }
            .store(in: &cancellables)

        sortBookmarksViewModel.$selectedSortMode.sink { [weak self] newSortMode in
            self?.setupSort(mode: newSortMode)
        }.store(in: &cancellables)

        if case .bookmarkBarMenu = mode {
            subscribeToScrollingEvents()
            subscribeToMenuPopoverEvents()
            subscribeToDragDropEvents()
            // only subscribe to click outside events in root bookmarks menu
            // to close all the bookmarks menu popovers
            if !(view.window?.parent?.contentViewController is Self) {
                subscribeToClickOutsideEvents()
            }
        }
    }

    private func subscribeToMenuPopoverEvents() {
        // show submenu for folder when dragging or hovering over it
        Publishers.Merge(
            // hover over bookmarks menu row
            outlineView.$highlightedRow.map { ($0, HighlightEvent.hover) },
            // dragging over folder
            dataSource.$dragDestinationFolder.map { [weak self] folder in
                guard let self, let folder,
                      let node = treeController.findNodeWithId(representing: folder),
                      let row = outlineView.rowIfValid(forItem: node) else {
                    return (nil, .dragging)
                }
                return (row, .dragging)
            }
        )
        .compactMap { [weak self] (row, event) in
            self?.delayedHighlightRowEventPublisher(forRow: row, on: event)
        }
        .switchToLatest()
        .filter { [weak dataSource, weak outlineView] (row, folder, event) in
            // following is valid only when dragging
            guard event == .dragging else {
                return outlineView?.highlightedRow == row
            }
            // don‘t hide subfolder menu or switch to another folder if
            // mouse cursor is outside of the view
            guard outlineView?.isMouseLocationInsideBounds() == true else { return false }
            if let folder {
                // only show submenu if cursor is still pointing to the folder
                return folder == dataSource?.dragDestinationFolder
            } else {
                // hide submenu if mouse cursor moved away from the folder
                return true
            }
        }
        .sink { [weak self] (row, folder, _) in
            self?.outlineViewDidHighlight(folder, atRow: row)
        }
        .store(in: &cancellables)
    }

    private enum HighlightEvent { case hover, dragging }
    /// Process Outline View row highlighing event on hover or drag over to expand or close a subfolder.
    /// Cances the highlight or adds a delay for the event delivery as appropriate
    /// - Returns:`BookmarkFolder?` (and row and the event kind) Publisher being currently highlighted
    ///           with delay added if needed.
    private func delayedHighlightRowEventPublisher(forRow row: Int?, on event: HighlightEvent) -> AnyPublisher<(Int?, BookmarkFolder?, HighlightEvent), Never>? {

        if let currentEvent = NSApp.currentEvent,
           currentEvent.type == .keyDown,
           currentEvent.keyCode == kVK_RightArrow {
            // don‘t expand the first highlighted folder in a submenu when it was
            // expanded using the Right arrow key
            return Empty().eraseToAnyPublisher()
        }

        let bookmarkNode = row.flatMap { outlineView.item(atRow: $0) } as? BookmarkNode
        let folder = bookmarkNode?.representedObject as? BookmarkFolder

        // prevent closing or opening another submenu when mouse is moving down+right
        let isMouseMovingDownRight: Bool = {
            if let currentEvent = NSApp.currentEvent,
               currentEvent.type == .mouseMoved,
               currentEvent.deltaY >= 0,
               currentEvent.deltaX >= currentEvent.deltaY {
                true
            } else {
                false
            }
        }()
        var delay: RunLoop.SchedulerTimeType.Stride
        // is moving down+right to a submenu?
        if event == .hover, isMouseMovingDownRight,
           let bookmarkListPopover, bookmarkListPopover.isShown,
           let expandedFolder = bookmarkListPopover.rootFolder,
           let node = treeController.node(representing: expandedFolder),
           let expandedRow = outlineView.rowIfValid(forItem: node) {
            guard expandedRow != row else { return nil }

            // delay submenu hiding when cursor is moving right (to the menu)
            // over other elements that would normally hide the submenu
            delay = 0.3
            // restore the originally highlighted row for the expanded folder
            outlineView.highlightedRow = expandedRow

        } else if event == .dragging {
            // delay folder expanding when dragging over a subfolder
            delay = 0.2
        } else if folder != nil {
            // delay folder expanding when hovering over a subfolder
            delay = 0.1
        } else {
            // hide submenu instantly when mouse is moved away from folder
            // unless it‘s moving down+right as handled above.
            delay = 0
        }

        let valuePublisher = Just((row, folder, event))
        if delay > 0 {
            return valuePublisher
                .delay(for: delay, scheduler: RunLoop.main)
                .eraseToAnyPublisher()
        } else {
            return valuePublisher.eraseToAnyPublisher()
        }
    }

    private func subscribeToDragDropEvents() {
        // restore drag&drop target folder highlight on mouse out
        // when the submenu is shown
        enum DropRowEvent {
            case dropRow(Int?)
            case highlightedRow(Int?)
        }
        Publishers.Merge(
            dataSource.$targetRowForDropOperation.map(DropRowEvent.dropRow),
            outlineView.$highlightedRow.map(DropRowEvent.highlightedRow)
        )
        .sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .dropRow(let row):
                guard row == nil else { break }
                if let bookmarkListPopover, bookmarkListPopover.isShown,
                   let expandedFolder = bookmarkListPopover.rootFolder,
                   let node = treeController.node(representing: expandedFolder),
                   let expandedRow = outlineView.rowIfValid(forItem: node),
                   expandedRow != outlineView.highlightedRow {
                    // restore expanded subfolder drop target row highlight
                    dataSource.targetRowForDropOperation = expandedRow
                }
            case .highlightedRow:
                // hide drop destination row highlight when drag operation ends
                if dataSource.targetRowForDropOperation != nil {
                    dataSource.targetRowForDropOperation = nil
                }
            }
        }
        .store(in: &cancellables)
    }

    private func subscribeToClickOutsideEvents() {
        Publishers.Merge(
            // close bookmarks menu when main menu is clicked
            NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification,
                                                 object: NSApp.mainMenu).asVoid(),
            // close bookmarks menu on click outside of the menu or its submenus
            NSEvent.publisher(forEvents: [.local, .global],
                              matching: [.leftMouseDown, .rightMouseDown])
            .filter { [weak self] event in
                if event.type == .leftMouseDown,
                   event.deviceIndependentFlags == .command,
                   event.window == nil {
                    // don‘t close on Cmd+click in other app
                    return false
                }
                guard let self,
                      // always close on global event
                      let eventWindow = event.window else { return true /* close */}
                // is showing submenu?
                if let popover = nextResponder as? BookmarkListPopover,
                   let positioningView = popover.positioningView,
                   positioningView.isMouseLocationInsideBounds(event.locationInWindow) {
                    // don‘t close when the button used to open the popover is
                    // clicked again, it‘ll be managed by
                    // BookmarksBarViewController.closeBookmarksPopovers
                    return false
                }
                // go up from the clicked window to figure out if the click is in a submenu
                for window in sequence(first: eventWindow, next: \.parent)
                where window === self.view.window {
                    // we found our window: the click was in the menu tree
                    return false // don‘t close
                }
                return true // close
            }.asVoid()
        )
        .sink { [weak self] _ in
            self?.delegate?.closeBookmarksPopovers(self!) // close
        }
        .store(in: &cancellables)
    }

    func reloadData(withRootFolder rootFolder: BookmarkFolder? = nil) {
        if let rootFolder {
            self.representedObject = rootFolder
            isSearchVisible = false
        }
        // this weirdness is needed to load a new `BookmarkFolder` object on any modification
        // because `BookmarkManager.move(objectUUIDs:toIndex:withinParentFolder)` doesn‘t
        // actually move a `Bookmark` object into actual `BookmarkFolder` object
        // as well as updating a `Bookmark` doesn‘t modify it, instead
        // `BookmarkManager.loadBookmarks()` is called every time recreating the whole
        // bookmark hierarchy.
        var rootFolder = rootFolder
        if rootFolder == nil, let oldRootFolder = self.representedObject as? BookmarkFolder {
            if oldRootFolder.id == PseudoFolder.bookmarks.id {
                // reloadData for clipped Bookmarks will be triggered with updated rootFolder
                // from BookmarksBarViewController.bookmarksBarViewModelReloadedData
                return
            }
            rootFolder = bookmarkManager.getBookmarkFolder(withId: oldRootFolder.id)
        }

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

            dataSource.reloadData(with: sortBookmarksViewModel.selectedSortMode,
                                  withRootFolder: rootFolder ?? self.representedObject as? BookmarkFolder)
            outlineView.reloadData()

            expandAndRestore(selectedNodes: selectedNodes)
        }

        let isEmpty = (outlineView.numberOfRows == 0)
        self.emptyState?.isHidden = !isEmpty
        self.searchBookmarksButton?.isHidden = isEmpty
        self.outlineView.isHidden = isEmpty

        if isEmpty {
            self.showEmptyStateView(for: .noBookmarks)
        }
    }

    private func setupSort(mode: BookmarksSortMode) {
        hideSearchBar()
        dataSource.reloadData(with: mode)
        outlineView.reloadData()
        sortBookmarksButton?.image = (mode == .nameDescending) ? .bookmarkSortDesc : .bookmarkSortAsc
        sortBookmarksButton?.backgroundColor = mode.shouldHighlightButton ? .buttonMouseDown : .clear
        sortBookmarksButton?.mouseOverColor = mode.shouldHighlightButton ? .buttonMouseDown : .buttonMouseOver
    }

    private func showDialog(_ view: any ModalView) {
        delegate?.popover(shouldPreventClosure: true)

        view.show(in: parent?.view.window) { [weak delegate] in
            delegate?.popover(shouldPreventClosure: false)
        }
    }

    // MARK: Layout

    func adjustPreferredContentSize(positionedRelativeTo positioningRect: NSRect,
                                    of positioningView: NSView,
                                    at preferredEdge: NSRectEdge) {
        _=view // loadViewIfNeeded()

        guard let mainWindow = positioningView.window,
              let screenFrame = mainWindow.screen?.visibleFrame else { return }

        self.reloadData(withRootFolder: representedObject as? BookmarkFolder)
        outlineView.highlightedRow = nil
        scrollView.contentView.bounds.origin = .zero // scroll to top

        guard case .bookmarkBarMenu = mode else {
            // if not menu popover
            preferredContentSize = Constants.preferredContentSize
            return
        }
        guard outlineView.numberOfRows > 0 else {
            preferredContentSize = Constants.noContentMenuSize
            preferredContentOffset.y = 0
            return
        }

        // popover borders
        let contentInsets = BookmarkListPopover.popoverInsets
        // positioning rect in Screen coordinates
        let windowRect = positioningView.convert(positioningRect, to: nil)
        let screenPosRect = mainWindow.convertToScreen(windowRect)
        // available screen space at the bottom
        let availableHeightBelow = screenPosRect.minY - screenFrame.minY - contentInsets.bottom

        // calculate size to fit all the contents
        var preferredContentSize = calculatePreferredContentSize()

        // menu expanding from the right edge (.maxX positioning)
        // expand up if available space at the bottom is less than content size
        if availableHeightBelow < preferredContentSize.height,
           preferredEdge == .maxX {
            // how much of the content height doesn‘t fit at the bottom?
            let contentHeightToExpandUp = preferredContentSize.height - (screenPosRect.minY - screenFrame.minY) - contentInsets.top - contentInsets.bottom
            // set the popover size to fit all the contents but not more than space available
            preferredContentSize.height = min(screenFrame.height - contentInsets.top - contentInsets.bottom, preferredContentSize.height)
            // shift the popover up from the positioining rect as much as needed
            if contentHeightToExpandUp > 0 {
                let availableHeightOnTop = screenFrame.maxY - screenPosRect.minY - contentInsets.top
                preferredContentOffset.y = min(availableHeightOnTop, contentHeightToExpandUp)
            } else {
                preferredContentOffset.y = 0
            }

        // menu expanding up from the bottom edge (.minY positioning)
        // if available space at the bottom is less than 4 rows
        } else if Int(availableHeightBelow / BookmarkOutlineCellView.rowHeight) < Constants.minVisibleRows {
            // expand the menu up from the bottom-most point
            let availableHeightOnTop = screenFrame.maxY - screenPosRect.minY - contentInsets.top
            // shift the popover up matching the content size but not more than space available
            preferredContentOffset.y = min(availableHeightOnTop, preferredContentSize.height) - availableHeightBelow
            // set the popover size to fit all the contents but not more than space available
            preferredContentSize.height = min(screenFrame.height - contentInsets.top - contentInsets.bottom, preferredContentSize.height)

        } else {
            // expand the menu down when space is available to fit the content
            preferredContentOffset = .zero
            preferredContentSize.height = min(availableHeightBelow, preferredContentSize.height)
        }

        self.preferredContentSize = preferredContentSize
        updateScrollButtons()
    }

    private func calculatePreferredContentSize() -> NSSize {
        let contentInsets = BookmarkListPopover.popoverInsets
        var contentSize = NSSize(width: 0, height: 20)
        for row in 0..<outlineView.numberOfRows {
            let node = outlineView.item(atRow: row) as? BookmarkNode

            // desired width (limited to maxMenuPopoverContentWidth)
            if contentSize.width < Constants.maxMenuPopoverContentWidth {
                let cellWidth = BookmarkOutlineCellView.preferredContentWidth(for: node) + contentInsets.left + contentInsets.right
                if cellWidth > contentSize.width {
                    contentSize.width = min(Constants.maxMenuPopoverContentWidth, cellWidth)
                }
            }
            // desired row height
            if node?.representedObject is SpacerNode {
                contentSize.height += OutlineSeparatorViewCell.rowHeight(for: mode)
            } else {
                contentSize.height += BookmarkOutlineCellView.rowHeight
            }
        }
        return contentSize
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        updateScrollButtons()
    }

    private func updateSearchAndExpand(_ folder: BookmarkFolder) {
        showTreeView()
        expandFoldersAndScrollUntil(folder)
        outlineView.scrollToAdjustedPositionInOutlineView(folder)

        guard let node = treeController.node(representing: folder) else { return }

        outlineView.highlight(node)
    }

    private func showSearchBar() {
        isSearchVisible = true
        view.addSubview(searchBar)
        outlineView.highlightedRow = nil

        guard let titleTextField, let boxDivider else { return }
        boxDividerTopConstraint?.isActive = false
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: titleTextField.bottomAnchor,
                                           constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor,
                                               constant: 16),
            view.trailingAnchor.constraint(equalTo: searchBar.trailingAnchor,
                                           constant: 16),
            boxDivider.topAnchor.constraint(equalTo: searchBar.bottomAnchor,
                                            constant: 10),
        ])

        searchBar.makeMeFirstResponder()
        searchBookmarksButton?.backgroundColor = .buttonMouseDown
        searchBookmarksButton?.mouseOverColor = .buttonMouseDown
    }

    private func hideSearchBar() {
        isSearchVisible = false
        outlineView.highlightedRow = nil
        outlineView.makeMeFirstResponder()
        searchBar.stringValue = ""
        searchBar.removeFromSuperview()
        boxDividerTopConstraint?.isActive = true
        searchBookmarksButton?.backgroundColor = .clear
        searchBookmarksButton?.mouseOverColor = .buttonMouseOver
    }

    private func showTreeView() {
        emptyState?.isHidden = true
        outlineView.isHidden = false
        dataSource.reloadData(with: sortBookmarksViewModel.selectedSortMode)
        outlineView.reloadData()
        if !isSearchVisible {
            outlineView.makeMeFirstResponder()
        }
    }

    private func showEmptyStateView(for mode: BookmarksEmptyStateContent) {
        emptyState?.isHidden = false
        outlineView.isHidden = true
        emptyStateTitle?.stringValue = mode.title
        emptyStateMessage?.stringValue = mode.description
        emptyStateImageView?.image = mode.image
        importButton?.isHidden = mode.shouldHideImportButton
    }

    private func showSubmenu(for folder: BookmarkFolder, atRow row: Int) {
        guard let cell = outlineView.view(atColumn: 0, row: row, makeIfNecessary: false) else { return }

        let bookmarkListPopover: BookmarkListPopover
        if let popover = self.bookmarkListPopover {
            bookmarkListPopover = popover
            if bookmarkListPopover.isShown {
                if bookmarkListPopover.rootFolder?.id == folder.id {
                    // submenu for the folder is already shown
                    return
                }
                bookmarkListPopover.close()
            }
            // reuse the popover for another folder
            bookmarkListPopover.reloadData(withRootFolder: folder)
        } else {
            bookmarkListPopover = BookmarkListPopover(mode: .bookmarkBarMenu, rootFolder: folder)
            bookmarkListPopover.delegate = self
            self.bookmarkListPopover = bookmarkListPopover
        }

        bookmarkListPopover.show(positionedAsSubmenuAgainst: cell)
    }

    // MARK: Actions

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_ANSI_F where event.deviceIndependentFlags == .command
            && mode != .bookmarkBarMenu:

            if isSearchVisible {
                searchBar.makeMeFirstResponder()
            } else {
                showSearchBar()
            }

        case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space:
            if outlineView.highlightedRow != nil {
                // submit action when there‘s a highlighted row
                handleClick(outlineView)

            } else if outlineView.numberOfRows > 0 {
                // when in child menu popover without selection: highlight first row
                outlineView.highlightedRow = 0
            }

        case kVK_Escape:
            delegate?.closeBookmarksPopovers(self)

        case kVK_LeftArrow:
            // if in submenu: close this submenu
            if view.window?.parent?.contentViewController is Self,
               let popover = nextResponder as? NSPopover {
                popover.close()
            } else /* we‘re in root menu */ {
                // switch between bookmarks menus on left/right
                delegate?.openPreviousBookmarksMenu(self)
            }
        case kVK_RightArrow:
            // expand currently highlighted folder
            if let highlightedRow = outlineView.highlightedRow,
               let bookmarkNode = outlineView.item(atRow: highlightedRow) as? BookmarkNode,
               let folder = bookmarkNode.representedObject as? BookmarkFolder {
                showSubmenu(for: folder, atRow: highlightedRow)
                // highlight first submenu row when expanding with Right key
                bookmarkListPopover?.viewController.outlineView.highlightFirstItem()
            } else {
                // switch between bookmarks menus on left/right
                delegate?.openNextBookmarksMenu(self)
            }

        default:
            // start search when letters are typed
            if mode != .bookmarkBarMenu,
               let characters = event.characters,
               !characters.isEmpty {

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

    @objc func newFolderButtonClicked(_ sender: AnyObject) {
        let parentFolder = sender.representedObject as? BookmarkFolder
        let view = BookmarksDialogViewFactory.makeAddBookmarkFolderView(parentFolder: parentFolder)
        showDialog(view)
    }

    @objc func searchBookmarksButtonClicked(_ sender: NSButton) {
        isSearchVisible.toggle()
    }

    @objc func sortBookmarksButtonClicked(_ sender: NSButton) {
        let menu = sortBookmarksViewModel.menu
        bookmarkMetrics.fireSortButtonClicked(origin: .panel)
        menu.delegate = sortBookmarksViewModel
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

        case let folder as BookmarkFolder:
            switch mode {
            case .popover where dataSource.isSearching:
                bookmarkMetrics.fireSearchResultClicked(origin: .panel)
                hideSearchBar()
                updateSearchAndExpand(folder)
            case .popover:
                handleItemClickWhenNotInSearchMode(item: item)
            case .bookmarkBarMenu:
                showSubmenu(for: folder, atRow: row)
            }

        case let menuItem as MenuItemNode:
            if menuItem.identifier == BookmarkTreeController.openAllInNewTabsIdentifier {
                self.openInNewTabs(sender)
            } else {
                assertionFailure("Unsupported menu item action \(menuItem.identifier)")
            }
            delegate?.closeBookmarksPopovers(self)

        default: break
        }
    }

    private func onBookmarkClick(_ bookmark: Bookmark) {
        if dataSource.isSearching {
            bookmarkMetrics.fireSearchResultClicked(origin: .panel)
        }

        WindowControllersManager.shared.open(bookmark: bookmark)
        delegate?.closeBookmarksPopovers(self)
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
        delegate?.closeBookmarksPopovers(self)
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

    private func showContextMenu(for cell: BookmarkOutlineCellView) {
        let row = outlineView.row(for: cell)
        guard
            let item = outlineView.item(atRow: row),
            let contextMenu = ContextualMenu.menu(for: [item], target: self, forSearch: dataSource.isSearching)
        else {
            return
        }

        contextMenu.popUpAtMouseLocation(in: view)
    }

    /// Show or close folder submenu on row hover
    /// the method is called from `outlineView.$highlightedRow` observer after a delay as needed
    func outlineViewDidHighlight(_ folder: BookmarkFolder?, atRow row: Int?) {
        guard let row, let folder else {
            // close submenu if shown
            guard let bookmarkListPopover, bookmarkListPopover.isShown else { return }
            bookmarkListPopover.close()
            // unhighlight drop destination row if highlighted
            dataSource.targetRowForDropOperation = nil
            return
        }

        showSubmenu(for: folder, atRow: row)
    }

    // MARK: Bookmarks Menu scrolling

    private func subscribeToScrollingEvents() {
        // scrollViewDidScroll
        NotificationCenter.default
            .publisher(for: NSView.boundsDidChangeNotification, object: scrollView.contentView).asVoid()
            .compactMap { [weak scrollView=scrollView] in
                scrollView?.documentVisibleRect
            }
            .scan((old: CGRect.zero, new: scrollView.documentVisibleRect)) {
                (old: $0.new, new: $1)
            }
            .sink { [weak self] change in
                self?.scrollViewDidScroll(old: change.old, new: change.new)
            }.store(in: &cancellables)

        // Scroll Up Button hover
        scrollUpButton?.publisher(for: \.isMouseOver)
            .map { [weak scrollDownButton] isMouseOver in
                guard isMouseOver,
                      NSApp.currentEvent?.type != .keyDown else {
                    if let scrollDownButton, scrollDownButton.isMouseOver {
                        // ignore mouse over change when the button appears on
                        // the Down key press
                        scrollDownButton.isMouseOver = false
                    }
                    return Empty<Void, Never>().eraseToAnyPublisher()
                }
                return Timer.publish(every: 0.1, on: .main, in: .default)
                    .autoconnect()
                    .asVoid()
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [weak outlineView] in
                guard let outlineView else { return }
                // scroll up on scrollUpButton hover on Timed events
                let newScrollOrigin = NSPoint(x: outlineView.visibleRect.origin.x, y: outlineView.visibleRect.origin.y - BookmarkOutlineCellView.rowHeight)
                outlineView.scroll(newScrollOrigin)
            }
            .store(in: &cancellables)

        // Scroll Down Button hover
        scrollDownButton?.publisher(for: \.isMouseOver)
            .map { [weak scrollDownButton] isMouseOver in
                guard isMouseOver,
                      NSApp.currentEvent?.type != .keyDown else {
                    if let scrollDownButton, scrollDownButton.isMouseOver {
                        // ignore mouse over change when the button appears on
                        // the Down key press
                        scrollDownButton.isMouseOver = false
                    }
                    return Empty<Void, Never>().eraseToAnyPublisher()
                }
                return Timer.publish(every: 0.1, on: .main, in: .default)
                    .autoconnect()
                    .asVoid()
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [weak outlineView] in
                guard let outlineView else { return }
                // scroll down on scrollDownButton hover on Timed events
                let newScrollOrigin = NSPoint(x: outlineView.visibleRect.origin.x, y: outlineView.visibleRect.origin.y + BookmarkOutlineCellView.rowHeight)
                outlineView.scroll(newScrollOrigin)
            }
            .store(in: &cancellables)
    }

    private func scrollViewDidScroll(old oldVisibleRect: NSRect, new visibleRect: NSRect) {
        guard let window = view.window, let screen = window.screen else { return }

        let availableHeight = screen.visibleFrame.maxY - window.frame.maxY
        let scrollDeltaY = visibleRect.minY - oldVisibleRect.minY
        if scrollDeltaY > 0, availableHeight > 0 {
            let contentHeight = outlineView.bounds.height
            // shift bookmarks menu popover up incrementing height if screen space is available
            var popoverHeightIncrement = min(availableHeight, scrollDeltaY)
            if preferredContentSize.height + popoverHeightIncrement > contentHeight {
                popoverHeightIncrement = contentHeight - preferredContentSize.height
            }
            if popoverHeightIncrement > 0 {
                preferredContentOffset.y = popoverHeightIncrement
                preferredContentSize.height += popoverHeightIncrement
                // decrement scrolling position
                if preferredContentSize.height + popoverHeightIncrement > contentHeight {
                    scrollView.contentView.bounds.origin.y = 0
                } else {
                    scrollView.contentView.bounds.origin.y -= popoverHeightIncrement
                }
            }
            // -> will update scroll buttons on next `viewDidLayout` pass

        } else {
            updateScrollButtons()
        }

        if let event = NSApp.currentEvent, event.type != .keyDown {
            // update current highlighted row to match cursor position
            outlineView.updateHighlightedRowUnderCursor()
        }
    }

    private func updateScrollButtons() {
        guard let scrollUpButton, let scrollDownButton else { return }
        let contentHeight = outlineView.bounds.height

        var visibleRect = scrollView.documentVisibleRect
        if scrollUpButton.isShown {
            visibleRect.size.height += scrollUpButton.frame.height
        }
        if scrollDownButton.isShown {
            visibleRect.size.height += scrollDownButton.frame.height
        }
        scrollUpButton.isShown = visibleRect.minY > 0
        scrollDownButton.isShown = visibleRect.maxY < contentHeight
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
            return ContextualMenu.menu(for: [item], forSearch: dataSource.isSearching)
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
// MARK: - BookmarkMenuItemSelectors
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
        showDialog(view)
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
// MARK: - FolderMenuItemSelectors
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
        showDialog(view)
    }

    func deleteFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Delete Folder context menu item")
            return
        }

        bookmarkManager.remove(folder: folder)
    }

    func openInNewTabs(_ sender: Any) {
        guard let tabCollection = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel,
              let folder = ((sender as? NSMenuItem)?.representedObject ?? self.treeController.rootNode.representedObject) as? BookmarkFolder
        else {
            assertionFailure("Cannot open all in new tabs")
            return
        }
        delegate?.closeBookmarksPopovers(self)

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
                showSearch(forSearchQuery: searchQuery)
            }

            bookmarkMetrics.fireSearchExecuted(origin: .panel)
        }
    }

    private func showSearch(forSearchQuery searchQuery: String) {
        outlineView.highlightedRow = nil
        dataSource.reloadData(forSearchQuery: searchQuery, sortMode: sortBookmarksViewModel.selectedSortMode)

        if treeController.rootNode.childNodes.isEmpty {
            showEmptyStateView(for: .noSearchResults)
        } else {
            emptyState?.isHidden = true
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
// MARK: - MouseOverButtonDelegate
extension BookmarkListViewController: MouseOverButtonDelegate {

    // scroll bookmarks menu up/down on scroll buttons mouse over
    func mouseOverButton(_ sender: MouseOverButton, draggingEntered info: any NSDraggingInfo, isMouseOver: UnsafeMutablePointer<Bool>) -> NSDragOperation {

        assert(sender === scrollUpButton || sender === scrollDownButton)
        isMouseOver.pointee = true
        return .none
    }

    // scroll bookmarks menu up/down on dragging over scroll buttons
    func mouseOverButton(_ sender: MouseOverButton, draggingUpdatedWith info: any NSDraggingInfo, isMouseOver: UnsafeMutablePointer<Bool>) -> NSDragOperation {
        assert(sender === scrollUpButton || sender === scrollDownButton)
        isMouseOver.pointee = true
        return .none
    }

}
// MARK: - BookmarkListPopoverDelegate
extension BookmarkListViewController: BookmarkListPopoverDelegate {
    // pass delegate calls up when called from submenu
    func openNextBookmarksMenu(_ sender: BookmarkListPopover) {
        delegate?.openNextBookmarksMenu(self)
    }
    func openPreviousBookmarksMenu(_ sender: BookmarkListPopover) {
        delegate?.openPreviousBookmarksMenu(self)
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
#Preview("Bookmarks Bar Menu", traits: BookmarkListViewController.Constants.preferredContentSize.fixedLayout) {
    BookmarkListViewController(mode: .bookmarkBarMenu, bookmarkManager: _mockPreviewBookmarkManager(previewEmptyState: false))
        ._preview_hidingWindowControlsOnAppear()
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
