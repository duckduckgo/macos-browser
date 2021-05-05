//
//  BookmarkNodePathTests.swift
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

class BookmarkNodePathTests: XCTestCase {

    private class TestObject: NSObject {}

    func testWhenInitializingWithRootNode_ThenPathContainsOneNode() {
        let node = BookmarkNode(representedObject: TestObject(), parent: nil)
        let path = BookmarkNode.Path(node: node)

        XCTAssertEqual(path.components, [node])
    }

    func testWhenInitializingWithChildNode_ThenPathContainsTwoNodes() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        let childNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        let path = BookmarkNode.Path(node: childNode)

        XCTAssertEqual(path.components, [rootNode, childNode])
    }

    func testWhenInitializingWithNestedNodes_ThenPathContainsThreeNodes() {
        let rootNode = BookmarkNode(representedObject: TestObject(), parent: nil)
        let childNode = BookmarkNode(representedObject: TestObject(), parent: rootNode)
        let childOfChildNode = BookmarkNode(representedObject: TestObject(), parent: childNode)
        let path = BookmarkNode.Path(node: childOfChildNode)

        XCTAssertEqual(path.components, [rootNode, childNode, childOfChildNode])
    }

}
