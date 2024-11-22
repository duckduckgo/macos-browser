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

public class MaliciousSiteProtectionManager: MaliciousSiteDetecting {
    static let shared = MaliciousSiteProtectionManager()

    private let revision: Int
    private let filterSetURL: URL
    private let filterSetDataSHA: String
    private let hashPrefixURL: URL
    private let hashPrefixDataSHA: String

    private let detector: MaliciousSiteDetecting
    private let updateManager: MaliciousSiteProtection.UpdateManaging
    private let dataActivities: PhishingDetectionDataActivityHandling
    private let detectionPreferences: MaliciousSiteProtectionPreferences
    private let featureFlagger: FeatureFlagger
    private let configManager: PrivacyConfigurationManaging

    private var featureFlagsCancellable: AnyCancellable?
    private var detectionPreferencesEnabledCancellable: AnyCancellable?

    init(
        revision: Int = 1686837,
        filterSetURL: URL = Bundle.main.url(forResource: "phishingFilterSet", withExtension: "json")!,
        filterSetDataSHA: String = "517e610cd7c304f91ff5aaee91d570f7b6e678dbe9744e00cdb0a3126068432f",
        hashPrefixURL: URL = Bundle.main.url(forResource: "phishingHashPrefixes", withExtension: "json")!,
        hashPrefixDataSHA: String = "05075ab14302a9e0329fbc0ba7e4e3118d7fa37846ec087c3942cfb1be92ffe0",
        apiClient: MaliciousSiteProtection.APIClientProtocol? = nil,
        embeddedDataProvider: MaliciousSiteProtection.EmbeddedDataProviding? = nil,
        dataManager: MaliciousSiteProtection.DataManaging? = nil,
        detector: MaliciousSiteProtection.MaliciousSiteDetecting? = nil,
        updateManager: MaliciousSiteProtection.UpdateManaging? = nil,
        dataActivities: PhishingDetectionDataActivityHandling? = nil,
        detectionPreferences: MaliciousSiteProtectionPreferences = MaliciousSiteProtectionPreferences.shared,
        featureFlagger: FeatureFlagger? = nil,
        configManager: PrivacyConfigurationManaging? = nil
    ) {
        self.revision = revision
        self.filterSetURL = filterSetURL
        self.filterSetDataSHA = filterSetDataSHA
        self.hashPrefixURL = hashPrefixURL
        self.hashPrefixDataSHA = hashPrefixDataSHA

        self.featureFlagger = featureFlagger ?? NSApp.delegateTyped.featureFlagger
        self.configManager = configManager ?? AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager

        let embeddedDataProvider = embeddedDataProvider ?? MaliciousSiteProtection.EmbeddedDataProvider(
            revision: revision,
            filterSetURL: filterSetURL,
            filterSetDataSHA: filterSetDataSHA,
            hashPrefixURL: hashPrefixURL,
            hashPrefixDataSHA: hashPrefixDataSHA
        )

        let apiClient = apiClient ?? MaliciousSiteProtection.APIClient(environment: .production)
        let dataManager = dataManager ?? MaliciousSiteProtection.DataManager(embeddedDataProvider: embeddedDataProvider)

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
