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

//    override func setUp() {
//        TestsDependencyProvider<Tab>.setUp {
//            $0.faviconManagement = FaviconManagerMock()
//            $0.useDefault(for: \.privatePlayer)
//            $0.useDefault(for: \.windowControllersManager)
//            $0.useDefault(for: \.historyCoordinating)
//            $0.extensionsBuilder = TestTabExtensionsBuilder()
//        }
//    }
//
//    override func tearDown() {
//        TestsDependencyProvider<Tab>.reset()
//    }

    func testWhenThereIsOneTabWithNoHistoryThenClearingOptionsContainsCurrentTab() {
        let tab = Tab(content: .url("https://duck.com".url!))
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: .init(tabs: [tab]))

        let viewModel = makeViewModel(with: tabCollectionViewModel)

        XCTAssertEqual(viewModel.availableClearingOptions, [.currentTab, .allData])
    }

    func testWhenThereIsOneTabWithOneVisitedURLThenClearingOptionsContainsCurrentSite() {
        let tabCollectionViewModel = TabCollectionViewModel()
        let tab = Tab(content: .url("https://duck.com".url!))
        tabCollectionViewModel.removeAllTabs()
        tabCollectionViewModel.append(tab: tab)
        tab.addVisit(of: "https://a.com".url!)

        let viewModel = makeViewModel(with: tabCollectionViewModel)
        XCTAssertEqual(viewModel.availableClearingOptions, [.currentSite, .allData])
    }

    func testWhenThereIsOneTabWithMoreThanOneVisitedURLThenClearingOptionsContainsCurrentTab() {
        let tabCollectionViewModel = TabCollectionViewModel()
        let tab = Tab(content: .url("https://duck.com".url!))
        tabCollectionViewModel.removeAllTabs()
        tabCollectionViewModel.append(tab: tab)
        tab.addVisit(of: "https://a.com".url!)
        tab.addVisit(of: "https://b.com".url!)

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
