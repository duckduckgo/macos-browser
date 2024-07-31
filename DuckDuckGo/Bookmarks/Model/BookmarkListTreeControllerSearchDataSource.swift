//
//  BookmarkListTreeControllerSearchDataSource.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

final class BookmarkListTreeControllerSearchDataSource: BookmarkTreeControllerSearchDataSource {
    private let bookmarkManager: BookmarkManager

    init(bookmarkManager: BookmarkManager) {
        self.bookmarkManager = bookmarkManager
    }

    func nodes(forSearchQuery searchQuery: String, sortMode: BookmarksSortMode) -> [BookmarkNode] {
        let searchResults = bookmarkManager.search(by: searchQuery)

        return rebuildChildNodes(for: searchResults.sorted(by: sortMode))
    }

    private func rebuildChildNodes(for results: [BaseBookmarkEntity]) -> [BookmarkNode] {
        let rootNode = BookmarkNode.genericRootNode()
        let nodes = results.compactMap { (item) -> BookmarkNode in
            let itemNode = rootNode.createChildNode(item)
            itemNode.canHaveChildNodes = false
            return itemNode
        }

        return nodes
    }
}
