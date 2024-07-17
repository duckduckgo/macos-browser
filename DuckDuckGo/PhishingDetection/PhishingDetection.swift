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

/// PhishingDetection is implemented using two datasets that are embedded into the client as a Bundle in `DataProvider`,
/// and kept up to date by `DataActivities` and `UpdateManager`. If the feature is disabled in `Preferences`,
/// we stop the background tasks and don't check `isMalicious` on any URLs. 
protocol PhishingSiteDetecting {
    func checkIsMaliciousIfEnabled(url: URL) async -> Bool
}

public class PhishingDetection: PhishingSiteDetecting {
    static let shared: PhishingDetection = PhishingDetection()
    private var detector: PhishingDetecting
    private var updateManager: PhishingDetectionUpdateManaging
    private var dataActivities: PhishingDetectionDataActivityHandling
    private var detectionPreferences: PhishingDetectionPreferences
    private var dataStore: PhishingDetectionDataStoring
    private var featureFlagger: FeatureFlagger
    private var cancellable: AnyCancellable?
    private let revision: Int
    private let filterSetURL: URL
    private let filterSetDataSHA: String
    private let hashPrefixURL: URL
    private let hashPrefixDataSHA: String

    private init(
        revision: Int = 1653367,
        filterSetURL: URL = Bundle.main.url(forResource: "filterSet", withExtension: "json")!,
        filterSetDataSHA: String = "edd913cb0a579c2b163a01347531ed78976bfaf1d14b96a658c4a39d34a70ffc",
        hashPrefixURL: URL = Bundle.main.url(forResource: "hashPrefixes", withExtension: "json")!,
        hashPrefixDataSHA: String = "c61349d196c46db9155ca654a0d33368ee0f33766fcd63e5a20f1d5c92026dc5",
        detectionClient: PhishingDetectionAPIClient = PhishingDetectionAPIClient(),
        dataProvider: PhishingDetectionDataProvider? = nil,
        dataStore: PhishingDetectionDataStoring? = nil,
        detector: PhishingDetecting? = nil,
        updateManager: PhishingDetectionUpdateManaging? = nil,
        dataActivities: PhishingDetectionDataActivityHandling? = nil,
        detectionPreferences: PhishingDetectionPreferences = PhishingDetectionPreferences.shared,
        featureFlagger: FeatureFlagger? = nil
    ) {
        self.revision = revision
        self.filterSetURL = filterSetURL
        self.filterSetDataSHA = filterSetDataSHA
        self.hashPrefixURL = hashPrefixURL
        self.hashPrefixDataSHA = hashPrefixDataSHA

        let resolvedDataProvider = dataProvider ?? PhishingDetectionDataProvider(
            revision: revision,
            filterSetURL: filterSetURL,
            filterSetDataSHA: filterSetDataSHA,
            hashPrefixURL: hashPrefixURL,
            hashPrefixDataSHA: hashPrefixDataSHA
        )
        self.dataStore = dataStore ?? PhishingDetectionDataStore(dataProvider: resolvedDataProvider)
        self.detector = detector ?? PhishingDetector(apiClient: detectionClient, dataProvider: resolvedDataProvider, dataStore: self.dataStore)
        self.updateManager = updateManager ?? PhishingDetectionUpdateManager(client: detectionClient, dataStore: self.dataStore)
        self.dataActivities = dataActivities ?? PhishingDetectionDataActivities(detectionService: self.detector, phishingDetectionDataProvider: resolvedDataProvider, updateManager: self.updateManager)
        self.detectionPreferences = detectionPreferences
        self.featureFlagger = NSApp.delegateTyped.featureFlagger
        if let featureFlagger = featureFlagger,
           featureFlagger.isFeatureOn(.phishingDetection),
           self.detectionPreferences.isEnabled {
            startUpdateTasks()
        }
        self.setupBindings()
    }

    convenience init(
        dataActivities: PhishingDetectionDataActivityHandling,
        dataStore: PhishingDetectionDataStoring,
        detector: PhishingDetecting
    ) {
        self.init(
            dataStore: dataStore,
            detector: detector,
            dataActivities: dataActivities
        )
    }

    private func setupBindings() {
        cancellable = detectionPreferences.$isEnabled.sink { [weak self] isEnabled in
            self?.handleIsEnabledChange(enabled: isEnabled)
        }
    }

    public func checkIsMaliciousIfEnabled(url: URL) async -> Bool {
        print("[+] featureFlagger: ", featureFlagger)
        print("[+] isFeatureOn: ", featureFlagger.isFeatureOn(.phishingDetection))
        if featureFlagger.isFeatureOn(.phishingDetection),
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
        Task {
            await dataStore.loadData()
            dataActivities.start()
        }
    }

    private func stopUpdateTasks() {
        dataActivities.stop()
    }

    deinit {
        cancellable?.cancel()
    }
}
