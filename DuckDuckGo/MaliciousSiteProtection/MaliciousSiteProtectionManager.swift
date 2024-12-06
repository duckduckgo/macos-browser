//
//  MaliciousSiteProtectionManager.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit
import Combine
import Common
import FeatureFlags
import Foundation
import MaliciousSiteProtection
import Networking
import PixelKit

extension MaliciousSiteProtectionManager {

    static func fileName(for dataType: MaliciousSiteProtection.DataManager.StoredDataType) -> String {
        switch (dataType, dataType.threatKind) {
        case (.hashPrefixSet, .phishing): "phishingHashPrefixes.json"
        case (.filterSet, .phishing): "phishingFilterSet.json"
        case (.hashPrefixSet, .malware): "malwareHashPrefixes.json"
        case (.filterSet, .malware): "malwareFilterSet.json"
        }
    }

    static func updateInterval(for dataKind: MaliciousSiteProtection.DataManager.StoredDataType) -> TimeInterval? {
        switch dataKind {
        case .hashPrefixSet: .minutes(20)
        case .filterSet: .hours(12)
        }
    }

    struct EmbeddedDataProvider: MaliciousSiteProtection.EmbeddedDataProviding {

        private enum Constants {
            // TODO: Rollback the revision and filter (with -f) set when malware is available on the server
            static let embeddedDataRevision = 1696473
            static let phishingEmbeddedHashPrefixDataSHA = "cdb609c37e950b7d0dcdaa80ae4071cf2c87223cfdd189caafae723722bd3158"
            static let phishingEmbeddedFilterSetDataSHA = "4e52518aba04b0fd360fada76c9899001d3137d4a745cc13c484a54115a0fcd8"
            static let malwareEmbeddedHashPrefixDataSHA = "6b5eb296e9e10ae9ea41c5b5356f532226d647e4f3b832c30ac670102446ea7a"
            static let malwareEmbeddedFilterSetDataSHA = "4dc971fffaf244ee99267f28222a2c116743e35ef837dcbc0199693ed6a691cd"
        }

        func revision(for dataType: MaliciousSiteProtection.DataManager.StoredDataType) -> Int {
            Constants.embeddedDataRevision
        }

        func url(for dataType: MaliciousSiteProtection.DataManager.StoredDataType) -> URL {
            let fileName = fileName(for: dataType)
            guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
                fatalError("Could not find embedded data file \"\(fileName)\"")
            }
            return url
        }

        func hash(for dataType: MaliciousSiteProtection.DataManager.StoredDataType) -> String {
            switch (dataType, dataType.threatKind) {
            case (.hashPrefixSet, .phishing): Constants.phishingEmbeddedHashPrefixDataSHA
            case (.filterSet, .phishing): Constants.phishingEmbeddedFilterSetDataSHA
            case (.hashPrefixSet, .malware): Constants.malwareEmbeddedHashPrefixDataSHA
            case (.filterSet, .malware): Constants.malwareEmbeddedFilterSetDataSHA
            }
        }

        // see `EmbeddedThreatDataProviding.swift` extension for `EmbeddedThreatDataProviding.load` method implementation
    }
}

public class MaliciousSiteProtectionManager: MaliciousSiteDetecting {
    static let shared = MaliciousSiteProtectionManager()

    private let detector: MaliciousSiteDetecting
    private let updateManager: MaliciousSiteProtection.UpdateManager
    private let detectionPreferences: MaliciousSiteProtectionPreferences
    private let featureFlagger: FeatureFlagger
    private let configManager: PrivacyConfigurationManaging

    private var featureFlagsCancellable: AnyCancellable?
    private var detectionPreferencesEnabledCancellable: AnyCancellable?
    private var updateTask: Task<Void, Error>?
    var backgroundUpdatesEnabled: Bool { updateTask != nil }

    init(
        apiEnvironment: MaliciousSiteDetector.APIEnvironment = .production,
        apiService: APIService = DefaultAPIService(urlSession: .shared),
        embeddedDataProvider: MaliciousSiteProtection.EmbeddedDataProviding? = nil,
        dataManager: MaliciousSiteProtection.DataManager? = nil,
        detector: MaliciousSiteProtection.MaliciousSiteDetecting? = nil,
        detectionPreferences: MaliciousSiteProtectionPreferences = MaliciousSiteProtectionPreferences.shared,
        featureFlagger: FeatureFlagger? = nil,
        configManager: PrivacyConfigurationManaging? = nil,
        updateIntervalProvider: UpdateManager.UpdateIntervalProvider? = nil
    ) {
        self.featureFlagger = featureFlagger ?? NSApp.delegateTyped.featureFlagger
        self.configManager = configManager ?? AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager

        let embeddedDataProvider = embeddedDataProvider ?? EmbeddedDataProvider()
        let dataManager = dataManager ?? {
            let configurationUrl = FileManager.default.configurationDirectory()
            let fileStore = MaliciousSiteProtection.FileStore(dataStoreURL: configurationUrl)
            return MaliciousSiteProtection.DataManager(fileStore: fileStore, embeddedDataProvider: embeddedDataProvider, fileNameProvider: Self.fileName(for:))
        }()

        self.detector = detector ?? MaliciousSiteDetector(apiEnvironment: apiEnvironment, service: apiService, dataManager: dataManager, eventMapping: Self.debugEvents)
        self.updateManager = MaliciousSiteProtection.UpdateManager(apiEnvironment: apiEnvironment, service: apiService, dataManager: dataManager, updateIntervalProvider: updateIntervalProvider ?? Self.updateInterval)
        self.detectionPreferences = detectionPreferences

        self.setupBindings()
    }

    private static let debugEvents = EventMapping<MaliciousSiteProtection.Event> {event, _, _, _ in
        PixelKit.fire(event)
    }

    private func setupBindings() {
        if featureFlagger.isFeatureOn(.maliciousSiteProtectionErrorPage) {
            subscribeToDetectionPreferences()
            return
        }

        guard let overridesHandler = featureFlagger.localOverrides?.actionHandler as? FeatureFlagOverridesPublishingHandler<FeatureFlag> else { return }
        featureFlagsCancellable = overridesHandler.flagDidChangePublisher
            .filter { $0.0 == .maliciousSiteProtectionErrorPage }
            .sink { [weak self] change in
                guard let self else { return }
                if change.1 {
                    subscribeToDetectionPreferences()
                } else {
                    detectionPreferencesEnabledCancellable = nil
                    stopUpdateTasks()
                }
            }
    }

    private func subscribeToDetectionPreferences() {
        detectionPreferencesEnabledCancellable = detectionPreferences.$isEnabled
            .sink { [weak self] isEnabled in
                self?.handleIsEnabledChange(enabled: isEnabled)
            }
    }

    private func handleIsEnabledChange(enabled: Bool) {
        if enabled {
            startUpdateTasks()
        } else {
            stopUpdateTasks()
        }
    }

    private func startUpdateTasks() {
        self.updateTask = updateManager.startPeriodicUpdates()
    }

    private func stopUpdateTasks() {
        updateTask?.cancel()
        updateTask = nil
    }

    // MARK: - Public

    public func evaluate(_ url: URL) async -> ThreatKind? {
        guard configManager.privacyConfig.isFeature(.maliciousSiteProtection, enabledForDomain: url.host),
              detectionPreferences.isEnabled else { return .none }

        return await detector.evaluate(url)
    }

}
