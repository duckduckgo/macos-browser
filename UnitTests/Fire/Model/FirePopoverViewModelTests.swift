//
//  FirePopoverViewModelTests.swift
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

final class FirePopoverViewModelTests: XCTestCase {

    func testWhenThereIsOneTabWithNoHistoryThenClearingOptionsContainsCurrentTab() {
        let tab = Tab(content: .url("https://duck.com".url!))
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: .init(tabs: [tab]))

        let viewModel = makeViewModel(with: tabCollectionViewModel)

        XCTAssertEqual(viewModel.availableClearingOptions, [.currentTab, .allData])
    }

    func testWhenThereIsOneTabWithOneVisitedURLThenClearingOptionsContainsCurrentSite() {
        let extensionBuilder = TestTabExtensionsBuilder(load: [HistoryTabExtensionMock.self]) { builder in { _, _ in
            builder.override {
                HistoryTabExtensionMock()
            }
        }}

        let tabCollectionViewModel = TabCollectionViewModel()
        let tab = Tab(content: .url("https://duck.com".url!), extensionsBuilder: extensionBuilder)
        tabCollectionViewModel.removeAllTabs()
        tabCollectionViewModel.append(tab: tab)
        (tab.history as! HistoryTabExtensionMock).localHistory.insert("a.com")

        let viewModel = makeViewModel(with: tabCollectionViewModel)
        XCTAssertEqual(viewModel.availableClearingOptions, [.currentSite, .allData])
    }

    func testWhenThereIsOneTabWithMoreThanOneVisitedURLThenClearingOptionsContainsCurrentTab() {
        let extensionBuilder = TestTabExtensionsBuilder(load: [HistoryTabExtensionMock.self]) { builder in { _, _ in
            builder.override {
                HistoryTabExtensionMock()
            }
        }}

        let tabCollectionViewModel = TabCollectionViewModel()
        let tab = Tab(content: .url("https://duck.com".url!), extensionsBuilder: extensionBuilder)
        tabCollectionViewModel.removeAllTabs()
        tabCollectionViewModel.append(tab: tab)
        (tab.history as! HistoryTabExtensionMock).localHistory.insert("a.com")
        (tab.history as! HistoryTabExtensionMock).localHistory.insert("b.com")

        let viewModel = makeViewModel(with: tabCollectionViewModel)
        XCTAssertEqual(viewModel.availableClearingOptions, [.currentTab, .allData])
    }

    func testWhenThereIsMoreThanOneTabThenClearingOptionsContainsCurrentWindow() {
        let tabCollectionViewModel = TabCollectionViewModel()
        tabCollectionViewModel.removeAllTabs()
        tabCollectionViewModel.append(tab: .init(content: .url("https://duck.com".url!)))
        tabCollectionViewModel.append(tab: .init(content: .url("https://spreadprivacy.com".url!)))

        let viewModel = makeViewModel(with: tabCollectionViewModel)
        XCTAssertEqual(viewModel.availableClearingOptions, [.currentTab, .currentWindow, .allData])
    }

    private func makeViewModel(with tabCollectionViewModel: TabCollectionViewModel) -> FirePopoverViewModel {
        FirePopoverViewModel(
            fireViewModel: .init(),
            tabCollectionViewModel: tabCollectionViewModel,
            historyCoordinating: HistoryCoordinatingMock(),
            fireproofDomains: FireproofDomains(store: FireproofDomainsStoreMock()),
            faviconManagement: FaviconManagerMock()
        )
    }
}
