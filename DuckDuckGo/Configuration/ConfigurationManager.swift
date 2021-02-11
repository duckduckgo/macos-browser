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

class ConfigurationManager {

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
        static let refreshPeriodSeconds = 60.0 * 60 * 12
        static let retryDelaySeconds = 60.0 * 60
    }

    static let shared = ConfigurationManager()

    private let queue: DispatchQueue = DispatchQueue(label: "Configuration Manager")

    @UserDefaultsWrapper(key: .configLastUpdated, defaultValue: Date())
    var lastUpdateTime: Date

    private var cancellable: AnyCancellable?

    private init() { }

    func updateConfigIfReady() {
        guard self.isReadyToUpdate(), cancellable == nil else { return }

        let configDownloader: ConfigurationDownloader = DefaultConfigurationDownloader(deliveryQueue: self.queue)

        cancellable =

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
            .timeout(.seconds(Constants.downloadTimeoutSeconds), scheduler: self.queue, options: nil, customError: { Error.timeout })
            .sink { completion in

                print("*** sink receive completion")

                if case .failure(let error) = completion {
                    os_log("Failed to complete configuration update %s", type: .error, error.localizedDescription)
                    self.tryAgainSoon()
                } else {
                    self.tryAgainLater()
                }

                self.cancellable = nil
                configDownloader.cancelAll()

            } receiveValue: { _ in
                // no-op - if you want to do something more globally if any of the files were downloaded, this is the place
            }

    }
    private func isReadyToUpdate() -> Bool {
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
        print("***", #function)
        TrackerRadarManager.shared.reload()
        // TODO recompile the blocker rules
        // TODO tell the open tabs to reconfigure their webviews
    }

    private func updateBloomFilter() throws {
        print("***", #function)

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
        print("***", #function)

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
