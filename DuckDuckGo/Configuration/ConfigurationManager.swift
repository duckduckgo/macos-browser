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

final class ConfigurationManager {

    enum Error: Swift.Error {
        case timeout
        case bloomFilterSpecNotFound
        case bloomFilterBinaryNotFound
        case bloomFilterPersistenceFailed
        case bloomFilterExclusionsNotFound
        case bloomFilterExclusionsPersistenceFailed
    }

    struct Constants {
        static let downloadTimeoutSeconds = 60.0 * 5
#if DEBUG
        static let refreshPeriodSeconds = 60.0 * 2 // 2 minutes when in debug mode
#else
        static let refreshPeriodSeconds = 60.0 * 30 // 30 minutes
#endif
        static let retryDelaySeconds = 60.0 * 60 * 1 // 1 hour delay before checking again if something went wrong last time
        static let refreshCheckIntervalSeconds = 60.0 // Check if we need a refresh every minute
    }

    static let shared = ConfigurationManager()

    static let queue: DispatchQueue = DispatchQueue(label: "Configuration Manager")

    @UserDefaultsWrapper(key: .configLastUpdated, defaultValue: .distantPast)
    var lastUpdateTime: Date

    private var timerCancellable: AnyCancellable?
    private var refreshCancellable: AnyCancellable?
    private var lastRefreshCheckTime: Date = Date()

    private let configDownloader: ConfigurationDownloading

    /// Use the shared instance if subscribing to events.  Only use the constructor for testing.
    init(configDownloader: ConfigurationDownloading = DefaultConfigurationDownloader(deliveryQueue: ConfigurationManager.queue)) {
        self.configDownloader = configDownloader
    }

    func start() {
        os_log("Starting configuration refresh timer", log: .config, type: .debug)
        timerCancellable = Timer.publish(every: Constants.refreshCheckIntervalSeconds, on: .main, in: .default)
            .autoconnect()
            .receive(on: Self.queue)
            .sink(receiveValue: { _ in
                self.lastRefreshCheckTime = Date()
                self.refreshIfNeeded()
            })
        refreshNow()
    }

    func log() {
        os_log("last update %{public}s", log: .config, type: .default, String(describing: lastUpdateTime))
        os_log("last refresh check %{public}s", log: .config, type: .default, String(describing: lastRefreshCheckTime))
    }

    private func refreshNow() {

        refreshCancellable =

            Publishers.MergeMany(

                configDownloader.refreshDataThenUpdate(for: [
                    .trackerRadar,
                    .surrogates,
                    .privacyConfiguration
                ], self.updateTrackerBlockingDependencies),

                configDownloader.refreshDataThenUpdate(for: [
                    .bloomFilterBinary,
                    .bloomFilterSpec
                ], self.updateBloomFilter),

                configDownloader.refreshDataThenUpdate(for: [
                    .bloomFilterExcludedDomains
                ], self.updateBloomFilterExclusions)

            )
            .collect()
            .timeout(.seconds(Constants.downloadTimeoutSeconds), scheduler: Self.queue, options: nil, customError: { Error.timeout })
            .sink { [self] completion in

                if case .failure(let error) = completion {
                    os_log("Failed to complete configuration update %s", log: .config, type: .error, error.localizedDescription)
                    Pixel.fire(.debug(event: .configurationFetchError, error: error))

                    tryAgainSoon()
                } else {
                    tryAgainLater()
                }

                refreshCancellable = nil
                configDownloader.cancelAll()

                DefaultConfigurationStorage.shared.log()
                log()

            } receiveValue: { value in
                // no-op - if you want to do something more globally if any of the files were downloaded, this is the place
            }

    }

    public func refreshIfNeeded() {
        guard self.isReadyToRefresh(), refreshCancellable == nil else {
            os_log("Configuration refresh is not needed at this time", log: .config, type: .debug)
            return
        }
        refreshNow()
    }

    private func isReadyToRefresh() -> Bool {
        return Date().timeIntervalSince(lastUpdateTime) > Constants.refreshPeriodSeconds
    }

    private func tryAgainLater() {
        lastUpdateTime = Date()
    }

    private func tryAgainSoon() {
        // Set the last update time to in the past so it triggers again sooner
        lastUpdateTime = Date(timeIntervalSinceNow: Constants.refreshPeriodSeconds - Constants.retryDelaySeconds)
    }

    private func updateTrackerBlockingDependencies() throws {

        let tdsEtag = DefaultConfigurationStorage.shared.loadEtag(for: .trackerRadar)
        let tdsData = DefaultConfigurationStorage.shared.loadData(for: .trackerRadar)
        ContentBlocking.shared.trackerDataManager.reload(etag: tdsEtag, data: tdsData)

        let configEtag = DefaultConfigurationStorage.shared.loadEtag(for: .privacyConfiguration)
        let configData = DefaultConfigurationStorage.shared.loadData(for: .privacyConfiguration)
        _=ContentBlocking.shared.privacyConfigurationManager.reload(etag: configEtag, data: configData)

        _=ContentBlocking.shared.contentBlockingManager.scheduleCompilation()
    }

    private func updateBloomFilter() throws {

        let configStore = DefaultConfigurationStorage.shared
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

        let configStore = DefaultConfigurationStorage.shared
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
