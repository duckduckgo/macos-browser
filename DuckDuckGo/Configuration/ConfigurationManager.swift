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
import BrowserServicesKit
import Configuration
import Common
import Networking
import PixelKit

final class ConfigurationManager: DefaultConfigurationManager {

    static let shared = ConfigurationManager(fetcher: ConfigurationFetcher(store: ConfigurationStore.shared,
                                                                           log: .config,
                                                                           eventMapping: configurationDebugEvents))

    @UserDefaultsWrapper(key: .configLastUpdated, defaultValue: .distantPast)
    private(set) var lastUpdateTime: Date

    @UserDefaultsWrapper(key: .configLastInstalled, defaultValue: nil)
    private(set) var lastConfigurationInstallDate: Date?

    static let configurationDebugEvents = EventMapping<ConfigurationDebugEvents> { event, error, _, _ in
        let domainEvent: GeneralPixel
        switch event {
        case .invalidPayload(let configuration):
            domainEvent = .invalidPayload(configuration)
        }

        PixelKit.fire(DebugEvent(domainEvent, error: error))
    }

    func log() {
        os_log("last update %{public}s", log: .config, type: .default, String(describing: lastUpdateTime))
        os_log("last refresh check %{public}s", log: .config, type: .default, String(describing: lastRefreshCheckTime))
    }

    override public func refreshNow(isDebug: Bool = false) async {
        let updateTrackerBlockingDependenciesTask = Task {
            let didFetchAnyTrackerBlockingDependencies = await fetchTrackerBlockingDependencies(isDebug: isDebug)
            if didFetchAnyTrackerBlockingDependencies {
                updateTrackerBlockingDependencies()
                tryAgainLater()
            }
        }

        let updateBloomFilterTask = Task {
            do {
                try await fetcher.fetch(all: [.bloomFilterBinary, .bloomFilterSpec])
                try await updateBloomFilter()
                tryAgainLater()
            } catch {
                handleRefreshError(error)
            }
        }

        let updateBloomFilterExclusionsTask = Task {
            do {
                try await fetcher.fetch(.bloomFilterExcludedDomains)
                try await updateBloomFilterExclusions()
                tryAgainLater()
            } catch {
                handleRefreshError(error)
            }
        }

        await updateTrackerBlockingDependenciesTask.value
        await updateBloomFilterTask.value
        await updateBloomFilterExclusionsTask.value

        ConfigurationStore.shared.log()
        log()
    }

    private func fetchTrackerBlockingDependencies(isDebug: Bool) async -> Bool {
        var didFetchAnyTrackerBlockingDependencies = false

        var tasks = [Configuration: Task<(), Swift.Error>]()
        tasks[.trackerDataSet] = Task { try await fetcher.fetch(.trackerDataSet) }
        tasks[.surrogates] = Task { try await fetcher.fetch(.surrogates) }
        tasks[.privacyConfiguration] = Task { try await fetcher.fetch(.privacyConfiguration, isDebug: isDebug) }

        for (configuration, task) in tasks {
            do {
                try await task.value
                didFetchAnyTrackerBlockingDependencies = true
            } catch {
                os_log("Failed to complete configuration update to %@: %@",
                       log: .config,
                       type: .error,
                       configuration.rawValue,
                       error.localizedDescription)
                tryAgainSoon()
            }
        }

        return didFetchAnyTrackerBlockingDependencies
    }

    private func handleRefreshError(_ error: Swift.Error) {
        // Avoid firing a configuration fetch error pixel when we received a 304 status code.
        // A 304 status code is expected when we request the config with an ETag that matches the current remote version.
        if case APIRequest.Error.invalidStatusCode(304) = error {
            return
        }

        os_log("Failed to complete configuration update %@", log: .config, type: .error, error.localizedDescription)
        PixelKit.fire(DebugEvent(GeneralPixel.configurationFetchError(error: error)))
        tryAgainSoon()
    }

    private func updateTrackerBlockingDependencies() {
        lastConfigurationInstallDate = Date()
        ContentBlocking.shared.trackerDataManager.reload(etag: ConfigurationStore.shared.loadEtag(for: .trackerDataSet),
                                                         data: ConfigurationStore.shared.loadData(for: .trackerDataSet))
        ContentBlocking.shared.privacyConfigurationManager.reload(etag: ConfigurationStore.shared.loadEtag(for: .privacyConfiguration),
                                                                  data: ConfigurationStore.shared.loadData(for: .privacyConfiguration))
        ContentBlocking.shared.contentBlockingManager.scheduleCompilation()
    }

    private func updateBloomFilter() async throws {
        guard let specData = ConfigurationStore.shared.loadData(for: .bloomFilterSpec) else {
            throw Error.bloomFilterSpecNotFound
        }
        guard let bloomFilterData = ConfigurationStore.shared.loadData(for: .bloomFilterBinary) else {
            throw Error.bloomFilterBinaryNotFound
        }
        try await Task.detached {
            let spec = try JSONDecoder().decode(HTTPSBloomFilterSpecification.self, from: specData)
            do {
                try await PrivacyFeatures.httpsUpgrade.persistBloomFilter(specification: spec, data: bloomFilterData)
            } catch {
                assertionFailure("persistBloomFilter failed: \(error)")
                throw Error.bloomFilterPersistenceFailed.withUnderlyingError(error)
            }
            await PrivacyFeatures.httpsUpgrade.loadData()
        }.value
    }

    private func updateBloomFilterExclusions() async throws {
        guard let bloomFilterExclusions = ConfigurationStore.shared.loadData(for: .bloomFilterExcludedDomains) else {
            throw Error.bloomFilterExclusionsNotFound
        }
        try await Task.detached {
            let excludedDomains = try JSONDecoder().decode(HTTPSExcludedDomains.self, from: bloomFilterExclusions).data
            do {
                try await PrivacyFeatures.httpsUpgrade.persistExcludedDomains(excludedDomains)
            } catch {
                throw Error.bloomFilterExclusionsPersistenceFailed.withUnderlyingError(error)
            }
            await PrivacyFeatures.httpsUpgrade.loadData()
        }.value
    }

}
