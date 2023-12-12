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
import SecureStorage

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
    let syncDataProviders: SyncDataProviders?
    let tabCleanupPreparer = TabCleanupPreparer()
    let secureVaultFactory: AutofillVaultFactory
    let tld: TLD

    private var dispatchGroup: DispatchGroup?

    enum BurningData: Equatable {
        case specificDomains(_ domains: Set<String>, shouldPlayFireAnimation: Bool)
        case all

        var shouldPlayFireAnimation: Bool {
            switch self {
            case .all, .specificDomains(_, shouldPlayFireAnimation: true):
                return true
            // We don't present the fire animation if user burns from the privacy feed
            case .specificDomains(_, shouldPlayFireAnimation: false):
                return false
            }
        }
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

        var shouldPlayFireAnimation: Bool {
            switch self {
            // We don't present the fire animation if user burns from the privacy feed
            case .none:
                return false
            case .tab, .window, .allWindows:
                return true
            }
        }
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
         syncDataProviders: SyncDataProviders? = nil,
         secureVaultFactory: AutofillVaultFactory = AutofillSecureVaultFactory
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
        self.syncService = syncService ?? NSApp.delegateTyped.syncService
        self.syncDataProviders = syncDataProviders ?? NSApp.delegateTyped.syncDataProviders
        self.secureVaultFactory = secureVaultFactory
        self.tld = tld
        self.autoconsentManagement = autoconsentManagement ?? AutoconsentManagement.shared
        if let stateRestorationManager = stateRestorationManager {
            self.stateRestorationManager = stateRestorationManager
        } else {
            self.stateRestorationManager = NSApp.delegateTyped.stateRestorationManager
        }
    }

    @MainActor
    func burnEntity(entity: BurningEntity,
                    includingHistory: Bool = true,
                    completion: (() -> Void)? = nil) {
        os_log("Fire started", log: .fire)

        let group = DispatchGroup()
        dispatchGroup = group

        let domains = domainsToBurn(from: entity)
        assert(domains.areAllETLDPlus1(tld: tld))

        burningData = .specificDomains(domains, shouldPlayFireAnimation: entity.shouldPlayFireAnimation)

        burnLastSessionState()
        burnDeletedBookmarks()

        let tabViewModels = tabViewModels(of: entity)

        tabCleanupPreparer.prepareTabsForCleanup(tabViewModels) {

            group.enter()
            self.burnTabs(burningEntity: entity) {
                Task {
                    await self.burnWebCache(baseDomains: domains)
                    if includingHistory {
                        self.burnHistory(ofEntity: entity) {
                            self.burnFavicons(for: domains) {
                                group.leave()
                            }
                        }
                    } else {
                        group.leave()
                    }
                }
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
    func burnAll(completion: (() -> Void)? = nil) {
        os_log("Fire started", log: .fire)

        let group = DispatchGroup()
        dispatchGroup = group

        burningData = .all

        let entity = BurningEntity.allWindows(mainWindowControllers: windowControllerManager.mainWindowControllers, selectedDomains: Set())

        burnLastSessionState()
        burnDeletedBookmarks()

        let windowControllers = windowControllerManager.mainWindowControllers

        let tabViewModels = tabViewModels(of: entity)

        tabCleanupPreparer.prepareTabsForCleanup(tabViewModels) {

            group.enter()
            self.burnTabs(burningEntity: .allWindows(mainWindowControllers: windowControllers, selectedDomains: Set())) {
                Task { @MainActor in
                    await self.burnWebCache()
                    self.burnHistory {
                        self.burnPermissions {
                            self.burnFavicons {
                                self.burnDownloads()
                                group.leave()
                            }
                        }
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
        // Convert to eTLD+1 domains
        domains = domains.convertedToETLDPlus1(tld: tld)

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

        func closeWindow(of tabCollectionViewModel: TabCollectionViewModel) {
            guard let windowController = windowControllerManager.windowController(for: tabCollectionViewModel) else {
                return
            }
            windowController.close()
        }

        switch entity {
        case .none:
            return
        case .tab(tabViewModel: _, selectedDomains: _, parentTabCollectionViewModel: let tabCollectionViewModel):
            if tabCollectionViewModel.tabs.count == 0 {
                closeWindow(of: tabCollectionViewModel)
            }
        case .window(tabCollectionViewModel: let tabCollectionViewModel, selectedDomains: _):
            closeWindow(of: tabCollectionViewModel)
        case .allWindows(mainWindowControllers: let mainWindowControllers, selectedDomains: _):
            mainWindowControllers.forEach {
                $0.close()
            }
        }

        // Open a new window in case there is none
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.windowControllerManager.mainWindowControllers.count == 0 {
                NSApp.delegateTyped.newWindow(self)
            }
        }
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

    private func burnHistory(completion: @escaping () -> Void) {
        historyCoordinating.burnAll(completion: completion)
    }

    @MainActor
    private func burnHistory(ofEntity entity: BurningEntity, completion: @escaping () -> Void) {
        let visits: [Visit]
        switch entity {
        case .none(selectedDomains: let domains):
            burnHistory(of: domains, completion: completion)
            return
        case .tab(tabViewModel: let tabViewModel, selectedDomains: _, parentTabCollectionViewModel: _):
            visits = tabViewModel.tab.localHistory
        case .window(tabCollectionViewModel: let tabCollectionViewModel, selectedDomains: _):
            visits = tabCollectionViewModel.localHistory
        case .allWindows:
            burnAllHistory(completion: completion)
            return
        }

        historyCoordinating.burnVisits(visits, completion: completion)
    }

    private func burnHistory(of baseDomains: Set<String>, completion: @escaping () -> Void) {
        historyCoordinating.burnDomains(baseDomains, tld: ContentBlocking.shared.tld, completion: completion)
    }

    private func burnAllHistory(completion: @escaping () -> Void) {
        historyCoordinating.burnAll(completion: completion)
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
        return Set(accounts.compactMap { $0.domain })
    }

    @MainActor
    private func burnFavicons(completion: @escaping () -> Void) {
        let autofillDomains = autofillDomains()
        self.faviconManagement.burnExcept(fireproofDomains: FireproofDomains.shared,
                                          bookmarkManager: LocalBookmarkManager.shared,
                                          savedLogins: autofillDomains,
                                          completion: completion)
    }

    @MainActor
    private func burnFavicons(for baseDomains: Set<String>, completion: @escaping () -> Void) {
        let autofillDomains = autofillDomains()
        self.faviconManagement.burnDomains(baseDomains,
                                           exceptBookmarks: LocalBookmarkManager.shared,
                                           exceptSavedLogins: autofillDomains,
                                           exceptExistingHistory: historyCoordinating.history ?? [],
                                           tld: tld,
                                           completion: completion)
    }

    // MARK: - Tabs

    @MainActor
    private func burnTabs(burningEntity: BurningEntity,
                          completion: @escaping () -> Void) {

        func replacementPinnedTab(from pinnedTab: Tab) -> Tab {
            return Tab(content: pinnedTab.content.loadedFromCache(), shouldLoadInBackground: true)
        }

        func burnPinnedTabs() {
            for (index, pinnedTab) in pinnedTabsManager.tabCollection.tabs.enumerated() {
                let newTab = replacementPinnedTab(from: pinnedTab)
                pinnedTabsManager.tabCollection.replaceTab(at: index, with: newTab)
            }
        }

        // Close tabs
        switch burningEntity {
        case .none: break
        case .tab(tabViewModel: let tabViewModel,
                  selectedDomains: _,
                  parentTabCollectionViewModel: let tabCollectionViewModel):
            assert(tabViewModel === tabCollectionViewModel.selectedTabViewModel)
            if pinnedTabsManager.isTabPinned(tabViewModel.tab) {
                let tab = replacementPinnedTab(from: tabViewModel.tab)
                if let index = tabCollectionViewModel.selectionIndex {
                    tabCollectionViewModel.replaceTab(at: index, with: tab, forceChange: true)
                }
            } else {
                tabCollectionViewModel.removeSelected(forceChange: true)
            }
        case .window(tabCollectionViewModel: let tabCollectionViewModel,
                     selectedDomains: _):
            tabCollectionViewModel.removeAllTabs(forceChange: true)
            burnPinnedTabs()

        case .allWindows(mainWindowControllers: let mainWindowControllers,
                         selectedDomains: _):
            mainWindowControllers.forEach {
                $0.mainViewController.tabCollectionViewModel.removeAllTabs(forceChange: true)
            }
            burnPinnedTabs()
        }

        completion()
    }

    private func domainsToBurn(from entity: BurningEntity) -> Set<String> {
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
            let pinnedTabViewModels = Array(pinnedTabsManager.tabViewModels.values)
            let tabViewModels = Array(tabCollectionViewModel.tabViewModels.values)
            return pinnedTabViewModels + tabViewModels
        case .allWindows:
            let pinnedTabViewModels = Array(pinnedTabsManager.tabViewModels.values)
            let tabViewModels = windowControllerManager.allTabViewModels
            return pinnedTabViewModels + tabViewModels
        }
    }

    // MARK: - Autoconsent visit cache

    private func burnAutoconsentCache() {
        self.autoconsentManagement?.clearCache()
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
            syncDataProviders?.bookmarksAdapter.databaseCleaner.cleanUpDatabaseNow()
        }
    }
}

extension TabCollection {

    // Local history of TabCollection instance including history of already closed tabs
    var localHistory: [Visit] {
        tabs.flatMap { $0.localHistory }
    }

    var localHistoryDomains: Set<String> {
        var domains = Set<String>()

        for tab in tabs {
            domains = domains.union(tab.localHistoryDomains)
        }
        return domains
    }

    var localHistoryDomainsOfRemovedTabs: Set<String> {
        var domains = Set<String>()
        for visit in localHistoryOfRemovedTabs {
            if let host = visit.historyEntry?.url.host {
                domains.insert(host)
            }
        }
        return domains
    }

}

extension Set where Element == String {

    func areAllETLDPlus1(tld: TLD) -> Bool {
        for domain in self {
            guard let eTLDPlus1Host = tld.eTLDplus1(domain) else {
                return false
            }
            if domain != eTLDPlus1Host {
                return false
            }
        }
        return true
    }

}
