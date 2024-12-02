//
//  PinnedTabsViewModelTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

extension Tab {
    @MainActor
    convenience init(content: TabContent, parentTab: Tab? = nil) {
        self.init(content: content, parentTab: parentTab, shouldLoadInBackground: false)
    }
}

class PinnedTabsViewModelTests: XCTestCase {

    var model: PinnedTabsViewModel!
    var collection: TabCollection!
    var bookmarkManagerMock: MockBookmarkManager!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        collection = TabCollection(tabs: [
            Tab(content: .url("http://a.com".url!, source: .link)),
            Tab(content: .url("http://b.com".url!, source: .link)),
            Tab(content: .url("http://c.com".url!, source: .link)),
            Tab(content: .url("http://d.com".url!, source: .link)),
            Tab(content: .url("http://e.com".url!, source: .link))
        ])
        bookmarkManagerMock = .init()
        model = PinnedTabsViewModel(collection: collection, bookmarkManager: bookmarkManagerMock)
    }

    func testInitialState() throws {
        XCTAssertNil(model.selectedItem)
        XCTAssertNil(model.hoveredItem)
        XCTAssertNil(model.selectedItemIndex)
        XCTAssertNil(model.hoveredItemIndex)
        XCTAssertTrue(model.shouldDrawLastItemSeparator)
        XCTAssertTrue(model.itemsWithoutSeparator.isEmpty)
    }

    func testWhenItemIsSelectedThenSelectedItemIndexIsUpdated() throws {
        model.selectedItem = collection.tabs[2]
        XCTAssertEqual(model.selectedItemIndex, 2)
        model.selectedItem = collection.tabs[4]
        XCTAssertEqual(model.selectedItemIndex, 4)
        model.selectedItem = collection.tabs[0]
        XCTAssertEqual(model.selectedItemIndex, 0)
        model.selectedItem = nil
        XCTAssertNil(model.selectedItemIndex)
    }

    func testWhenItemIsHoveredThenHoveredItemIndexIsUpdated() throws {
        model.hoveredItem = collection.tabs[2]
        XCTAssertEqual(model.hoveredItemIndex, 2)
        model.hoveredItem = collection.tabs[4]
        XCTAssertEqual(model.hoveredItemIndex, 4)
        model.hoveredItem = collection.tabs[0]
        XCTAssertEqual(model.hoveredItemIndex, 0)
        model.hoveredItem = nil
        XCTAssertNil(model.hoveredItemIndex)
    }

    func testWhenSelectedItemChangesThenItemsWithoutSeparatorIsUpdated() throws {
        model.selectedItem = collection.tabs[0]
        XCTAssertEqual(model.itemsWithoutSeparator, [collection.tabs[0]])

        model.selectedItem = collection.tabs[1]
        XCTAssertEqual(model.itemsWithoutSeparator, [collection.tabs[0], collection.tabs[1]])

        model.selectedItem = collection.tabs[3]
        XCTAssertEqual(model.itemsWithoutSeparator, [collection.tabs[2], collection.tabs[3]])

        model.shouldDrawLastItemSeparator = false
        XCTAssertEqual(model.itemsWithoutSeparator, [collection.tabs[2], collection.tabs[3], collection.tabs[4]])
    }

    @MainActor
    func testWhenThereIsOnlyOneItemThenDraggingMovesWindow() throws {
        let tabA = Tab(content: .url("http://a.com".url!, source: .link))
        let tabB = Tab(content: .url("http://b.com".url!, source: .link))

        model.items = [tabA, tabB]
        XCTAssertFalse(model.dragMovesWindow)

        model.items = [tabA]
        XCTAssertTrue(model.dragMovesWindow)
    }

    @MainActor
    func testThatItemsReorderingIsPublished() throws {
        var events: [[Tab]] = []
        let cancellable = model.tabsDidReorderPublisher.sink(receiveValue: { events.append($0) })

        let tabA = Tab(content: .url("http://a.com".url!, source: .link))
        let tabB = Tab(content: .url("http://b.com".url!, source: .link))
        let tabC = Tab(content: .url("http://c.com".url!, source: .link))

        model.items = []
        XCTAssertTrue(events.isEmpty)

        model.items = [tabA]
        model.items = [tabA, tabB]
        XCTAssertTrue(events.isEmpty)

        model.items = [tabB, tabA]
        model.items = [tabB, tabA, tabC]

        model.items = [tabC, tabA, tabB]
        model.items = [tabC, tabA, tabB]
        model.items = [tabC, tabA, tabB]

        model.items = [tabC, tabB, tabA]

        cancellable.cancel()

        XCTAssertEqual(events, [
            [tabB, tabA],
            [tabC, tabA, tabB],
            [tabC, tabB, tabA]
        ])
    }

    @MainActor
    func testThatContextMenuActionsArePublished() {
        let tabA = Tab(content: .url("http://a.com".url!, source: .link))
        let tabB = Tab(content: .url("http://b.com".url!, source: .link))

        var events: [PinnedTabsViewModel.ContextMenuAction] = []

        let cancellable = model.contextMenuActionPublisher.sink { events.append($0) }

        model.items = [tabA, tabB]

        model.bookmark(tabA)
        model.unpin(tabB)
        model.duplicate(tabA)
        model.fireproof(tabA)
        model.removeFireproofing(tabB)
        model.close(tabA)
        model.muteOrUmute(tabB)
        model.removeBookmark(tabA)

        cancellable.cancel()

        XCTAssertEqual(events.count, 8)

        guard case .bookmark(tabA) = events[0],
              case .unpin(1) = events[1],
              case .duplicate(0) = events[2],
              case .fireproof(tabA) = events[3],
              case .removeFireproofing(tabB) = events[4],
              case .close(0) = events[5],
              case .muteOrUnmute(tabB) = events[6],
              case .removeBookmark(tabA) = events[7]
        else {
            XCTFail("Incorrect context menu action")
            return
        }
    }

    @MainActor
    func testWhenIsPinnedTabBookmarkedCalledAndURLIsBookmarkedThenReturnTrue() {
        // GIVEN
        bookmarkManagerMock.isUrlBookmarked = true
        let tab = Tab(content: .url(URL.duckDuckGo, source: .link))

        // WHEN
        let result = model.isPinnedTabBookmarked(tab)

        // THEN
        XCTAssertTrue(result)
    }

    @MainActor
    func testWhenIsPinnedTabBookmarkedCalledAndURLIsNotBookmarkedThenReturnFalse() {
        // GIVEN
        bookmarkManagerMock.isUrlBookmarked = false
        let tab = Tab(content: .url(URL.duckDuckGo, source: .link))

        // WHEN
        let result = model.isPinnedTabBookmarked(tab)

        // THEN
        XCTAssertFalse(result)
    }

}

private extension Array where Element == Tab {
    @MainActor
    static func urls(_ urlStrings: String ...) -> [Tab] {
        self.init(urlStrings.map({ Tab(content: .url($0.url!, source: .link)) }))
    }
}
