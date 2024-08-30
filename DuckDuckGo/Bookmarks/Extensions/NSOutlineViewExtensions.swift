//
//  NSOutlineViewExtensions.swift
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

extension NSOutlineView {

    var selectedItems: [AnyObject] {
        return selectedRowIndexes.compactMap { (index) -> AnyObject? in
            return item(atRow: index) as AnyObject
        }
    }

    var selectedNodes: [BookmarkNode] {
        return (selectedItems as? [BookmarkNode]) ?? []
    }

    var selectedFolders: [BookmarkFolder] {
        selectedNodes.compactMap { $0.representedObject as? BookmarkFolder }
    }

    var selectedPseudoFolders: [PseudoFolder] {
        selectedNodes.compactMap { $0.representedObject as? PseudoFolder }
    }

    func rowIfValid(forItem item: Any?) -> Int? {
        let row = row(forItem: item)
        guard row >= 0, row != NSNotFound else { return nil }
        return row
    }

    func revealAndSelect(nodePath: BookmarkNode.Path) {
        let totalNodePathComponents = nodePath.components.count
        if totalNodePathComponents < 2 {
            return
        }

        let indexToSelect = totalNodePathComponents - 1

        for index in 1...indexToSelect {
            let node = nodePath.components[index]

            let rowForNode = row(forItem: node)
            if rowForNode < 0 {
                return
            }

            if index == indexToSelect {
                selectRowIndexes(IndexSet(integer: rowForNode), byExtendingSelection: false)
                scrollRowToVisible(rowForNode)
                return
            } else {
                expandItem(node)
            }
        }
    }

}
