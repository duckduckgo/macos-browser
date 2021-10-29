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

final class HTTPSUpgrade {

    typealias UpgradeCheckCompletion = (Bool) -> Void
    static let shared = HTTPSUpgrade()
    
    private let dataReloadLock = NSLock()
    private let store: HTTPSUpgradeStore
    private var bloomFilter: BloomFilterWrapper?
    
    private var userUnprotected: Set<String> = []
    
    init(store: HTTPSUpgradeStore = HTTPSUpgradePersistence()) {
        self.store = store
    }
    
    func reload() {
        let protectionStore = DomainsProtectionUserDefaultsStore()
        userUnprotected = protectionStore.unprotectedDomains
    }

    func isUpgradeable(url: URL, completion: @escaping UpgradeCheckCompletion,
                       config: PrivacyConfigurationManagment = PrivacyConfigurationManager.shared) {
        
        guard url.scheme == URL.NavigationalScheme.http.rawValue else {
            completion(false)
            return
        }
        
        guard let host = url.host else {
            completion(false)
            return
        }
        
        if store.shouldExcludeDomain(host) {
            completion(false)
            return
        }
        
        if config.isEnabled(featureKey: .https) {
            // Check exception lists before upgrading
            if config.tempUnprotectedDomains.contains(host) {
                completion(false)
                return
            }
            if userUnprotected.contains(host) {
                completion(false)
                return
            }
            if config.exceptionsList(forFeature: .https).contains(host) {
                completion(false)
                return
            }
        } else {
            completion(false)
            return
        }
        
        waitForAnyReloadsToComplete()
        let isUpgradable = isInUpgradeList(host: host)
        completion(isUpgradable)
           
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
