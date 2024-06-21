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

protocol PhishingDetectionProtocol {
    func checkIsMaliciousIfEnabled(url: URL) async -> Bool
}

public class PhishingDetection: PhishingDetectionProtocol {
    static let shared: PhishingDetection = PhishingDetection()
    private var detector: PhishingDetecting
    private var updateManager: PhishingDetectionUpdateManaging
    private var dataActivities: PhishingDetectionDataActivities
    private var detectionPreferences: PhishingDetectionPreferences
    private var dataStore: PhishingDetectionDataStore
    private var cancellable: AnyCancellable?
    private let revision: Int
    private let filterSetURL: URL
    private let filterSetDataSHA: String
    private let hashPrefixURL: URL
    private let hashPrefixDataSHA: String

    init(
        revision: Int = 1645643,
        filterSetURL: URL = Bundle.main.url(forResource: "filterSet", withExtension: "json")!,
        filterSetDataSHA: String = "c3127eb62e5655e46c177ebad399a4d7a616d4e6b655e71e6c336a9572a71dee",
        hashPrefixURL: URL = Bundle.main.url(forResource: "hashPrefixes", withExtension: "json")!,
        hashPrefixDataSHA: String = "fc376b9c5345ad46b1c7eadfaa55a1d11167a2b10ee5457cb761a681388fe411",
        detectionClient: PhishingDetectionAPIClient = PhishingDetectionAPIClient(),
        dataProvider: PhishingDetectionDataProvider? = nil,
        dataStore: PhishingDetectionDataStore? = nil,
        detector: PhishingDetecting? = nil,
        updateManager: PhishingDetectionUpdateManaging? = nil,
        dataActivities: PhishingDetectionDataActivities? = nil,
        detectionPreferences: PhishingDetectionPreferences = PhishingDetectionPreferences.shared
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

        self.setupBindings()
    }

    private func setupBindings() {
        cancellable = detectionPreferences.$isEnabled.sink { [weak self] isEnabled in
            self?.handleIsEnabledChange(enabled: isEnabled)
        }
    }

    public func checkIsMaliciousIfEnabled(url: URL) async -> Bool {
        if detectionPreferences.isEnabled {
            return await detector.isMalicious(url: url)
        } else {
            return false
        }
    }

    public func handleIsEnabledChange(enabled: Bool) {
        if enabled {
            startUpdateTasks()
        } else {
            stopUpdateTasks()
        }
    }

    func startUpdateTasks() {
        Task {
            await dataStore.loadData()
        }
        Task {
            dataActivities.start()
        }
    }

    func stopUpdateTasks() {
        dataActivities.stop()
    }

    deinit {
        cancellable?.cancel()
    }
}
