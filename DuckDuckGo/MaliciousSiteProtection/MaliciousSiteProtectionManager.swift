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
import PixelKit

extension MaliciousSiteProtectionManager {

    static func fileName(for dataType: MaliciousSiteProtection.DataManager.StoredDataType) -> String {
        switch (dataType, dataType.threatKind) {
        case (.hashPrefixSet, .phishing): "phishingHashPrefixes.json"
        case (.filterSet, .phishing): "phishingFilterSet.json"
//            case (.hashPrefixes, .malware): "malwareHashPrefixes.json"
//            case (.filters, .malware): "malwareFilterSet.json"
        }
    }

    struct EmbeddedDataProvider: MaliciousSiteProtection.EmbeddedDataProviding {

        private enum Constants {
            static let embeddedDataRevision = 1692083
            static let phishingEmbeddedHashPrefixDataSHA = "b423fa3cf21d82a8f537ae3c817c7aa5338603401c77a6ed7094f0b20af30055"
            static let phishingEmbeddedFilterSetDataSHA = "6633f7a2e521071485128c6bf3b84ce2a2dc7bd09750fed7b0300913ed8bfa96"
//            static let malwareEmbeddedHashPrefixDataSHA = "b423fa3cf21d82a8f537ae3c817c7aa5338603401c77a6ed7094f0b20af30055"
//            static let malwareEmbeddedFilterSetDataSHA = "6633f7a2e521071485128c6bf3b84ce2a2dc7bd09750fed7b0300913ed8bfa96"
        }

        func revision(for dataType: MaliciousSiteProtection.DataManager.StoredDataType) -> Int {
            Constants.embeddedDataRevision
        }

        func url(for dataType: MaliciousSiteProtection.DataManager.StoredDataType) -> URL {
            return Bundle.main.url(forResource: fileName(for: dataType), withExtension: nil)!
        }

        func hash(for dataType: MaliciousSiteProtection.DataManager.StoredDataType) -> String {
            switch (dataType, dataType.threatKind) {
            case (.hashPrefixSet, .phishing): Constants.phishingEmbeddedHashPrefixDataSHA
            case (.filterSet, .phishing): Constants.phishingEmbeddedFilterSetDataSHA
//            case (.hashPrefixes, .malware): Constants.malwareEmbeddedHashPrefixDataSHA
//            case (.filters, .malware): Constants.malwareEmbeddedFilterSetDataSHA
            }
        }

        // see `EmbeddedThreatDataProviding.swift` extension for `EmbeddedThreatDataProviding.load` method implementation
    }
}

public class MaliciousSiteProtectionManager: MaliciousSiteDetecting {
    static let shared = MaliciousSiteProtectionManager()

    private let detector: MaliciousSiteDetecting
    private let updateManager: MaliciousSiteProtection.UpdateManaging
    private let dataActivities: PhishingDetectionDataActivityHandling
    private let detectionPreferences: MaliciousSiteProtectionPreferences
    private let featureFlagger: FeatureFlagger
    private let configManager: PrivacyConfigurationManaging

    private var featureFlagsCancellable: AnyCancellable?
    private var detectionPreferencesEnabledCancellable: AnyCancellable?

    init(
        fileStoreUrl: URL? = nil,
        apiClient: MaliciousSiteProtection.APIClientProtocol = .production,
        embeddedDataProvider: MaliciousSiteProtection.EmbeddedDataProviding? = nil,
        dataManager: MaliciousSiteProtection.DataManaging? = nil,
        detector: MaliciousSiteProtection.MaliciousSiteDetecting? = nil,
        updateManager: MaliciousSiteProtection.UpdateManaging? = nil,
        dataActivities: PhishingDetectionDataActivityHandling? = nil,
        detectionPreferences: MaliciousSiteProtectionPreferences = MaliciousSiteProtectionPreferences.shared,
        featureFlagger: FeatureFlagger? = nil,
        configManager: PrivacyConfigurationManaging? = nil
    ) {
        self.featureFlagger = featureFlagger ?? NSApp.delegateTyped.featureFlagger
        self.configManager = configManager ?? AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager

        let embeddedDataProvider = embeddedDataProvider ?? EmbeddedDataProvider()
        let configurationUrl = fileStoreUrl ?? FileManager.default.configurationDirectory()
        let fileStore = MaliciousSiteProtection.FileStore(dataStoreURL: configurationUrl)
        let dataManager = dataManager ?? MaliciousSiteProtection.DataManager(fileStore: fileStore, embeddedDataProvider: embeddedDataProvider, fileNameProvider: Self.fileName(for:))

        self.detector = detector ?? MaliciousSiteDetector(apiClient: apiClient, dataManager: dataManager, eventMapping: Self.debugEvents)
        self.updateManager = updateManager ?? MaliciousSiteProtection.UpdateManager(apiClient: apiClient, dataManager: dataManager)
        self.detectionPreferences = detectionPreferences
        self.dataActivities = dataActivities ?? PhishingDetectionDataActivities(updateManager: self.updateManager)

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
        dataActivities.start()
    }

    private func stopUpdateTasks() {
        dataActivities.stop()
    }

    // MARK: - Public

    public func evaluate(_ url: URL) async -> ThreatKind? {
        guard configManager.privacyConfig.isFeature(.maliciousSiteProtection, enabledForDomain: url.host) || featureFlagger.localOverrides?.override(for: FeatureFlag.maliciousSiteProtectionErrorPage) == true,
              detectionPreferences.isEnabled || !(featureFlagger.isFeatureOn(.maliciousSiteProtectionPreferences) || featureFlagger.localOverrides?.override(for: FeatureFlag.maliciousSiteProtectionPreferences) == true) else { return .none }

        return await detector.evaluate(url)
    }

}
