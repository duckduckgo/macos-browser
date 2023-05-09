//
//  BookmarkSidebarTreeController.swift
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

final class BookmarkSidebarTreeController: BookmarkTreeControllerDataSource {

    func treeController(treeController: BookmarkTreeController, childNodesFor node: BookmarkNode) -> [BookmarkNode] {
        return node.isRoot ? childNodesForRootNode(node) : childNodes(for: node)
    }

    private let bookmarkManager: BookmarkManager

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
    }

    // MARK: - Private

    private func childNodesForRootNode(_ node: BookmarkNode) -> [BookmarkNode] {
        let favorites = PseudoFolder.favorites
        let favoritesNode = BookmarkNode(representedObject: favorites, parent: node)
        favoritesNode.canHaveChildNodes = false

        let blankSpacer = SpacerNode.blank
        let spacerNode = BookmarkNode(representedObject: blankSpacer, parent: node)
        spacerNode.canHaveChildNodes = false

        let bookmarks = PseudoFolder.bookmarks
        let bookmarksNode = BookmarkNode(representedObject: bookmarks, parent: node)
        bookmarksNode.canHaveChildNodes = true

        return [favoritesNode, spacerNode, bookmarksNode]
    }

    private func childNodes(for parentNode: BookmarkNode) -> [BookmarkNode] {
        if let pseudoFolder = parentNode.representedObject as? PseudoFolder, pseudoFolder == PseudoFolder.bookmarks {
            return childNodesForBookmarksPseudoFolder(parentNode)
        }

        if let folder = parentNode.representedObject as? BookmarkFolder {
            return childNodes(for: folder, parentNode: parentNode)
        }

        return []
    }

    private func createNode(with folder: BookmarkFolder, parent: BookmarkNode) -> BookmarkNode {
        let node = BookmarkNode(representedObject: folder, parent: parent)
        node.canHaveChildNodes = !folder.childFolders.isEmpty

        return node
    }

    private func childNodesForBookmarksPseudoFolder(_ parent: BookmarkNode) -> [BookmarkNode] {
        let nodes = bookmarkManager.list?.topLevelEntities.compactMap { (possibleFolder) -> BookmarkNode? in
            guard let folder = possibleFolder as? BookmarkFolder else { return nil }

            let folderNode = parent.findOrCreateChildNode(with: folder)
            folderNode.canHaveChildNodes = !folder.childFolders.isEmpty

            return folderNode
        } ?? []

        return nodes.bookmarksSortedAlphabetically()
    }

    private func childNodes(for folder: BookmarkFolder, parentNode: BookmarkNode) -> [BookmarkNode] {
        var children = [BookmarkFolder]()
        var updatedChildNodes = [BookmarkNode]()

        for folder in folder.childFolders {
            children.append(folder)
        }

        children.forEach { folder in
            if let existingNode = parentNode.childNodeRepresenting(object: folder) {
                if !updatedChildNodes.contains(existingNode) {
                    updatedChildNodes += [existingNode]
                    return
                }
            }

            let newNode = self.createNode(with: folder, parent: parentNode)
            updatedChildNodes += [newNode]
        }

        return updatedChildNodes.bookmarksSortedAlphabetically()
    }

}
