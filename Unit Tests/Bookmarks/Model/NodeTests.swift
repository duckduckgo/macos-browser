//
//  NodeTests.swift
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

class NodeTests: XCTestCase {

    private class TestObject: NSObject {}

    func testWhenCreatingGenericRootNode_ThenRootNodeIsReturned() {
        let node = Node.genericRootNode()
        XCTAssertNil(node.parent)
        XCTAssertTrue(node.canHaveChildNodes)
    }

    func testWhenInitializingMultipleNodes_ThenEachNodeHasUniqueID() {
        let firstNode = Node(representedObject: TestObject(), parent: nil)
        let secondNode = Node(representedObject: TestObject(), parent: nil)

        XCTAssertNotEqual(firstNode.uniqueID, secondNode.uniqueID)
    }

    func testWhenIsRootNode_ThenIsRootReturnsCorrectValue() {
        let rootNode = Node(representedObject: TestObject(), parent: nil)
        XCTAssertTrue(rootNode.isRoot)

        let childNode = Node(representedObject: TestObject(), parent: rootNode)
        XCTAssertFalse(childNode.isRoot)
    }

    func testWhenNestingNodes_ThenNodeLevelsIncrementBasedOnParentLevel() {
        let rootNode = Node(representedObject: TestObject(), parent: nil)

        XCTAssertEqual(rootNode.level, 0)

        let firstChildOfRootNode = Node(representedObject: TestObject(), parent: rootNode)
        let secondChildOfRootNode = Node(representedObject: TestObject(), parent: rootNode)

        XCTAssertEqual(firstChildOfRootNode.level, 1)
        XCTAssertEqual(secondChildOfRootNode.level, 1)

        let firstNestedChild = Node(representedObject: TestObject(), parent: firstChildOfRootNode)
        let secondNestedChild = Node(representedObject: TestObject(), parent: firstChildOfRootNode)

        XCTAssertEqual(firstNestedChild.level, 2)
        XCTAssertEqual(secondNestedChild.level, 2)
    }

    func testWhenGettingNumberOfChildNodes_ThenNumberMatchesNumberOfChildren() {
        let rootNode = Node(representedObject: TestObject(), parent: nil)
        XCTAssertEqual(rootNode.numberOfChildNodes, 0)

        let childNode = Node(representedObject: TestObject(), parent: rootNode)
        XCTAssertEqual(childNode.numberOfChildNodes, 0)

        rootNode.childNodes = [childNode]
        XCTAssertEqual(rootNode.numberOfChildNodes, 1)
    }

    func testWhenGettingIndexOfChildNode_AndChildExists_ThenIndexIsReturned() {
        let rootNode = Node(representedObject: TestObject(), parent: nil)
        let firstChildNode = Node(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = Node(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        XCTAssertEqual(rootNode.indexOfChild(firstChildNode), 0)
        XCTAssertEqual(rootNode.indexOfChild(secondChildNode), 1)
    }

    func testWhenGettingIndexOfChildNode_AndChildDoesNotExist_ThenNilIsReturned() {
        let rootNode = Node(representedObject: TestObject(), parent: nil)
        let unrelatedNode = Node(representedObject: TestObject(), parent: nil)

        XCTAssertNil(rootNode.indexOfChild(unrelatedNode))
    }

    func testWhenGettingChildNodeAtIndex_AndChildExists_ThenNodeIsReturned() {
        let rootNode = Node(representedObject: TestObject(), parent: nil)
        let firstChildNode = Node(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = Node(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        XCTAssertEqual(rootNode.childAtIndex(0), firstChildNode)
        XCTAssertEqual(rootNode.childAtIndex(1), secondChildNode)
    }

    func testWhenGettingChildNodeAtIndex_AndChildDoesNotExist_ThenNilIsReturned() {
        let rootNode = Node(representedObject: TestObject(), parent: nil)

        XCTAssertNil(rootNode.childAtIndex(0))
        XCTAssertNil(rootNode.childAtIndex(1))
        XCTAssertNil(rootNode.childAtIndex(2))
    }

    func testWhenGettingIndexPath_AndNodeIsRootNode_ThenRootIndexPathIsReturned() {
        let rootNode = Node(representedObject: TestObject(), parent: nil)
        let indexPath = rootNode.indexPath

        XCTAssertEqual(indexPath, IndexPath.init(index: 0))
    }

    func testWhenGettingIndexPath_AndNodeIsChild_ThenChildIndexPathIsReturned() {
        let rootNode = Node(representedObject: TestObject(), parent: nil)
        let firstChildNode = Node(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = Node(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        let firstChildIndexPath = firstChildNode.indexPath
        XCTAssertEqual(firstChildIndexPath, IndexPath(arrayLiteral: 0, 0))

        let secondChildIndexPath = secondChildNode.indexPath
        XCTAssertEqual(secondChildIndexPath, IndexPath(arrayLiteral: 0, 1))
    }

    func testWhenGettingChildNodeForObject_AndObjectIsFound_ThenNodeIsReturned() {
        let desiredObject = TestObject()

        let rootNode = Node(representedObject: TestObject(), parent: nil)
        let firstChildNode = Node(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = Node(representedObject: desiredObject, parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        let foundNode = rootNode.childNodeRepresenting(object: desiredObject)
        XCTAssertEqual(foundNode, secondChildNode)
    }

    func testWhenGettingChildNodeForObject_AndObjectIsNotFound_ThenNilIsReturned() {
        let rootNode = Node(representedObject: TestObject(), parent: nil)
        let firstChildNode = Node(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = Node(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        let foundNode = rootNode.childNodeRepresenting(object: TestObject())
        XCTAssertNil(foundNode)
    }

    func testWhenGettingChildNodeForObject_AndObjectIsNotDirectChild_ThenNilIsReturned() {
        let desiredObject = TestObject()
        let rootNode = Node(representedObject: TestObject(), parent: nil)

        let childOfRootNode = Node(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [childOfRootNode]

        let childOfChildNode = Node(representedObject: desiredObject, parent: childOfRootNode)
        childOfRootNode.childNodes = [childOfChildNode]

        let foundNode = rootNode.childNodeRepresenting(object: desiredObject)
        XCTAssertNil(foundNode)
    }

    func testWhenGettingDescendantNodeForObject_AndObjectIsNotDirectChild_ThenNodeIsReturned() {
        let desiredObject = TestObject()
        let rootNode = Node(representedObject: TestObject(), parent: nil)

        let childOfRootNode = Node(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [childOfRootNode]

        let childOfChildNode = Node(representedObject: desiredObject, parent: childOfRootNode)
        childOfRootNode.childNodes = [childOfChildNode]

        let foundNode = rootNode.descendantNodeRepresenting(object: desiredObject)
        XCTAssertEqual(foundNode, childOfChildNode)
    }

    func testWhenCheckingIfNodeIsAncestor_AndNodeIsSelf_ThenFalseIsReturned() {
        let rootNode = Node(representedObject: TestObject(), parent: nil)
        XCTAssertFalse(rootNode.isAncestor(of: rootNode))
    }

    func testWhenCheckingIfNodeIsAncestor_AndNodeIsAncestor_ThenTrueIsReturned() {
        let rootNode = Node(representedObject: TestObject(), parent: nil)
        let firstChildNode = Node(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = Node(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        XCTAssertTrue(rootNode.isAncestor(of: secondChildNode))
    }

    func testWhenCheckingRepresentedObjectEquality_AndObjectsAreEqual_ThenTrueIsReturned() {
        let object = TestObject()
        let node = Node(representedObject: object, parent: nil)

        XCTAssertTrue(node.representedObjectEquals(object))
        XCTAssertFalse(node.representedObjectEquals(TestObject()))
    }

    func testWhenFindingOrCreatingChildNode_AndChildExists_ThenChildIsReturned() {
        let childObject = TestObject()
        let rootNode = Node(representedObject: TestObject(), parent: nil)
        let childNode = Node(representedObject: childObject, parent: rootNode)
        rootNode.childNodes = [childNode]

        XCTAssertEqual(rootNode.findOrCreateChildNode(with: childObject), childNode)
    }

    func testWhenFindingOrCreatingChildNode_AndChildDoesNotExist_ThenChildIsCreated() {
        let rootNode = Node(representedObject: TestObject(), parent: nil)
        let childNode = Node(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [childNode]

        XCTAssertNotEqual(rootNode.findOrCreateChildNode(with: TestObject()), childNode)
    }

}
