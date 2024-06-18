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

    override func tearDown() {
        WindowsManager.closeWindows()
        for controller in WindowControllersManager.shared.mainWindowControllers {
            WindowControllersManager.shared.unregister(controller)
        }
    }

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
        _ = WindowsManager.openNewWindow(with: tabCollectionViewModel, lazyLoadTabs: true)

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 3)
        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.first?.content, .newtab)

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
            .init(content: .url("https://duck.com/".url!, source: .link)),
            .init(content: .url("https://spreadprivacy.com/".url!, source: .link)),
            .init(content: .url("https://wikipedia.org/".url!, source: .link))
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
        _ = WindowsManager.openNewWindow(with: tabCollectionViewModel, lazyLoadTabs: true)

        let burningExpectation = expectation(description: "Burning")
        fire.burnAll {
            burningExpectation.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 0)
        XCTAssertEqual(pinnedTabsManager.tabCollection.tabs.map(\.content.userEditableUrl), pinnedTabs.map(\.content.userEditableUrl))
    }

    func testWhenBurnAll_ThenAllWebsiteDataAreRemoved() {
        let manager = WebCacheManagerMock()
        let historyCoordinator = HistoryCoordinatingMock()
        let zoomLevelsCoordinator = MockSavedZoomCoordinator()
        let permissionManager = PermissionManagerMock()
        let faviconManager = FaviconManagerMock()
        let recentlyClosedCoordinator = RecentlyClosedCoordinatorMock()

        let fire = Fire(cacheManager: manager,
                        historyCoordinating: historyCoordinator,
                        permissionManager: permissionManager,
                        savedZoomLevelsCoordinating: zoomLevelsCoordinator,
                        windowControllerManager: WindowControllersManager.shared,
                        faviconManagement: faviconManager,
                        recentlyClosedCoordinator: recentlyClosedCoordinator,
                        tld: ContentBlocking.shared.tld)
        let tabCollectionViewModel = TabCollectionViewModel.makeTabCollectionViewModel()
        _ = WindowsManager.openNewWindow(with: tabCollectionViewModel, lazyLoadTabs: true)

        let finishedBurningExpectation = expectation(description: "Finished burning")
        fire.burnAll {
            finishedBurningExpectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        XCTAssert(manager.clearCalled)
        XCTAssert(historyCoordinator.burnAllCalled)
        XCTAssert(permissionManager.burnPermissionsCalled)
        XCTAssert(recentlyClosedCoordinator.burnCacheCalled)
        XCTAssert(zoomLevelsCoordinator.burnAllZoomLevelsCalled)
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

        _ = TabCollectionViewModel.makeTabCollectionViewModel()

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
        let appStateRestorationManager = AppStateRestorationManager(fileStore: fileStore,
                                                                    service: service,
                                                                    shouldRestorePreviousSession: false)
        appStateRestorationManager.applicationDidFinishLaunching()

        let fire = Fire(historyCoordinating: HistoryCoordinatingMock(),
                        stateRestorationManager: appStateRestorationManager,
                        tld: ContentBlocking.shared.tld)

        XCTAssertTrue(appStateRestorationManager.canRestoreLastSessionState)
        fire.burnAll()
        XCTAssertFalse(appStateRestorationManager.canRestoreLastSessionState)
    }

    func testWhenBurnDomainsIsCalledThenLastSessionStateIsCleared() {
        let fileName = "testStateFileForBurningAllData"
        let fileStore = preparePersistedState(withFileName: fileName)
        let service = StatePersistenceService(fileStore: fileStore, fileName: fileName)
        let appStateRestorationManager = AppStateRestorationManager(fileStore: fileStore,
                                                                    service: service,
                                                                    shouldRestorePreviousSession: false)
        appStateRestorationManager.applicationDidFinishLaunching()

        let fire = Fire(historyCoordinating: HistoryCoordinatingMock(),
                        stateRestorationManager: appStateRestorationManager,
                        tld: ContentBlocking.shared.tld)

        XCTAssertTrue(appStateRestorationManager.canRestoreLastSessionState)
        fire.burnEntity(entity: .none(selectedDomains: Set()))
        XCTAssertFalse(appStateRestorationManager.canRestoreLastSessionState)
    }

    func testWhenBurnDomainsIsCalledThenSelectedDomainsZoomLevelsAreBurned() {
        let domainsToBurn: Set<String> = ["test.com", "provola.co.uk"]
        let zoomLevelsCoordinator = MockSavedZoomCoordinator()
        let fire = Fire(savedZoomLevelsCoordinating: zoomLevelsCoordinator,
                        tld: ContentBlocking.shared.tld)

        fire.burnEntity(entity: .none(selectedDomains: domainsToBurn))

        XCTAssertTrue(zoomLevelsCoordinator.burnZoomLevelsOfDomainsCalled)
        XCTAssertEqual(zoomLevelsCoordinator.domainsBurned, domainsToBurn)
    }

    func testWhenBurnVisitIsCalledForTodayThenAllExistingTabsAreCleared() {
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
        _ = WindowsManager.openNewWindow(with: tabCollectionViewModel, lazyLoadTabs: true)
        XCTAssertNotEqual(tabCollectionViewModel.allTabsCount, 0)

        let finishedBurningExpectation = expectation(description: "Finished burning")
        fire.burnVisits(of: [],
                        except: FireproofDomains.shared,
                        isToday: true,
                        completion: {
            finishedBurningExpectation.fulfill()
        })

        waitForExpectations(timeout: 5)
        XCTAssertEqual(tabCollectionViewModel.allTabsCount, 0)
        XCTAssert(manager.clearCalled)
        XCTAssert(historyCoordinator.burnVisitsCalled)
        XCTAssertFalse(historyCoordinator.burnAllCalled)
        XCTAssert(permissionManager.burnPermissionsOfDomainsCalled)
        XCTAssertFalse(permissionManager.burnPermissionsCalled)
        XCTAssert(recentlyClosedCoordinator.burnCacheCalled)
    }

    func testWhenBurnVisitIsCalledForOtherDayThenExistingTabsRemainOpen() {
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
        _ = WindowsManager.openNewWindow(with: tabCollectionViewModel, lazyLoadTabs: true)
        XCTAssertNotEqual(tabCollectionViewModel.allTabsCount, 0)
        let numberOfTabs = tabCollectionViewModel.allTabsCount

        let finishedBurningExpectation = expectation(description: "Finished burning")
        fire.burnVisits(of: [],
                        except: FireproofDomains.shared,
                        isToday: false,
                        completion: {
            finishedBurningExpectation.fulfill()
        })

        waitForExpectations(timeout: 5)
        XCTAssertEqual(tabCollectionViewModel.allTabsCount, numberOfTabs)
        XCTAssert(manager.clearCalled)
        XCTAssert(historyCoordinator.burnVisitsCalled)
        XCTAssertFalse(historyCoordinator.burnAllCalled)
        XCTAssert(permissionManager.burnPermissionsOfDomainsCalled)
        XCTAssertFalse(permissionManager.burnPermissionsCalled)
        XCTAssert(recentlyClosedCoordinator.burnCacheCalled)
    }

    // Burner window content sharing (screen capture) should be disabled
    func testWhenBurnerWindow_sharingTypeIsNone() {
        // collect sharing type passed at NSWindowController.setWindow in initWithWindow (sharingType should be set before initWithWindow: call)
        _=NSWindowController.swizzleSetWindowOnce

        let regularWindow = WindowsManager.openNewWindow(with: .empty, source: .ui, isBurner: false, parentTab: nil)!
        XCTAssertEqual(regularWindow.windowController?.windowSharingType?.rawValue, NSWindow.SharingType.readOnly.rawValue)
        XCTAssertEqual(regularWindow.sharingType, .readOnly)

        let window = WindowsManager.openNewWindow(with: .empty, source: .ui, isBurner: true, parentTab: nil)!
        XCTAssertEqual(window.windowController?.windowSharingType?.rawValue, NSWindow.SharingType.none.rawValue)
        XCTAssertEqual(window.sharingType, .none)

        if #available(macOS 14.0, *) {
            let window = WindowsManager.openNewWindow(burnerMode: .burner(websiteDataStore: WKWebsiteDataStore(forIdentifier: UUID())))!
            XCTAssertEqual(window.windowController?.windowSharingType?.rawValue, NSWindow.SharingType.none.rawValue)
            XCTAssertEqual(window.sharingType, .none)
        }

        let window3 = WindowsManager.openNewWindow(with: .init(), isBurner: true)!
        XCTAssertEqual(window3.windowController?.windowSharingType?.rawValue, NSWindow.SharingType.none.rawValue)
        XCTAssertEqual(window.sharingType, .none)
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
        tabCollectionViewModel.append(tab: Tab(content: .none))
        tabCollectionViewModel.append(tab: Tab(content: .none))
        return tabCollectionViewModel
    }

}

fileprivate extension NSWindowController {

    static var swizzleSetWindowOnce: Void = {
        let setWindowMethod = class_getInstanceMethod(NSWindowController.self, #selector(setter: NSWindowController.window))!
        let swizzledSetWindowMethod = class_getInstanceMethod(NSWindowController.self, #selector(NSWindowController.swizzled_setWindow))!

        method_exchangeImplementations(setWindowMethod, swizzledSetWindowMethod)
    }()

    private static let windowSharingTypeKey = UnsafeRawPointer(bitPattern: "windowSharingTypeKey".hashValue)!
    var windowSharingType: NSWindow.SharingType? {
        get {
            objc_getAssociatedObject(self, Self.windowSharingTypeKey) as? NSWindow.SharingType
        }
        set {
            objc_setAssociatedObject(self, Self.windowSharingTypeKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    @objc dynamic func swizzled_setWindow(_ window: NSWindow?) {
        self.windowSharingType = window?.sharingType
        self.swizzled_setWindow(window) // call original
    }

}

class MockSavedZoomCoordinator: SavedZoomLevelsCoordinating {
    var burnAllZoomLevelsCalled = false
    var burnZoomLevelsOfDomainsCalled = false
    var domainsBurned: Set<String> = []

    func burnZoomLevels(except fireproofDomains: DuckDuckGo_Privacy_Browser.FireproofDomains) {
        burnAllZoomLevelsCalled = true
    }

    func burnZoomLevel(of baseDomains: Set<String>) {
        burnZoomLevelsOfDomainsCalled = true
        domainsBurned = baseDomains
    }
}
