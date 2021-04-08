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
        static let refreshPeriodSeconds = 60.0 * 60 * 12 // 12 hours
#endif
        static let retryDelaySeconds = 60.0 * 60 * 1 // 1 hour delay before checking again if something went wrong last time
        static let refreshCheckIntervalSeconds = 60.0 // Check if we need a refresh every minute
    }

    static let shared = ConfigurationManager()

    static let queue: DispatchQueue = DispatchQueue(label: "Configuration Manager")

    @UserDefaultsWrapper(key: .configLastUpdated, defaultValue: .distantPast)
    var lastUpdateTime: Date

    private var trackerBlockerDataUpdatedSubject = PassthroughSubject<Void, Never>()
    private var timerCancellable: AnyCancellable?
    private var refreshCancellable: AnyCancellable?
    private var lastRefreshCheckTime: Date = Date()

    private let scriptSource: ScriptSourceProviding
    private let configDownloader: ConfigurationDownloading

    /// Use the shared instance if subscribing to events.  Only use the constructor for testing.
    init(scriptSource: ScriptSourceProviding = DefaultScriptSourceProvider.shared,
         configDownloader: ConfigurationDownloading = DefaultConfigurationDownloader(deliveryQueue: ConfigurationManager.queue)) {

        self.scriptSource = scriptSource
        self.configDownloader = configDownloader

        os_log("Starting configuration refresh timer", log: .config, type: .debug)
        timerCancellable = Timer.publish(every: Constants.refreshCheckIntervalSeconds, on: .main, in: .default)
            .autoconnect()
            .receive(on: Self.queue)
            .sink(receiveValue: { _ in
                self.lastRefreshCheckTime = Date()
                self.refreshIfNeeded()
            })
    }

    public func trackerBlockerDataUpdatedPublisher() -> AnyPublisher<Void, Never> {
        return trackerBlockerDataUpdatedSubject.share().eraseToAnyPublisher()
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
                    .temporaryUnprotectedSites
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
                    Pixel.fire(.debug(event: .configurationFetchError, error: error, countedBy: .counter))

                    tryAgainSoon()
                } else {
                    tryAgainLater()
                }

                refreshCancellable = nil
                configDownloader.cancelAll()

                DefaultConfigurationStorage.shared.log()
                log()

            } receiveValue: { _ in
                // no-op - if you want to do something more globally if any of the files were downloaded, this is the place
            }

    }

    private func refreshIfNeeded() {
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

        TrackerRadarManager.shared.reload()
        scriptSource.reload()
        ContentBlockerRulesManager.shared.compileRules { _ in
            self.trackerBlockerDataUpdatedSubject.send(())
        }

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

        let httpsStore = HTTPSUpgradePersistence()
        guard httpsStore.persistBloomFilter(specification: spec, data: bloomFilterData) else {
            throw Error.bloomFilterPersistenceFailed
        }

        HTTPSUpgrade.shared.loadData()
    }

    private func updateBloomFilterExclusions() throws {

        let configStore = DefaultConfigurationStorage.shared
        guard let bloomFilterExclusions = configStore.loadData(for: .bloomFilterExcludedDomains) else {
            throw Error.bloomFilterExclusionsNotFound
        }

        let excludedDomains = try JSONDecoder().decode(HTTPSExcludedDomains.self, from: bloomFilterExclusions).data

        let httpsStore = HTTPSUpgradePersistence()
        guard httpsStore.persistExcludedDomains(excludedDomains) else {
            throw Error.bloomFilterExclusionsPersistenceFailed
        }

        HTTPSUpgrade.shared.loadData()
    }

}
