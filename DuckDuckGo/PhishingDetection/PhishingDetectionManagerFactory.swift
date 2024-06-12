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

    public static let revision = 1645592
    private static let filterSetURL = Bundle.main.url(forResource: "filterSet", withExtension: "json")!
    private static let filterSetDataSHA = "38e0b9de817f645c4bec37c0d4a3e58baecccb040f5718dc069a72c7385a0bed"
    private static let hashPrefixURL = Bundle.main.url(forResource: "hashPrefixes", withExtension: "json")!
    private static let hashPrefixDataSHA = "38e0b9de817f645c4bec37c0d4a3e58baecccb040f5718dc069a72c7385a0bed"

    public static func create() -> PhishingDetectionManager {
        let detectionClient = PhishingDetectionAPIClient()
        let dataProvider = PhishingDetectionDataProvider(revision: revision, filterSetURL: filterSetURL, filterSetDataSHA: filterSetDataSHA, hashPrefixURL: hashPrefixURL, hashPrefixDataSHA: hashPrefixDataSHA)
        let service = PhishingDetectionService(apiClient: detectionClient, dataProvider: dataProvider)
        let dataActivities = PhishingDetectionDataActivities(detectionService: service)
        return PhishingDetectionManager(service: service, dataActivities: dataActivities)
    }

}

