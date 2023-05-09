//
//  BookmarkTreeController.swift
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

protocol BookmarkTreeControllerDataSource: AnyObject {

    func treeController(treeController: BookmarkTreeController, childNodesFor: BookmarkNode) -> [BookmarkNode]

}

final class BookmarkTreeController {

    let rootNode: BookmarkNode

    private weak var dataSource: BookmarkTreeControllerDataSource?

    init(dataSource: BookmarkTreeControllerDataSource, rootNode: BookmarkNode) {
        self.dataSource = dataSource
        self.rootNode = rootNode

        rebuild()
    }

    convenience init(dataSource: BookmarkTreeControllerDataSource) {
        self.init(dataSource: dataSource, rootNode: BookmarkNode.genericRootNode())
    }

    // MARK: - Public

    func rebuild() {
        rebuildChildNodes(node: rootNode)
    }

    func visitNodes(with visitBlock: (BookmarkNode) -> Void) {
        visit(node: rootNode, visitor: visitBlock)
    }

    func node(representing object: AnyObject) -> BookmarkNode? {
        return nodeInArrayRepresentingObject(nodes: [rootNode], representedObject: object)
    }

    // MARK: - Private

    private func nodeInArrayRepresentingObject(nodes: [BookmarkNode], representedObject: AnyObject) -> BookmarkNode? {
        for node in nodes {
            if node.representedObjectEquals(representedObject) {
                return node
            }

            if node.canHaveChildNodes {
                if let foundNode = nodeInArrayRepresentingObject(nodes: node.childNodes, representedObject: representedObject) {
                    return foundNode
                }
            }
        }

        return nil
    }

    private func visit(node: BookmarkNode, visitor: (BookmarkNode) -> Void) {
        visitor(node)
        node.childNodes.forEach { visit(node: $0, visitor: visitor) }
    }

    @discardableResult
    private func rebuildChildNodes(node: BookmarkNode) -> Bool {
        guard node.canHaveChildNodes else {
            return false
        }

        let childNodes: [BookmarkNode] = dataSource?.treeController(treeController: self, childNodesFor: node) ?? []
        var childNodesDidChange = childNodes != node.childNodes

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
