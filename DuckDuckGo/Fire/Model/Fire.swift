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

final class Fire {

    let webCacheManager: WebCacheManager
    let historyCoordinating: HistoryCoordinating
    let permissionManager: PermissionManagerProtocol

    @Published private(set) var isBurning = false
    @Published private(set) var progress = 0.0

    init(cacheManager: WebCacheManager = .shared,
         historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
         permissionManager: PermissionManagerProtocol = PermissionManager.shared) {
        self.webCacheManager = cacheManager
        self.historyCoordinating = historyCoordinating
        self.permissionManager = permissionManager
    }

    func burnAll(tabCollectionViewModel: TabCollectionViewModel?, completion: (() -> Void)? = nil) {
        os_log("Fire started", log: .fire)

        isBurning = true
        let group = DispatchGroup()

        group.enter()
        burnWebCache {
            group.leave()
        }

        burnHistory()
        burnPermissions()

        group.enter()
        burnTabs(tabCollectionViewModel: tabCollectionViewModel) {
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            self?.isBurning = false

            os_log("Fire finished", log: .fire)
        }
    }

    private func burnWebCache(completion: @escaping () -> Void) {
        os_log("WebsiteDataStore began cookie deletion", log: .fire)
        webCacheManager.clear(progress: { progress in
            self.progress = progress
        }, completion: {
            os_log("WebsiteDataStore completed cookie deletion", log: .fire)

            DispatchQueue.main.async {
                completion()
            }
        })
    }

    private func burnHistory() {
        self.historyCoordinating.burnHistory(except: FireproofDomains.shared)
    }

    private func burnPermissions() {
        self.permissionManager.burnPermissions(except: FireproofDomains.shared)
    }

    private func burnTabs(tabCollectionViewModel: TabCollectionViewModel?, completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            os_log("WebsiteDataStore began tab deletion", log: .fire)
            if let tabCollectionViewModel = tabCollectionViewModel {
                if tabCollectionViewModel.tabCollection.tabs.count > 0 {
                    tabCollectionViewModel.removeAllTabsAndAppendNewTab(forceChange: true)
                } else {
                    tabCollectionViewModel.appendNewTab(forceChange: true)
                }
                tabCollectionViewModel.tabCollection.cleanLastRemovedTab()
            }

            os_log("WebsiteDataStore completed tab deletion", log: .fire)

            completion()
        }
    }

}
