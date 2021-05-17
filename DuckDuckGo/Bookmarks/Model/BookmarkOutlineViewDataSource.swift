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

import Foundation

final class BookmarkOutlineViewDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {

    enum ContentMode {
        case bookmarksAndFolders
        case foldersOnly
    }

    @Published var selectedFolders: [BookmarkFolder] = []

    let treeController: TreeController
    var expandedNodes = Set<UUID>()

    private let contentMode: ContentMode

    private var favoritesPseudoFolder = PseudoFolder.favorites
    private var bookmarksPseudoFolder = PseudoFolder.bookmarks

    init(contentMode: ContentMode, treeController: TreeController) {
        self.contentMode = contentMode
        self.treeController = treeController

        super.init()

        reloadData()
    }

    func reloadData() {
        favoritesPseudoFolder.count = LocalBookmarkManager.shared.list?.favoriteBookmarks.count ?? 0
        bookmarksPseudoFolder.count = LocalBookmarkManager.shared.list?.totalBookmarks ?? 0
        treeController.rebuild()
    }

    // MARK: - Private

    private func id(from notification: Notification) -> UUID? {
        let node = notification.userInfo?["NSObject"] as? BookmarkNode
        let objectID = (node?.representedObject as? BaseBookmarkEntity)?.id

        return objectID
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
        return nodeForItem(item).canHaveChildNodes
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outline = notification.object as? NSOutlineView else { return }
        selectedFolders = outline.selectedFolders
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        if let objectID = id(from: notification) {
            expandedNodes.insert(objectID)
        }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        if let objectID = id(from: notification) {
            expandedNodes.remove(objectID)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? BookmarkNode,
              let cell = outlineView.makeView(withIdentifier: BookmarkOutlineViewCell.identifier, owner: self) as? BookmarkOutlineViewCell else {
            assertionFailure("\(#file): Failed to create BookmarkOutlineViewCell or cast item to Node")
            return nil
        }

        if let bookmark = node.representedObject as? Bookmark {
            cell.update(from: bookmark)
            return cell
        }

        if let folder = node.representedObject as? BookmarkFolder {
            cell.update(from: folder)
            return cell
        }

        if let folder = node.representedObject as? PseudoFolder {
            if folder == .bookmarks {
                cell.update(from: bookmarksPseudoFolder)
            } else if folder == .favorites {
                cell.update(from: favoritesPseudoFolder)
            } else {
                assertionFailure("\(#file): Tried to update PseudoFolder cell with invalid type")
            }

            return cell
        }

        return OutlineSeparatorViewCell(separatorVisible: contentMode == .bookmarksAndFolders)
    }

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let node = item as? BookmarkNode, let entity = node.representedObject as? BaseBookmarkEntity else { return nil }
        return entity.pasteboardWriter
    }

    func outlineView(_ outlineView: NSOutlineView,
                     validateDrop info: NSDraggingInfo,
                     proposedItem item: Any?,
                     proposedChildIndex index: Int) -> NSDragOperation {
        guard index == -1 else {
            return .none
        }

        let destinationNode = nodeForItem(item)

        if let bookmarks = PasteboardBookmark.pasteboardBookmarks(with: info.draggingPasteboard) {
            return validateDrop(for: bookmarks, destination: destinationNode)
        }

        if let folders = PasteboardFolder.pasteboardFolders(with: info.draggingPasteboard) {
            return validateDrop(for: folders, destination: destinationNode)
        }

        return .none
    }

    func validateDrop(for draggedBookmarks: Set<PasteboardBookmark>, destination: BookmarkNode) -> NSDragOperation {
        guard destination.representedObject is BookmarkFolder || destination.representedObject is PseudoFolder || destination.isRoot else {
            return .none
        }

        return .move
    }

    func validateDrop(for draggedFolders: Set<PasteboardFolder>, destination: BookmarkNode) -> NSDragOperation {
        if destination.representedObject is PseudoFolder || destination.isRoot {
            return .move
        }

        guard let destinationFolder = destination.representedObject as? BookmarkFolder else {
            return .none
        }

        // Folders cannot be dragged onto themselves:

        let containsDestination = draggedFolders.contains { draggedFolder in
            return draggedFolder.id == destinationFolder.id.uuidString
        }

        if containsDestination {
            return .none
        }

        // Folders cannot be dragged onto any of their descendants:

        let containsDescendantOfDestination = draggedFolders.contains { draggedFolder in
            let folder = BookmarkFolder(id: UUID(uuidString: draggedFolder.id)!, title: draggedFolder.name)

            guard let draggedNode = treeController.nodeInTreeRepresentingObject(folder) else {
                return false
            }

            let descendant = draggedNode.descendantNodeRepresenting(object: destination.representedObject)

            return descendant != nil
        }

        if containsDescendantOfDestination {
            return .none
        }

        return .move
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        let representedObject = (item as? BookmarkNode)?.representedObject
        let draggedBookmarks = PasteboardBookmark.pasteboardBookmarks(with: info.draggingPasteboard) ?? Set<PasteboardBookmark>()
        let draggedFolders = PasteboardFolder.pasteboardFolders(with: info.draggingPasteboard) ?? Set<PasteboardFolder>()

        if draggedBookmarks.isEmpty && draggedFolders.isEmpty {
            return false
        }

        let draggedObjectIdentifierStrings = draggedBookmarks.map(\.id) + draggedFolders.map(\.id)
        let draggedObjectIdentifiers = draggedObjectIdentifierStrings.compactMap(UUID.init(uuidString:))

        // Handle the nil destination case:

        if representedObject is PseudoFolder || item == nil {
            LocalBookmarkManager.shared.add(objectsWithUUIDs: draggedObjectIdentifiers, to: nil) { _ in
                // Handle error
            }

            return true
        }

        // Handle the existing destination case:

        guard let parent = representedObject as? BookmarkFolder else { return false }

        LocalBookmarkManager.shared.add(objectsWithUUIDs: draggedObjectIdentifiers, to: parent) { _ in
            print("Added object to parent")
        }

        return true
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return RoundedSelectionRowView()
    }

    // MARK: - NSTableViewDelegate

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if let node = item as? BookmarkNode, node.representedObject is SpacerNode {
            return false
        }

        return contentMode == .foldersOnly
    }

}
