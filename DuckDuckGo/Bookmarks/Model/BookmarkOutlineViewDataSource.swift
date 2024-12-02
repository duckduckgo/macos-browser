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
import os.log

final class BookmarkOutlineViewDataSource: NSObject, BookmarksOutlineViewDataSource, NSOutlineViewDelegate {

    enum ContentMode: CaseIterable {
        case bookmarksAndFolders
        case foldersOnly
        case bookmarksMenu

        var isSeparatorVisible: Bool {
            switch self {
            case .bookmarksAndFolders, .bookmarksMenu: true
            case .foldersOnly: false
            }
        }

        var showMenuButtonOnHover: Bool {
            switch self {
            case .bookmarksAndFolders, .bookmarksMenu: true
            case .foldersOnly: false
            }
        }
    }

    @Published var selectedFolders: [BookmarkFolder] = []

    private var outlineView: BookmarksOutlineView?

    private let contentMode: ContentMode
    private var sortMode: BookmarksSortMode
    private(set) var expandedNodesIDs = Set<String>()
    @Published private(set) var isSearching = false

    /// Currently highlighted drag destination folder.
    /// When a drag and drop to a folder happens while in search, we need to stor the destination folder
    /// so we can expand the tree to the destination folder once the drop finishes.
    @Published private(set) var dragDestinationFolder: BookmarkFolder?

    /// Represents currently highlighted drag&drop target row
    @PublishedAfter var targetRowForDropOperation: Int? {
        didSet {
            guard let outlineView else { return }
            // unhighlight old highlighted row
            if let oldValue, oldValue != targetRowForDropOperation,
               oldValue < outlineView.numberOfRows,
               let oldTargetRowViewForDropOperation = outlineView.rowView(atRow: oldValue, makeIfNecessary: false),
               oldTargetRowViewForDropOperation.isTargetForDropOperation {
                oldTargetRowViewForDropOperation.isTargetForDropOperation = false
            }
            // highlight newly highlighted row on value change from outside
            if let targetRowForDropOperation,
               targetRowForDropOperation < outlineView.numberOfRows,
               let targetRowViewForDropOperation = outlineView.rowView(atRow: targetRowForDropOperation, makeIfNecessary: false),
               !targetRowViewForDropOperation.isTargetForDropOperation {
                targetRowViewForDropOperation.isTargetForDropOperation = true
            }
        }
    }

    private let treeController: BookmarkTreeController
    private let bookmarkManager: BookmarkManager
    private let dragDropManager: BookmarkDragDropManager
    private let presentFaviconsFetcherOnboarding: (() -> Void)?

    init(
        contentMode: ContentMode,
        bookmarkManager: BookmarkManager,
        treeController: BookmarkTreeController,
        dragDropManager: BookmarkDragDropManager = .shared,
        sortMode: BookmarksSortMode,
        presentFaviconsFetcherOnboarding: (() -> Void)? = nil
    ) {
        self.contentMode = contentMode
        self.bookmarkManager = bookmarkManager
        self.dragDropManager = dragDropManager
        self.treeController = treeController
        self.presentFaviconsFetcherOnboarding = presentFaviconsFetcherOnboarding
        self.sortMode = sortMode

        super.init()
    }

    func reloadData(with sortMode: BookmarksSortMode, withRootFolder rootFolder: BookmarkFolder? = nil) {
        isSearching = false
        dragDestinationFolder = nil
        self.sortMode = sortMode
        treeController.rebuild(for: sortMode, withRootFolder: rootFolder)
    }

    func reloadData(forSearchQuery searchQuery: String, sortMode: BookmarksSortMode) {
        isSearching = true
        self.sortMode = sortMode
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
        if self.outlineView == nil {
            self.outlineView = outlineView as? BookmarksOutlineView ?? {
                assertionFailure("BookmarksOutlineView subclass expected instead of \(outlineView)")
                return nil
            }()
        }
        return nodeForItem(item).numberOfChildNodes
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return nodeForItem(item).childNodes[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // don‘t display disclosure indicator for “empty” nodes when no indentation level
        return contentMode == .bookmarksMenu ? false : nodeForItem(item).canHaveChildNodes
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

    func firstHighlightableRow(for outlineView: BookmarksOutlineView) -> Int? {
        return (0..<outlineView.numberOfRows).first { row in
            nodeForItem(outlineView.item(atRow: row)).canBeHighlighted
        }
    }

    func nextHighlightableRow(inNextSection: Bool, for outlineView: BookmarksOutlineView, after row: Int) -> Int? {
        if inNextSection {
            return lastHighlightableRow(for: outlineView) // no sections support for now
        }
        return ((row + 1)..<outlineView.numberOfRows).first { row in
            nodeForItem(outlineView.item(atRow: row)).canBeHighlighted
        }
    }

    func previousHighlightableRow(inPreviousSection: Bool, for outlineView: BookmarksOutlineView, before row: Int) -> Int? {
        if inPreviousSection {
            return firstHighlightableRow(for: outlineView) // no sections support for now
        }
        return (0..<row).last { row in
            nodeForItem(outlineView.item(atRow: row)).canBeHighlighted
        }
    }

    func lastHighlightableRow(for outlineView: BookmarksOutlineView) -> Int? {
        return (0..<outlineView.numberOfRows).last { row in
            nodeForItem(outlineView.item(atRow: row)).canBeHighlighted
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

        let cell = outlineView.makeView(withIdentifier: BookmarkOutlineCellView.identifier(for: contentMode), owner: self) as? BookmarkOutlineCellView
            ?? BookmarkOutlineCellView(identifier: BookmarkOutlineCellView.identifier(for: contentMode))
        cell.delegate = self
        cell.update(from: node, isSearch: isSearching)

        if let bookmark = node.representedObject as? Bookmark, bookmark.favicon(.small) == nil {
            presentFaviconsFetcherOnboarding?()
        }

        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let row = outlineView.row(forItem: item)
        let rowView = RoundedSelectionRowView()
        rowView.insets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        // observe row drag&drop target highlight state and update `targetRowForDropOperation`
        let cancellable = rowView.publisher(for: \.isTargetForDropOperation).sink { [weak self] isTargetForDropOperation in
            guard let self else { return }
            if isTargetForDropOperation {
                if self.targetRowForDropOperation != row {
                    self.targetRowForDropOperation = row
                }
            } else if self.targetRowForDropOperation == row {
                self.targetRowForDropOperation = nil
            }
        }
        rowView.onDeinit {
            withExtendedLifetime(cancellable) {}
        }
        return rowView
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if let node = item as? BookmarkNode, node.representedObject is SpacerNode {
            return OutlineSeparatorViewCell.rowHeight(for: contentMode)
        }
        return BookmarkOutlineCellView.rowHeight
    }

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let node = item as? BookmarkNode, let entity = node.representedObject as? BaseBookmarkEntity else { return nil }
        return entity.pasteboardWriter
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        if !sortMode.isReorderingEnabled { return .none }

        let destinationNode = nodeForItem(item)

        if contentMode == .foldersOnly, destinationNode.isRoot {
            // disable dropping at Root in Bookmark Manager tree view
            return .none
        }

        let destination = destinationNode.isRoot ? PseudoFolder.bookmarks : destinationNode.representedObject

        guard !isSearching || destination is BookmarkFolder else { return .none }

        if let destinationFolder = destination as? BookmarkFolder {
            self.dragDestinationFolder = destinationFolder
        }

        let operation = dragDropManager.validateDrop(info, to: destination)
        self.dragDestinationFolder = (operation == .none || item == nil) ? nil : destinationNode.representedObject as? BookmarkFolder

        return operation
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

    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        let windowPoint = outlineView.window?.convertPoint(fromScreen: screenPoint)
        if (windowPoint.map({ outlineView.isMouseLocationInsideBounds($0) }) ?? false) == false {
            dragDestinationFolder = nil
        } // else: leave the dragDestinationFolder set for folder expansion in Search mode
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
        guard let outlineView = cell.superview?.superview as? NSOutlineView else {
            assertionFailure("cell.superview?.superview is not NSOutlineView")
            return
        }
        outlineView.menu?.popUpAtMouseLocation(in: cell)
    }
}
