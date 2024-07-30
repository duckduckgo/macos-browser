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

    func popoverShouldClose(_ bookmarkListViewController: BookmarkListViewController)
    func popover(shouldPreventClosure: Bool)

}

final class BookmarkListViewController: NSViewController {

    enum Mode {
        case popover
        case bookmarkBarMenu
    }

    fileprivate enum Constants {
        static let preferredContentSize = CGSize(width: 420, height: 300)
        static let noContentMenuSize = CGSize(width: 240, height: 0)
        static let maxMenuPopoverContentWidth: CGFloat = 500 - 13 * 2
        static let minVisibleRows = 4
    }

    let mode: Mode

    weak var delegate: BookmarkListViewControllerDelegate?
    var currentTabWebsite: WebsiteInfo?

    private var newBookmarkButton: MouseOverButton?
    private var newFolderButton: MouseOverButton?
    private var manageBookmarksButton: MouseOverButton?

    private lazy var scrollView = SteppedScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 408),
                                                    stepSize: BookmarkOutlineCellView.rowHeight)
    private lazy var outlineView = BookmarksOutlineView(frame: scrollView.frame)

    private var scrollDownButton: MouseOverButton?
    private var scrollUpButton: MouseOverButton?

    private var emptyState: NSView?

    private var cancellables = Set<AnyCancellable>()
    private let bookmarkManager: BookmarkManager
    private let treeControllerDataSource: BookmarkListTreeControllerDataSource
    private let treeController: BookmarkTreeController

    private var bookmarkListPopover: BookmarkListPopover?
    private(set) var preferredContentOffset: CGPoint = .zero

    private lazy var dataSource: BookmarkOutlineViewDataSource = {
        BookmarkOutlineViewDataSource(
            contentMode: mode == .bookmarkBarMenu ? .bookmarksMenu : .bookmarksAndFolders,
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

    init(mode: Mode = .popover,
         bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
         rootFolder: BookmarkFolder? = nil) {

        self.mode = mode
        self.bookmarkManager = bookmarkManager
        self.treeControllerDataSource = BookmarkListTreeControllerDataSource(bookmarkManager: bookmarkManager)
        self.treeController = BookmarkTreeController(dataSource: treeControllerDataSource, rootFolder: rootFolder, isBookmarksBarMenu: mode == .bookmarkBarMenu)

        super.init(nibName: nil, bundle: nil)
        self.representedObject = rootFolder
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    override func loadView() {
        view = NSView() // ColorView(frame: .zero, backgroundColor: .popoverBackground)
        view.autoresizesSubviews = false

        let titleTextField = (mode == .bookmarkBarMenu) ? nil : {
            let titleTextField = NSTextField(string: UserText.bookmarks)

            titleTextField.isEditable = false
            titleTextField.isBordered = false
            titleTextField.drawsBackground = false
            titleTextField.translatesAutoresizingMaskIntoConstraints = false
            titleTextField.font = .systemFont(ofSize: 17)
            titleTextField.textColor = .labelColor
            titleTextField.setContentHuggingPriority(.defaultHigh, for: .vertical)
            titleTextField.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)

            return titleTextField
        }()

        let boxDivider = (mode == .bookmarkBarMenu) ? nil : {
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
            manageBookmarksButton.imageHugsTitle = true
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
            stackView.addArrangedSubview(buttonsDivider)
            stackView.addArrangedSubview(manageBookmarksButton)
            return stackView
        }()

//        scrollView.setValue(self, forKey: "contextMenuDelegate")
//        scrollView.setValue(1, forKey: "scrollingBehavior")
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
//            scrollView.autohidesScrollers = false
            scrollView.hasVerticalScroller = false
            scrollView.perform("setAutoforwardsScrollWheelEvents:", with: 1)
            scrollView.scrollerStyle = .overlay
            scrollView.verticalScrollElasticity = .none
            scrollView.horizontalScrollElasticity = .none
//            scrollView.scrollerInsets = NSEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
//            scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 12)
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
// TODO: fix cell line wrapping into 2nd line
        let clipView = NSClipView(frame: scrollView.frame)
        clipView.setValue(0, forKey: "canAnimateScrolls")
        clipView.translatesAutoresizingMaskIntoConstraints = true
        clipView.autoresizingMask = [.width, .height]
        clipView.documentView = outlineView
        clipView.drawsBackground = false
        scrollView.contentView = clipView
// TODO: buttons scrolling is broken now: multiple items get highlighted and scroll is instant to the top
        scrollUpButton = mode == .popover ? nil : {
            let scrollUpButton = MouseOverButton(image: .condenseUp, target: nil, action: nil)
            scrollUpButton.translatesAutoresizingMaskIntoConstraints = false
            scrollUpButton.bezelStyle = .shadowlessSquare
            scrollUpButton.normalTintColor = .labelColor
            scrollUpButton.backgroundColor = .clear
            // TODO: remove
            scrollUpButton.mouseOverColor = .blackWhite10
            return scrollUpButton
        }()
        scrollDownButton = mode == .popover ? nil : {
            let scrollDownButton = MouseOverButton(image: .expandDown, target: nil, action: nil)
            scrollDownButton.translatesAutoresizingMaskIntoConstraints = false
            scrollDownButton.bezelStyle = .shadowlessSquare
            scrollDownButton.normalTintColor = .labelColor
            scrollDownButton.backgroundColor = .clear
            // TODO: remove
            scrollDownButton.mouseOverColor = .blackWhite10
            return scrollDownButton
        }()

        titleTextField.map(view.addSubview)
        boxDivider.map(view.addSubview)
        stackView.map(view.addSubview)
        view.addSubview(scrollView)
        scrollUpButton.map(view.addSubview)
        scrollDownButton.map(view.addSubview)

        emptyState = (mode == .bookmarkBarMenu) ? nil : {
            let emptyStateImageView = NSImageView(image: .bookmarksEmpty)
            emptyStateImageView.translatesAutoresizingMaskIntoConstraints = false
            emptyStateImageView.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
            emptyStateImageView.setContentHuggingPriority(.init(rawValue: 251), for: .vertical)

            let emptyStateTitle = NSTextField()
            emptyStateTitle.translatesAutoresizingMaskIntoConstraints = false
            emptyStateTitle.setContentHuggingPriority(.defaultHigh, for: .vertical)
            emptyStateTitle.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
            emptyStateTitle.alignment = .center
            emptyStateTitle.drawsBackground = false
            emptyStateTitle.isBordered = false
            emptyStateTitle.isEditable = false
            emptyStateTitle.font = .systemFont(ofSize: 15, weight: .semibold)
            emptyStateTitle.textColor = .labelColor
            emptyStateTitle.attributedStringValue = NSAttributedString.make(UserText.bookmarksEmptyStateTitle,
                                                                            lineHeight: 1.14,
                                                                            kern: -0.23)

            let emptyStateMessage = NSTextField()
            emptyStateMessage.translatesAutoresizingMaskIntoConstraints = false
            emptyStateMessage.setContentHuggingPriority(.defaultHigh, for: .vertical)
            emptyStateMessage.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
            emptyStateMessage.alignment = .center
            emptyStateMessage.drawsBackground = false
            emptyStateMessage.isBordered = false
            emptyStateMessage.isEditable = false
            emptyStateMessage.font = .systemFont(ofSize: 13)
            emptyStateMessage.textColor = .labelColor
            emptyStateMessage.attributedStringValue = NSAttributedString.make(UserText.bookmarksEmptyStateMessage,
                                                                              lineHeight: 1.05,
                                                                              kern: -0.08)

            let importButton = NSButton(title: UserText.importBookmarksButtonTitle, target: self,
                                        action: #selector(onImportClicked))
            importButton.translatesAutoresizingMaskIntoConstraints = false

            let emptyState = NSView()
            emptyState.addSubview(emptyStateImageView)
            emptyState.addSubview(emptyStateTitle)
            emptyState.addSubview(emptyStateMessage)
            emptyState.addSubview(importButton)

            emptyState.isHidden = true
            emptyState.translatesAutoresizingMaskIntoConstraints = false

            view.addSubview(emptyState)

            setupEmptyStateLayout(emptyState: emptyState, emptyStateImageView: emptyStateImageView, emptyStateTitle: emptyStateTitle, emptyStateMessage: emptyStateMessage, importButton: importButton, boxDivider: boxDivider)

            return emptyState
        }()

        setupLayout(titleTextField: titleTextField, boxDivider: boxDivider, stackView: stackView, buttonsDivider: buttonsDivider)
    }

    private func setupLayout(titleTextField: NSTextField?, boxDivider: NSBox?, stackView: NSStackView?, buttonsDivider: NSBox?) {
        var constraints = [
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                .priority(900),
        ]

        if let titleTextField, let boxDivider, let stackView {
            constraints += [
                titleTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
                titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),

                stackView.centerYAnchor.constraint(equalTo: titleTextField.centerYAnchor),
                view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 20),

                boxDivider.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 12),
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

        NSLayoutConstraint.activate(constraints)
    }

    private func setupEmptyStateLayout(emptyState: NSView, emptyStateImageView: NSImageView, emptyStateTitle: NSTextField, emptyStateMessage: NSTextField, importButton: NSButton, boxDivider: NSBox?) {

        if let boxDivider {
            NSLayoutConstraint.activate([
                emptyState.topAnchor.constraint(equalTo: boxDivider.bottomAnchor),
                emptyState.centerXAnchor.constraint(equalTo: boxDivider.centerXAnchor),
            ])
        } else {
            assertionFailure("boxDivider is nil")
        }
        NSLayoutConstraint.activate([
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
        super.viewDidLoad()

        preferredContentSize = Constants.preferredContentSize

        outlineView.setDraggingSourceOperationMask([.move], forLocal: true)
        outlineView.registerForDraggedTypes([BookmarkPasteboardWriter.bookmarkUTIInternalType,
                                             FolderPasteboardWriter.folderUTIInternalType])
        if case .bookmarkBarMenu = mode {
            subscribeToMenuPopoverEvents()
        }
    }

    private func subscribeToMenuPopoverEvents() {
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

        bookmarkManager.listPublisher.receive(on: DispatchQueue.main).sink { [weak self] list in
            self?.reloadData()
            let isEmpty = list?.topLevelEntities.isEmpty ?? true
            self?.emptyState?.isHidden = !isEmpty
            self?.outlineView.isHidden = isEmpty
        }.store(in: &cancellables)

        scrollUpButton?.$isMouseOver
            .map { isMouseOver in
                guard isMouseOver else {
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
                let newScrollOrigin = NSPoint(x: outlineView.visibleRect.origin.x, y: outlineView.visibleRect.origin.y - BookmarkOutlineCellView.rowHeight)
                outlineView.scroll(newScrollOrigin)
            }
            .store(in: &cancellables)

        scrollDownButton?.$isMouseOver
            .map { isMouseOver in
                guard isMouseOver else {
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
                let newScrollOrigin = NSPoint(x: outlineView.visibleRect.origin.x, y: outlineView.visibleRect.origin.y + BookmarkOutlineCellView.rowHeight)
                outlineView.scroll(newScrollOrigin)
            }
            .store(in: &cancellables)

        outlineView.$highlightedRow
            .throttle(for: 0.3, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] row in
                guard let self else { return }

                guard let row,
                      let bookmarkNode = outlineView.item(atRow: row) as? BookmarkNode,
                      let folder = bookmarkNode.representedObject as? BookmarkFolder,
                      let cell = self.outlineView.view(atColumn: 0,
                                                       row: row, makeIfNecessary: false) else {
                    guard let bookmarkListPopover, bookmarkListPopover.isShown else { return }
                    bookmarkListPopover.close()
                    return
                }

                // TODO: don‘t show submenu while scrolling
                let bookmarkListPopover: BookmarkListPopover
                if let popover = self.bookmarkListPopover {
                    bookmarkListPopover = popover
                    if bookmarkListPopover.isShown {
                        bookmarkListPopover.close()
                    }
                    bookmarkListPopover.reloadData(withRootFolder: folder)
                } else {
                    bookmarkListPopover = BookmarkListPopover(mode: .bookmarkBarMenu, rootFolder: folder)
                    self.bookmarkListPopover = bookmarkListPopover
                }
// TODO: sometimes when opening Imported->Other->Books -> nested popover is shown, hidden, shown again
// TODO: Don‘t expand instantly to the next level when expanded and the first item in the submenu is another folder
                bookmarkListPopover.show(positionedAsSubmenuAgainst: cell)
                if let currentEvent = NSApp.currentEvent,
                   currentEvent.type == .keyDown, currentEvent.keyCode == kVK_RightArrow,
                   bookmarkListPopover.viewController.outlineView.numberOfRows > 0 {
                    DispatchQueue.main.async {
                        bookmarkListPopover.viewController.outlineView.highlightedRow = 0
                    }
                }
            }
            .store(in: &cancellables)
    }

    func adjustPreferredContentSize(positionedAt preferredEdge: NSRectEdge,
                                    of positioningView: NSView,
                                    contentInsets: NSEdgeInsets) {
        _=view // loadViewIfNeeded()

        guard let mainWindow = positioningView.window,
              let screenFrame = mainWindow.screen?.visibleFrame else { return }

        reloadData()
        outlineView.highlightedRow = nil
        scrollView.contentView.bounds.origin = .zero // scroll to top

        guard case .bookmarkBarMenu = mode else {
            // if not menu popover
            preferredContentSize = Constants.preferredContentSize
            return
        }
        guard outlineView.numberOfRows > 0 else {
            preferredContentSize = Constants.noContentMenuSize
            return
        }

        // available screen space at the bottom
        let windowRect = positioningView.convert(positioningView.bounds, to: nil)
        let positioningRect = mainWindow.convertToScreen(windowRect)
        var availableHeight = positioningRect.minY - screenFrame.minY - contentInsets.bottom

        var preferredContentSize = NSSize.zero
        var contentHeight: CGFloat = 20
        for row in 0..<outlineView.numberOfRows {
            let node = outlineView.item(atRow: row) as? BookmarkNode

            if preferredContentSize.width < Constants.maxMenuPopoverContentWidth {
                let cellWidth = BookmarkOutlineCellView.preferredContentWidth(for: node) + contentInsets.left + contentInsets.right
                if cellWidth > preferredContentSize.width {
                    preferredContentSize.width = min(Constants.maxMenuPopoverContentWidth, cellWidth)
                }
            }
            if node?.representedObject is SpacerNode {
                contentHeight += OutlineSeparatorViewCell.rowHeight(for: mode)
            } else {
                contentHeight += BookmarkOutlineCellView.rowHeight
            }
        }

        if availableHeight < contentHeight,
           preferredEdge == .maxX || Int(availableHeight / BookmarkOutlineCellView.rowHeight) < Constants.minVisibleRows {
            // available screen space at the top
            availableHeight = screenFrame.maxY - positioningRect.minY - contentInsets.top
            // expand the menu up if available space at the bottom is less than 4 rows
            preferredContentOffset.y = min(availableHeight, contentHeight)
            preferredContentSize.height = min(screenFrame.height - contentInsets.top - contentInsets.bottom, contentHeight)

        } else {
            // expand the menu down
            preferredContentOffset = .zero
            preferredContentSize.height = min(availableHeight, contentHeight)
        }

        self.preferredContentSize = preferredContentSize

        updateScrollButtons()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        updateScrollButtons()
    }

    private func scrollViewDidScroll(old oldVisibleRect: NSRect, new visibleRect: NSRect) {
        guard let window = view.window, let screen = window.screen else { return }

        let availableHeight = screen.visibleFrame.maxY - window.frame.maxY
        let scrollDeltaY = visibleRect.minY - oldVisibleRect.minY
        if scrollDeltaY > 0, availableHeight > 0 {
            let contentHeight = outlineView.bounds.height // CGFloat(outlineView.numberOfRows) * Constants.rowHeight
            // shift bookmarks menu popover up incrementing height if screen space is available
            var popoverHeightIncrement = min(availableHeight, scrollDeltaY)
            if preferredContentSize.height + popoverHeightIncrement > contentHeight {
                popoverHeightIncrement = contentHeight - preferredContentSize.height
            }
            if popoverHeightIncrement > 0 {
                preferredContentOffset.y = popoverHeightIncrement
                preferredContentSize.height += popoverHeightIncrement
                // decrement scrolling position
                scrollView.contentView.bounds.origin.y -= popoverHeightIncrement
            }
            // will update scroll buttons on viewDidLayout
        } else {
            updateScrollButtons()
        }

        // TODO: when mouse is over the "scroll up" button and items are selected using the down arrow key, the button detects mouse over on appear and starts scrolling resetting the selection here.
        if let event = NSApp.currentEvent,
           event.type != .keyDown {
            outlineView.mouseMoved(with: event)
        }
    }

    private func updateScrollButtons() {
        guard let scrollUpButton, let scrollDownButton else { return }
        let contentHeight = outlineView.rowHeight * CGFloat(outlineView.numberOfRows) + 16

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

    private func reloadData() {
        let selectedNodes = self.selectedNodes

        dataSource.reloadData(rebuild: true)
        outlineView.reloadData()

        expandAndRestore(selectedNodes: selectedNodes)
    }

    func reloadData(withRootFolder rootFolder: BookmarkFolder) {
        self.representedObject = rootFolder
        treeController.rebuild(withRootFolder: rootFolder)
        dataSource.reloadData(rebuild: false)
        outlineView.reloadData()
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

    @objc func openManagementInterface(_ sender: NSButton) {
        showManageBookmarks()
    }

    @objc func handleClick(_ sender: NSOutlineView) {
        guard sender.clickedRow != -1 else { return }

        let item = sender.item(atRow: sender.clickedRow)
        guard let node = item as? BookmarkNode else { return }

        switch node.representedObject {
        case let bookmark as Bookmark:
            WindowControllersManager.shared.open(bookmark: bookmark)
            delegate?.popoverShouldClose(self)

        case let menuItem as MenuItemNode:
            if menuItem.identifier == BookmarkTreeController.openAllInNewTabsIdentifier {
                self.openInNewTabs(sender)
            } else {
                assertionFailure("Unsupported menu item action \(menuItem.identifier)")
            }
            delegate?.popoverShouldClose(self)
        default:
            if outlineView.isItemExpanded(item) {
                outlineView.animator().collapseItem(item)
            } else {
                outlineView.animator().expandItem(item)
            }
        }
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

    func openInNewTabs(_ sender: Any) {
        guard let tabCollection = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel,
              let folder = ((sender as? NSMenuItem)?.representedObject ?? self.treeController.rootNode.representedObject) as? BookmarkFolder
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
