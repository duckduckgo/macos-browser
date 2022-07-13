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

import Foundation
import os.log
import BrowserServicesKit
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
    
    func prepareModelsForCleanup(_ models: [TabViewModel],
                                 completion: @escaping () -> Void) {
        guard !models.isEmpty else {
            completion()
            return
        }
        
        assert(self.completion == nil)
        self.completion = completion
        
        numberOfTabs = models.count
        models.forEach { $0.prepareForDataClearing(caller: self) }
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

    enum BurningData {
        case specificDomains(_ domains: Set<String>)
        case all
    }
    @Published private(set) var burningData: BurningData?

    init(cacheManager: WebCacheManager = WebCacheManager.shared,
         historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
         permissionManager: PermissionManagerProtocol = PermissionManager.shared,
         downloadListCoordinator: DownloadListCoordinator = DownloadListCoordinator.shared,
         windowControllerManager: WindowControllersManager = WindowControllersManager.shared,
         faviconManagement: FaviconManagement = FaviconManager.shared,
         autoconsentManagement: AutoconsentManagement? = nil,
         stateRestorationManager: AppStateRestorationManager? = nil,
         recentlyClosedCoordinator: RecentlyClosedCoordinating? = RecentlyClosedCoordinator.shared,
         pinnedTabsManager: PinnedTabsManager = WindowControllersManager.shared.pinnedTabsManager
    ) {
        self.webCacheManager = cacheManager
        self.historyCoordinating = historyCoordinating
        self.permissionManager = permissionManager
        self.downloadListCoordinator = downloadListCoordinator
        self.windowControllerManager = windowControllerManager
        self.faviconManagement = faviconManagement
        self.recentlyClosedCoordinator = recentlyClosedCoordinator
        self.pinnedTabsManager = pinnedTabsManager
        
        if #available(macOS 11, *), autoconsentManagement == nil {
            self.autoconsentManagement = AutoconsentUserScript.background
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

    func burnDomains(_ domains: Set<String>, completion: (() -> Void)? = nil) {
        os_log("Fire started", log: .fire)

        burnLastSessionState()

        burningData = .specificDomains(domains)

        // Add www prefixes
        let wwwDomains = Set(domains.map { domain -> String in
            if !domain.hasPrefix("www.") {
                return "www.\(domain)"
            }
            return domain
        })
        let burningDomains = domains.union(wwwDomains)
        let collectionsCleanupInfo = tabViewModelsFor(domains: burningDomains)
        
        // Prepare all Tabs that are going to be burned
        let modelsToRemove = collectionsCleanupInfo.values.flatMap { tabViewModelsCleanupInfo in
            tabViewModelsCleanupInfo.filter({ $0.action == .burn }).compactMap { $0.tabViewModel }
        }

        let pinnedTabsViewModels = pinnedTabViewModels()
        
        tabsCleaner.prepareModelsForCleanup(modelsToRemove) {

            let group = DispatchGroup()
            
            group.enter()
            self.burnTabsFrom(collectionViewModels: collectionsCleanupInfo,
                         relatedToDomains: burningDomains) {
                group.leave()
            }

            group.enter()
            self.burnPinnedTabs(pinnedTabsViewModels, relatedToDomains: domains) {
                group.leave()
            }

            group.enter()
            Task {
                await self.burnWebCache(domains: burningDomains)
                group.leave()
            }

            group.enter()
            self.burnHistory(of: burningDomains, completion: {
                self.burnPermissions(of: burningDomains, completion: {
                    self.burnFavicons(for: burningDomains) {
                        self.burnDownloads(of: burningDomains)
                        group.leave()
                    }
                })
            })

            self.burnRecentlyClosed(domains: burningDomains)
            self.burnAutoconsentCache()

            group.notify(queue: .main) {
                self.burningData = nil
                completion?()

                os_log("Fire finished", log: .fire)
            }
        }
    }

    func burnAll(tabCollectionViewModel: TabCollectionViewModel, completion: (() -> Void)? = nil) {
        os_log("Fire started", log: .fire)
        burningData = .all
        
        burnLastSessionState()

        let pinnedTabsViewModels = pinnedTabViewModels()

        tabsCleaner.prepareModelsForCleanup(allTabViewModels()) {
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
    
    // MARK: - Tab Models
    
    private func allTabViewModels() -> [TabViewModel] {
        var allTabViewModels = [TabViewModel] ()
        for window in windowControllerManager.mainWindowControllers {
            let tabCollectionViewModel = window.mainViewController.tabCollectionViewModel
            
            allTabViewModels.append(contentsOf: tabCollectionViewModel.tabViewModels.values)
        }
        return allTabViewModels
    }

    private func pinnedTabViewModels() -> [TabViewModel] {
        return Array(windowControllerManager.pinnedTabsManager.tabViewModels.values)
    }

    private func tabViewModelsFor(domains: Set<String>) -> TabCollectionsCleanupInfo {
        var collectionsCleanupInfo = TabCollectionsCleanupInfo()
        for window in windowControllerManager.mainWindowControllers {
            let tabCollectionViewModel = window.mainViewController.tabCollectionViewModel
            
            collectionsCleanupInfo[tabCollectionViewModel] = tabCollectionViewModel.prepareCleanupInfoForTabs(relatedToDomains: domains)
        }

        return collectionsCleanupInfo
    }

    // MARK: - Web cache

    private func burnWebCache() async {
        os_log("WebsiteDataStore began cookie deletion", log: .fire)
        await webCacheManager.clear()
        os_log("WebsiteDataStore completed cookie deletion", log: .fire)
    }

    private func burnWebCache(domains: Set<String>? = nil) async {
        os_log("WebsiteDataStore began cookie deletion", log: .fire)
        await webCacheManager.clear(domains: domains)
        os_log("WebsiteDataStore completed cookie deletion", log: .fire)
    }

    // MARK: - History

    private func burnHistory(completion: @escaping () -> Void) {
        self.historyCoordinating.burn(except: FireproofDomains.shared, completion: completion)
    }

    private func burnHistory(of domains: Set<String>, completion: @escaping () -> Void) {
        self.historyCoordinating.burnDomains(domains, completion: completion)
    }

    // MARK: - Permissions

    private func burnPermissions(completion: @escaping () -> Void) {
        self.permissionManager.burnPermissions(except: FireproofDomains.shared, completion: completion)
    }

    private func burnPermissions(of domains: Set<String>, completion: @escaping () -> Void) {
        self.permissionManager.burnPermissions(of: domains, completion: completion)
    }

    // MARK: - Downloads

    private func burnDownloads() {
        self.downloadListCoordinator.cleanupInactiveDownloads()
    }

    private func burnDownloads(of domains: Set<String>) {
        self.downloadListCoordinator.cleanupInactiveDownloads(for: domains)
    }

    // MARK: - Favicons

    private func burnFavicons(completion: @escaping () -> Void) {
        self.faviconManagement.burnExcept(fireproofDomains: FireproofDomains.shared,
                                          bookmarkManager: LocalBookmarkManager.shared,
                                          completion: completion)
    }

    private func burnFavicons(for domains: Set<String>, completion: @escaping () -> Void) {
        self.faviconManagement.burnDomains(domains,
                                           except: LocalBookmarkManager.shared,
                                           completion: completion)
    }

    // MARK: - Windows & Tabs

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

            completion()
        }
    }

    private func burnPinnedTabs(_ tabViewModels: [TabViewModel],
                                relatedToDomains domains: Set<String>? = nil,
                                completion: @escaping () -> Void) {
        // Close tabs where specified domains are currently loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            let keyWindow = self?.windowControllerManager.lastKeyMainWindowController
            keyWindow?.mainViewController.tabCollectionViewModel.clearPinnedTabsData(for: domains)

            completion()
        }
    }

    private func burnTabsFrom(collectionViewModels: TabCollectionsCleanupInfo,
                              relatedToDomains domains: Set<String>,
                              completion: @escaping () -> Void) {
        // Close tabs where specified domains are currently loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for (tabCollectionViewModel, tabsCleanupInfo) in collectionViewModels {
                tabCollectionViewModel.clearData(tabsCleanupInfo, forDomains: domains)
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

    private func burnLastSessionState() {
        stateRestorationManager?.clearLastSessionState()
    }

    // MARK: - Burn Recently Closed

    private func burnRecentlyClosed(domains: Set<String>? = nil) {
        recentlyClosedCoordinator?.burnCache(domains: domains)
    }

}

fileprivate extension TabCollectionViewModel {
    
    struct TabCleanupInfo {
        let tabViewModel: TabViewModel
        let action: Tab.FireAction
    }
    
    func prepareCleanupInfoForTabs(relatedToDomains domains: Set<String>) -> [TabCleanupInfo] {

        var result = [TabCleanupInfo]()

        for (tab, tabViewModel) in tabViewModels {
            let action = tab.fireAction(for: domains)
            switch action {
            case .none: continue
            case .replace, .burn:
                result.append(TabCleanupInfo(tabViewModel: tabViewModel,
                                             action: action))
            }
        }

        return result
    }

    // Burns data related to domains from the collection of tabs
    func clearData(_ cleanupInfo: [TabCleanupInfo], forDomains domains: Set<String>) {
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
                
                let tab = Tab(content: tabCleanupInfo.tabViewModel.tab.content, shouldLoadInBackground: true)
                replaceTab(at: .unpinned(tabIndex), with: tab, forceChange: true)
            case .burn:
                toRemove.insert(tabIndex)
            }
        }
        removeTabsAndAppendNew(at: toRemove, forceChange: true)

        // Clean local history of closed tabs
        tabCollection.localHistoryOfRemovedTabs.subtract(domains)
    }

    func clearPinnedTabsData(for domains: Set<String>? = nil) {
        // Go one by one and replace pinned tabs
        for (i, tab) in pinnedTabsManager.tabCollection.tabs.enumerated() {
            let tab = Tab(content: tab.content, shouldLoadInBackground: true)
            replaceTab(at: .pinned(i), with: tab, forceChange: true)
        }

        if let domains = domains {
            // Clean local history of closed tabs
            pinnedTabsManager.tabCollection.localHistoryOfRemovedTabs.subtract(domains)
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
    func fireAction(for domains: Set<String>) -> FireAction {
        // If currently visited website belongs to one of domains, burn
        if let host = content.url?.host, domains.contains(host) {
            return .burn
        }

        // If tab visited one of domains in past, replace (to clean internal data)
        if localHistory.contains(where: { visitedDomain in
            domains.contains(visitedDomain)
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
            if let host = historyEntry.url.host {
                return result.union([host.dropWWW()])
            } else {
                return result
            }
        })
    }

}
