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
    }

    @IBOutlet var tabSwitcherButton: NSPopUpButton!
    @IBOutlet var outlineView: NSOutlineView!

    weak var delegate: BookmarkManagementSidebarViewControllerDelegate?

    private let treeControllerDataSource = BookmarkSidebarTreeController()

    private lazy var treeController: TreeController = {
        return TreeController(dataSource: treeControllerDataSource)
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

    override func viewDidLoad() {
        super.viewDidLoad()

        outlineView.register(BookmarkOutlineViewCell.nib, forIdentifier: BookmarkOutlineViewCell.identifier)
        outlineView.dataSource = dataSource
        outlineView.delegate = dataSource
        outlineView.setDraggingSourceOperationMask([.copy], forLocal: true)
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

        LocalBookmarkManager.shared.topLevelItemsPublisher.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.reloadData()
        }.store(in: &cancellables)

        LocalBookmarkManager.shared.listPublisher.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.reloadData()
        }.store(in: &cancellables)
    }

    func select(folder: BookmarkFolder) {
        if let node = treeController.nodeInTreeRepresentingObject(folder) {
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
                if dataSource.expandedNodes.contains(objectID) {
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

    func restoreSelection(to nodes: [BookmarkNode]) {
        guard selectedNodes != nodes else { return }

        var indexes = IndexSet()
        for node in nodes {
            // The actual instance of the Bookmark may have changed after reloading, so this is a hack to get the right one.
            let foundNode = treeController.nodeInTreeRepresentingObject(node.representedObject)
            let row = outlineView.row(forItem: foundNode as Any)
            if row > -1 {
                indexes.insert(row)
            }
        }

        if indexes.isEmpty {
            let node = treeController.nodeInTreeRepresentingObject(PseudoFolder.bookmarks)
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
        let addFolderViewController = AddFolderModalViewController.create()
        addFolderViewController.delegate = self
        presentAsModalWindow(addFolderViewController)
    }

    func renameFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Rename Folder context menu item")
            return
        }
        
        let addFolderViewController = AddFolderModalViewController.create()
        addFolderViewController.delegate = self
        addFolderViewController.edit(folder: folder)
        presentAsModalWindow(addFolderViewController)
    }

    func deleteFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Folder from Delete Folder context menu item")
            return
        }

        LocalBookmarkManager.shared.remove(folder: folder)
    }

}

// MARK: - Modal Delegates

extension BookmarkManagementSidebarViewController: AddFolderModalViewControllerDelegate {

    func addFolderViewController(_ viewController: AddFolderModalViewController, addedFolderWith name: String) {
        LocalBookmarkManager.shared.makeFolder(for: name, parent: nil)
    }

    func addFolderViewController(_ viewController: AddFolderModalViewController, saved folder: BookmarkFolder) {
        LocalBookmarkManager.shared.update(folder: folder)
    }

}
