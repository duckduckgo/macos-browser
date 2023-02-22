//
//  HTTPSUpgrade.swift
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

final class HTTPSUpgrade {

    static let shared = HTTPSUpgrade()

    private let dataReloadLock = NSLock()
    private let store: HTTPSUpgradeStore
    private var bloomFilter: BloomFilterWrapper?

    init(store: HTTPSUpgradeStore = HTTPSUpgradePersistence()) {
        self.store = store
    }

    func isUpgradeable(url: URL, config: PrivacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig) -> Bool {

        guard url.scheme == URL.NavigationalScheme.http.rawValue else {
            return false
        }

        guard let host = url.host else {
            return false
        }

        if store.shouldExcludeDomain(host) {
            return false
        }

        guard config.isFeature(.httpsUpgrade, enabledForDomain: host) else {
            return false
        }

        waitForAnyReloadsToComplete()
        let isUpgradable = isInUpgradeList(host: host)

        return isUpgradable
    }

    private func isInUpgradeList(host: String) -> Bool {
        guard let bloomFilter = bloomFilter else { return false }
        return bloomFilter.contains(host)
    }

    private func waitForAnyReloadsToComplete() {
        // wait for lock (by locking and unlocking) before continuing
        dataReloadLock.lock()
        dataReloadLock.unlock()
    }

    func loadDataAsync() {
        DispatchQueue.global(qos: .background).async {
            self.loadData()
        }
    }

    func loadData() {
        if !dataReloadLock.try() {
            os_log("Reload already in progress", type: .debug)
            return
        }
        bloomFilter = store.bloomFilter()
        dataReloadLock.unlock()
    }
}
