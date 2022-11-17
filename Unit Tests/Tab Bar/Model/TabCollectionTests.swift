//
//  TabCollectionTests.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

final class TabCollectionTests: XCTestCase {

    override func setUp() {
        registerDependency(&Tab.Dependencies.faviconManagement, value: FaviconManagerMock())
        registerDependency(&Tab.Dependencies.historyCoordinating, value: HistoryCoordinatingMock())
    }

    // MARK: - Append

    func testWhenTabIsAppendedThenItsIndexIsLast() {
        let tabCollection = TabCollection()

        let tab1 = Tab()
        tabCollection.append(tab: tab1)
        XCTAssertEqual(tabCollection.tabs[tabCollection.tabs.count - 1], tab1)

        let tab2 = Tab()
        tabCollection.append(tab: tab2)
        XCTAssertEqual(tabCollection.tabs[tabCollection.tabs.count - 1], tab2)
    }

    // MARK: - Insert

    func testWhenInsertIsCalledWithIndexOutOfBoundsThenItemIsNotInserted() {
        let tabCollection = TabCollection()
        let tab = Tab()

        tabCollection.insert(tab: tab, at: -1)
        XCTAssertEqual(tabCollection.tabs.count, 0)
        XCTAssertFalse(tabCollection.tabs.contains(tab))
    }

    func testWhenTabIsInsertedAtIndexThenItemsWithEqualOrHigherIndexesAreMoved() {
        let tabCollection = TabCollection()

        let tab1 = Tab()
        tabCollection.insert(tab: tab1, at: 0)
        XCTAssertEqual(tabCollection.tabs[0], tab1)

        let tab2 = Tab()
        tabCollection.insert(tab: tab2, at: 0)
        XCTAssertEqual(tabCollection.tabs[0], tab2)
        XCTAssertEqual(tabCollection.tabs[1], tab1)

    }

    // MARK: - Remove

    func testWhenRemoveIsCalledWithIndexOutOfBoundsThenNoItemIsRemoved() {
        let tabCollection = TabCollection()

        let tab = Tab()
        tabCollection.append(tab: tab)
        XCTAssertEqual(tabCollection.tabs.count, 1)
        XCTAssert(tabCollection.tabs.contains(tab))

        XCTAssertFalse(tabCollection.remove(at: 1))
        XCTAssertEqual(tabCollection.tabs.count, 1)
        XCTAssert(tabCollection.tabs.contains(tab))
    }

    func testWhenTabIsRemovedAtIndexThenItemsWithHigherIndexesAreMoved() {
        let tabCollection = TabCollection()

        let tab1 = Tab()
        tabCollection.append(tab: tab1)
        let tab2 = Tab()
        tabCollection.append(tab: tab2)
        let tab3 = Tab()
        tabCollection.append(tab: tab3)

        XCTAssert(tabCollection.remove(at: 0))

        XCTAssertEqual(tabCollection.tabs[0], tab2)
        XCTAssertEqual(tabCollection.tabs[1], tab3)
    }

    func testWhenTabIsRemoved_ThenItsLocalHistoryIsKeptInTabCollection() {
        let url = URL.duckDuckGo

        let tabCollection = TabCollection()

        let tab1 = Tab()
        tabCollection.append(tab: tab1)
        let tab2 = Tab()
        tabCollection.append(tab: tab2)
        tab2.addVisit(of: url)

        tabCollection.removeAll()
        XCTAssert(tabCollection.localHistoryOfRemovedTabs.contains(url.host!))
    }

    // MARK: - Move

    func testWhenMoveIsCalledWithIndexesOutOfBoundsThenNoItemIsMoved() {
        let tabCollection = TabCollection()

        let tab1 = Tab()
        tabCollection.append(tab: tab1)
        let tab2 = Tab()
        tabCollection.append(tab: tab2)

        tabCollection.moveTab(at: 0, to: 3)
        tabCollection.moveTab(at: 0, to: -1)
        tabCollection.moveTab(at: 3, to: 0)
        tabCollection.moveTab(at: -1, to: 0)
        XCTAssertEqual(tabCollection.tabs[0], tab1)
        XCTAssertEqual(tabCollection.tabs[1], tab2)
    }

    func testWhenMoveIsCalledWithSameIndexesThenNoItemIsMoved() {
        let tabCollection = TabCollection()

        let tab1 = Tab()
        tabCollection.append(tab: tab1)
        let tab2 = Tab()
        tabCollection.append(tab: tab2)

        tabCollection.moveTab(at: 0, to: 0)
        tabCollection.moveTab(at: 1, to: 1)
        XCTAssertEqual(tabCollection.tabs[0], tab1)
        XCTAssertEqual(tabCollection.tabs[1], tab2)
    }

    func testWhenTabIsMovedThenOtherItemsAreReorganizedProperly() {
        let tabCollection = TabCollection()

        let tab1 = Tab()
        tabCollection.append(tab: tab1)
        let tab2 = Tab()
        tabCollection.append(tab: tab2)
        let tab3 = Tab()
        tabCollection.append(tab: tab3)

        tabCollection.moveTab(at: 0, to: 1)
        XCTAssertEqual(tabCollection.tabs[0], tab2)
        XCTAssertEqual(tabCollection.tabs[1], tab1)
        XCTAssertEqual(tabCollection.tabs[2], tab3)

        tabCollection.moveTab(at: 0, to: 2)
        XCTAssertEqual(tabCollection.tabs[0], tab1)
        XCTAssertEqual(tabCollection.tabs[1], tab3)
        XCTAssertEqual(tabCollection.tabs[2], tab2)
    }

}

extension Tab {
    convenience override init() {
        self.init(content: .homePage)
    }
}
