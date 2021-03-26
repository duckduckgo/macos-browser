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

        waitForExpectations(timeout: 1, handler: nil)

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 1)
        XCTAssert(tabCollectionViewModel.tabCollection.tabs.first?.isHomepageShown ?? false)
    }

    func testWhenBurnAllThenAllWebsiteDataAreRemovedAndLastRemovedTabCacheIsNil() {
        let manager = WebCacheManagerMock()
        let fire = Fire(cacheManager: manager)
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel

        fire.burnAll(tabCollectionViewModel: tabCollectionViewModel)

        XCTAssert(manager.removeAllWebsiteDataCalled)
        XCTAssertNil(tabCollectionViewModel.tabCollection.lastRemovedTabCache)
    }

    func testWhenBurnAllThenBurningFlagToggles() {
        let fire = Fire()
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel

        let isBurningExpectation = expectation(description: "Burning")
        let finishedBurningExpectation = expectation(description: "Finished burning")

        var burningStarted = false
        fire.$isBurning.sink { isBurning in
            if isBurning {
                burningStarted = true
                isBurningExpectation.fulfill()
            } else {
                if burningStarted {
                    finishedBurningExpectation.fulfill()
                }
            }
        } .store(in: &cancellables)

        fire.burnAll(tabCollectionViewModel: tabCollectionViewModel)

        waitForExpectations(timeout: 1, handler: nil)
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
