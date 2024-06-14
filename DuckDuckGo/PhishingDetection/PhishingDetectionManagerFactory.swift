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

    public static let revision = 1646071
    private static let filterSetURL = Bundle.main.url(forResource: "filterSet", withExtension: "json")!
    private static let filterSetDataSHA = "c3127eb62e5655e46c177ebad399a4d7a616d4e6b655e71e6c336a9572a71dee"
    private static let hashPrefixURL = Bundle.main.url(forResource: "hashPrefixes", withExtension: "json")!
    private static let hashPrefixDataSHA = "1623184273842d8210891774cf51c44a710f569a34955aa4bcfca1b7a24e0d4b"

    public static func create() -> PhishingDetectionManager {
        let detectionClient = PhishingDetectionAPIClient()
        let dataProvider = PhishingDetectionDataProvider(revision: revision, filterSetURL: filterSetURL, filterSetDataSHA: filterSetDataSHA, hashPrefixURL: hashPrefixURL, hashPrefixDataSHA: hashPrefixDataSHA)
        let service = PhishingDetectionService(apiClient: detectionClient, dataProvider: dataProvider)
        let dataActivities = PhishingDetectionDataActivities(detectionService: service)
        return PhishingDetectionManager(service: service, dataActivities: dataActivities)
    }

}
