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

final class Fire {

    let webCacheManager: WebCacheManager
    let historyCoordinating: HistoryCoordinating
    let permissionManager: PermissionManagerProtocol
    let downloadListCoordinator: DownloadListCoordinator
    let windowControllerManager: WindowControllersManager
    let faviconManagement: FaviconManagement
    let autoconsentManagement: AutoconsentManagement?

    @Published private(set) var isBurning = false

    init(cacheManager: WebCacheManager = WebCacheManager.shared,
         historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
         permissionManager: PermissionManagerProtocol = PermissionManager.shared,
         downloadListCoordinator: DownloadListCoordinator = DownloadListCoordinator.shared,
         windowControllerManager: WindowControllersManager = WindowControllersManager.shared,
         faviconManagement: FaviconManagement = FaviconManager.shared,
         autoconsentManagement: AutoconsentManagement? = nil) {
        self.webCacheManager = cacheManager
        self.historyCoordinating = historyCoordinating
        self.permissionManager = permissionManager
        self.downloadListCoordinator = downloadListCoordinator
        self.windowControllerManager = windowControllerManager
        self.faviconManagement = faviconManagement
        
        if #available(macOS 11, *), autoconsentManagement == nil {
            self.autoconsentManagement = AutoconsentUserScript.background
        } else {
            self.autoconsentManagement = autoconsentManagement
        }
    }

    func burnDomains(_ domains: Set<String>, completion: (() -> Void)? = nil) {
        os_log("Fire started", log: .fire)

        isBurning = true
        let group = DispatchGroup()

        // Add www prefixes
        let wwwDomains = Set(domains.map { domain -> String in
            if !domain.hasPrefix("www.") {
                return "www.\(domain)"
            }
            return domain
        })
        let burningDomains = domains.union(wwwDomains)

        group.enter()
        Task {
            await burnWebCache(domains: burningDomains)
            group.leave()
        }

        group.enter()
        burnHistory(of: burningDomains, completion: {
            self.burnPermissions(of: burningDomains, completion: {
                self.burnFavicons(for: burningDomains) {
                    self.burnDownloads(of: burningDomains)
                    group.leave()
                }
            })
        })

        group.enter()
        burnTabs(relatedTo: burningDomains, completion: {
            group.leave()
        })
        
        burnAutoconsentCache()

        group.notify(queue: .main) {
            self.isBurning = false
            completion?()

            os_log("Fire finished", log: .fire)
        }
    }

    func burnAll(tabCollectionViewModel: TabCollectionViewModel, completion: (() -> Void)? = nil) {
        os_log("Fire started", log: .fire)

        isBurning = true
        let group = DispatchGroup()

        group.enter()
        Task {
            await burnWebCache()
            group.leave()
        }

        group.enter()
        burnHistory {
            self.burnPermissions {
                self.burnFavicons {
                    self.burnDownloads()
                    group.leave()
                }
            }
        }

        group.enter()
        burnWindows(exceptOwnerOf: tabCollectionViewModel) {
            group.leave()
        }
        
        burnAutoconsentCache()

        group.notify(queue: .main) {
            self.isBurning = false
            completion?()

            os_log("Fire finished", log: .fire)
        }
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
            tabCollectionViewModel.tabCollection.cleanLastRemovedTab()

            completion()
        }
    }

    private func burnTabs(relatedTo domains: Set<String>, completion: @escaping () -> Void) {
        // Close tabs where specified domains are currently loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            let tabCollectionViewModels = self.windowControllerManager.mainWindowControllers.map { $0.mainViewController.tabCollectionViewModel }
            tabCollectionViewModels.forEach { tabCollectionViewModel in
                tabCollectionViewModel.burn(domains: domains)
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

}

fileprivate extension TabCollectionViewModel {

    // Burns data related to domains from the collection of tabs
    func burn(domains: Set<String>) {
        // Go one by one and execute the fire action
        var toRemove = IndexSet()
        for (index, tab) in tabCollection.tabs.enumerated() {
            switch tab.fireAction(for: domains) {
            case .none: continue
            case .replace:
                let tab = Tab(content: tab.content, shouldLoadInBackground: true)
                replaceTab(at: index, with: tab, forceChange: true)
            case .burn:
                toRemove.insert(index)
            }
        }
        removeTabsAndAppendNew(at: toRemove, forceChange: true)

        // Clean last removed tab if needed
        if let lastRemovedTabHost = tabCollection.lastRemovedTabCache?.url?.host,
           domains.contains(lastRemovedTabHost) {
            tabCollection.cleanLastRemovedTab()
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
        if visitedDomains.contains(where: { visitedDomain in
            domains.contains(visitedDomain)
        }) {
            return .replace
        }

        return .none
    }

}
