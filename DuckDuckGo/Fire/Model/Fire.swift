//
//  Fire.swift
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

import Common
import Foundation
import BrowserServicesKit
import DDGSync
import PrivacyDashboard
import WebKit

final class Fire {

    let webCacheManager: WebCacheManager
    let historyCoordinating: HistoryCoordinating
    let permissionManager: PermissionManagerProtocol
    let downloadListCoordinator: DownloadListCoordinator
    let windowControllerManager: WindowControllersManager
    let faviconManagement: FaviconManagement
    let autoconsentManagement: AutoconsentManagement?
    let stateRestorationManager: AppStateRestorationManager?
    let recentlyClosedCoordinator: RecentlyClosedCoordinating?
    let pinnedTabsManager: PinnedTabsManager
    let bookmarkManager: BookmarkManager
    let syncService: DDGSyncing?
    let tabCleanupPreparer = TabCleanupPreparer()
    let secureVaultFactory: SecureVaultFactory
    let tld: TLD

    private var dispatchGroup: DispatchGroup?

    enum BurningData: Equatable {
        case specificDomains(_ domains: Set<String>)
        case all
    }

    enum BurningEntity {
        case none(selectedDomains: Set<String>)
        case tab(tabViewModel: TabViewModel,
                 selectedDomains: Set<String>,
                 parentTabCollectionViewModel: TabCollectionViewModel)
        case window(tabCollectionViewModel: TabCollectionViewModel,
                    selectedDomains: Set<String>)
        case allWindows(mainWindowControllers: [MainWindowController],
                        selectedDomains: Set<String>)
        //TODO! a special case for all data and all domains
    }

    @Published private(set) var burningData: BurningData?

    @MainActor
    init(cacheManager: WebCacheManager = WebCacheManager.shared,
         historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
         permissionManager: PermissionManagerProtocol = PermissionManager.shared,
         downloadListCoordinator: DownloadListCoordinator = DownloadListCoordinator.shared,
         windowControllerManager: WindowControllersManager = WindowControllersManager.shared,
         faviconManagement: FaviconManagement = FaviconManager.shared,
         autoconsentManagement: AutoconsentManagement? = nil,
         stateRestorationManager: AppStateRestorationManager? = nil,
         recentlyClosedCoordinator: RecentlyClosedCoordinating? = RecentlyClosedCoordinator.shared,
         pinnedTabsManager: PinnedTabsManager? = nil,
         tld: TLD,
         bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
         syncService: DDGSyncing? = nil,
         secureVaultFactory: SecureVaultFactory = SecureVaultFactory.default
    ) {
        self.webCacheManager = cacheManager
        self.historyCoordinating = historyCoordinating
        self.permissionManager = permissionManager
        self.downloadListCoordinator = downloadListCoordinator
        self.windowControllerManager = windowControllerManager
        self.faviconManagement = faviconManagement
        self.recentlyClosedCoordinator = recentlyClosedCoordinator
        self.pinnedTabsManager = pinnedTabsManager ?? WindowControllersManager.shared.pinnedTabsManager
        self.bookmarkManager = bookmarkManager
        self.syncService = syncService ?? (NSApp.delegate as? AppDelegate)?.syncService
        self.secureVaultFactory = secureVaultFactory
        self.tld = tld

        if #available(macOS 11, *), autoconsentManagement == nil {
            self.autoconsentManagement = AutoconsentManagement.shared
        } else {
            self.autoconsentManagement = autoconsentManagement
        }

        if let stateRestorationManager = stateRestorationManager {
            self.stateRestorationManager = stateRestorationManager
        } else if let appDelegate = NSApp.delegate as? AppDelegate {
            self.stateRestorationManager = appDelegate.stateRestorationManager
        } else {
            self.stateRestorationManager = nil
        }
    }

    @MainActor
    func burnEntity(entity: BurningEntity,
                    includingHistory: Bool = true,
                    completion: (() -> Void)? = nil) {
        os_log("Fire started", log: .fire)

        let group = DispatchGroup()
        dispatchGroup = group

        let domains = burningDomains(from: entity)
        burningData = .specificDomains(domains)

        burnLastSessionState()
        burnDeletedBookmarks()

        //TODO!
//        let pinnedTabsViewModels = pinnedTabViewModels(for: baseDomains)

        let tabViewModels = tabViewModels(of: entity)

        tabCleanupPreparer.prepareTabsForCleanup(tabViewModels) {

            group.enter()
            self.burnTabs(burningEntity: entity) {
                Task {
                    await self.burnWebCache(baseDomains: domains)
                    group.leave()
                }
            }

            //TODO!
//            group.enter()
//            self.burnPinnedTabs(pinnedTabsViewModels, onlyRelatedToDomains: baseDomains) {
//                group.leave()
//            }

            if includingHistory {
                group.enter()
                self.burnHistory(of: domains, completion: {
                    self.burnFavicons(for: domains) {
                        group.leave()
                    }
                })
            }

            group.enter()
            self.burnPermissions(of: domains, completion: {
                self.burnDownloads(of: domains)
                group.leave()
            })

            self.burnRecentlyClosed(baseDomains: domains)
            self.burnAutoconsentCache()

            group.notify(queue: .main) {
                self.dispatchGroup = nil
                self.closeWindows(entity: entity)

                self.burningData = nil

                completion?()

                os_log("Fire finished", log: .fire)
            }
        }
    }

    @MainActor
    func burnAll(eraseFullHistory: Bool, completion: (() -> Void)? = nil) {
        os_log("Fire started", log: .fire)

        let group = DispatchGroup()
        dispatchGroup = group

        burningData = .all

        //TODO! special entity
        let entity = BurningEntity.allWindows(mainWindowControllers: windowControllerManager.mainWindowControllers, selectedDomains: Set())

        burnLastSessionState()
        burnDeletedBookmarks()

        //TODO!
//        let pinnedTabsViewModels = pinnedTabViewModels()
        let windowControllers = windowControllerManager.mainWindowControllers

        tabCleanupPreparer.prepareTabsForCleanup(allTabViewModels()) {

            group.enter()
            self.burnTabs(burningEntity: .allWindows(mainWindowControllers: windowControllers, selectedDomains: Set())) {
                Task {
                    await self.burnWebCache()
                    group.leave()
                }
            }

            //TODO!
//            group.enter()
//            self.burnPinnedTabs(pinnedTabsViewModels) {
//                group.leave()
//            }

            group.enter()
            self.burnHistory(keepFireproofDomains: !eraseFullHistory) {
                self.burnPermissions {
                    self.burnFavicons {
                        self.burnDownloads()
                        group.leave()
                    }
                }
            }

            self.burnRecentlyClosed()
            self.burnAutoconsentCache()

            group.notify(queue: .main) {
                self.dispatchGroup = nil
                self.closeWindows(entity: entity)

                self.burningData = nil
                completion?()

                os_log("Fire finished", log: .fire)
            }
        }
    }

    // Burns visit passed to the method but preserves other visits of same domains
    @MainActor
    func burnVisits(of visits: [Visit],
                    except fireproofDomains: FireproofDomains,
                    completion: (() -> Void)? = nil) {

        // Get domains to burn
        var domains = Set<String>()
        visits.forEach { visit in
            guard let historyEntry = visit.historyEntry else {
                assertionFailure("No history entry")
                return
            }

            if let domain = historyEntry.url.host,
               !fireproofDomains.isFireproof(fireproofDomain: domain) {
                domains.insert(domain)
            }
        }

        historyCoordinating.burnVisits(visits) {
            self.burnEntity(entity: .none(selectedDomains: domains),
                            includingHistory: false,
                            completion: completion)
        }
    }

    // MARK: - Fire animation

    func fireAnimationDidStart() {
        assert(dispatchGroup != nil)

        dispatchGroup?.enter()
    }

    func fireAnimationDidFinish() {
        assert(dispatchGroup != nil)

        dispatchGroup?.leave()
    }

    // MARK: - Closing windows

    @MainActor
    private func closeWindows(entity: BurningEntity) {
        switch entity {
        case .none:
            return
        case .tab:
            return
        case .window(tabCollectionViewModel: let tabCollectionViewModel, selectedDomains: _):
            guard let windowController = windowControllerManager.mainWindowControllers.first(where: { tabCollectionViewModel === $0.mainViewController.tabCollectionViewModel}) else {
                return
            }
            windowController.close()
        case .allWindows(mainWindowControllers: let mainWindowControllers, selectedDomains: _):
            mainWindowControllers.forEach {
                $0.close()
            }
        }
    }

    // MARK: - Tabs

    @MainActor
    private func allTabViewModels() -> [TabViewModel] {
        var allTabViewModels = [TabViewModel] ()
        for window in windowControllerManager.mainWindowControllers {
            let tabCollectionViewModel = window.mainViewController.tabCollectionViewModel

            allTabViewModels.append(contentsOf: tabCollectionViewModel.tabViewModels.values)
        }
        return allTabViewModels
    }

    // MARK: - Web cache

    private func burnWebCache() async {
        os_log("WebsiteDataStore began cookie deletion", log: .fire)
        await webCacheManager.clear()
        os_log("WebsiteDataStore completed cookie deletion", log: .fire)
    }

    private func burnWebCache(baseDomains: Set<String>? = nil) async {
        os_log("WebsiteDataStore began cookie deletion", log: .fire)
        await webCacheManager.clear(baseDomains: baseDomains)
        os_log("WebsiteDataStore completed cookie deletion", log: .fire)
    }

    // MARK: - History

    private func burnHistory(keepFireproofDomains: Bool, completion: @escaping () -> Void) {
        if keepFireproofDomains {
            historyCoordinating.burn(except: FireproofDomains.shared, completion: completion)
        } else {
            historyCoordinating.burnAll(completion: completion)
        }
    }

    private func burnHistory(of baseDomains: Set<String>, completion: @escaping () -> Void) {
        historyCoordinating.burnDomains(baseDomains, tld: ContentBlocking.shared.tld, completion: completion)
    }

    // MARK: - Permissions

    private func burnPermissions(completion: @escaping () -> Void) {
        self.permissionManager.burnPermissions(except: FireproofDomains.shared, completion: completion)
    }

    private func burnPermissions(of baseDomains: Set<String>, completion: @escaping () -> Void) {
        self.permissionManager.burnPermissions(of: baseDomains, tld: tld, completion: completion)
    }

    // MARK: - Downloads

    @MainActor
    private func burnDownloads() {
        self.downloadListCoordinator.cleanupInactiveDownloads()
    }

    @MainActor
    private func burnDownloads(of baseDomains: Set<String>) {
        self.downloadListCoordinator.cleanupInactiveDownloads(for: baseDomains, tld: tld)
    }

    // MARK: - Favicons

    private func autofillDomains() -> Set<String> {
        guard let vault = try? secureVaultFactory.makeVault(errorReporter: SecureVaultErrorReporter.shared),
              let accounts = try? vault.accounts() else {
            return []
        }
        return Set(accounts.map { $0.domain })
    }

    private func burnFavicons(completion: @escaping () -> Void) {
        let autofillDomains = autofillDomains()
        self.faviconManagement.burnExcept(fireproofDomains: FireproofDomains.shared,
                                          bookmarkManager: LocalBookmarkManager.shared,
                                          savedLogins: autofillDomains,
                                          completion: completion)
    }

    private func burnFavicons(for baseDomains: Set<String>, completion: @escaping () -> Void) {
        let autofillDomains = autofillDomains()
        self.faviconManagement.burnDomains(baseDomains,
                                           exceptBookmarks: LocalBookmarkManager.shared,
                                           exceptSavedLogins: autofillDomains,
                                           tld: tld,
                                           completion: completion)
    }

    // MARK: - Tabs

    private func burnPinnedTabs(onlyRelatedToDomains domains: Set<String>? = nil,
                                completion: @escaping () -> Void) {
        //TODO!
//        // Close tabs where specified domains are currently loaded
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
//            let keyWindow = self?.windowControllerManager.lastKeyMainWindowController
//            keyWindow?.mainViewController.tabCollectionViewModel.burnPinnedTabs(cleanupInfo, onlyForDomains: domains)
//
//            completion()
//        }
    }

    @MainActor
    private func burnTabs(burningEntity: BurningEntity,
                          completion: @escaping () -> Void) {
        // Close tabs
        switch burningEntity {
        case .none: break
        case .tab(tabViewModel: let tabViewModel,
                  selectedDomains: _,
                  parentTabCollectionViewModel: let tabCollectionViewModel):
            assert(tabViewModel === tabCollectionViewModel.selectedTabViewModel)
            tabCollectionViewModel.removeSelected(forceChange: true)
        case .window(tabCollectionViewModel: let tabCollectionViewModel,
                     selectedDomains: _):
            tabCollectionViewModel.removeAllTabs(forceChange: true)
        case .allWindows(mainWindowControllers: let mainWindowControllers,
                         selectedDomains: _):
            mainWindowControllers.forEach {
                $0.mainViewController.tabCollectionViewModel.removeAllTabs(forceChange: true)
            }
        }

        completion()
    }

    private func burningDomains(from entity: BurningEntity) -> Set<String> {
        switch entity {
        case .none(let domains):
            return domains
        case .tab(tabViewModel: _, selectedDomains: let domains, parentTabCollectionViewModel: _):
            return domains
        case .window(tabCollectionViewModel: _, selectedDomains: let domains):
            return domains
        case .allWindows(mainWindowControllers: _, selectedDomains: let domains):
            return domains
        }
    }

    @MainActor
    private func tabViewModels(of entity: BurningEntity) -> [TabViewModel] {
        switch entity {
        case .none:
            return []
        case .tab(tabViewModel: let tabViewModel, selectedDomains: _, parentTabCollectionViewModel: _):
            return [tabViewModel]
        case .window(tabCollectionViewModel: let tabCollectionViewModel, selectedDomains: _):
            return Array(tabCollectionViewModel.tabViewModels.values)
        case .allWindows(mainWindowControllers: let mainWindowControllers, selectedDomains: _):
            var tabViewModels = [TabViewModel]()
            for window in mainWindowControllers {
                let tabCollectionViewModel = window.mainViewController.tabCollectionViewModel

                tabViewModels.append(contentsOf: tabCollectionViewModel.tabViewModels.values)
            }
            return tabViewModels
        }
    }

    // MARK: - Autoconsent visit cache

    private func burnAutoconsentCache() {
        if #available(macOS 11, *), self.autoconsentManagement != nil {
            self.autoconsentManagement!.clearCache()
        }
    }

    // MARK: - Last Session State

    @MainActor
    private func burnLastSessionState() {
        stateRestorationManager?.clearLastSessionState()
    }

    // MARK: - Burn Recently Closed

    @MainActor
    private func burnRecentlyClosed(baseDomains: Set<String>? = nil) {
        recentlyClosedCoordinator?.burnCache(baseDomains: baseDomains, tld: tld)
    }

    // MARK: - Bookmarks cleanup

    private func burnDeletedBookmarks() {
        if syncService?.authState == .inactive {
            LocalBookmarkManager.shared.cleanUpBookmarksDatabase()
        }
    }
}

// MARK: - Tab Cleanup Info

extension Fire {

    @MainActor
    private func pinnedTabViewModels(for baseDomains: Set<String>? = nil) -> [TabViewModel] {
        //TODO!
//        guard let baseDomains = baseDomains else {
//            return pinnedTabsManager.tabViewModels.values.map { tabViewModel in
//                TabCollectionViewModel.TabCleanupInfo.init(tabViewModel: tabViewModel, action: .replace)
//            }
//        }
//
//        return prepareCleanupInfo(for: pinnedTabsManager.tabViewModels, relatedToDomains: baseDomains)
        return []
    }

}

fileprivate extension TabCollectionViewModel {

//TODO! Clean local history of TabCollectionViewModel for closed tabs?

//    // Burns data related to domains from the collection of tabs
//    func burnTabCollection(_ cleanupInfo: [TabCleanupInfo], forDomains baseDomains: Set<String>, tld: TLD) {
//        removeTabsAndAppendNew(at: toRemove, forceChange: true)
//
//        // TODO! Clean local history of closed tabs
//        tabCollection.localHistoryOfRemovedTabs = tabCollection.localHistoryOfRemovedTabs.filter { localHistoryDomain in
//            let localHistoryBaseDomain = tld.eTLDplus1(localHistoryDomain) ?? ""
//            return !baseDomains.contains(localHistoryBaseDomain)
//        }
//    }

//    // Burns data from the collection of pinned tabs, optionally limited to the set of domains
//    func burnPinnedTabs(_ cleanupInfo: [TabCleanupInfo], onlyForDomains domains: Set<String>? = nil) {
//        guard let pinnedTabsManager = pinnedTabsManager else {
//            return
//        }
//
//        // Go one by one and replace pinned tabs
//        for tabCleanupInfo in cleanupInfo {
//            guard let tabIndex = pinnedTabsManager.tabCollection.tabs.firstIndex(of: tabCleanupInfo.tabViewModel.tab) else {
//                assertionFailure("Tab index not found for a pinned TabViewModel")
//                continue
//            }
//            switch tabCleanupInfo.action {
//            case .none: continue
//            case .replace, .burn:
//                // Burning does not ever close pinned tabs, so treat burning as replacing
//                let tab = Tab(content: tabCleanupInfo.tabViewModel.tab.content, shouldLoadInBackground: true, isBurner: false, shouldLoadFromCache: true)
//                replaceTab(at: .pinned(tabIndex), with: tab, forceChange: true)
//            }
//        }


    //TODO
//        // Clean local history of pinned tabs
//        if let domains = domains {
//            pinnedTabsManager.tabCollection.localHistoryOfRemovedTabs.subtract(domains)
//        } else {
//            pinnedTabsManager.tabCollection.localHistoryOfRemovedTabs.removeAll()
//        }
//    }
}

extension TabCollection {

    // Local history of TabCollection instance including history of already closed tabs
    var localHistory: Set<String> {
        let localHistoryOfCurrentTabs = tabs.reduce(Set<String>()) { result, tab in
            return result.union(tab.localHistory)
        }
        return localHistoryOfRemovedTabs.union(localHistoryOfCurrentTabs)
    }

}
