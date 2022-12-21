//
//  ContentBlockerRulesLists.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import TrackerRadarKit
import BrowserServicesKit
import CryptoKit

final class ContentBlockerRulesLists: DefaultContentBlockerRulesListsSource {

    enum Constants {
        static let clickToLoadRulesListName = "ClickToLoad"
    }

    static var fbTrackerDataFile: Data = {
        do {
            let url = Bundle.main.url(forResource: "fb-tds", withExtension: "json")!
            return try Data(contentsOf: url)
        } catch {
            fatalError("Failed to load FB-TDS")
        }
    }()

    static var fbTrackerDataSet: TrackerRadarKit.TrackerData = {
        do {
            return try JSONDecoder().decode(TrackerData.self, from: fbTrackerDataFile)
        } catch {
            fatalError("Failed to JSON decode FB-TDS")
        }
    }()

    func MD5(data: Data) -> String {
        let digest = Insecure.MD5.hash(data: data)

        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }

    private let adClickAttribution: AdClickAttributing

    init(trackerDataManager: TrackerDataManager, adClickAttribution: AdClickAttributing) {
        self.adClickAttribution = adClickAttribution
        super.init(trackerDataManager: trackerDataManager)
    }

    override var contentBlockerRulesLists: [ContentBlockerRulesList] {
        var result = super.contentBlockerRulesLists

        if adClickAttribution.isEnabled,
           let tdsRulesIndex = result.firstIndex(where: { $0.name == DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName }) {
            let tdsRules = result[tdsRulesIndex]
            let allowlistedTrackerNames = adClickAttribution.allowlist.map { $0.entity }
            let splitter = AdClickAttributionRulesSplitter(rulesList: tdsRules, allowlistedTrackerNames: allowlistedTrackerNames)
            if let splitRules = splitter.split() {
                result.remove(at: tdsRulesIndex)
                result.append(splitRules.0)
                result.append(splitRules.1)
            }
        }

        // Add new ones
        let etag = MD5(data: Self.fbTrackerDataFile)
        let dataSet: TrackerDataManager.DataSet = TrackerDataManager.DataSet(Self.fbTrackerDataSet, etag)
        let additionalRulesList = ContentBlockerRulesList(name: Constants.clickToLoadRulesListName,
                                                          trackerData: nil,
                                                          fallbackTrackerData: dataSet)

        result.append(additionalRulesList)
        return result
    }
}
