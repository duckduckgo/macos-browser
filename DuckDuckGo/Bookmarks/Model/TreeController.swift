//
//  TreeController.swift
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

protocol TreeControllerDataSource: AnyObject {

    func treeController(treeController: TreeController, childNodesFor: BookmarkNode) -> [BookmarkNode]

}

typealias NodeVisitor = (BookmarkNode) -> Void

final class TreeController {

    let rootNode: BookmarkNode

    private weak var dataSource: TreeControllerDataSource?

    init(dataSource: TreeControllerDataSource, rootNode: BookmarkNode) {
        self.dataSource = dataSource
        self.rootNode = rootNode

        rebuild()
    }

    convenience init(dataSource: TreeControllerDataSource) {
        self.init(dataSource: dataSource, rootNode: BookmarkNode.genericRootNode())
    }

    @discardableResult
    func rebuild() -> Bool {
        return rebuildChildNodes(node: rootNode)
    }

    func visitNodes(with visitBlock: NodeVisitor) {
        visit(node: rootNode, visitor: visitBlock)
    }

    func nodeInTreeRepresentingObject(_ representedObject: AnyObject) -> BookmarkNode? {
        return nodeInArrayRepresentingObject(nodes: [rootNode], representedObject: representedObject, recurse: true)
    }

    private func nodeInArrayRepresentingObject(nodes: [BookmarkNode], representedObject: AnyObject, recurse: Bool = false) -> BookmarkNode? {
        for node in nodes {
            if node.representedObjectEquals(representedObject) {
                return node
            }

            if recurse, node.canHaveChildNodes {
                if let foundNode = nodeInArrayRepresentingObject(nodes: node.childNodes, representedObject: representedObject, recurse: recurse) {
                    return foundNode
                }
            }
        }

        return nil
    }

}

private extension TreeController {

    func visit(node: BookmarkNode, visitor: NodeVisitor) {
        visitor(node)

        node.childNodes.forEach { childNode in
            visit(node: childNode, visitor: visitor)
        }
    }

    func nodeArraysAreEqual(_ lhs: [BookmarkNode]?, _ rhs: [BookmarkNode]?) -> Bool {
        if lhs == nil && rhs == nil {
            return true
        }

        return lhs == rhs
    }

    func rebuildChildNodes(node: BookmarkNode) -> Bool {
        if !node.canHaveChildNodes {
            return false
        }

        var childNodesDidChange = false

        let childNodes = dataSource?.treeController(treeController: self, childNodesFor: node) ?? [BookmarkNode]()

        childNodesDidChange = !nodeArraysAreEqual(childNodes, node.childNodes)

        if childNodesDidChange {
            node.childNodes = childNodes
        }

        childNodes.forEach { childNode in
            if rebuildChildNodes(node: childNode) {
                childNodesDidChange = true
            }
        }

        return childNodesDidChange
    }

}
