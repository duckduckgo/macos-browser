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

    @Published private(set) var isBurning = false

    init(cacheManager: WebCacheManager = .shared,
         historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared) {
        self.webCacheManager = cacheManager
        self.historyCoordinating = historyCoordinating
    }

    private func burnAll(completion: (() -> Void)? = nil) {
        os_log("WebsiteDataStore began cookie deletion", log: .fire)
        webCacheManager.clear { [/* hold self while burning */ self] in
            os_log("WebsiteDataStore completed cookie deletion", log: .fire)

            os_log("HistoryCoordinating began history deletion", log: .fire)
            self.historyCoordinating.burnHistory(except: FireproofDomains.shared)
            os_log("HistoryCoordinating completed history deletion", log: .fire)

            self.isBurning = false

            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    func burnAll(tabCollectionViewModel: TabCollectionViewModel?, completion: (() -> Void)? = nil) {
        isBurning = true
        
        tabCollectionViewModel?.tabCollection.tabs.forEach { $0.stopLoading() }
        burnAll {
            defer {
                completion?()
            }
            guard let tabCollectionViewModel = tabCollectionViewModel else { return }
            if tabCollectionViewModel.tabCollection.tabs.count > 0 {
                tabCollectionViewModel.removeAllTabsAndAppendNewTab()
            } else {
                tabCollectionViewModel.appendNewTab()
            }

            tabCollectionViewModel.tabCollection.cleanLastRemovedTab()
        }
    }

}
