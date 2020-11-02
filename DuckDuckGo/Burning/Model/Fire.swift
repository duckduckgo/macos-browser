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

    let websiteDataStore: WebsiteDataStore

    @Published private(set) var isBurning = false

    init(websiteDataStore: WebsiteDataStore) {
        self.websiteDataStore = websiteDataStore
    }

    func burnAll(tabCollectionViewModel: TabCollectionViewModel) {
        isBurning = true

        guard let tab = tabCollectionViewModel.tabCollection.tabs.first else {
            os_log("Fire: No tab available", type: .error)
            isBurning = false
            return
        }
        tab.openHomepage()

        tabCollectionViewModel.removeAllTabs(except: 0)

        websiteDataStore.removeAllWebsiteData { [weak self] in
            self?.isBurning = false
        }
    }
}
