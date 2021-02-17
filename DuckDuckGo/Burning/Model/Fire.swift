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

class Fire {

    let webCacheManager: WebCacheManager

    @Published private(set) var isBurning = false

    init(cacheManager: WebCacheManager = .shared) {
        self.webCacheManager = cacheManager
    }

    func burnAll(tabCollectionViewModel: TabCollectionViewModel) {
        isBurning = true

        tabCollectionViewModel.tabCollection.tabs.forEach { $0.stopLoading() }

        if tabCollectionViewModel.tabCollection.tabs.count > 0 {
            tabCollectionViewModel.removeAllTabsAndAppendNewTab()
        } else {
            tabCollectionViewModel.appendNewTab()
        }

        os_log("Fire.swift beginning cookie deletion", log: Logging.fireButton, type: .debug)
        webCacheManager.clear { [weak self] in
            os_log("Fire.swift completed cookie deletion", log: Logging.fireButton, type: .debug)
            self?.isBurning = false
        }
    }
}
