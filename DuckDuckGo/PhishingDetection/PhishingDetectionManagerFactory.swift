//
//  PhishingDetectionManagerFactory.swift
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

public class PhishingDetectionManagerFactory {

    public static let revision = 1645643
    private static let filterSetURL = Bundle.main.url(forResource: "filterSet", withExtension: "json")!
    private static let filterSetDataSHA = "c3127eb62e5655e46c177ebad399a4d7a616d4e6b655e71e6c336a9572a71dee"
    private static let hashPrefixURL = Bundle.main.url(forResource: "hashPrefixes", withExtension: "json")!
    private static let hashPrefixDataSHA = "fc376b9c5345ad46b1c7eadfaa55a1d11167a2b10ee5457cb761a681388fe411"
    private static var instance: PhishingDetector?

    public static func create() -> PhishingDetector {
        if let instance = instance {
            return instance
        }
        let detectionClient = PhishingDetectionAPIClient()
        let dataProvider = PhishingDetectionDataProvider(revision: revision, filterSetURL: filterSetURL, filterSetDataSHA: filterSetDataSHA, hashPrefixURL: hashPrefixURL, hashPrefixDataSHA: hashPrefixDataSHA)
        let dataStore = PhishingDetectionDataStore(dataProvider: dataProvider)
        Task {
            await dataStore.loadData()
        }
        let service = PhishingDetector(apiClient: detectionClient, dataProvider: dataProvider, dataStore: dataStore)
        let updateManager = PhishingDetectionUpdateManager(client: detectionClient, dataStore: dataStore)
        let dataActivities = PhishingDetectionDataActivities(detectionService: service, phishingDetectionDataProvider: dataProvider, updateManager: updateManager)
        Task {
            dataActivities.start()
        }
        instance = service
        return service
    }
}
