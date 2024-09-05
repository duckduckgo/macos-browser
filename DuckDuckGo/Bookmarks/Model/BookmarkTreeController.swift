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
    func treeController(childNodesFor: BookmarkNode, sortMode: BookmarksSortMode) -> [BookmarkNode]
}

protocol BookmarkTreeControllerSearchDataSource: AnyObject {
    func nodes(forSearchQuery searchQuery: String, sortMode: BookmarksSortMode) -> [BookmarkNode]
}

final class BookmarkTreeController {

    static let openAllInNewTabsIdentifier = "openAllInNewTabs"
    static let emptyPlaceholderIdentifier = "empty"

    private(set) var rootNode: BookmarkNode
    private let isBookmarksBarMenu: Bool

    private weak var dataSource: BookmarkTreeControllerDataSource?
    private weak var searchDataSource: BookmarkTreeControllerSearchDataSource?

    init(dataSource: BookmarkTreeControllerDataSource,
         sortMode: BookmarksSortMode,
         searchDataSource: BookmarkTreeControllerSearchDataSource? = nil,
         rootNode: BookmarkNode? = nil,
         isBookmarksBarMenu: Bool = false) {
        self.dataSource = dataSource
        self.searchDataSource = searchDataSource
        self.rootNode = rootNode ?? BookmarkNode.genericRootNode()
        self.isBookmarksBarMenu = isBookmarksBarMenu

        rebuild(for: sortMode)
    }

    convenience init(dataSource: BookmarkTreeControllerDataSource,
                     sortMode: BookmarksSortMode,
                     searchDataSource: BookmarkTreeControllerSearchDataSource? = nil,
                     rootFolder: BookmarkFolder?,
                     isBookmarksBarMenu: Bool) {
        self.init(dataSource: dataSource, sortMode: sortMode, searchDataSource: searchDataSource, rootNode: rootFolder.map(Self.rootNode(from:)), isBookmarksBarMenu: isBookmarksBarMenu)
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

    private static func menuItemNode(withIdentifier identifier: String, title: String, isEnabled: Bool = true, for parentNode: BookmarkNode) -> BookmarkNode {
        let spacerObject = MenuItemNode(identifier: identifier, title: title, isEnabled: isEnabled)
        let node = BookmarkNode(representedObject: spacerObject, parent: parentNode)
        return node
    }

    // MARK: - Public

    func rebuild(forSearchQuery searchQuery: String, sortMode: BookmarksSortMode) {
        rootNode.childNodes = searchDataSource?.nodes(forSearchQuery: searchQuery, sortMode: sortMode) ?? []
    }

    func rebuild(for sortMode: BookmarksSortMode, withRootFolder rootFolder: BookmarkFolder? = nil) {
        if let rootFolder {
            self.rootNode = Self.rootNode(from: rootFolder)
        }
        rebuildChildNodes(node: rootNode, sortMode: sortMode)
    }

    func visitNodes(with visitBlock: (BookmarkNode) -> Void) {
        visit(node: rootNode, visitor: visitBlock)
    }

    func node(representing object: AnyObject) -> BookmarkNode? {
        return nodeInArrayRepresentingObject(nodes: [rootNode]) { $0.representedObjectEquals(object) }
    }

    func findNodeWithId(representing object: AnyObject) -> BookmarkNode? {
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
    private func rebuildChildNodes(node: BookmarkNode, sortMode: BookmarksSortMode = .manual) -> Bool {
        guard node.canHaveChildNodes else { return false }

        let childNodes: [BookmarkNode] = dataSource?.treeController(childNodesFor: node, sortMode: sortMode) ?? []
        var childNodesDidChange = childNodes != node.childNodes

        if childNodesDidChange {
            node.childNodes = childNodes
        }

        if isBookmarksBarMenu {
            // count up to 2 bookmarks in the node – add “Open all in new tabs” item if 2 bookmarks and more
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

            } else if childNodes.isEmpty {
                node.childNodes.append(Self.menuItemNode(withIdentifier: Self.emptyPlaceholderIdentifier, title: UserText.bookmarksBarFolderEmpty, isEnabled: false, for: node))
            }
        } else {
            childNodes.forEach { childNode in
                if rebuildChildNodes(node: childNode, sortMode: sortMode) {
                    childNodesDidChange = true
                }
            }
        }

        return childNodesDidChange
    }

}
