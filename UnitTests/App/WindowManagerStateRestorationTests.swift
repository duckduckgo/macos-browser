//
//  WindowManagerStateRestorationTests.swift
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

final class WindowManagerStateRestorationTests: XCTestCase {

    override func setUp() {
    }

    @MainActor
    override func tearDown() {
        WindowsManager.closeWindows()
    }

    func isTab(_ a: Tab, equalTo b: Tab) -> Bool {
        a.url == b.url
        && a.title == b.title
        && a.getActualInteractionStateData() == b.getActualInteractionStateData()
        && a.webView.configuration.websiteDataStore.isPersistent == b.webView.configuration.websiteDataStore.isPersistent
    }

    func areTabsEqual(_ a: [Tab], _ b: [Tab]) -> Bool {
        a.count == b.count &&
            !a.enumerated().contains { !isTab($0.1, equalTo: b[$0.0]) }
    }

    @MainActor
    func areTabCollectionViewModelsEqual(_ a: TabCollectionViewModel, _ b: TabCollectionViewModel) -> Bool {
        a.selectionIndex == b.selectionIndex && areTabsEqual(a.tabCollection.tabs, b.tabCollection.tabs)
    }

    // MARK: -

    @MainActor
    func testWindowManagerStateRestoration() throws {
        let tabs1 = [
            Tab(content: .url(.duckDuckGo, source: .link),
                title: "DDG",
                interactionStateData: "data".data(using: .utf8)!,
                shouldLoadInBackground: false),
            Tab(),
            Tab(content: .url(URL(string: "https://duckduckgo.com/?q=search&t=osx&ia=web")!, source: .link),
                title: "DDG search",
                interactionStateData: "data 2".data(using: .utf8)!,
                shouldLoadInBackground: false)
        ]
        let tabs2 = [
            Tab(),
            Tab(),
            Tab(content: .url(URL(string: "https://duckduckgo.com/?q=another_search&t=osx&ia=web")!, source: .link),
                title: "DDG search",
                interactionStateData: "data 3".data(using: .utf8)!,
                shouldLoadInBackground: false)
        ]
        let pinnedTabs = [
            Tab(content: .url(URL(string: "https://duck.com")!, source: .link)),
            Tab(content: .url(URL(string: "https://wikipedia.org")!, source: .link)),
            Tab(content: .url(URL(string: "https://duckduckgo.com/?q=search_in_pinned_tab&t=osx&ia=web")!, source: .link),
                title: "DDG search",
                interactionStateData: "data 4".data(using: .utf8)!,
                shouldLoadInBackground: false)
        ]

        WindowControllersManager.shared.pinnedTabsManager.setUp(with: .init(tabs: pinnedTabs))
        let model1 = TabCollectionViewModel(tabCollection: TabCollection(tabs: tabs1), selectionIndex: 0)
        let model2 = TabCollectionViewModel(tabCollection: TabCollection(tabs: tabs2), selectionIndex: 2)
        WindowsManager.openNewWindow(with: model1)
        WindowsManager.openNewWindow(with: model2)
        WindowControllersManager.shared.lastKeyMainWindowController = WindowControllersManager.shared.mainWindowControllers[1]

        let state = WindowManagerStateRestoration(windowControllersManager: WindowControllersManager.shared)
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        state.encode(with: archiver)
        let data = archiver.encodedData

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        guard let restored = WindowManagerStateRestoration(coder: unarchiver) else {
            return XCTFail("Could not unarchive WindowManagerStateRestoration")
        }

        XCTAssertTrue(areTabsEqual(restored.pinnedTabs!.tabs, pinnedTabs))
        XCTAssertEqual(restored.windows.count, 2)
        XCTAssertEqual(restored.keyWindowIndex, 1)
        for (idx, window) in state.windows.enumerated() {
            XCTAssertTrue(areTabCollectionViewModelsEqual(window.model,
                                                          state.windows[idx].model))
            XCTAssertEqual(window.frame, state.windows[idx].frame)
            XCTAssertEqual(window.model.pinnedTabs, pinnedTabs)
        }
    }

}
