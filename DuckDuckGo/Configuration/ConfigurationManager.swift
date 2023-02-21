//
//  ConfigurationManager.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import Combine
import os
import BrowserServicesKit
import Configuration

final class ConfigurationManager {

    enum Error: Swift.Error {
        
        case timeout
        case bloomFilterSpecNotFound
        case bloomFilterBinaryNotFound
        case bloomFilterPersistenceFailed
        case bloomFilterExclusionsNotFound
        case bloomFilterExclusionsPersistenceFailed
        
    }

    enum Constants {
        
        static let downloadTimeoutSeconds = 60.0 * 5
#if DEBUG
        static let refreshPeriodSeconds = 60.0 * 2 // 2 minutes
#else
        static let refreshPeriodSeconds = 60.0 * 30 // 30 minutes
#endif
        static let retryDelaySeconds = 60.0 * 60 * 1 // 1 hour delay before checking again if something went wrong last time
        static let refreshCheckIntervalSeconds = 60.0 // check if we need a refresh every minute
        
    }

    static let shared = ConfigurationManager()

    static let queue: DispatchQueue = DispatchQueue(label: "Configuration Manager")

    @UserDefaultsWrapper(key: .configLastUpdated, defaultValue: .distantPast)
    var lastUpdateTime: Date

    private var timerCancellable: AnyCancellable?
    private var refreshCancellable: AnyCancellable?
    private var lastRefreshCheckTime: Date = Date()

    func start() {
        os_log("Starting configuration refresh timer", log: .config, type: .debug)
        timerCancellable = Timer.publish(every: Constants.refreshCheckIntervalSeconds, on: .main, in: .default)
            .autoconnect()
            .receive(on: Self.queue)
            .sink(receiveValue: { _ in
                self.lastRefreshCheckTime = Date()
                self.refreshIfNeeded()
            })
        Task {
            await refreshNow()
        }
    }

    func log() {
        os_log("last update %{public}s", log: .config, type: .default, String(describing: lastUpdateTime))
        os_log("last refresh check %{public}s", log: .config, type: .default, String(describing: lastRefreshCheckTime))
    }

    private func refreshNow() async {
        
        let fetcher = ConfigurationFetcher(store: ConfigurationStore.shared)
        do {
            try await fetcher.fetch([.trackerRadar, .surrogates, .privacyConfiguration]) {
                self.updateTrackerBlockingDependencies()
                self.tryAgainLater()
            }
        } catch {
            handleRefreshError(error)
        }
        
        do {
            try await fetcher.fetch([.bloomFilterBinary, .bloomFilterSpec]) {
                try self.updateBloomFilter()
                self.tryAgainLater()
            }
        } catch {
            handleRefreshError(error)
        }
        
        do {
            try await fetcher.fetch([.bloomFilterExcludedDomains]) {
                try self.updateBloomFilterExclusions()
                self.tryAgainLater()
            }
        } catch {
            handleRefreshError(error)
        }
        
        ConfigurationStore.shared.log()
        log()
        
    }
    
    private func handleRefreshError(_ error: Swift.Error) {
        os_log("Failed to complete configuration update %s", log: .config, type: .error, error.localizedDescription)
        Pixel.fire(.debug(event: .configurationFetchError, error: error))
        tryAgainSoon()
    }

    public func refreshIfNeeded() {
        guard isReadyToRefresh, refreshCancellable == nil else {
            os_log("Configuration refresh is not needed at this time", log: .config, type: .debug)
            return
        }
        Task {
            await refreshNow()
        }
    }

    private var isReadyToRefresh: Bool { Date().timeIntervalSince(lastUpdateTime) > Constants.refreshPeriodSeconds }

    private func tryAgainLater() {
        lastUpdateTime = Date()
    }

    private func tryAgainSoon() {
        // Set the last update time to in the past so it triggers again sooner
        lastUpdateTime = Date(timeIntervalSinceNow: Constants.refreshPeriodSeconds - Constants.retryDelaySeconds)
    }

    private func updateTrackerBlockingDependencies() {
        let tdsEtag = ConfigurationStore.shared.loadEtag(for: .trackerRadar)
        let tdsData = ConfigurationStore.shared.loadData(for: .trackerRadar)
        ContentBlocking.shared.trackerDataManager.reload(etag: tdsEtag, data: tdsData)

        let configEtag = ConfigurationStore.shared.loadEtag(for: .privacyConfiguration)
        let configData = ConfigurationStore.shared.loadData(for: .privacyConfiguration)
        _ = ContentBlocking.shared.privacyConfigurationManager.reload(etag: configEtag, data: configData)

        _ = ContentBlocking.shared.contentBlockingManager.scheduleCompilation()
    }

    private func updateBloomFilter() throws {
        let configStore = ConfigurationStore.shared
        guard let specData = configStore.loadData(for: .bloomFilterSpec) else {
            throw Error.bloomFilterSpecNotFound
        }

        guard let bloomFilterData = configStore.loadData(for: .bloomFilterBinary) else {
            throw Error.bloomFilterBinaryNotFound
        }

        let spec = try JSONDecoder().decode(HTTPSBloomFilterSpecification.self, from: specData)

        let httpsStore = AppHTTPSUpgradeStore()
        guard httpsStore.persistBloomFilter(specification: spec, data: bloomFilterData) else {
            throw Error.bloomFilterPersistenceFailed
        }

        PrivacyFeatures.httpsUpgrade.loadData()
    }

    private func updateBloomFilterExclusions() throws {
        let configStore = ConfigurationStore.shared
        guard let bloomFilterExclusions = configStore.loadData(for: .bloomFilterExcludedDomains) else {
            throw Error.bloomFilterExclusionsNotFound
        }

        let excludedDomains = try JSONDecoder().decode(HTTPSExcludedDomains.self, from: bloomFilterExclusions).data

        let httpsStore = AppHTTPSUpgradeStore()
        guard httpsStore.persistExcludedDomains(excludedDomains) else {
            throw Error.bloomFilterExclusionsPersistenceFailed
        }

        PrivacyFeatures.httpsUpgrade.loadData()
    }

}
