//
//  BookmarkNodeTests.swift
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

class BookmarkNodeTests: XCTestCase {

    private class TestObject: NSObject {}

    func testWhenCreatingGenericRootNode_ThenRootNodeIsReturned() {
        let node = BookmarkNode.genericRootNode()
        XCTAssertNil(node.parent)
        XCTAssertTrue(node.canHaveChildNodes)
    }

    func testWhenInitializingMultipleNodes_ThenEachNodeHasUniqueID() {
        let firstNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        let secondNode = BookmarkNode(representedObject: TestObject(), parent: nil)

        XCTAssertNotEqual(firstNode.uniqueID, secondNode.uniqueID)
    }

    func testWhenIsRootNode_ThenIsRootReturnsCorrectValue() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        XCTAssertTrue(rootNode.isRoot)

        let childNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        XCTAssertFalse(childNode.isRoot)
    }

    func testWhenNestingNodes_ThenNodeLevelsIncrementBasedOnParentLevel() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)

        XCTAssertEqual(rootNode.level, 0)

        let firstChildOfRootNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        let secondChildOfRootNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)

        XCTAssertEqual(firstChildOfRootNode.level, 1)
        XCTAssertEqual(secondChildOfRootNode.level, 1)

        let firstNestedChild = BookmarkNode(representedObject: TestObject(), parent: firstChildOfRootNode)
        let secondNestedChild = BookmarkNode(representedObject: TestObject(), parent: firstChildOfRootNode)

        XCTAssertEqual(firstNestedChild.level, 2)
        XCTAssertEqual(secondNestedChild.level, 2)
    }

    func testWhenGettingNumberOfChildNodes_ThenNumberMatchesNumberOfChildren() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        XCTAssertEqual(rootNode.numberOfChildNodes, 0)

        let childNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        XCTAssertEqual(childNode.numberOfChildNodes, 0)

        rootNode.childNodes = [childNode]
        XCTAssertEqual(rootNode.numberOfChildNodes, 1)
    }

    func testWhenGettingIndexOfChildNode_AndChildExists_ThenIndexIsReturned() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        let firstChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        XCTAssertEqual(rootNode.indexOfChild(firstChildNode), 0)
        XCTAssertEqual(rootNode.indexOfChild(secondChildNode), 1)
    }

    func testWhenGettingIndexOfChildNode_AndChildDoesNotExist_ThenNilIsReturned() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        let unrelatedNode = BookmarkNode(representedObject: TestObject(), parent: nil)

        XCTAssertNil(rootNode.indexOfChild(unrelatedNode))
    }

    func testWhenGettingChildNodeAtIndex_AndChildExists_ThenNodeIsReturned() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        let firstChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        XCTAssertEqual(rootNode.childAtIndex(0), firstChildNode)
        XCTAssertEqual(rootNode.childAtIndex(1), secondChildNode)
    }

    func testWhenGettingChildNodeAtIndex_AndChildDoesNotExist_ThenNilIsReturned() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)

        XCTAssertNil(rootNode.childAtIndex(0))
        XCTAssertNil(rootNode.childAtIndex(1))
        XCTAssertNil(rootNode.childAtIndex(2))
    }

    func testWhenGettingIndexPath_AndNodeIsRootNode_ThenRootIndexPathIsReturned() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        let indexPath = rootNode.indexPath

        XCTAssertEqual(indexPath, IndexPath.init(index: 0))
    }

    func testWhenGettingIndexPath_AndNodeIsChild_ThenChildIndexPathIsReturned() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        let firstChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        let firstChildIndexPath = firstChildNode.indexPath
        XCTAssertEqual(firstChildIndexPath, IndexPath(arrayLiteral: 0, 0))

        let secondChildIndexPath = secondChildNode.indexPath
        XCTAssertEqual(secondChildIndexPath, IndexPath(arrayLiteral: 0, 1))
    }

    func testWhenGettingChildNodeForObject_AndObjectIsFound_ThenNodeIsReturned() {
        let desiredObject = TestObject()

        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        let firstChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = BookmarkNode(representedObject: desiredObject, parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        let foundNode = rootNode.childNodeRepresenting(object: desiredObject)
        XCTAssertEqual(foundNode, secondChildNode)
    }

    func testWhenGettingChildNodeForObject_AndObjectIsNotFound_ThenNilIsReturned() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        let firstChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        let foundNode = rootNode.childNodeRepresenting(object: TestObject())
        XCTAssertNil(foundNode)
    }

    func testWhenGettingChildNodeForObject_AndObjectIsNotDirectChild_ThenNilIsReturned() {
        let desiredObject = TestObject()
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)

        let childOfRootNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [childOfRootNode]

        let childOfChildNode = BookmarkNode(representedObject: desiredObject, parent: childOfRootNode)
        childOfRootNode.childNodes = [childOfChildNode]

        let foundNode = rootNode.childNodeRepresenting(object: desiredObject)
        XCTAssertNil(foundNode)
    }

    func testWhenGettingDescendantNodeForObject_AndObjectIsNotDirectChild_ThenNodeIsReturned() {
        let desiredObject = TestObject()
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)

        let childOfRootNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [childOfRootNode]

        let childOfChildNode = BookmarkNode(representedObject: desiredObject, parent: childOfRootNode)
        childOfRootNode.childNodes = [childOfChildNode]

        let foundNode = rootNode.descendantNodeRepresenting(object: desiredObject)
        XCTAssertEqual(foundNode, childOfChildNode)
    }

    func testWhenCheckingIfNodeIsAncestor_AndNodeIsSelf_ThenFalseIsReturned() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        XCTAssertFalse(rootNode.isAncestor(of: rootNode))
    }

    func testWhenCheckingIfNodeIsAncestor_AndNodeIsAncestor_ThenTrueIsReturned() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        let firstChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        let secondChildNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [firstChildNode, secondChildNode]

        XCTAssertTrue(rootNode.isAncestor(of: secondChildNode))
    }

    func testWhenCheckingRepresentedObjectEquality_AndObjectsAreEqual_ThenTrueIsReturned() {
        let object = TestObject()
        let node = BookmarkNode(representedObject: object, parent: nil)

        XCTAssertTrue(node.representedObjectEquals(object))
        XCTAssertFalse(node.representedObjectEquals(TestObject()))
    }

    func testWhenFindingOrCreatingChildNode_AndChildExists_ThenChildIsReturned() {
        let childObject = TestObject()
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        let childNode = BookmarkNode(representedObject: childObject, parent: rootNode)
        rootNode.childNodes = [childNode]

        XCTAssertEqual(rootNode.findOrCreateChildNode(with: childObject), childNode)
    }

    func testWhenFindingOrCreatingChildNode_AndChildDoesNotExist_ThenChildIsCreated() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        let childNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        rootNode.childNodes = [childNode]

        XCTAssertNotEqual(rootNode.findOrCreateChildNode(with: TestObject()), childNode)
    }

}
