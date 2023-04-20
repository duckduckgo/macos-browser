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

@MainActor
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
    private var lastUpdateTime: Date

    private var timerCancellable: AnyCancellable?
    private var lastRefreshCheckTime: Date = Date()

    private lazy var fetcher = ConfigurationFetcher(store: ConfigurationStore.shared,
                                                    log: .config,
                                                    eventMapping: Self.configurationDebugEvents)

    private static let configurationDebugEvents = EventMapping<ConfigurationDebugEvents> { event, error, _, _ in
        let domainEvent: Pixel.Event.Debug
        switch event {
        case .invalidPayload(let configuration):
            domainEvent = .invalidPayload(configuration)
        }

        Pixel.fire(.debug(event: domainEvent, error: error))
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
        Task {
            await refreshNow()
        }
    }

    func log() {
        os_log("last update %{public}s", log: .config, type: .default, String(describing: lastUpdateTime))
        os_log("last refresh check %{public}s", log: .config, type: .default, String(describing: lastRefreshCheckTime))
    }

    private func refreshNow() async {
        let updateTrackerBlockingDependenciesTask = Task {
            let didFetchAnyTrackerBlockingDependencies = await fetchTrackerBlockingDependencies()
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

    private func fetchTrackerBlockingDependencies() async -> Bool {
        var didFetchAnyTrackerBlockingDependencies = false

        var tasks = [Configuration: Task<(), Swift.Error>]()
        tasks[.trackerDataSet] = Task { try await fetcher.fetch(.trackerDataSet) }
        tasks[.surrogates] = Task { try await fetcher.fetch(.surrogates) }
        tasks[.privacyConfiguration] = Task { try await fetcher.fetch(.privacyConfiguration) }

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
        Pixel.fire(.debug(event: .configurationFetchError, error: error))
        tryAgainSoon()
    }

    @discardableResult
    public func refreshIfNeeded() -> Task<Void, Never>? {
        guard isReadyToRefresh else {
            os_log("Configuration refresh is not needed at this time", log: .config, type: .debug)
            return nil
        }
        return Task {
            await refreshNow()
        }
    }

    private var isReadyToRefresh: Bool { Date().timeIntervalSince(lastUpdateTime) > Constants.refreshPeriodSeconds }

    public func forceRefresh() {
        Task {
            await refreshNow()
        }
    }

    private func tryAgainLater() {
        lastUpdateTime = Date()
    }

    private func tryAgainSoon() {
        // Set the last update time to in the past so it triggers again sooner
        lastUpdateTime = Date(timeIntervalSinceNow: Constants.refreshPeriodSeconds - Constants.retryDelaySeconds)
    }

    private func updateTrackerBlockingDependencies() {
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
                throw Error.bloomFilterPersistenceFailed
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
                throw Error.bloomFilterExclusionsPersistenceFailed
            }
            await PrivacyFeatures.httpsUpgrade.loadData()
        }.value
    }

}
