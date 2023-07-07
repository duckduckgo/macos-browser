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

        cache.burn(for: ["site1.com", "site3.com"])

        XCTAssertEqual(cache.count, 2)
        let tab = try XCTUnwrap(cache[0] as? RecentlyClosedTab)
        XCTAssertEqual(tab.tabContent, .url("https://site2.com".url!))

        let window = try XCTUnwrap(cache[1] as? RecentlyClosedWindow)
        XCTAssertEqual(window.tabs.count, 1)
        XCTAssertEqual(window.tabs[0].tabContent, .url("https://site2.com".url!))
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

        cache.burn(for: ["unrelatedsite1.com", "unrelatedsite2.com"])

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
        self.init(tabContent: .url(url.url!), favicon: nil, title: nil, interactionData: Data(), index: .unpinned(0))
    }
}

private extension RecentlyClosedWindow {
    convenience init(_ tabs: [RecentlyClosedTab]) {
        self.init(tabs: tabs, droppingPoint: nil, contentSize: nil)
    }
}

@objc(WindowManagerMock)
private final class WindowManagerMock: NSObject, WindowManagerProtocol {

    var pinnedTabsManager = PinnedTabsManager(tabCollection: .init())

    var didRegisterWindowController = PassthroughSubject<(MainWindowController), Never>()
    var didUnregisterWindowController = PassthroughSubject<(MainWindowController), Never>()

    func register(_ windowController: MainWindowController) {}
    func unregister(_ windowController: MainWindowController) {}

    var windows: [NSWindow] = []

    var lastKeyMainWindowController: DuckDuckGo_Privacy_Browser.MainWindowController?

    var mainWindowControllers: [DuckDuckGo_Privacy_Browser.MainWindowController] = []

    var mainWindowControllersPublisher: AnyPublisher<[DuckDuckGo_Privacy_Browser.MainWindowController], Never> {
        fatalError()
    }

    var didChangeKeyWindowController: AnyPublisher<Void, Never> {
        fatalError()
    }

    func openPopUpWindow(with tab: DuckDuckGo_Privacy_Browser.Tab, isBurner: Bool, contentSize: NSSize?) {
        fatalError()
    }

    func beginSheetFromMainWindow(_ viewController: NSViewController) {
        fatalError()
    }

    func showTab(with content: DuckDuckGo_Privacy_Browser.Tab.TabContent) {
        fatalError()
    }

    func showBookmarksTab() {
        fatalError()
    }

    func open(bookmark: DuckDuckGo_Privacy_Browser.Bookmark) {
        fatalError()
    }

    var isInInitialState: Bool = false

    var isInInitialStatePublisher: AnyPublisher<Bool, Never> {
        Just(false).eraseToAnyPublisher()
    }

    func updateIsInInitialState() {
        fatalError()
    }

    func openNewWindow(isBurner: Bool, lazyLoadTabs: Bool) -> DuckDuckGo_Privacy_Browser.MainWindow? {
        fatalError()
    }

    func openNewWindow(with initialUrl: URL, isBurner: Bool, parentTab: DuckDuckGo_Privacy_Browser.Tab?) {
        fatalError()
    }

    func openNewWindow(with tab: DuckDuckGo_Privacy_Browser.Tab, isBurner: Bool, droppingPoint: NSPoint?, contentSize: NSSize?, showWindow: Bool, popUp: Bool) -> DuckDuckGo_Privacy_Browser.MainWindow? {
        fatalError()
    }

    func openNewWindow(with tabCollectionViewModel: DuckDuckGo_Privacy_Browser.TabCollectionViewModel?, isBurner: Bool, droppingPoint: NSPoint?, contentSize: NSSize?, showWindow: Bool, popUp: Bool, lazyLoadTabs: Bool) -> DuckDuckGo_Privacy_Browser.MainWindow? {
        fatalError()
    }

    func openNewWindow(with tabCollection: DuckDuckGo_Privacy_Browser.TabCollection, isBurner: Bool, droppingPoint: NSPoint?, contentSize: NSSize?, popUp: Bool) {
        fatalError()
    }

    func showPreferencesTab(withSelectedPane pane: DuckDuckGo_Privacy_Browser.PreferencePaneIdentifier?) {
        fatalError()
    }

    func show(url: URL?, newTab: Bool) {
        fatalError()
    }

    func closeWindows(except window: NSWindow?) {
        fatalError()
    }

    func showNetworkProtectionStatus(retry: Bool) async {
        fatalError()
    }

}
