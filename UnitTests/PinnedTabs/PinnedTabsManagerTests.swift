//
//  PinnedTabsManagerTests.swift
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

class PinnedTabsManagerTests: XCTestCase {

    func testInitialState() throws {
        let manager = PinnedTabsManager()
        XCTAssertTrue(manager.tabCollection.tabs.isEmpty)
        XCTAssertTrue(manager.pinnedDomains.isEmpty)
    }

    @MainActor
    func testPinning() throws {
        let manager = PinnedTabsManager()
        let tab = Tab("https://duck.com")

        XCTAssertFalse(manager.isTabPinned(tab))
        manager.pin(tab)
        XCTAssertTrue(manager.isTabPinned(tab))
        XCTAssertTrue(manager.isDomainPinned("duck.com"))
        XCTAssertEqual(manager.pinnedDomains, ["duck.com"])
    }

    @MainActor
    func testWhenIndexIsSpecifiedThenTabIsPinnedAtThatIndex() {
        let tabA = Tab("https://a.com")
        let tabB = Tab("https://b.com")
        let tabC = Tab("https://c.com")

        let manager = PinnedTabsManager(tabCollection: .init(tabs: [tabA, tabB]))

        manager.pin(tabC, at: 1)
        XCTAssertEqual(manager.tabCollection.tabs, [tabA, tabC, tabB])
    }

    @MainActor
    func testThatPinnedTabCanBeUnpinned() {
        let tabA = Tab("https://a.com")
        let tabB = Tab("https://b.com")

        let manager = PinnedTabsManager(tabCollection: .init(tabs: [tabA, tabB]))

        let unpinnedTab = manager.unpinTab(at: 1)
        XCTAssertIdentical(unpinnedTab, tabB)
        XCTAssertFalse(manager.isTabPinned(tabB))
        XCTAssertFalse(manager.isDomainPinned("b.com"))
    }

    @MainActor
    func testWhenTabIsUnpinnedThenUnpinnedEventIsPublished() {
        let tabA = Tab("https://a.com")
        let tabB = Tab("https://b.com")

        let manager = PinnedTabsManager(tabCollection: .init(tabs: [tabA, tabB]))

        var events: [Int] = []
        let cancellable = manager.didUnpinTabPublisher
            .sink { index in
                events.append(index)
            }

        _ = manager.unpinTab(at: 1)

        cancellable.cancel()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[safe: 0], 1)
    }

    @MainActor
    func testWhenTabUnpinningFailsThenUnpinnedEventIsNotPublished() {
        let tabA = Tab("https://a.com")
        let tabB = Tab("https://b.com")

        let manager = PinnedTabsManager(tabCollection: .init(tabs: [tabA, tabB]))

        var events: [Int] = []
        let cancellable = manager.didUnpinTabPublisher
            .sink { index in
                events.append(index)
            }

        _ = manager.unpinTab(at: 100)

        cancellable.cancel()

        XCTAssertTrue(events.isEmpty)
    }

    @MainActor
    func testThatTabViewModelsAreCreatedForPinnedTabs() {
        let manager = PinnedTabsManager()
        let tab = Tab("https://duck.com")

        XCTAssertTrue(manager.tabViewModels.isEmpty)

        manager.pin(tab)

        XCTAssertNotNil(manager.tabViewModels[tab])
        XCTAssertNotNil(manager.tabViewModel(at: 0))
    }

    @MainActor
    func testWhenSetUpIsCalledThenPinnedTabsArePopulatedWithCollectionContents() {
        let manager = PinnedTabsManager()
        let tabA = Tab("https://a.com")
        let tabB = Tab("https://b.com")
        let tabC = Tab("https://c.com")
        let collection = TabCollection(tabs: [tabA, tabB, tabC])

        manager.setUp(with: collection)

        XCTAssertEqual(collection.tabs, manager.tabCollection.tabs)
    }
}

private extension Tab {
    @MainActor
    convenience init(_ urlString: String) {
        self.init(content: .url(urlString.url!, source: .link))
    }
}
