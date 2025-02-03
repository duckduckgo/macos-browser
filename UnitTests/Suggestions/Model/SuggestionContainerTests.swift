//
//  SuggestionContainerTests.swift
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

import Combine
import Suggestions
import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class SuggestionContainerTests: XCTestCase {

    func testWhenGetSuggestionsIsCalled_ThenContainerAsksAndHoldsSuggestionsFromLoader() {
        let suggestionLoadingMock = SuggestionLoadingMock()
        let historyCoordinatingMock = HistoryCoordinatingMock()
        let suggestionContainer = SuggestionContainer(openTabsProvider: { [] },
                                                      suggestionLoading: suggestionLoadingMock,
                                                      historyCoordinating: historyCoordinatingMock,
                                                      bookmarkManager: LocalBookmarkManager.shared,
                                                      burnerMode: .regular)

        let e = expectation(description: "Suggestions updated")
        let cancellable = suggestionContainer.$result.sink {
            if $0 != nil {
                e.fulfill()
            }
        }

        suggestionContainer.getSuggestions(for: "test")
        let result = SuggestionResult.aSuggestionResult
        suggestionLoadingMock.completion!(result, nil)

        XCTAssert(suggestionLoadingMock.getSuggestionsCalled)
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertEqual(suggestionContainer.result?.all, result.topHits + result.duckduckgoSuggestions + result.localSuggestions)
    }

    func testWhenStopGettingSuggestionsIsCalled_ThenNoSuggestionsArePublished() {
        let suggestionLoadingMock = SuggestionLoadingMock()
        let historyCoordinatingMock = HistoryCoordinatingMock()
        let suggestionContainer = SuggestionContainer(openTabsProvider: { [] },
                                                      suggestionLoading: suggestionLoadingMock,
                                                      historyCoordinating: historyCoordinatingMock,
                                                      bookmarkManager: LocalBookmarkManager.shared,
                                                      burnerMode: .regular)

        suggestionContainer.getSuggestions(for: "test")
        suggestionContainer.stopGettingSuggestions()
        suggestionLoadingMock.completion?(SuggestionResult.aSuggestionResult, nil)

        XCTAssert(suggestionLoadingMock.getSuggestionsCalled)
        XCTAssertNil(suggestionContainer.result)
    }

    func testSuggestionLoadingCacheClearing() {
        let suggestionLoadingMock = SuggestionLoadingMock()
        let historyCoordinatingMock = HistoryCoordinatingMock()
        let suggestionContainer = SuggestionContainer(openTabsProvider: { [] },
                                                      suggestionLoading: suggestionLoadingMock,
                                                      historyCoordinating: historyCoordinatingMock,
                                                      bookmarkManager: LocalBookmarkManager.shared,
                                                      burnerMode: .regular)

        XCTAssertNil(suggestionContainer.suggestionDataCache)
        let e = expectation(description: "Suggestions updated")
        suggestionContainer.suggestionLoading(suggestionLoadingMock, suggestionDataFromUrl: URL.testsServer, withParameters: [:]) { data, error in
            XCTAssertNotNil(suggestionContainer.suggestionDataCache)
            e.fulfill()

            // Test the cache is not cleared if useCachedData is true
            XCTAssertFalse(suggestionLoadingMock.getSuggestionsCalled)
            suggestionContainer.getSuggestions(for: "test", useCachedData: true)
            XCTAssertNotNil(suggestionContainer.suggestionDataCache)
            XCTAssert(suggestionLoadingMock.getSuggestionsCalled)

            suggestionLoadingMock.getSuggestionsCalled = false

            // Test the cache is cleared if useCachedData is false
            XCTAssertFalse(suggestionLoadingMock.getSuggestionsCalled)
            suggestionContainer.getSuggestions(for: "test", useCachedData: false)
            XCTAssertNil(suggestionContainer.suggestionDataCache)
            XCTAssert(suggestionLoadingMock.getSuggestionsCalled)
        }

        waitForExpectations(timeout: 1)
    }

    @MainActor
    func testStandardOpenTabProviderReturnsOpenTabsWithoutCurrentAndBurnerTabs() {
        let openTabs: [[OpenTab]] = [
            [
                OpenTab(title: "Example", url: URL(string: "https://example.com")!),
                OpenTab(title: "Selected Tab", url: URL(string: "https://another-example.com")!),
                OpenTab(title: "New Tab", url: URL.newtab),
                OpenTab(title: "Bookmarks", url: URL.bookmarks),
                OpenTab(title: "Settings", url: URL.settings),
                OpenTab(title: "Last Tab", url: URL(string: "https://last.com")!),
            ],
            [
                OpenTab(title: "Yet Another Example", url: URL(string: "https://yet-another-example.com")!),
                OpenTab(title: "Yet Another Example", url: URL(string: "https://yet-another-example.com")!), // duplicate
                OpenTab(title: "Duplicate to Selected Tab", url: URL(string: "https://another-example.com")!),
            ]
        ]
        let pinnedTabs = [
            OpenTab(title: "Pinned tab 1", url: URL(string: "https://pinned-example.com")!),
            OpenTab(title: "Pinned tab 2", url: URL(string: "https://pinned-example-2.com")!),
        ]
        let burnerTabs: [[OpenTab]] = [
            [
                OpenTab(title: "Burner example", url: URL(string: "https://burner-example.com")!),
                OpenTab(title: "Burner example 2", url: URL(string: "https://burner-example-1.com")!),
            ],
            [
                OpenTab(title: "Burner example 3", url: URL(string: "https://burner-example-2.com")!),
            ]
        ]

        let suggestionLoadingMock = SuggestionLoadingMock()

        let burnerMode = BurnerMode(isBurner: true)
        // Create tab collection view models for open and burner tabs
        let tabCollectionViewModels = openTabs.map {
            TabCollectionViewModel(tabCollection: tabCollection($0), burnerMode: .regular)
        } + burnerTabs.map {
            TabCollectionViewModel(tabCollection: tabCollection($0, burnerMode: burnerMode), burnerMode: burnerMode)
        }

        let windowControllersManagerMock = WindowControllersManagerMock(pinnedTabsManager: pinnedTabsManager(tabs: pinnedTabs),
                                                                        tabCollectionViewModels: tabCollectionViewModels)

        // Set the selected tab to the first open tab
        windowControllersManagerMock.selectedTab = tabCollectionViewModels.first!.tabCollection.tabs[1]

        // Create a suggestion container with the mock open tabs provider
        let suggestionContainer = SuggestionContainer(burnerMode: .regular,
                                                      windowControllersManager: windowControllersManagerMock)

        // Get the standard open tabs
        let openTabSuggestions = Set(suggestionContainer.openTabs(for: suggestionLoadingMock) as! [OpenTab])

        // Verify that the standard tab provider returns the expected open tabs
        let expectedOpenTabs = Set((openTabs.flatMap { $0 } + pinnedTabs).filter {
            $0.url != windowControllersManagerMock.selectedTab?.content.userEditableUrl
            && $0.title != "Duplicate Example"
            && $0.url != .newtab
        })
        XCTAssertEqual(openTabSuggestions, expectedOpenTabs)
    }

    @MainActor
    func testStandardBurnerTabProviderReturnsCurrentSessionBurnerTabs() {
        let openTabs: [[OpenTab]] = [
            [
                OpenTab(title: "Example", url: URL(string: "https://example.com")!),
                OpenTab(title: "Selected Tab", url: URL(string: "https://another-example.com")!),
            ],
            [
                OpenTab(title: "Yet Another Example", url: URL(string: "https://yet-another-example.com")!),
                OpenTab(title: "Duplicate Example", url: URL(string: "https://yet-another-example.com")!),
            ]
        ]

        let pinnedTabs = [
            OpenTab(title: "Pinned tab 1", url: URL(string: "https://pinned-example.com")!),
            OpenTab(title: "Pinned tab 2", url: URL(string: "https://pinned-example-2.com")!),
        ]

        let burnerTabs: [[OpenTab]] = [
            [
                OpenTab(title: "Burner example", url: URL(string: "https://burner-example.com")!),
                OpenTab(title: "Burner example 2", url: URL(string: "https://burner-example-1.com")!),
            ],
            [
                OpenTab(title: "Burner example 3", url: URL(string: "https://burner-example-2.com")!),
                OpenTab(title: "Burner example 4", url: URL(string: "https://burner-example-3.com")!),
                OpenTab(title: "Burner example 5", url: URL(string: "https://burner-example-4.com")!),
            ]
        ]

        let suggestionLoadingMock = SuggestionLoadingMock()
        let burnerModes = [
            BurnerMode(isBurner: true),
            BurnerMode(isBurner: true),
        ]

        // Create tab collection view models for open and burner tabs
        let tabCollectionViewModels = openTabs.map {
            TabCollectionViewModel(tabCollection: tabCollection($0), burnerMode: .regular)
        } + burnerTabs.enumerated().map { (index, tabs) in
            TabCollectionViewModel(tabCollection: tabCollection(tabs, burnerMode: burnerModes[index]), burnerMode: burnerModes[index])
        }

        let windowControllersManagerMock = WindowControllersManagerMock(pinnedTabsManager: pinnedTabsManager(tabs: pinnedTabs),
                                                                        tabCollectionViewModels: tabCollectionViewModels)

        // Set the selected tab to the first open tab
        windowControllersManagerMock.selectedTab = tabCollectionViewModels.last!.tabCollection.tabs.first!

        // Create a suggestion container with the mock open tabs provider in burner mode
        let suggestionContainer = SuggestionContainer(burnerMode: burnerModes[1],
                                                      windowControllersManager: windowControllersManagerMock)

        // Get the open tabs for the container with burner mode
        let openTabSuggestions = Set(suggestionContainer.openTabs(for: suggestionLoadingMock) as! [OpenTab])

        // Verify that only the burner tabs from the current burner session are returned
        let expectedBurnerTabs = Set(burnerTabs.flatMap { $0 })
        let filteredExpectedBurnerTabs = expectedBurnerTabs.filter { tab in
            // Ensure that we only include tabs from the current burner session
            ["Burner example 4", "Burner example 5"].contains(tab.title)
        }
        XCTAssertEqual(openTabSuggestions, filteredExpectedBurnerTabs)
    }
}

private extension SuggestionContainerTests {

    class WindowControllersManagerMock: WindowControllersManagerProtocol {
        var mainWindowControllers: [DuckDuckGo_Privacy_Browser.MainWindowController] = []

        var lastKeyMainWindowController: DuckDuckGo_Privacy_Browser.MainWindowController?

        var pinnedTabsManager: DuckDuckGo_Privacy_Browser.PinnedTabsManager

        var didRegisterWindowController = PassthroughSubject<(DuckDuckGo_Privacy_Browser.MainWindowController), Never>()

        var didUnregisterWindowController = PassthroughSubject<(DuckDuckGo_Privacy_Browser.MainWindowController), Never>()

        func register(_ windowController: DuckDuckGo_Privacy_Browser.MainWindowController) {
        }

        func unregister(_ windowController: DuckDuckGo_Privacy_Browser.MainWindowController) {
        }

        func show(url: URL?, source: DuckDuckGo_Privacy_Browser.Tab.TabContent.URLSource, newTab: Bool) {
        }

        func showBookmarksTab() {
        }

        func showTab(with content: DuckDuckGo_Privacy_Browser.Tab.TabContent) {
        }

        var selectedTab: Tab?
        var allTabCollectionViewModels: [TabCollectionViewModel] = []

        func openNewWindow(with tabCollectionViewModel: DuckDuckGo_Privacy_Browser.TabCollectionViewModel?, burnerMode: DuckDuckGo_Privacy_Browser.BurnerMode, droppingPoint: NSPoint?, contentSize: NSSize?, showWindow: Bool, popUp: Bool, lazyLoadTabs: Bool, isMiniaturized: Bool, isMaximized: Bool, isFullscreen: Bool) -> DuckDuckGo_Privacy_Browser.MainWindow? {
            nil
        }

        init(pinnedTabsManager: PinnedTabsManager, tabCollectionViewModels: [TabCollectionViewModel] = []) {
            self.pinnedTabsManager = pinnedTabsManager
            self.allTabCollectionViewModels = tabCollectionViewModels
        }
    }

    @MainActor
    private func tabCollection(_ openTabs: [OpenTab], burnerMode: BurnerMode = .regular) -> TabCollection {
        let tabs = openTabs.map {
            Tab(content: TabContent.contentFromURL($0.url, source: .link), title: $0.title, burnerMode: burnerMode)
        }
        return TabCollection(tabs: tabs)
    }

    @MainActor
    private func pinnedTabsManager(tabs: [OpenTab]) -> PinnedTabsManager {
        PinnedTabsManager(tabCollection: tabCollection(tabs))
    }

}
