//
//  RecentlyClosedCoordinatorTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class RecentlyClosedCoordinatorTests: XCTestCase {

    let tab1 = RecentlyClosedTab("https://site1.com")
    let tab2 = RecentlyClosedTab("https://site2.com")
    let tab3 = RecentlyClosedTab("https://site2.com")
    let tab4 = RecentlyClosedTab("https://site3.com")

    func testWhenDomainsAreBurnedThenCachedTabsOpenToThemAreRemoved() throws {
        var cache: [RecentlyClosedCacheItem] = [
            tab1,
            tab2,
            RecentlyClosedWindow([
                tab3,
                tab4
            ])
        ]

        cache.burn(for: ["site1.com", "site3.com"], tld: ContentBlocking.shared.tld)

        XCTAssertEqual(cache.count, 2)
        let tab = try XCTUnwrap(cache[0] as? RecentlyClosedTab)
        XCTAssertEqual(tab.tabContent, .url("https://site2.com".url!, source: .link))

        let window = try XCTUnwrap(cache[1] as? RecentlyClosedWindow)
        XCTAssertEqual(window.tabs.count, 1)
        XCTAssertEqual(window.tabs[0].tabContent, .url("https://site2.com".url!, source: .link))
    }

    func testWhenDomainsAreBurnedThenInteractionDataIsDeleted() throws {
        var cache: [RecentlyClosedCacheItem] = [
            tab1,
            tab2,
            RecentlyClosedWindow([
                tab3,
                tab4
            ])
        ]

        cache.burn(for: ["unrelatedsite1.com", "unrelatedsite2.com"], tld: ContentBlocking.shared.tld)

        XCTAssertEqual(cache.count, 3)

        let tab1 = try XCTUnwrap(cache[0] as? RecentlyClosedTab)
        XCTAssertNil(tab1.interactionData)

        let tab2 = try XCTUnwrap(cache[1] as? RecentlyClosedTab)
        XCTAssertNil(tab2.interactionData)

        let window = try XCTUnwrap(cache[2] as? RecentlyClosedWindow)
        XCTAssertEqual(window.tabs.count, 2)
        XCTAssertNil(window.tabs[0].interactionData)
        XCTAssertNil(window.tabs[1].interactionData)
    }
}

private extension RecentlyClosedTab {
    convenience init(_ url: String) {
        self.init(tabContent: .url(url.url!, source: .link), favicon: nil, title: nil, interactionData: Data(), index: .unpinned(0))
    }
}

private extension RecentlyClosedWindow {
    convenience init(_ tabs: [RecentlyClosedTab]) {
        self.init(tabs: tabs, droppingPoint: nil, contentSize: nil)
    }
}

final class WindowControllersManagerMock: WindowControllersManagerProtocol {

    var mainWindowControllers: [DuckDuckGo_Privacy_Browser.MainWindowController] = []

    var pinnedTabsManager = PinnedTabsManager(tabCollection: .init())

    var didRegisterWindowController = PassthroughSubject<(MainWindowController), Never>()
    var didUnregisterWindowController = PassthroughSubject<(MainWindowController), Never>()

    func register(_ windowController: MainWindowController) {}
    func unregister(_ windowController: MainWindowController) {}

    var lastKeyMainWindowController: MainWindowController?

    struct ShowArgs: Equatable {
        let url: URL?, source: Tab.TabContent.URLSource, newTab: Bool
    }
    var showCalled: ShowArgs?
    func show(url: URL?, source: Tab.TabContent.URLSource, newTab: Bool) {
        showCalled = .init(url: url, source: source, newTab: newTab)
    }
    var showBookmarksTabCalled = false
    func showBookmarksTab() {
        showBookmarksTabCalled = true
    }

    struct OpenNewWindowArgs: Equatable {
        var contents: [TabContent]?
        var burnerMode: BurnerMode = .regular, droppingPoint: NSPoint?, contentSize: NSSize?, showWindow: Bool = true, popUp: Bool = false, lazyLoadTabs: Bool = false, isMiniaturized: Bool = false, isMaximized: Bool = false, isFullscreen: Bool = false
    }
    var openNewWindowCalled: OpenNewWindowArgs?
    @discardableResult
    func openNewWindow(with tabCollectionViewModel: DuckDuckGo_Privacy_Browser.TabCollectionViewModel?, burnerMode: DuckDuckGo_Privacy_Browser.BurnerMode, droppingPoint: NSPoint?, contentSize: NSSize?, showWindow: Bool, popUp: Bool, lazyLoadTabs: Bool, isMiniaturized: Bool, isMaximized: Bool, isFullscreen: Bool) -> DuckDuckGo_Privacy_Browser.MainWindow? {
        openNewWindowCalled = .init(contents: tabCollectionViewModel?.tabs.map(\.content), burnerMode: burnerMode, droppingPoint: droppingPoint, contentSize: contentSize, showWindow: showWindow, popUp: popUp, lazyLoadTabs: lazyLoadTabs, isMiniaturized: isMiniaturized, isMaximized: isMaximized, isFullscreen: isFullscreen)
        return nil
    }
    func showTab(with content: DuckDuckGo_Privacy_Browser.Tab.TabContent) { }
}
