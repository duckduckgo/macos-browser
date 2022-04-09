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

import Combine
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class FireTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()

    func testWhenBurnAllThenTabsAreClosedAndNewEmptyTabIsOpen() {
        let manager = WebCacheManagerMock()
        let historyCoordinator = HistoryCoordinatingMock()
        let permissionManager = PermissionManagerMock()
        let faviconManager = FaviconManagerMock()

        let fire = Fire(
            cacheManager: manager,
            historyCoordinating: historyCoordinator,
            permissionManager: permissionManager,
            faviconManagement: faviconManager)
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel

        let burningExpectation = expectation(description: "Burning")
        fire.burnAll(tabCollectionViewModel: tabCollectionViewModel) {
            burningExpectation.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 1)
        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.first?.content, .homePage)
    }

    func testWhenBurnAll_ThenAllWebsiteDataAreRemovedAndHistoryIsCleanedAndLastRemovedTabCacheIsNil() {
        let manager = WebCacheManagerMock()
        let historyCoordinator = HistoryCoordinatingMock()
        let permissionManager = PermissionManagerMock()
        let faviconManager = FaviconManagerMock()

        let fire = Fire(
            cacheManager: manager,
            historyCoordinating: historyCoordinator,
            permissionManager: permissionManager,
            faviconManagement: faviconManager)
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel

        let finishedBurningExpectation = expectation(description: "Finished burning")
        fire.burnAll(tabCollectionViewModel: tabCollectionViewModel) {
            finishedBurningExpectation.fulfill()
        }

        waitForExpectations(timeout: 1)
        XCTAssert(manager.clearCalled)
        XCTAssert(historyCoordinator.burnCalled)
        XCTAssert(permissionManager.burnPermissionsCalled)
        XCTAssertNil(tabCollectionViewModel.tabCollection.lastRemovedTabCache)
    }

    func testWhenBurnAllThenBurningFlagToggles() {
        let manager = WebCacheManagerMock()
        let historyCoordinator = HistoryCoordinatingMock()
        let permissionManager = PermissionManagerMock()
        let faviconManager = FaviconManagerMock()

        let fire = Fire(
            cacheManager: manager,
            historyCoordinating: historyCoordinator,
            permissionManager: permissionManager,
            faviconManagement: faviconManager)

        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel

        let isBurningExpectation = expectation(description: "Burning")
        let finishedBurningExpectation = expectation(description: "Finished burning")

        fire.$burningData.dropFirst().sink { burningData in
            if burningData != nil {
                isBurningExpectation.fulfill()
            } else {
                finishedBurningExpectation.fulfill()
            }
        } .store(in: &cancellables)

        fire.burnAll(tabCollectionViewModel: tabCollectionViewModel)

        waitForExpectations(timeout: 5, handler: nil)
    }

}

extension TabCollectionViewModel {

    fileprivate static var aTabCollectionViewModel: TabCollectionViewModel {
        let tabCollectionViewModel = TabCollectionViewModel()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        return tabCollectionViewModel
    }

}
