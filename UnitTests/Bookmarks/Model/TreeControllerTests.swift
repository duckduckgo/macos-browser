//
//  TreeControllerTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

private class MockTreeControllerDataSource: BookmarkTreeControllerDataSource {

    func treeController(treeController: BookmarkTreeController, childNodesFor node: BookmarkNode) -> [BookmarkNode] {
        return node.childNodes
    }

}

class TreeControllerTests: XCTestCase {

    private class TestObject {}

    func testWhenInitializingTreeControllerWithRootNode_ThenRootNodeIsSet() {
        let dataSource = MockTreeControllerDataSource()
        let node = BookmarkNode(representedObject: TestObject(), parent: nil)
        let treeController = BookmarkTreeController(dataSource: dataSource, rootNode: node)

        XCTAssertEqual(treeController.rootNode, node)
    }

    func testWhenInitializingTreeControllerWithoutRootNode_ThenGenericRootNodeIsCreated() {
        let dataSource = MockTreeControllerDataSource()
        let treeController = BookmarkTreeController(dataSource: dataSource)

        XCTAssertTrue(treeController.rootNode.canHaveChildNodes)
    }

    func testWhenGettingNodeRepresentingObject_AndObjectExistsInTree_ThenNodeIsReturned() {
        let desiredObject = TestObject()

        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        rootNode.canHaveChildNodes = true

        let firstChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = BookmarkNode(representedObject: desiredObject, parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        let dataSource = MockTreeControllerDataSource()
        let treeController = BookmarkTreeController(dataSource: dataSource, rootNode: rootNode)

        let foundNode = treeController.node(representing: desiredObject)
        XCTAssertEqual(foundNode, secondChildNode)
    }

    func testWhenGettingNodeRepresentingObject_AndObjectDoesNotExistInTree_ThenNilIsReturned() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        rootNode.canHaveChildNodes = true

        let firstChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        let dataSource = MockTreeControllerDataSource()
        let treeController = BookmarkTreeController(dataSource: dataSource, rootNode: rootNode)

        let foundNode = treeController.node(representing: TestObject())
        XCTAssertNil(foundNode)
    }

    func testWhenVisitingNodes_ThenEachNodeIsVisited() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        rootNode.canHaveChildNodes = true

        let firstChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        let dataSource = MockTreeControllerDataSource()
        let treeController = BookmarkTreeController(dataSource: dataSource, rootNode: rootNode)

        var visitedNodes = Set<Int>()

        treeController.visitNodes { node in
            visitedNodes.insert(node.uniqueID)
        }

        XCTAssertEqual(visitedNodes, [rootNode.uniqueID, firstChildNode.uniqueID, secondChildNode.uniqueID])
    }

}
