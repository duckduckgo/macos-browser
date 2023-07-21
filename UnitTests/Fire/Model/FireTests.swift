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

@MainActor
final class FireTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()

    func testWhenBurnAll_ThenAllWindowsAreClosed() {
        let manager = WebCacheManagerMock()
        let historyCoordinator = HistoryCoordinatingMock()
        let permissionManager = PermissionManagerMock()
        let faviconManager = FaviconManagerMock()

        let fire = Fire(cacheManager: manager,
                        historyCoordinating: historyCoordinator,
                        permissionManager: permissionManager,
                        windowControllerManager: WindowControllersManager.shared,
                        faviconManagement: faviconManager,
                        tld: ContentBlocking.shared.tld)

        let tabCollectionViewModel = TabCollectionViewModel.makeTabCollectionViewModel()
        let window = WindowsManager.openNewWindow(with: tabCollectionViewModel, isBurner: false, lazyLoadTabs: true)

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 3)
        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.first?.content, .homePage)

        let burningExpectation = expectation(description: "Burning")

        fire.burnAll {
            XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 0)
            burningExpectation.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)
    }

    func testWhenBurnAll_ThenPinnedTabsArePersisted() {
        let manager = WebCacheManagerMock()
        let historyCoordinator = HistoryCoordinatingMock()
        let permissionManager = PermissionManagerMock()
        let faviconManager = FaviconManagerMock()

        let pinnedTabs: [Tab] = [
            .init(content: .url("https://duck.com/".url!)),
            .init(content: .url("https://spreadprivacy.com/".url!)),
            .init(content: .url("https://wikipedia.org/".url!))
        ]
        let pinnedTabsManager = PinnedTabsManager(tabCollection: .init(tabs: pinnedTabs))

        let fire = Fire(cacheManager: manager,
                        historyCoordinating: historyCoordinator,
                        permissionManager: permissionManager,
                        windowControllerManager: WindowControllersManager.shared,
                        faviconManagement: faviconManager,
                        pinnedTabsManager: pinnedTabsManager,
                        tld: ContentBlocking.shared.tld)
        let tabCollectionViewModel = TabCollectionViewModel.makeTabCollectionViewModel(with: pinnedTabsManager)
        let window = WindowsManager.openNewWindow(with: tabCollectionViewModel, isBurner: false, lazyLoadTabs: true)

        let burningExpectation = expectation(description: "Burning")
        fire.burnAll {
            burningExpectation.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 0)
        XCTAssertEqual(pinnedTabsManager.tabCollection.tabs.map(\.content.url), pinnedTabs.map(\.content.url))
    }

    func testWhenBurnAll_ThenAllWebsiteDataAreRemoved() {
        let manager = WebCacheManagerMock()
        let historyCoordinator = HistoryCoordinatingMock()
        let permissionManager = PermissionManagerMock()
        let faviconManager = FaviconManagerMock()
        let recentlyClosedCoordinator = RecentlyClosedCoordinatorMock()

        let fire = Fire(cacheManager: manager,
                        historyCoordinating: historyCoordinator,
                        permissionManager: permissionManager,
                        windowControllerManager: WindowControllersManager.shared,
                        faviconManagement: faviconManager,
                        recentlyClosedCoordinator: recentlyClosedCoordinator,
                        tld: ContentBlocking.shared.tld)
        let tabCollectionViewModel = TabCollectionViewModel.makeTabCollectionViewModel()
        let window = WindowsManager.openNewWindow(with: tabCollectionViewModel, isBurner: false, lazyLoadTabs: true)

        let finishedBurningExpectation = expectation(description: "Finished burning")
        fire.burnAll {
            finishedBurningExpectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        XCTAssert(manager.clearCalled)
        XCTAssert(historyCoordinator.burnAllCalled)
        XCTAssert(permissionManager.burnPermissionsCalled)
        XCTAssert(recentlyClosedCoordinator.burnCacheCalled)
    }

    func testWhenBurnAllThenBurningFlagToggles() {
        let manager = WebCacheManagerMock()
        let historyCoordinator = HistoryCoordinatingMock()
        let permissionManager = PermissionManagerMock()
        let faviconManager = FaviconManagerMock()

        let fire = Fire(cacheManager: manager,
                        historyCoordinating: historyCoordinator,
                        permissionManager: permissionManager,
                        faviconManagement: faviconManager,
                        tld: ContentBlocking.shared.tld)

        let tabCollectionViewModel = TabCollectionViewModel.makeTabCollectionViewModel()

        let isBurningExpectation = expectation(description: "Burning")
        let finishedBurningExpectation = expectation(description: "Finished burning")

        fire.$burningData.dropFirst().sink { burningData in
            if burningData != nil {
                isBurningExpectation.fulfill()
            } else {
                finishedBurningExpectation.fulfill()
            }
        } .store(in: &cancellables)

        fire.burnAll()

        waitForExpectations(timeout: 5, handler: nil)
    }

    func testWhenBurnAllIsCalledThenLastSessionStateIsCleared() {
        let fileName = "testStateFileForBurningAllData"
        let fileStore = preparePersistedState(withFileName: fileName)
        let service = StatePersistenceService(fileStore: fileStore, fileName: fileName)
        let appStateRestorationManager = AppStateRestorationManager(service: service, shouldRestorePreviousSession: false)
        appStateRestorationManager.applicationDidFinishLaunching()

        let fire = Fire(stateRestorationManager: appStateRestorationManager,
                        tld: ContentBlocking.shared.tld)

        XCTAssertTrue(appStateRestorationManager.canRestoreLastSessionState)
        fire.burnAll()
        XCTAssertFalse(appStateRestorationManager.canRestoreLastSessionState)
    }

    func testWhenBurnDomainsIsCalledThenLastSessionStateIsCleared() {
        let fileName = "testStateFileForBurningAllData"
        let fileStore = preparePersistedState(withFileName: fileName)
        let service = StatePersistenceService(fileStore: fileStore, fileName: fileName)
        let appStateRestorationManager = AppStateRestorationManager(service: service, shouldRestorePreviousSession: false)
        appStateRestorationManager.applicationDidFinishLaunching()

        let fire = Fire(stateRestorationManager: appStateRestorationManager,
                        tld: ContentBlocking.shared.tld)

        XCTAssertTrue(appStateRestorationManager.canRestoreLastSessionState)
        fire.burnEntity(entity: .none(selectedDomains: Set()))
        XCTAssertFalse(appStateRestorationManager.canRestoreLastSessionState)
    }

    func preparePersistedState(withFileName fileName: String) -> FileStore {
        let fileStore = FileStoreMock()
        let state = SavedStateMock()
        state.val1 = "String"
        state.val2 = 0x8badf00d

        let serviceToPersistStateFile = StatePersistenceService(fileStore: fileStore, fileName: fileName)
        serviceToPersistStateFile.persistState(using: state.encode(with:), sync: true)

        return fileStore
    }

}

fileprivate extension TabCollectionViewModel {

    @MainActor
    static func makeTabCollectionViewModel(with pinnedTabsManager: PinnedTabsManager? = nil) -> TabCollectionViewModel {

        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: .init(), pinnedTabsManager: pinnedTabsManager ?? WindowControllersManager.shared.pinnedTabsManager)
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        return tabCollectionViewModel
    }

}
