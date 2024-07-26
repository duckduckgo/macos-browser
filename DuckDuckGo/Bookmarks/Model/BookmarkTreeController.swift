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

    func treeController(_ treeController: BookmarkTreeController, childNodesFor: BookmarkNode) -> [BookmarkNode]

}

final class BookmarkTreeController {

    static let openAllInNewTabsIdentifier = "openAllInNewTabs"

    private(set) var rootNode: BookmarkNode
    private let isBookmarksBarMenu: Bool
    private weak var dataSource: BookmarkTreeControllerDataSource?

    init(dataSource: BookmarkTreeControllerDataSource, rootNode: BookmarkNode? = nil, isBookmarksBarMenu: Bool = false) {
        self.dataSource = dataSource
        self.rootNode = rootNode ?? BookmarkNode.genericRootNode()
        self.isBookmarksBarMenu = isBookmarksBarMenu

        rebuild()
    }

    convenience init(dataSource: BookmarkTreeControllerDataSource, rootFolder: BookmarkFolder?, isBookmarksBarMenu: Bool) {
        self.init(dataSource: dataSource, rootNode: rootFolder.map(Self.rootNode(from:)), isBookmarksBarMenu: isBookmarksBarMenu)
    }

    private static func rootNode(from rootFolder: BookmarkFolder) -> BookmarkNode {
        let genericRootNode = BookmarkNode.genericRootNode()
        let bookmarksNode = BookmarkNode(representedObject: rootFolder, parent: genericRootNode)
        bookmarksNode.canHaveChildNodes = true
        return bookmarksNode
    }

    private static func separatorNode(for parentNode: BookmarkNode) -> BookmarkNode {
        let spacerObject = SpacerNode.divider
        let node = BookmarkNode(representedObject: spacerObject, parent: parentNode)
        return node
    }

    private static func menuItemNode(withIdentifier identifier: String, title: String, for parentNode: BookmarkNode) -> BookmarkNode {
        let spacerObject = MenuItemNode(identifier: identifier, title: title)
        let node = BookmarkNode(representedObject: spacerObject, parent: parentNode)
        return node
    }

    // MARK: - Public

    func rebuild(withRootFolder rootFolder: BookmarkFolder) {
        self.rootNode = Self.rootNode(from: rootFolder)
        rebuild()
    }

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
        guard node.canHaveChildNodes else { return false }

        let childNodes: [BookmarkNode] = dataSource?.treeController(self, childNodesFor: node) ?? []
        var childNodesDidChange = childNodes != node.childNodes

        if childNodesDidChange {
            node.childNodes = childNodes
        }

        if isBookmarksBarMenu {
            var bookmarksCount = 0
            for childNode in childNodes where childNode.representedObject is Bookmark {
                bookmarksCount += 1
                if bookmarksCount > 1 {
                    break
                }
            }
            if bookmarksCount > 1 {
                node.childNodes.append(Self.separatorNode(for: node))
                node.childNodes.append(Self.menuItemNode(withIdentifier: Self.openAllInNewTabsIdentifier, title: UserText.bookmarksOpenInNewTabs, for: node))
            }

        } else {
            for childNode in childNodes {
                if rebuildChildNodes(node: childNode) {
                    childNodesDidChange = true
                }
            }
        }

        return childNodesDidChange
    }

}
