//
//  NodePath.swift
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

struct NodePath {

    let components: [Node]

    init(node: Node) {
        var temporaryComponents = [node]
        var currentNode = node

        while true {
            if let parent = currentNode.parent {
                temporaryComponents.append(parent)
                currentNode = parent
            } else {
                break
            }
        }

        self.components = temporaryComponents.reversed()
    }

    init?(representedObject: AnyObject, treeController: TreeController) {
        if let node = treeController.nodeInTreeRepresentingObject(representedObject) {
            self.init(node: node)
        }

        return nil
    }

}

extension NSOutlineView {

    func revealAndSelect(nodePath: NodePath) {
        let numberOfNodes = nodePath.components.count
        if numberOfNodes < 2 {
            return
        }

        let indexOfNodeToSelect = numberOfNodes - 1

        for index in 1...indexOfNodeToSelect {
            let node = nodePath.components[index]

            let rowForNode = row(forItem: node)
            if rowForNode < 0 {
                return
            }

            if index == indexOfNodeToSelect {
                selectRowIndexes(IndexSet(integer: rowForNode), byExtendingSelection: false)
                scrollRowToVisible(rowForNode)
                return
            } else {
                expandItem(node)
            }
        }
    }

}
