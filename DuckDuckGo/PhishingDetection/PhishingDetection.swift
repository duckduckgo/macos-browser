//
//  PhishingDetection.swift
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

import Foundation
import PhishingDetection
import Combine
import BrowserServicesKit
import PixelKit
import Common

/// PhishingDetection is implemented using two datasets that are embedded into the client as a Bundle in `DataProvider`,
/// and kept up to date by `DataActivities` and `UpdateManager`. If the feature is disabled in `Preferences`,
/// we stop the background tasks and don't check `isMalicious` on any URLs. 
public protocol PhishingSiteDetecting {
    func checkIsMaliciousIfEnabled(url: URL) async -> Bool
}

public class PhishingDetection: PhishingSiteDetecting {
    static let shared: PhishingDetection = PhishingDetection()
    private var detector: PhishingDetecting
    private var updateManager: PhishingDetectionUpdateManaging
    private var dataActivities: PhishingDetectionDataActivityHandling
    private var detectionPreferences: PhishingDetectionPreferences
    private var dataStore: PhishingDetectionDataSaving
    private var featureFlagger: FeatureFlagger
    private var configManager: PrivacyConfigurationManaging
    private var cancellable: AnyCancellable?
    private let revision: Int
    private let filterSetURL: URL
    private let filterSetDataSHA: String
    private let hashPrefixURL: URL
    private let hashPrefixDataSHA: String

    private init(
        revision: Int = 1686837,
        filterSetURL: URL = Bundle.main.url(forResource: "filterSet", withExtension: "json")!,
        filterSetDataSHA: String = "517e610cd7c304f91ff5aaee91d570f7b6e678dbe9744e00cdb0a3126068432f",
        hashPrefixURL: URL = Bundle.main.url(forResource: "hashPrefixes", withExtension: "json")!,
        hashPrefixDataSHA: String = "05075ab14302a9e0329fbc0ba7e4e3118d7fa37846ec087c3942cfb1be92ffe0",
        detectionClient: PhishingDetectionAPIClient = PhishingDetectionAPIClient(),
        dataProvider: PhishingDetectionDataProvider? = nil,
        dataStore: PhishingDetectionDataSaving? = nil,
        detector: PhishingDetecting? = nil,
        updateManager: PhishingDetectionUpdateManaging? = nil,
        dataActivities: PhishingDetectionDataActivityHandling? = nil,
        detectionPreferences: PhishingDetectionPreferences = PhishingDetectionPreferences.shared,
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

        let resolvedDependencies = PhishingDetection.resolveDependencies(
            revision: revision,
            filterSetURL: filterSetURL,
            filterSetDataSHA: filterSetDataSHA,
            hashPrefixURL: hashPrefixURL,
            hashPrefixDataSHA: hashPrefixDataSHA,
            detectionClient: detectionClient,
            dataProvider: dataProvider,
            dataStore: dataStore,
            detector: detector,
            updateManager: updateManager,
            dataActivities: dataActivities
        )

        self.dataStore = resolvedDependencies.dataStore
        self.detector = resolvedDependencies.detector
        self.updateManager = resolvedDependencies.updateManager
        self.dataActivities = resolvedDependencies.dataActivities
        self.detectionPreferences = detectionPreferences

        self.startUpdateTasksIfEnabled()
        self.setupBindings()
    }

    convenience init(
        dataActivities: PhishingDetectionDataActivityHandling,
        dataStore: PhishingDetectionDataSaving,
        detector: PhishingDetecting,
        configManager: PrivacyConfigurationManaging = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager
    ) {
        self.init(
            dataStore: dataStore, detector: detector, dataActivities: dataActivities,
            detectionPreferences: PhishingDetectionPreferences.shared,
            featureFlagger: NSApp.delegateTyped.featureFlagger,
            configManager: configManager
        )
    }

    convenience init(featureFlagger: FeatureFlagger, configManager: PrivacyConfigurationManaging) {
        self.init(
            detectionClient: PhishingDetectionAPIClient(),
            dataProvider: nil,
            dataStore: nil,
            detector: nil,
            updateManager: nil,
            dataActivities: nil,
            detectionPreferences: PhishingDetectionPreferences.shared,
            featureFlagger: featureFlagger,
            configManager: configManager
        )
    }

    private static func resolveDependencies(
        revision: Int,
        filterSetURL: URL,
        filterSetDataSHA: String,
        hashPrefixURL: URL,
        hashPrefixDataSHA: String,
        detectionClient: PhishingDetectionAPIClient,
        dataProvider: PhishingDetectionDataProvider?,
        dataStore: PhishingDetectionDataSaving?,
        detector: PhishingDetecting?,
        updateManager: PhishingDetectionUpdateManaging?,
        dataActivities: PhishingDetectionDataActivityHandling?
    ) -> (dataStore: PhishingDetectionDataSaving, detector: PhishingDetecting, updateManager: PhishingDetectionUpdateManaging, dataActivities: PhishingDetectionDataActivityHandling) {

        let resolvedDataProvider = dataProvider ?? PhishingDetectionDataProvider(
            revision: revision,
            filterSetURL: filterSetURL,
            filterSetDataSHA: filterSetDataSHA,
            hashPrefixURL: hashPrefixURL,
            hashPrefixDataSHA: hashPrefixDataSHA
        )

        let resolvedDataStore = dataStore ?? PhishingDetectionDataStore(dataProvider: resolvedDataProvider)
        let resolvedDetector = detector ?? PhishingDetector(apiClient: detectionClient, dataStore: resolvedDataStore, eventMapping:
            EventMapping<PhishingDetectionEvents> {event, _, _, _ in
            switch event {
            case .errorPageShown(clientSideHit: let clientSideHit):
                PixelKit.fire(PhishingDetectionEvents.errorPageShown(clientSideHit: clientSideHit))
            case .iframeLoaded:
                PixelKit.fire(PhishingDetectionEvents.iframeLoaded)
            case .visitSite:
                PixelKit.fire(PhishingDetectionEvents.visitSite)
            case .updateTaskFailed48h(error: let error):
                PixelKit.fire(PhishingDetectionEvents.updateTaskFailed48h(error: error))
            case .settingToggled(to: let settingState):
                PixelKit.fire(PhishingDetectionEvents.settingToggled(to: settingState))
            }
        })
        let resolvedUpdateManager = updateManager ?? PhishingDetectionUpdateManager(client: detectionClient, dataStore: resolvedDataStore)
        let resolvedDataActivities = dataActivities ?? PhishingDetectionDataActivities(phishingDetectionDataProvider: resolvedDataProvider, updateManager: resolvedUpdateManager)

        return (resolvedDataStore, resolvedDetector, resolvedUpdateManager, resolvedDataActivities)
    }

    private func startUpdateTasksIfEnabled() {
        if featureFlagger.isFeatureOn(.phishingDetectionErrorPage),
           self.detectionPreferences.isEnabled {
            startUpdateTasks()
        }
    }

    private func setupBindings() {
        cancellable = detectionPreferences.$isEnabled.sink { [weak self] isEnabled in
            self?.handleIsEnabledChange(enabled: isEnabled)
        }
    }

    public func checkIsMaliciousIfEnabled(url: URL) async -> Bool {
        if configManager.privacyConfig.isFeature(.phishingDetection, enabledForDomain: url.host),
           detectionPreferences.isEnabled {
            return await detector.isMalicious(url: url)
        } else {
            return false
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

    deinit {
        cancellable?.cancel()
        stopUpdateTasks()
    }
}
