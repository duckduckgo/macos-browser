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
    }

    @Published var selectedFolders: [BookmarkFolder] = []

    let treeController: BookmarkTreeController

    private let contentMode: ContentMode
    private(set) var expandedNodesIDs = Set<String>()
    private(set) var isSearching = false
    private(set) var destinationFolderOnSearch: BookmarkFolder?
    private let bookmarkManager: BookmarkManager
    private let showMenuButtonOnHover: Bool
    private let onMenuRequestedAction: ((BookmarkOutlineCellView) -> Void)?
    private let presentFaviconsFetcherOnboarding: (() -> Void)?

    private var favoritesPseudoFolder = PseudoFolder.favorites
    private var bookmarksPseudoFolder = PseudoFolder.bookmarks

    init(
        contentMode: ContentMode,
        bookmarkManager: BookmarkManager,
        treeController: BookmarkTreeController,
        showMenuButtonOnHover: Bool = true,
        onMenuRequestedAction: ((BookmarkOutlineCellView) -> Void)? = nil,
        presentFaviconsFetcherOnboarding: (() -> Void)? = nil
    ) {
        self.contentMode = contentMode
        self.bookmarkManager = bookmarkManager
        self.treeController = treeController
        self.showMenuButtonOnHover = showMenuButtonOnHover
        self.onMenuRequestedAction = onMenuRequestedAction
        self.presentFaviconsFetcherOnboarding = presentFaviconsFetcherOnboarding

        super.init()

        reloadData()
    }

    func reloadData() {
        isSearching = false
        destinationFolderOnSearch = nil
        setFolderCount()
        treeController.rebuild()
    }

    func reloadData(for searchQuery: String) {
        isSearching = true
        setFolderCount()
        treeController.rebuild(for: searchQuery)
    }

    private func setFolderCount() {
        favoritesPseudoFolder.count = bookmarkManager.list?.favoriteBookmarks.count ?? 0
        bookmarksPseudoFolder.count = bookmarkManager.list?.totalBookmarks ?? 0
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
        return nodeForItem(item).canHaveChildNodes
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
        let cell = outlineView.makeView(withIdentifier: .init(BookmarkOutlineCellView.className()), owner: self) as? BookmarkOutlineCellView
            ?? BookmarkOutlineCellView(identifier: .init(BookmarkOutlineCellView.className()))
        cell.shouldShowMenuButton = showMenuButtonOnHover
        cell.delegate = self

        if let bookmark = node.representedObject as? Bookmark {
            cell.update(from: bookmark, isSearch: isSearching)

            if bookmark.favicon(.small) == nil {
                presentFaviconsFetcherOnboarding?()
            }
            return cell
        }

        if let folder = node.representedObject as? BookmarkFolder {
            cell.update(from: folder, isSearch: isSearching)
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
        let destinationNode = nodeForItem(item)

        if contentMode == .foldersOnly {
            // when in folders sidebar mode only allow moving a folder to another folder (or root)
            if destinationNode.representedObject is BookmarkFolder
                || (destinationNode.representedObject as? PseudoFolder == .bookmarks) {
                return .move
            }
            return .none
        }

        if isSearching {
            if let destinationFolder = destinationNode.representedObject as? BookmarkFolder {
                self.destinationFolderOnSearch = destinationFolder
                return .move
            }

            return .none
        }

        let bookmarks = PasteboardBookmark.pasteboardBookmarks(with: info.draggingPasteboard)
        let folders = PasteboardFolder.pasteboardFolders(with: info.draggingPasteboard)

        if let bookmarks = bookmarks, let folders = folders {
            let canMoveBookmarks = validateDrop(for: bookmarks, destination: destinationNode) == .move
            let canMoveFolders = validateDrop(for: folders, destination: destinationNode) == .move

            // If the dragged values contain both folders and bookmarks, only validate the move if all objects can be moved.
            if canMoveBookmarks, canMoveFolders {
                return .move
            } else {
                return .none
            }
        }

        if let bookmarks = bookmarks {
            return validateDrop(for: bookmarks, destination: destinationNode)
        }

        if let folders = folders {
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
            return draggedFolder.id == destinationFolder.id
        }

        if containsDestination {
            return .none
        }

        // Folders cannot be dragged onto any of their descendants:

        let containsDescendantOfDestination = draggedFolders.contains { draggedFolder in
            let folder = BookmarkFolder(id: draggedFolder.id, title: draggedFolder.name, parentFolderUUID: draggedFolder.parentFolderUUID, children: draggedFolder.children)

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

        if contentMode == .bookmarksAndFolders,
           let pseudoFolder = representedObject as? PseudoFolder {
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

        var index = index
        // for folders-only calculate new real index based on the nearest folder index
        if contentMode == .foldersOnly,
           index > -1,
           // get folder before the insertion point (or the first one)
           let nearestObject = (outlineView.child(max(0, index - 1), ofItem: item) as? BookmarkNode)?.representedObject as? BookmarkFolder,
           // get all the children of a new parent folder
           let siblings = (representedObject as? BookmarkFolder)?.children ?? bookmarkManager.list?.topLevelEntities {

            // insert after the nearest item (or in place of the nearest item for index == 0)
            index = (siblings.firstIndex(of: nearestObject) ?? 0) + (index == 0 ? 0 : 1)
        } else if index == -1 {
            // drop onto folder
            index = 0
        }

        let parent: ParentFolderType = (representedObject as? BookmarkFolder).map { .parent(uuid: $0.id) } ?? .root
        bookmarkManager.move(objectUUIDs: draggedObjectIdentifiers, toIndex: index, withinParentFolder: parent) { error in
            if let error = error {
                os_log("Failed to accept existing parent drop via outline view: %s", error.localizedDescription)
            }
        }

        return true
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

// MARK: - BookmarkOutlineCellViewDelegate

extension BookmarkOutlineViewDataSource: BookmarkOutlineCellViewDelegate {
    func outlineCellViewRequestedMenu(_ cell: BookmarkOutlineCellView) {
        onMenuRequestedAction?(cell)
    }
}
