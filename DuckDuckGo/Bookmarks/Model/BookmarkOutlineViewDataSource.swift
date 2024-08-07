//
//  BookmarkOutlineViewDataSource.swift
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
import Common
import Foundation

final class BookmarkOutlineViewDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {

    enum ContentMode {
        case bookmarksAndFolders
        case foldersOnly
        case bookmarksMenu

        var isSeparatorVisible: Bool {
            switch self {
            case .bookmarksAndFolders, .bookmarksMenu: true
            case .foldersOnly: false
            }
        }
    }

    @Published var selectedFolders: [BookmarkFolder] = []

    let treeController: BookmarkTreeController

    private let contentMode: ContentMode
    private(set) var expandedNodesIDs = Set<String>()
    private(set) var isSearching = false

    /// When a drag and drop to a folder happens while in search, we need to stor the destination folder
    /// so we can expand the tree to the destination folder once the drop finishes.
    @Published private(set) var dragDestinationFolder: BookmarkFolder?

    private let bookmarkManager: BookmarkManager
    private let dragDropManager: BookmarkDragDropManager
    private let showMenuButtonOnHover: Bool
    private let onMenuRequestedAction: ((BookmarkOutlineCellView) -> Void)?
    private let presentFaviconsFetcherOnboarding: (() -> Void)?

    init(
        contentMode: ContentMode,
        bookmarkManager: BookmarkManager,
        treeController: BookmarkTreeController,
        dragDropManager: BookmarkDragDropManager,
        sortMode: BookmarksSortMode,
        showMenuButtonOnHover: Bool = true,
        onMenuRequestedAction: ((BookmarkOutlineCellView) -> Void)? = nil,
        presentFaviconsFetcherOnboarding: (() -> Void)? = nil
    ) {
        self.contentMode = contentMode
        self.bookmarkManager = bookmarkManager
        self.dragDropManager = dragDropManager
        self.treeController = treeController
        self.showMenuButtonOnHover = showMenuButtonOnHover
        self.onMenuRequestedAction = onMenuRequestedAction
        self.presentFaviconsFetcherOnboarding = presentFaviconsFetcherOnboarding

        super.init()
    }

    func reloadData(with sortMode: BookmarksSortMode, withRootFolder rootFolder: BookmarkFolder? = nil) {
        isSearching = false
        dragDestinationFolder = nil
        treeController.rebuild(for: sortMode, withRootFolder: rootFolder)
    }

    func reloadData(forSearchQuery searchQuery: String, sortMode: BookmarksSortMode) {
        isSearching = true
        treeController.rebuild(forSearchQuery: searchQuery, sortMode: sortMode)
    }

    // MARK: - Private

    private func id(from notification: Notification) -> String? {
        let node = notification.userInfo?["NSObject"] as? BookmarkNode

        if let bookmark = node?.representedObject as? BaseBookmarkEntity {
            return bookmark.id
        }

        if let pseudoFolder = node?.representedObject as? PseudoFolder {
            return pseudoFolder.id
        }

        return nil
    }

    // MARK: - NSOutlineViewDataSource

    func nodeForItem(_ item: Any?) -> BookmarkNode {
        guard let item = item as? BookmarkNode else {
            return treeController.rootNode
        }

        return item
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return nodeForItem(item).numberOfChildNodes
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return nodeForItem(item).childNodes[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // don‘t display disclosure indicator for “empty” nodes when no indentation level
        contentMode == .bookmarksMenu ? false : nodeForItem(item).canHaveChildNodes
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outline = notification.object as? NSOutlineView else { return }
        selectedFolders = outline.selectedFolders
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        if let objectID = id(from: notification) {
            expandedNodesIDs.insert(objectID)
        }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        if let objectID = id(from: notification) {
            expandedNodesIDs.remove(objectID)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? BookmarkNode else {
            assertionFailure("\(#file): Failed to cast item to Node")
            return nil
        }
        if node.representedObject is SpacerNode {
            return outlineView.makeView(withIdentifier: contentMode.isSeparatorVisible
                                        ? OutlineSeparatorViewCell.separatorIdentifier
                                        : OutlineSeparatorViewCell.blankIdentifier, owner: self) as? OutlineSeparatorViewCell
                ?? OutlineSeparatorViewCell(isSeparatorVisible: contentMode.isSeparatorVisible)
        }

        let cell = outlineView.makeView(withIdentifier: .init(BookmarkOutlineCellView.className()), owner: self) as? BookmarkOutlineCellView
            ?? BookmarkOutlineCellView(identifier: .init(BookmarkOutlineCellView.className()))
        cell.shouldShowMenuButton = showMenuButtonOnHover
        cell.delegate = self
        cell.update(from: node, isSearch: isSearching, isMenuPopover: contentMode == .bookmarksMenu)

        if let bookmark = node.representedObject as? Bookmark, bookmark.favicon(.small) == nil {
            presentFaviconsFetcherOnboarding?()
        }

        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let view = RoundedSelectionRowView()
        view.insets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

        return view
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if let node = item as? BookmarkNode, node.representedObject is SpacerNode {
            return OutlineSeparatorViewCell.rowHeight(for: contentMode == .bookmarksMenu ? .bookmarkBarMenu : .popover)
        }
        return BookmarkOutlineCellView.rowHeight
    }

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let node = item as? BookmarkNode, let entity = node.representedObject as? BaseBookmarkEntity else { return nil }
        return entity.pasteboardWriter
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        let destinationNode = nodeForItem(item)

        if contentMode == .foldersOnly, destinationNode.isRoot {
            // disable dropping at Root in Bookmark Manager tree view
            return .none
        }

        return dragDropManager.validateDrop(info, to: destinationNode.representedObject)
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        var representedObject = (item as? BookmarkNode)?.representedObject ?? (treeController.rootNode.isRoot ? nil : treeController.rootNode.representedObject)
        if (representedObject as? BookmarkFolder)?.id == PseudoFolder.bookmarks.id {
            // BookmarkFolder with id == PseudoFolder.bookmarks.id is used for Clipped Items menu
            // use the PseudoFolder.bookmarks root as the destination and calculate drop index based on nearest items indices.
            representedObject = PseudoFolder.bookmarks
        }
        let index = {
            // for folders-only calculate new real index based on the nearest folder index
            if contentMode == .foldersOnly || representedObject is PseudoFolder,
               index > -1,
               // get folder before the insertion point (or the first one)
               let nearestObject = (outlineView.child(max(0, index - 1), ofItem: item) as? BookmarkNode)?.representedObject as? BookmarkFolder,
               // get all the children of a new parent folder (take actual bookmark list for the root)
               let siblings = ((representedObject is PseudoFolder ? nil : representedObject) as? BookmarkFolder)?.children ?? bookmarkManager.list?.topLevelEntities {

                // insert after the nearest item (or in place of the nearest item for index == 0)
                return (siblings.firstIndex(of: nearestObject) ?? 0) + (index == 0 ? 0 : 1)
            } else if index == -1 {
                // drop onto folder
                return 0
            }
            return index
        }()

        return dragDropManager.acceptDrop(info, to: representedObject ?? PseudoFolder.bookmarks, at: index)
    }

    // MARK: - NSTableViewDelegate

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if let node = item as? BookmarkNode, node.representedObject is SpacerNode {
            return false
        }

        return contentMode == .foldersOnly
    }

}

// MARK: - BookmarkOutlineCellViewDelegate

extension BookmarkOutlineViewDataSource: BookmarkOutlineCellViewDelegate {
    func outlineCellViewRequestedMenu(_ cell: BookmarkOutlineCellView) {
        onMenuRequestedAction?(cell)
    }
}
