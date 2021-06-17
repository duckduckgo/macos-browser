//
//  BookmarkListTreeControllerDataSource.swift
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

final class BookmarkListTreeControllerDataSource: BookmarkTreeControllerDataSource {

    func treeController(treeController: BookmarkTreeController, childNodesFor node: BookmarkNode) -> [BookmarkNode] {
        return node.isRoot ? childNodesForRootNode(node) : childNodes(node)
    }

    // MARK: - Private

    private func childNodesForRootNode(_ node: BookmarkNode) -> [BookmarkNode] {
        let favorites = PseudoFolder.favorites
        let favoritesNode = BookmarkNode(representedObject: favorites, parent: node)
        favoritesNode.canHaveChildNodes = true

        let blankSpacer = SpacerNode.blank
        let spacerNode = BookmarkNode(representedObject: blankSpacer, parent: nil)

        let topLevelNodes = LocalBookmarkManager.shared.list?.topLevelEntities.compactMap { (item) -> BookmarkNode? in
            if let folder = item as? BookmarkFolder {
                let itemNode = node.createChildNode(item)
                itemNode.canHaveChildNodes = !folder.children.isEmpty

                return itemNode
            } else if item is Bookmark {
                let itemNode = node.findOrCreateChildNode(with: item)
                itemNode.canHaveChildNodes = false
                return itemNode
            } else {
                assertionFailure("\(#file): Tried to display non-bookmark type in bookmark list")
                return nil
            }
        } ?? []

        return [favoritesNode, spacerNode] + topLevelNodes
    }

    private func childNodes(_ node: BookmarkNode) -> [BookmarkNode] {
        if let pseudoFolder = node.representedObject as? PseudoFolder, pseudoFolder == PseudoFolder.favorites {
            return childNodesForFavoritesPseudoFolder(node)
        }

        if let folder = node.representedObject as? BookmarkFolder {
            return childNodes(for: folder, parentNode: node)
        }

        return []
    }

    private func createNode(_ object: BaseBookmarkEntity, parent: BookmarkNode) -> BookmarkNode {
        let node = BookmarkNode(representedObject: object, parent: parent)

        if let folder = object as? BookmarkFolder, !folder.children.isEmpty {
            node.canHaveChildNodes = true
        } else {
            node.canHaveChildNodes = false
        }

        return node
    }

    private func childNodesForFavoritesPseudoFolder(_ parent: BookmarkNode) -> [BookmarkNode] {
        return LocalBookmarkManager.shared.list?.favoriteBookmarks.compactMap { (favorite) -> BookmarkNode? in
            let favoriteNode = parent.findOrCreateChildNode(with: favorite)
            favoriteNode.canHaveChildNodes = false
            return favoriteNode
        } ?? []
    }

    private func childNodes(for folder: BookmarkFolder, parentNode: BookmarkNode) -> [BookmarkNode] {
        var updatedChildNodes = [BookmarkNode]()

        folder.children.forEach { representedObject in
            if let existingNode = parentNode.childNodeRepresenting(object: representedObject) {
                if !updatedChildNodes.contains(existingNode) {
                    updatedChildNodes += [existingNode]
                    return
                }
            }

            let newNode = self.createNode(representedObject, parent: parentNode)
            updatedChildNodes += [newNode]
        }

        return updatedChildNodes
    }

}
