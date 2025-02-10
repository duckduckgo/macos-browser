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
            let allowlist = adClickAttribution.allowlist
            let allowlistedTrackerNames = allowlist.map { $0.entity }
            let adSplitter = AdClickAttributionRulesSplitter(rulesList: tdsRules, allowlistedTrackerNames: allowlistedTrackerNames)
            if let splitRules = adSplitter.split() {
                result.remove(at: tdsRulesIndex)
                result.append(splitRules.0)
                result.append(splitRules.1)
            }
        }

        // split CTL rules so they can be managed separately from the main list when user clicks through a CTL dialog
        if let tdsRulesIndex = result.firstIndex(where: { $0.name == DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName }) {
            let tdsRules = result[tdsRulesIndex]
            let ctlSplitter = ClickToLoadRulesSplitter(rulesList: tdsRules)
            if let splitRules = ctlSplitter.split() {
                result.remove(at: tdsRulesIndex)
                result.append(splitRules.withoutBlockCTL)
                result.append(splitRules.withBlockCTL)
            }
        }

        return result
    }
}
