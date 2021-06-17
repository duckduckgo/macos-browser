//
//  BookmarkNode.swift
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

final class BookmarkNode: Hashable {

    private final class RootNode {}

    private static var incrementingID = 0

    class func genericRootNode() -> BookmarkNode {
        let node = BookmarkNode(representedObject: RootNode(), parent: nil)
        node.canHaveChildNodes = true

        return node
    }

    class func bookmarkNodesSortedAlphabetically(_ nodes: [BookmarkNode]) -> [BookmarkNode] {
        return nodes.sorted { (firstNode, secondNode) -> Bool in
            guard let firstBookmark = firstNode.representedObject as? BaseBookmarkEntity,
                  let secondBookmark = secondNode.representedObject as? BaseBookmarkEntity else {
                return false
            }

            return firstBookmark.title.localizedStandardCompare(secondBookmark.title) == .orderedAscending
        }
    }

    weak var parent: BookmarkNode?

    let uniqueID: Int
    let representedObject: AnyObject
    var canHaveChildNodes = false
    var childNodes = [BookmarkNode]()

    var isRoot: Bool {
        return parent == nil
    }

    var numberOfChildNodes: Int {
        return childNodes.count
    }

    var indexPath: IndexPath {
        if let parent = parent {
            let parentPath = parent.indexPath
            if let childIndex = parent.indexOfChild(self) {
                return parentPath.appending(childIndex)
            }

            preconditionFailure("A Node’s parent must contain it as a child.")
        }

        return IndexPath(index: 0)
    }

    var level: Int {
        if let parent = parent {
            return parent.level + 1
        }

        return 0
    }

    init(representedObject: AnyObject, parent: BookmarkNode?) {
        self.representedObject = representedObject
        self.parent = parent
        self.uniqueID = BookmarkNode.incrementingID

        BookmarkNode.incrementingID += 1
    }

    func representedObjectEquals(_ otherRepresentedObject: AnyObject) -> Bool {
        if let entity = otherRepresentedObject as? BaseBookmarkEntity,
           let nodeEntity = self.representedObject as? BaseBookmarkEntity,
           entity == nodeEntity {
            return true
        }

        if let folder = otherRepresentedObject as? PseudoFolder, let nodeFolder = self.representedObject as? PseudoFolder, folder == nodeFolder {
            return true
        }

        if self.representedObject === otherRepresentedObject {
            return true
        }

        return false
    }

    func findOrCreateChildNode(with representedObject: AnyObject) -> BookmarkNode {
        if let node = childNodeRepresenting(object: representedObject) {
            return node
        }

        return createChildNode(representedObject)
    }

    func createChildNode(_ representedObject: AnyObject) -> BookmarkNode {
        return BookmarkNode(representedObject: representedObject, parent: self)
    }

    func childAtIndex(_ index: Int) -> BookmarkNode? {
        if index >= childNodes.count || index < 0 {
            return nil
        }

        return childNodes[index]
    }

    func indexOfChild(_ node: BookmarkNode) -> Int? {
        return childNodes.firstIndex { (childNode) -> Bool in
            childNode === node
        }
    }

    func childNodeRepresenting(object: AnyObject) -> BookmarkNode? {
        return findNodeRepresenting(object: object, recursively: false)
    }

    func descendantNodeRepresenting(object: AnyObject) -> BookmarkNode? {
        return findNodeRepresenting(object: object, recursively: true)
    }

    func isAncestor(of node: BookmarkNode) -> Bool {
        guard node != self else { return false }

        var currentNode = node

        while true {
            guard let parent = currentNode.parent else {
                return false
            }

            if parent == self {
                return true
            }

            currentNode = parent
        }
    }

    func findNodeRepresenting(object: AnyObject, recursively: Bool = false) -> BookmarkNode? {
        for childNode in childNodes {
            if childNode.representedObjectEquals(object) {
                return childNode
            }

            if recursively, let foundNode = childNode.descendantNodeRepresenting(object: object) {
                return foundNode
            }
        }

        return nil
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        // The Node class will most frequently represent Bookmark entities and PseudoFolders. Because of this, their unique properties are
        // used to derive the hash for the node so that equality can be handled based on the represented object.
        if let entity = self.representedObject as? BaseBookmarkEntity {
            hasher.combine(entity.id)
        } else if let folder = self.representedObject as? PseudoFolder {
            hasher.combine(folder.name)
        } else {
            hasher.combine(uniqueID)
        }
    }

    // MARK: - Equatable

    class func == (lhs: BookmarkNode, rhs: BookmarkNode) -> Bool {
        return lhs === rhs
    }

}

// MARK: - BookmarkNode.Path

extension BookmarkNode {

    struct Path {

        let components: [BookmarkNode]

        init(node: BookmarkNode) {
            var pathComponents = [node]
            var currentNode = node

            while let parent = currentNode.parent {
                pathComponents.append(parent)
                currentNode = parent
            }

            self.components = pathComponents.reversed()
        }

        init?(representedObject: AnyObject, treeController: BookmarkTreeController) {
            if let node = treeController.node(representing: representedObject) {
                self.init(node: node)
            }

            return nil
        }

    }

}

// MARK: - BookmarkNode Array Extensions

extension Array where Element == BookmarkNode {

    func representedObjects() -> [AnyObject] {
        return self.map { $0.representedObject }
    }

    func bookmarksSortedAlphabetically() -> [BookmarkNode] {
        return BookmarkNode.bookmarkNodesSortedAlphabetically(self)
    }

}
