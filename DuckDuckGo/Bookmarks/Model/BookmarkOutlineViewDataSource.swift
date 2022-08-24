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
import Foundation
import os.log

final class BookmarkOutlineViewDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {

    enum ContentMode {
        case bookmarksAndFolders
        case foldersOnly
    }

    @Published var selectedFolders: [BookmarkFolder] = []

    let treeController: BookmarkTreeController
    var expandedNodes = Set<UUID>()

    private let contentMode: ContentMode
    private let bookmarkManager: BookmarkManager

    private var favoritesPseudoFolder = PseudoFolder.favorites
    private var bookmarksPseudoFolder = PseudoFolder.bookmarks

    init(contentMode: ContentMode, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared, treeController: BookmarkTreeController) {
        self.contentMode = contentMode
        self.bookmarkManager = bookmarkManager
        self.treeController = treeController

        super.init()

        reloadData()
    }

    func reloadData() {
        favoritesPseudoFolder.count = bookmarkManager.list?.favoriteBookmarks.count ?? 0
        bookmarksPseudoFolder.count = bookmarkManager.list?.totalBookmarks ?? 0
        treeController.rebuild()
    }

    // MARK: - Private

    private func id(from notification: Notification) -> UUID? {
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
        if contentMode == .foldersOnly, index != -1 {
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
        if destination.isRoot {
            return .move
        }

        if let pseudoFolder = destination.representedObject as? PseudoFolder, pseudoFolder == .bookmarks {
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

            guard let draggedNode = treeController.node(representing: folder) else {
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
        guard let draggedObjectIdentifiers = info.draggingPasteboard.pasteboardItems?.compactMap(\.bookmarkEntityUUID),
              !draggedObjectIdentifiers.isEmpty else {
            return false
        }
        
        let representedObject = (item as? BookmarkNode)?.representedObject

        // Handle the nil destination case:

        if let pseudoFolder = representedObject as? PseudoFolder {
            if pseudoFolder == .favorites {
                bookmarkManager.update(objectsWithUUIDs: draggedObjectIdentifiers, update: { entity in
                    let bookmark = entity as? Bookmark
                    bookmark?.isFavorite = true
                }, completion: { error in
                    if let error = error {
                        os_log("Failed to update entities during drop via outline view: %s", error.localizedDescription)
                    }
                })
            } else if pseudoFolder == .bookmarks {
                bookmarkManager.add(objectsWithUUIDs: draggedObjectIdentifiers, to: nil) { error in
                    if let error = error {
                        os_log("Failed to accept nil parent drop via outline view: %s", error.localizedDescription)
                    }
                }
            }

            return true
        }

        // Handle the existing destination case:

        if let parent = representedObject as? BookmarkFolder {
            bookmarkManager.move(objectUUIDs: draggedObjectIdentifiers, toIndex: index, withinParentFolder: .parent(parent.id)) { error in
                if let error = error {
                    os_log("Failed to accept existing parent drop via outline view: %s", error.localizedDescription)
                }
            }
            
            return true
        } else if representedObject == nil {
            bookmarkManager.move(objectUUIDs: draggedObjectIdentifiers, toIndex: index, withinParentFolder: .root) { error in
                if let error = error {
                    os_log("Failed to accept existing parent drop via outline view: %s", error.localizedDescription)
                }
            }
            
            return true
        } else {
            return false
        }
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let view = RoundedSelectionRowView()
        view.insets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

        return view
    }

    // MARK: - NSTableViewDelegate

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if let node = item as? BookmarkNode, node.representedObject is SpacerNode {
            return false
        }

        return contentMode == .foldersOnly
    }

}
