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
import PrivacyDashboard
import WebKit

protocol TabDataClearing {
    func prepareForDataClearing(caller: TabDataCleaner)
}

/**
 Initiates cleanup of WebKit related data from Tabs:
 - Detach listeners and observers.
 - Flush WebView data by navigating to empty page.

 Once done, remove Tab objects.
 */
final class TabDataCleaner: NSObject, WKNavigationDelegate {

    private var numberOfTabs = 0
    private var processedTabs = 0

    private var completion: (() -> Void)?

    @MainActor
    func prepareTabsForCleanup(_ tabs: [TabViewModel],
                               completion: @escaping () -> Void) {
        guard !tabs.isEmpty else {
            completion()
            return
        }

        assert(self.completion == nil)
        self.completion = completion

        numberOfTabs = tabs.count
        tabs.forEach { $0.prepareForDataClearing(caller: self) }
    }

    private func notifyIfDone() {
        if processedTabs >= numberOfTabs {
            completion?()
            completion = nil
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        processedTabs += 1

        notifyIfDone()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Pixel.fire(.debug(event: .blankNavigationOnBurnFailed, error: error))
        processedTabs += 1

        notifyIfDone()
    }
}

final class Fire {

    // Drop www prefixes to produce list of burning domains
    static func getBurningDomain(from url: URL) -> String? {
        return url.host?.droppingWwwPrefix()
    }

    private typealias TabCollectionsCleanupInfo = [TabCollectionViewModel: [TabCollectionViewModel.TabCleanupInfo]]

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
    let tabsCleaner = TabDataCleaner()
    let secureVaultFactory: SecureVaultFactory
    let tld: TLD

    enum BurningData: Equatable {
        case specificDomains(_ domains: Set<String>)
        case all
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
         secureVaultFactory: SecureVaultFactory = SecureVaultFactory.default,
         tld: TLD
    ) {
        self.webCacheManager = cacheManager
        self.historyCoordinating = historyCoordinating
        self.permissionManager = permissionManager
        self.downloadListCoordinator = downloadListCoordinator
        self.windowControllerManager = windowControllerManager
        self.faviconManagement = faviconManagement
        self.recentlyClosedCoordinator = recentlyClosedCoordinator
        self.pinnedTabsManager = pinnedTabsManager ?? WindowControllersManager.shared.pinnedTabsManager
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
    // swiftlint:disable:next function_body_length
    func burnDomains(_ baseDomains: Set<String>,
                     includingHistory: Bool = true,
                     completion: (() -> Void)? = nil) {
        os_log("Fire started", log: .fire)

        burnLastSessionState()

        burningData = .specificDomains(baseDomains)

        let collectionsCleanupInfo = tabViewModelsFor(baseDomains: baseDomains)

        // Prepare all Tabs that are going to be burned
        let tabsToRemove = collectionsCleanupInfo.values.flatMap { tabViewModelsCleanupInfo in
            tabViewModelsCleanupInfo.filter({ $0.action == .burn }).compactMap { $0.tabViewModel }
        }

        let pinnedTabsViewModels = pinnedTabViewModels(for: baseDomains)

        tabsCleaner.prepareTabsForCleanup(tabsToRemove) {

            let group = DispatchGroup()

            group.enter()
            self.burnTabsFrom(collectionViewModels: collectionsCleanupInfo,
                              relatedTo: baseDomains) {
                group.leave()
            }

            group.enter()
            self.burnPinnedTabs(pinnedTabsViewModels, onlyRelatedToDomains: baseDomains) {
                group.leave()
            }

            group.enter()
            Task {
                await self.burnWebCache(baseDomains: baseDomains)
                group.leave()
            }

            if includingHistory {
                group.enter()
                self.burnHistory(of: baseDomains, completion: {
                    self.burnFavicons(for: baseDomains) {
                        group.leave()
                    }
                })
            }

            group.enter()
            self.burnPermissions(of: baseDomains, completion: {
                self.burnDownloads(of: baseDomains)
                group.leave()
            })

            self.burnRecentlyClosed(baseDomains: baseDomains)
            self.burnAutoconsentCache()

            group.notify(queue: .main) {
                self.burningData = nil
                completion?()

                os_log("Fire finished", log: .fire)
            }
        }
    }

    @MainActor
    func burnAll(tabCollectionViewModel: TabCollectionViewModel, completion: (() -> Void)? = nil) {
        os_log("Fire started", log: .fire)
        burningData = .all

        burnLastSessionState()

        let pinnedTabsViewModels = pinnedTabViewModels()

        tabsCleaner.prepareTabsForCleanup(allTabViewModels()) {
            let group = DispatchGroup()
            group.enter()
            Task {
                await self.burnWebCache()
                group.leave()
            }

            group.enter()
            self.burnPinnedTabs(pinnedTabsViewModels) {
                group.leave()
            }

            group.enter()
            self.burnHistory {
                self.burnPermissions {
                    self.burnFavicons {
                        self.burnDownloads()
                        group.leave()
                    }
                }
            }

            group.enter()
            self.burnWindows(exceptOwnerOf: tabCollectionViewModel) {
                group.leave()
            }

            self.burnRecentlyClosed()
            self.burnAutoconsentCache()

            group.notify(queue: .main) {
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

            if let domain = Fire.getBurningDomain(from: historyEntry.url),
               !fireproofDomains.isFireproof(fireproofDomain: domain) {
                domains.insert(domain)
            }
        }

        historyCoordinating.burnVisits(visits) {
            self.burnDomains(domains, includingHistory: false, completion: completion)
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

    private func burnHistory(completion: @escaping () -> Void) {
        self.historyCoordinating.burn(except: FireproofDomains.shared, completion: completion)
    }

    private func burnHistory(of baseDomains: Set<String>, completion: @escaping () -> Void) {
        self.historyCoordinating.burnDomains(baseDomains, tld: ContentBlocking.shared.tld, completion: completion)
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

    // MARK: - Windows & Tabs

    @MainActor
    private func burnWindows(exceptOwnerOf tabCollectionViewModel: TabCollectionViewModel, completion: @escaping () -> Void) {
        // Close windows except the burning one
        for mainWindowController in windowControllerManager.mainWindowControllers {
            guard mainWindowController.mainViewController.tabCollectionViewModel != tabCollectionViewModel else {
                continue
            }

            mainWindowController.close()
        }

        // Close all tabs of the burning window and open a new one
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if tabCollectionViewModel.tabCollection.tabs.count > 0 {
                tabCollectionViewModel.removeAllTabsAndAppendNew(forceChange: true)
            } else {
                tabCollectionViewModel.appendNewTab(forceChange: true)
            }
            tabCollectionViewModel.tabCollection.localHistoryOfRemovedTabs.removeAll()

            completion()
        }
    }

    private func burnPinnedTabs(_ cleanupInfo: [TabCollectionViewModel.TabCleanupInfo],
                                onlyRelatedToDomains domains: Set<String>? = nil,
                                completion: @escaping () -> Void) {
        // Close tabs where specified domains are currently loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            let keyWindow = self?.windowControllerManager.lastKeyMainWindowController
            keyWindow?.mainViewController.tabCollectionViewModel.burnPinnedTabs(cleanupInfo, onlyForDomains: domains)

            completion()
        }
    }

    private func burnTabsFrom(collectionViewModels: TabCollectionsCleanupInfo,
                              relatedTo baseDomains: Set<String>,
                              completion: @escaping () -> Void) {
        // Close tabs where specified domains are currently loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }

            for (tabCollectionViewModel, tabsCleanupInfo) in collectionViewModels {
                tabCollectionViewModel.burnTabCollection(tabsCleanupInfo, forDomains: baseDomains, tld: self.tld)
            }

            completion()
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
}

// MARK: - Tab Cleanup Info

extension Fire {

    @MainActor
    private func pinnedTabViewModels(for baseDomains: Set<String>? = nil) -> [TabCollectionViewModel.TabCleanupInfo] {
        guard let baseDomains = baseDomains else {
            return pinnedTabsManager.tabViewModels.values.map { tabViewModel in
                TabCollectionViewModel.TabCleanupInfo.init(tabViewModel: tabViewModel, action: .replace)
            }
        }

        return prepareCleanupInfo(for: pinnedTabsManager.tabViewModels, relatedToDomains: baseDomains)
    }

    @MainActor
    private func tabViewModelsFor(baseDomains: Set<String>) -> TabCollectionsCleanupInfo {
        var collectionsCleanupInfo = TabCollectionsCleanupInfo()
        for window in windowControllerManager.mainWindowControllers {
            let tabCollectionViewModel = window.mainViewController.tabCollectionViewModel

            collectionsCleanupInfo[tabCollectionViewModel] = prepareCleanupInfo(
                for: tabCollectionViewModel.tabViewModels,
                relatedToDomains: baseDomains
            )
        }

        return collectionsCleanupInfo
    }

    private func prepareCleanupInfo(
        for tabViewModels: [Tab: TabViewModel],
        relatedToDomains baseDomains: Set<String>
    ) -> [TabCollectionViewModel.TabCleanupInfo] {

        var result = [TabCollectionViewModel.TabCleanupInfo]()

        for (tab, tabViewModel) in tabViewModels {
            let action = tab.fireAction(for: baseDomains, tld: tld)
            switch action {
            case .none: continue
            case .replace, .burn:
                result.append(.init(tabViewModel: tabViewModel, action: action))
            }
        }

        return result
    }
}

fileprivate extension TabCollectionViewModel {

    struct TabCleanupInfo {
        let tabViewModel: TabViewModel
        let action: Tab.FireAction
    }

    // Burns data related to domains from the collection of tabs
    func burnTabCollection(_ cleanupInfo: [TabCleanupInfo], forDomains baseDomains: Set<String>, tld: TLD) {
        // Go one by one and execute the fire action
        var toRemove = IndexSet()
        for tabCleanupInfo in cleanupInfo {
            guard let tabIndex = tabCollection.tabs.firstIndex(of: tabCleanupInfo.tabViewModel.tab) else {
                assertionFailure("Tab index not found for given TabViewModel")
                continue
            }
            switch tabCleanupInfo.action {
            case .none: continue
            case .replace:
                let tab = Tab(content: tabCleanupInfo.tabViewModel.tab.content, shouldLoadInBackground: true, isBurner: false, shouldLoadFromCache: true)
                replaceTab(at: .unpinned(tabIndex), with: tab, forceChange: true)
            case .burn:
                toRemove.insert(tabIndex)
            }
        }
        removeTabsAndAppendNew(at: toRemove, forceChange: true)

        // Clean local history of closed tabs
        tabCollection.localHistoryOfRemovedTabs = tabCollection.localHistoryOfRemovedTabs.filter { localHistoryDomain in
            let localHistoryBaseDomain = tld.eTLDplus1(localHistoryDomain) ?? ""
            return !baseDomains.contains(localHistoryBaseDomain)
        }
    }

    // Burns data from the collection of pinned tabs, optionally limited to the set of domains
    func burnPinnedTabs(_ cleanupInfo: [TabCleanupInfo], onlyForDomains domains: Set<String>? = nil) {
        guard let pinnedTabsManager = pinnedTabsManager else {
            return
        }

        // Go one by one and replace pinned tabs
        for tabCleanupInfo in cleanupInfo {
            guard let tabIndex = pinnedTabsManager.tabCollection.tabs.firstIndex(of: tabCleanupInfo.tabViewModel.tab) else {
                assertionFailure("Tab index not found for a pinned TabViewModel")
                continue
            }
            switch tabCleanupInfo.action {
            case .none: continue
            case .replace, .burn:
                // Burning does not ever close pinned tabs, so treat burning as replacing
                let tab = Tab(content: tabCleanupInfo.tabViewModel.tab.content, shouldLoadInBackground: true, isBurner: false, shouldLoadFromCache: true)
                replaceTab(at: .pinned(tabIndex), with: tab, forceChange: true)
            }
        }

        // Clean local history of closed tabs
        if let domains = domains {
            pinnedTabsManager.tabCollection.localHistoryOfRemovedTabs.subtract(domains)
        } else {
            pinnedTabsManager.tabCollection.localHistoryOfRemovedTabs.removeAll()
        }
    }
}

fileprivate extension Tab {

    enum FireAction {
        case none

        // Replace with a new tab with the same content (internal data removed)
        case replace

        // Closes the tab
        case burn
    }

    // Burns data related to domains from the tab
    // Returns true if the tab should be closed because it remained empty after burning
    func fireAction(for baseDomains: Set<String>, tld: TLD) -> FireAction {
        guard let host = webView.url?.host, let baseDomain = tld.eTLDplus1(host) else {
            assertionFailure("Failed to get base domain")
            return .burn
        }

        // If currently visited website belongs to one of base domains, burn
        if baseDomains.contains(baseDomain) {
            return .burn
        }

        // If tab visited one of domains in past, replace (to clean internal data)
        if localHistory.contains(where: { visitedDomain in
            let visitedBaseDomain = tld.eTLDplus1(visitedDomain) ?? ""
            return baseDomains.contains(visitedBaseDomain)
        }) {
            return .replace
        }

        return .none
    }
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

extension History {

    var visitedDomains: Set<String> {
        return reduce(Set<String>(), { result, historyEntry in
            if let domain = Fire.getBurningDomain(from: historyEntry.url) {
                return result.union([domain])
            } else {
                return result
            }
        })
    }

}
