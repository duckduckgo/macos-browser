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
            static let embeddedDataRevision = 1693964 // TODO: Rollback the revision and hashes when malware is deployed on the server
            static let phishingEmbeddedHashPrefixDataSHA = "86e9b69a6224e22755408f8ec1d13354ca8d59048f11d0728d9c664602500e8e"
            static let phishingEmbeddedFilterSetDataSHA = "6c29956071ef76d83a65c6c34646f361e9d6b5007b7251f0c5473428486aa9ee"
            static let malwareEmbeddedHashPrefixDataSHA = "07c4f1bd44881974f53e07f67090bac60770378fb8f68d45bbf8451f6545b423"
            static let malwareEmbeddedFilterSetDataSHA = "9060c9e106444d578fc41df7b961343fc057e95adc88a3c0249504d477d7c4e0"
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
    private let updateManager: MaliciousSiteProtection.UpdateManaging
    private let detectionPreferences: MaliciousSiteProtectionPreferences
    private let featureFlagger: FeatureFlagger
    private let configManager: PrivacyConfigurationManaging

    private var featureFlagsCancellable: AnyCancellable?
    private var detectionPreferencesEnabledCancellable: AnyCancellable?
    private(set) var updateTask: Task<Void, Error>?

    init(
        fileStoreUrl: URL? = nil,
        apiClient: MaliciousSiteProtection.APIClientProtocol = .production,
        embeddedDataProvider: MaliciousSiteProtection.EmbeddedDataProviding? = nil,
        dataManager: MaliciousSiteProtection.DataManaging? = nil,
        detector: MaliciousSiteProtection.MaliciousSiteDetecting? = nil,
        updateManager: MaliciousSiteProtection.UpdateManaging? = nil,
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
        self.updateManager = updateManager ?? MaliciousSiteProtection.UpdateManager(apiClient: apiClient, dataManager: dataManager, updateIntervalProvider: Self.updateInterval)
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
        guard configManager.privacyConfig.isFeature(.maliciousSiteProtection, enabledForDomain: url.host) || featureFlagger.localOverrides?.override(for: FeatureFlag.maliciousSiteProtectionErrorPage) == true,
              detectionPreferences.isEnabled || !(featureFlagger.isFeatureOn(.maliciousSiteProtectionPreferences) || featureFlagger.localOverrides?.override(for: FeatureFlag.maliciousSiteProtectionPreferences) == true) else { return .none }

        return await detector.evaluate(url)
    }

}
