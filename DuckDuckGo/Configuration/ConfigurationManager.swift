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
import os.log
import Combine
import BrowserServicesKit
import Persistence
import Configuration
import Common
import Networking
import PixelKit

final class ConfigurationManager: DefaultConfigurationManager {

    private let trackerDataManager: TrackerDataManager
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private var contentBlockingManager: ContentBlockerRulesManagerProtocol

    private enum Constants {
        static let lastConfigurationInstallDateKey = "config.last.installed"
    }

    private var defaults: KeyValueStoring

    private(set) var lastConfigurationInstallDate: Date? {
        get {
            defaults.object(forKey: Constants.lastConfigurationInstallDateKey) as? Date
        }
        set {
            defaults.set(newValue, forKey: Constants.lastConfigurationInstallDateKey)
        }
    }

    static let configurationDebugEvents = EventMapping<ConfigurationDebugEvents> { event, error, _, _ in
        let domainEvent: GeneralPixel
        switch event {
        case .invalidPayload(let configuration):
            domainEvent = .invalidPayload(configuration)
        }

        PixelKit.fire(DebugEvent(domainEvent, error: error))
    }

    init(fetcher: ConfigurationFetching = ConfigurationFetcher(store: ConfigurationStore(), eventMapping: configurationDebugEvents),
         store: ConfigurationStoring = ConfigurationStore(),
         defaults: KeyValueStoring = UserDefaults.appConfiguration,
         trackerDataManager: TrackerDataManager = ContentBlocking.shared.trackerDataManager,
         privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
         contentBlockingManager: ContentBlockerRulesManagerProtocol = ContentBlocking.shared.contentBlockingManager) {

        self.trackerDataManager = trackerDataManager
        self.privacyConfigurationManager = privacyConfigurationManager
        self.contentBlockingManager = contentBlockingManager
        self.defaults = defaults

        super.init(fetcher: fetcher, store: store, defaults: defaults)
    }

    func log() {
        Logger.config.log("last update \(String(describing: self.lastUpdateTime), privacy: .public)")
        Logger.config.log("last refresh check \(String(describing: self.lastRefreshCheckTime), privacy: .public)")
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
                try await fetcher.fetch(.bloomFilterExcludedDomains, isDebug: isDebug)
                try await updateBloomFilterExclusions()
                tryAgainLater()
            } catch {
                handleRefreshError(error)
            }
        }

        await updateTrackerBlockingDependenciesTask.value
        await updateBloomFilterTask.value
        await updateBloomFilterExclusionsTask.value

        (store as? ConfigurationStore)?.log()

        Logger.config.info("last update \(String(describing: self.lastUpdateTime), privacy: .public)")
        Logger.config.info("last refresh check \(String(describing: self.lastRefreshCheckTime), privacy: .public)")
    }

    private func fetchTrackerBlockingDependencies(isDebug: Bool) async -> Bool {
        var didFetchAnyTrackerBlockingDependencies = false

        // Start surrogates fetch task
        let surrogatesTask = Task { try await fetcher.fetch(.surrogates, isDebug: isDebug) }

        // Perform privacyConfiguration fetch and update
        do {
            try await fetcher.fetch(.privacyConfiguration, isDebug: isDebug)
            didFetchAnyTrackerBlockingDependencies = true
            privacyConfigurationManager.reload(etag: store.loadEtag(for: .privacyConfiguration),
                                               data: store.loadData(for: .privacyConfiguration))
        } catch {
            Logger.config.error(
                "Failed to complete configuration update to \(Configuration.privacyConfiguration.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            tryAgainSoon()
        }

        // Start trackerDataSet fetch task after privacyConfiguration completes
        let trackerDataSetTask = Task { try await fetcher.fetch(.trackerDataSet, isDebug: isDebug) }

        // Wait for surrogates and trackerDataSet tasks
        let tasks: [(Configuration, Task<(), Swift.Error>)] = [
            (.surrogates, surrogatesTask),
            (.trackerDataSet, trackerDataSetTask)
        ]

        for (configuration, task) in tasks {
            do {
                try await task.value
                didFetchAnyTrackerBlockingDependencies = true
            } catch {
                Logger.config.error(
                    "Failed to complete configuration update to \(configuration.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
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

        Logger.config.error("Failed to complete configuration update \(error.localizedDescription, privacy: .public)")
        PixelKit.fire(DebugEvent(GeneralPixel.configurationFetchError(error: error)))
        tryAgainSoon()
    }

    private func updateTrackerBlockingDependencies() {
        lastConfigurationInstallDate = Date()

        trackerDataManager.reload(etag: store.loadEtag(for: .trackerDataSet),
                                  data: store.loadData(for: .trackerDataSet))
        privacyConfigurationManager.reload(etag: store.loadEtag(for: .privacyConfiguration),
                                           data: store.loadData(for: .privacyConfiguration))
        contentBlockingManager.scheduleCompilation()
    }

    private func updateBloomFilter() async throws {
        guard let specData = store.loadData(for: .bloomFilterSpec) else {
            throw Error.bloomFilterSpecNotFound
        }
        guard let bloomFilterData = store.loadData(for: .bloomFilterBinary) else {
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
        guard let bloomFilterExclusions = store.loadData(for: .bloomFilterExcludedDomains) else {
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

extension ConfigurationManager {
    override var presentedItemURL: URL? {
        store.fileUrl(for: .privacyConfiguration).deletingLastPathComponent()
    }

    override func presentedSubitemDidAppear(at url: URL) {
        guard url == store.fileUrl(for: .privacyConfiguration) else { return }
        updateTrackerBlockingDependencies()
    }

    override func presentedSubitemDidChange(at url: URL) {
        guard url == store.fileUrl(for: .privacyConfiguration) else { return }
        updateTrackerBlockingDependencies()
    }
}
