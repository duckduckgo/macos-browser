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

protocol BookmarkTreeControllerSearchDataSource: AnyObject {

    func treeController(treeController: BookmarkTreeController, searchQuery: String) -> [BookmarkNode]
}

final class BookmarkTreeController {

    let rootNode: BookmarkNode

    private weak var dataSource: BookmarkTreeControllerDataSource?
    private weak var searchDataSource: BookmarkTreeControllerSearchDataSource?

    init(dataSource: BookmarkTreeControllerDataSource,
         searchDataSource: BookmarkTreeControllerSearchDataSource? = nil,
         rootNode: BookmarkNode) {
        self.dataSource = dataSource
        self.searchDataSource = searchDataSource
        self.rootNode = rootNode

        rebuild()
    }

    convenience init(dataSource: BookmarkTreeControllerDataSource,
                     searchDataSource: BookmarkTreeControllerSearchDataSource? = nil) {
        self.init(dataSource: dataSource, searchDataSource: searchDataSource, rootNode: BookmarkNode.genericRootNode())
    }

    // MARK: - Public

    func rebuild(for searchQuery: String) {
        rootNode.childNodes = searchDataSource?.treeController(treeController: self, searchQuery: searchQuery) ?? []
    }

    func rebuild() {
        rebuildChildNodes(node: rootNode)
    }

    func visitNodes(with visitBlock: (BookmarkNode) -> Void) {
        visit(node: rootNode, visitor: visitBlock)
    }

    func node(representing object: AnyObject) -> BookmarkNode? {
        return nodeInArrayRepresentingObject(nodes: [rootNode]) { $0.representedObjectEquals(object) }
    }

    func findNodeInSearchMode(representing object: AnyObject) -> BookmarkNode? {
        return nodeInArrayRepresentingObject(nodes: [rootNode]) { $0.representedObjectHasSameId(object) }
    }

    // MARK: - Private

    private func nodeInArrayRepresentingObject(nodes: [BookmarkNode], match: (BookmarkNode) -> Bool) -> BookmarkNode? {
        var stack: [BookmarkNode] = nodes

        while !stack.isEmpty {
            let node = stack.removeLast()

            if match(node) {
                return node
            }

            if node.canHaveChildNodes {
                stack.append(contentsOf: node.childNodes)
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
