//
//  BookmarkManagementSidebarViewController.swift
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

protocol BookmarkManagementSidebarViewControllerDelegate: AnyObject {

    func bookmarkManagementSidebarViewController(_ sidebarViewController: BookmarkManagementSidebarViewController,
                                                 enteredState state: BookmarkManagementSidebarViewController.SelectionState)

}

final class BookmarkManagementSidebarViewController: NSViewController {

    enum SelectionState: Equatable {
        case empty
        case folder(BookmarkFolder)
        case favorites

        var folder: BookmarkFolder? {
            if case .folder(let folder) = self { folder } else { nil }
        }

        var selectedFolderUUID: String? {
            folder?.id
        }
    }

    private lazy var viewColorView = ColorView(frame: .zero, backgroundColor: .interfaceBackground)
    private lazy var tableColumnCell = NSTextFieldCell()
    private lazy var tableColumn = NSTableColumn()
    private lazy var scrollView = NSScrollView()
    private lazy var customMenu = NSMenu()
    private lazy var customMenuItemBookmarks = NSMenuItem(title: UserText.bookmarks, action: nil, keyEquivalent: "")
    let tabSwitcherButton = NSPopUpButton()
    private lazy var outlineView = BookmarksOutlineView()

    weak var delegate: BookmarkManagementSidebarViewControllerDelegate?

    private let bookmarkManager: BookmarkManager
    private let treeControllerDataSource = BookmarkSidebarTreeController()

    private lazy var treeController: BookmarkTreeController = {
        return BookmarkTreeController(dataSource: treeControllerDataSource)
    }()

    private lazy var dataSource: BookmarkOutlineViewDataSource = {
        BookmarkOutlineViewDataSource(contentMode: .foldersOnly, treeController: treeController)
    }()

    private var cancellables = Set<AnyCancellable>()

    private var selectedNodes: [BookmarkNode] {
        if let nodes = outlineView.selectedItems as? [BookmarkNode] {
            return nodes
        }
        return [BookmarkNode]()
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
        view = NSView()

        view.addSubview(viewColorView)
        view.addSubview(scrollView)
        view.addSubview(tabSwitcherButton)

        tabSwitcherButton.translatesAutoresizingMaskIntoConstraints = false
        tabSwitcherButton.alignment = .left
        tabSwitcherButton.bezelStyle = .rounded
        if #available(macOS 11.0, *) {
            tabSwitcherButton.controlSize = .large
        }
        tabSwitcherButton.font = .systemFont(ofSize: 22)
        tabSwitcherButton.imageScaling = .scaleProportionallyDown
        tabSwitcherButton.lineBreakMode = .byTruncatingTail
        tabSwitcherButton.title = UserText.bookmarks
        tabSwitcherButton.cell?.state = .on

        customMenu.addItem(customMenuItemBookmarks)

        customMenuItemBookmarks.state = .on

        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalLineScroll = 28
        scrollView.horizontalPageScroll = 10
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.usesPredominantAxisScrolling = false
        scrollView.verticalLineScroll = 28
        scrollView.verticalPageScroll = 10

        let clipView = NSClipView()
        clipView.documentView = outlineView

        clipView.autoresizingMask = [.width, .height]
        clipView.backgroundColor = .clear
        clipView.drawsBackground = false
        clipView.frame = CGRect(x: 0, y: 0, width: 234, height: 410)

        outlineView.addTableColumn(NSTableColumn())

        outlineView.allowsColumnResizing = false
        outlineView.allowsEmptySelection = false
        outlineView.allowsExpansionToolTips = true
        outlineView.allowsMultipleSelection = false
        outlineView.autoresizingMask = [.width, .height]
        outlineView.autosaveTableColumns = false
        outlineView.backgroundColor = .clear
        outlineView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        outlineView.frame = CGRect(x: 0, y: 0, width: 234, height: 410)
        outlineView.gridColor = .gridColor
        outlineView.indentationPerLevel = 13
        outlineView.intercellSpacing = CGSize(width: 17, height: 0)
        outlineView.outlineTableColumn = tableColumn
        outlineView.rowHeight = 28
        outlineView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        outlineView.target = nil
        outlineView.doubleAction = #selector(onDoubleClick)
        outlineView.menu = NSMenu()
        outlineView.menu!.delegate = self

        tableColumn.maxWidth = 1000
        tableColumn.minWidth = 120
        tableColumn.resizingMask = [.autoresizingMask, .userResizingMask]
        tableColumn.width = 202

        tableColumnCell.backgroundColor = .controlBackgroundColor
        tableColumnCell.font = .systemFont(ofSize: 13)
        tableColumnCell.isEditable = true
        tableColumnCell.isSelectable = true
        tableColumnCell.lineBreakMode = .byTruncatingTail
        tableColumnCell.stringValue = "Text Cell"
        tableColumnCell.textColor = .controlTextColor

        tableColumn.headerCell.backgroundColor = .headerColor
        tableColumn.headerCell.isBordered = true
        tableColumn.headerCell.lineBreakMode = .byTruncatingTail
        tableColumn.headerCell.textColor = .headerTextColor

        scrollView.contentView = clipView

        viewColorView.translatesAutoresizingMaskIntoConstraints = false

        setupLayout()
    }

    private func setupLayout() {

        view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: 12).isActive = true
        view.trailingAnchor.constraint(equalTo: tabSwitcherButton.trailingAnchor, constant: 23).isActive = true
        scrollView.topAnchor.constraint(equalTo: tabSwitcherButton.bottomAnchor, constant: 12).isActive = true
        viewColorView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tabSwitcherButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 23).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12).isActive = true
        view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
        viewColorView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        viewColorView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        viewColorView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tabSwitcherButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 18).isActive = true

        tabSwitcherButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
    }

    @IBAction func onDoubleClick(_ sender: NSOutlineView) {
        guard let item = sender.item(atRow: sender.clickedRow) else { return }
        if sender.isItemExpanded(item) {
            sender.animator().collapseItem(item)
        } else {
            sender.animator().expandItem(item)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        outlineView.register(BookmarkOutlineViewCell.nib, forIdentifier: BookmarkOutlineViewCell.identifier)
        outlineView.dataSource = dataSource
        outlineView.delegate = dataSource
        outlineView.setDraggingSourceOperationMask([.move], forLocal: true)
        outlineView.registerForDraggedTypes([BookmarkPasteboardWriter.bookmarkUTIInternalType,
                                             FolderPasteboardWriter.folderUTIInternalType])

        dataSource.$selectedFolders.sink { [weak self] selectedFolders in
            guard let self = self else { return }

            switch selectedFolders.count {
            case 0:
                if self.outlineView.selectedPseudoFolders == [PseudoFolder.favorites] {
                    self.delegate?.bookmarkManagementSidebarViewController(self, enteredState: .favorites)
                } else {
                    self.delegate?.bookmarkManagementSidebarViewController(self, enteredState: .empty)
                }

            case 1:
                self.delegate?.bookmarkManagementSidebarViewController(self, enteredState: .folder(selectedFolders[0]))

            default:
                assertionFailure("\(#file): Multi-select is not yet supported")
                self.delegate?.bookmarkManagementSidebarViewController(self, enteredState: .empty)
            }
        }.store(in: &cancellables)

        bookmarkManager.listPublisher.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.reloadData()
        }.store(in: &cancellables)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        reloadData()

        tabSwitcherButton.select(tabType: .bookmarks)

        bookmarkManager.requestSync()
    }

    func select(folder: BookmarkFolder) {
        if let node = treeController.node(representing: folder) {
            let path = BookmarkNode.Path(node: node)
            outlineView.revealAndSelect(nodePath: path)
        }
    }

    private func reloadData() {
        let selectedNodes = self.selectedNodes
        dataSource.reloadData()
        outlineView.reloadData()

        expandAndRestore(selectedNodes: selectedNodes)
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

            // Expand the Bookmarks pseudo folder automatically.
            if let pseudoFolder = node.representedObject as? PseudoFolder, pseudoFolder == PseudoFolder.bookmarks {
                outlineView.expandItem(node)
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

extension BookmarkManagementSidebarViewController: NSMenuDelegate {

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

    func menuNeedsUpdate(_ menu: NSMenu) {
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

extension BookmarkManagementSidebarViewController: FolderMenuItemSelectors {

    func newFolder(_ sender: NSMenuItem) {
        AddBookmarkFolderModalView().show(in: view.window)
    }

    func renameFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Rename Folder context menu item")
            return
        }

        AddBookmarkFolderModalView(model: AddBookmarkFolderModalViewModel(folder: folder))
            .show(in: view.window)
    }

    func deleteFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Folder from Delete Folder context menu item")
            return
        }

        bookmarkManager.remove(folder: folder)
    }

    func openInNewTabs(_ sender: NSMenuItem) {
        guard let tabCollection = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel,
              let children = (sender.representedObject as? BookmarkFolder)?.children else {
            assertionFailure("Cannot open in new tabs")
            return
        }

        let tabs = children.compactMap { ($0 as? Bookmark)?.urlObject }.map { Tab(content: .url($0, source: .bookmark), shouldLoadInBackground: true, burnerMode: tabCollection.burnerMode) }
        tabCollection.append(tabs: tabs)
    }

}

#if DEBUG
@available(macOS 14.0, *)
#Preview {

    return BookmarkManagementSidebarViewController(bookmarkManager: {
        let bkman = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [
            BookmarkFolder(id: "1", title: "Folder 1", children: [
                BookmarkFolder(id: "2", title: "Nested Folder", children: [
                ])
            ]),
            BookmarkFolder(id: "3", title: "Another Folder", children: [
                BookmarkFolder(id: "4", title: "Nested Folder", children: [
                    BookmarkFolder(id: "5", title: "Another Nested Folder", children: [
                    ])
                ])
            ])
        ]))
        bkman.loadBookmarks()
        customAssertionFailure = { _, _, _ in }

        return bkman
    }())

}
#endif
