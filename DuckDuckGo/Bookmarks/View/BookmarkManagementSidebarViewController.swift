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

import AppKit
import Combine
import PreferencesUI_macOS

protocol BookmarkManagementSidebarViewControllerDelegate: AnyObject {

    func sidebarSelectionStateDidChange(_ state: BookmarkManagementSidebarViewController.SelectionState)
    func sidebarSelectedTabContentDidChange(_ content: Tab.TabContent)

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

    private let bookmarkManager: BookmarkManager
    private let dragDropManager: BookmarkDragDropManager
    private let treeControllerDataSource: BookmarkSidebarTreeController

    private lazy var tabSwitcherButton = NSPopUpButton()
    private lazy var scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 232, height: 410))
    private lazy var outlineView = BookmarksOutlineView(frame: scrollView.frame)

    private lazy var treeController = BookmarkTreeController(dataSource: treeControllerDataSource, sortMode: .manual)
    private lazy var dataSource = BookmarkOutlineViewDataSource(contentMode: .foldersOnly,
                                                                bookmarkManager: bookmarkManager,
                                                                treeController: treeController,
                                                                dragDropManager: dragDropManager,
                                                                sortMode: selectedSortMode)

    private var cancellables = Set<AnyCancellable>()
    private var selectedSortMode: BookmarksSortMode

    weak var delegate: BookmarkManagementSidebarViewControllerDelegate?

    private var selectedNodes: [BookmarkNode] {
        if let nodes = outlineView.selectedItems as? [BookmarkNode] {
            return nodes
        }
        return [BookmarkNode]()
    }

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
         dragDropManager: BookmarkDragDropManager = BookmarkDragDropManager.shared) {
        self.bookmarkManager = bookmarkManager
        self.dragDropManager = dragDropManager
        self.selectedSortMode = bookmarkManager.sortMode
        treeControllerDataSource = .init(bookmarkManager: bookmarkManager)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    override func loadView() {
        view = ColorView(frame: .zero, backgroundColor: .bookmarkPageBackground)

        view.addSubview(tabSwitcherButton)
        view.addSubview(scrollView)

        tabSwitcherButton.translatesAutoresizingMaskIntoConstraints = false
        tabSwitcherButton.font = PreferencesUI_macOS.Const.Fonts.popUpButton
        tabSwitcherButton.setButtonType(.momentaryLight)
        tabSwitcherButton.isBordered = false
        tabSwitcherButton.target = self
        tabSwitcherButton.action = #selector(selectedTabContentDidChange)
        tabSwitcherButton.menu = NSMenu {
            for content in Tab.TabContent.displayableTabTypes {
                NSMenuItem(title: content.title!, representedObject: content)
                    .withAccessibilityIdentifier("BookmarkManagementSidebarViewController.\(content.title!)")
            }
        }

        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.autohidesScrollers = true
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.usesPredominantAxisScrolling = false

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
        outlineView.rowHeight = 28
        outlineView.target = self
        outlineView.doubleAction = #selector(onDoubleClick)
        outlineView.menu = BookmarksContextMenu(bookmarkManager: bookmarkManager, delegate: self)
        outlineView.dataSource = dataSource
        outlineView.delegate = dataSource

        let clipView = NSClipView(frame: scrollView.frame)
        clipView.translatesAutoresizingMaskIntoConstraints = true
        clipView.autoresizingMask = [.width, .height]
        clipView.documentView = outlineView
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        setupLayout()
    }

    private func setupLayout() {
        tabSwitcherButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 18).isActive = true
        tabSwitcherButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
        tabSwitcherButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 23).isActive = true
        view.trailingAnchor.constraint(equalTo: tabSwitcherButton.trailingAnchor, constant: 23).isActive = true

        scrollView.topAnchor.constraint(equalTo: tabSwitcherButton.bottomAnchor, constant: 12).isActive = true
        view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: 12).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12).isActive = true
        view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        outlineView.setDraggingSourceOperationMask([.move], forLocal: true)
        outlineView.registerForDraggedTypes(BookmarkDragDropManager.draggedTypes)

        dataSource.$selectedFolders.sink { [weak self] selectedFolders in
            guard let self else { return }
            guard let selectedFolder = selectedFolders.first else {
                if self.outlineView.selectedPseudoFolders == [PseudoFolder.favorites] {
                    self.delegate?.sidebarSelectionStateDidChange(.favorites)
                } else {
                    self.delegate?.sidebarSelectionStateDidChange(.empty)
                }
                return
            }

            self.delegate?.sidebarSelectionStateDidChange(.folder(selectedFolder))

        }.store(in: &cancellables)

        bookmarkManager.listPublisher.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.reloadData()
        }.store(in: &cancellables)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        tabSwitcherButton.select(tabSwitcherButton.itemArray.first(where: { $0.representedObject as? Tab.TabContent == .bookmarks }))
        reloadData()

        bookmarkManager.requestSync()
    }

    func select(folder: BookmarkFolder) {
        if let node = treeController.node(representing: folder) {
            let path = BookmarkNode.Path(node: node)

            if !outlineView.isItemVisible(node) {
                outlineView.scrollToAdjustedPositionInOutlineView(node)
            }

            outlineView.revealAndSelect(nodePath: path)
        }
    }

    func selectBookmarksFolder() {
        if let node = treeController.node(representing: PseudoFolder.bookmarks) {
            let path = BookmarkNode.Path(node: node)
            outlineView.revealAndSelect(nodePath: path)
        }
    }

    func sortModeChanged(_ mode: BookmarksSortMode) {
        self.selectedSortMode = mode
        reloadData()
    }

    private func reloadData() {
        let selectedNodes = self.selectedNodes
        dataSource.reloadData(with: selectedSortMode)
        outlineView.reloadData()

        expandAndRestore(selectedNodes: selectedNodes)
    }

    // MARK: Actions

    @objc func selectedTabContentDidChange(_ sender: NSPopUpButton) {
        guard let content = sender.selectedItem?.representedObject as? Tab.TabContent else {
            assertionFailure("Expected TabContent representedObject")
            return
        }
        delegate?.sidebarSelectedTabContentDidChange(content)
    }

    @objc func onDoubleClick(_ sender: NSOutlineView) {
        guard let item = sender.item(atRow: sender.clickedRow) else { return }
        if sender.isItemExpanded(item) {
            sender.animator().collapseItem(item)
        } else {
            sender.animator().expandItem(item)
        }
    }

    // MARK: NSOutlineView Configuration

    private func expandAndRestore(selectedNodes: [BookmarkNode]) {
        // OutlineView doesn't allow multiple selections so there should be only one selected node at time.
        let selectedNode = selectedNodes.first
        // As the data source reloaded we need to refresh the previously selected nodes.
        // Lets consider the scenario where we add a folder to a subfolder.
        // When the folder is added we need to "refresh" the node because the previously selected node folder has changed (it has a child folder now).
        var refreshedSelectedNodes: [BookmarkNode] = []

        treeController.visitNodes { node in
            if let objectID = (node.representedObject as? BaseBookmarkEntity)?.id {
                if dataSource.expandedNodesIDs.contains(objectID) {
                    outlineView.expandItem(node)
                } else {
                    outlineView.collapseItem(node)
                }

                // Add the node if it contains previously selected folder
                if let folder = selectedNode?.representedObject as? BookmarkFolder, folder.id == objectID {
                    refreshedSelectedNodes.append(node)
                }
            }

            // Expand the Bookmarks pseudo folder automatically.
            if let pseudoFolder = node.representedObject as? PseudoFolder, pseudoFolder == PseudoFolder.bookmarks {
                outlineView.expandItem(node)
            }
        }

        restoreSelection(to: refreshedSelectedNodes)
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
// MARK: - BookmarksContextMenu
extension BookmarkManagementSidebarViewController: BookmarksContextMenuDelegate {

    var isSearching: Bool { false }
    var parentFolder: BookmarkFolder? { nil }
    var shouldIncludeManageBookmarksItem: Bool { false }

    func selectedItems() -> [Any] {
        guard let row = outlineView.clickedRowIfValid else { return [] }

        if outlineView.selectedRowIndexes.contains(row) {
            return outlineView.selectedItems
        }
        return outlineView.item(atRow: row).map { [$0] } ?? []
    }

    func showDialog(_ dialog: any ModalView) {
        dialog.show(in: view.window)
    }

    func closePopoverIfNeeded() {}
    func showInFolder(_ sender: NSMenuItem) {
        assertionFailure("BookmarkManagementSidebarViewController does not support search")
    }

}

#if DEBUG
private let previewSize = NSSize(width: 400, height: 660)
@available(macOS 14.0, *)
#Preview(traits: previewSize.fixedLayout) { {

    let vc = BookmarkManagementSidebarViewController(bookmarkManager: {
        let bkman = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [
            BookmarkFolder(id: "1", title: "Folder with a reasonably long name that would be clipped", children: [
                BookmarkFolder(id: "2", title: "Nested Folder", children: [
                ])
            ]),
            BookmarkFolder(id: "3", title: "Another Folder", children: [
                BookmarkFolder(id: "4", title: "Nested Folder", children: [
                    BookmarkFolder(id: "5", title: "Another Nested Folder", children: [
                        BookmarkFolder(id: "a", title: "Another Nested Folder", children: [
                            BookmarkFolder(id: "b", title: "Another Nested Folder", children: [
                                BookmarkFolder(id: "c", title: "Another Nested Folder", children: [
                                    BookmarkFolder(id: "d", title: "Another Nested Folder", children: [
                                        Bookmark(id: "z1", url: "a:b", title: "a", isFavorite: false),
                                        Bookmark(id: "z2", url: "a:b", title: "a", isFavorite: false),
                                        Bookmark(id: "z3", url: "a:b", title: "a", isFavorite: false),
                                    ])
                                ])
                            ])
                        ])
                    ])
                ])
            ]),
            BookmarkFolder(id: "6", title: "Third Folder", children: []),
            BookmarkFolder(id: "7", title: "Forth Folder", children: []),
            BookmarkFolder(id: "8", title: "Fifth Folder", children: []),
            Bookmark(id: "z", url: "a:b", title: "a", isFavorite: false)
        ]))
        bkman.loadBookmarks()
        customAssertionFailure = { _, _, _ in }

        return bkman
    }())
    vc.preferredContentSize = previewSize
    return vc

}()}
#endif
