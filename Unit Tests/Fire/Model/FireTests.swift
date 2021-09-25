//
//  FireTests.swift
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

import Foundation

import XCTest
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class FireTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()

    func testWhenBurnAllThenTabsAreClosedAndNewEmptyTabIsOpen() {
        let fire = Fire()
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel

        let burningExpectation = expectation(description: "Burning")
        fire.burnAll(tabCollectionViewModel: tabCollectionViewModel) {
            burningExpectation.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 1)
        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.first?.content, .homepage)
    }

    func testWhenBurnAll_ThenAllWebsiteDataAreRemovedAndHistoryIsCleanedAndLastRemovedTabCacheIsNil() {
        let manager = WebCacheManagerMock()
        let historyCoordinator = HistoryCoordinatingMock()
        let permissionManager = PermissionManagerMock()

        let fire = Fire(cacheManager: manager,
                        historyCoordinating: historyCoordinator,
                        permissionManager: permissionManager)
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel

        fire.burnAll(tabCollectionViewModel: tabCollectionViewModel)

        XCTAssert(manager.removeAllWebsiteDataCalled)
        XCTAssert(historyCoordinator.burnHistoryCalled)
        XCTAssert(permissionManager.burnPermissionsCalled)
        XCTAssertNil(tabCollectionViewModel.tabCollection.lastRemovedTabCache)
    }

    func testWhenBurnAllThenBurningFlagToggles() {
        let fire = Fire()
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel

        let isBurningExpectation = expectation(description: "Burning")
        let finishedBurningExpectation = expectation(description: "Finished burning")

        fire.$isBurning.dropFirst().sink { isBurning in
            if isBurning {
                isBurningExpectation.fulfill()
            } else {
                finishedBurningExpectation.fulfill()
            }
        } .store(in: &cancellables)

        fire.burnAll(tabCollectionViewModel: tabCollectionViewModel)

        waitForExpectations(timeout: 5, handler: nil)
    }

}

fileprivate extension TabCollectionViewModel {

    static var aTabCollectionViewModel: TabCollectionViewModel {
        let tabCollectionViewModel = TabCollectionViewModel()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        return tabCollectionViewModel
    }

}
