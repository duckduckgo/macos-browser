//
//  AltContentBlockerRulesSource.swift
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
import BrowserServicesKit
import TrackerRadarKit

final class AltContentBlockerRulesSource: ContentBlockerRulesSource {
    let trackerDataManager: TrackerDataManager
    let privacyConfigManager: PrivacyConfigurationManager
    
    let trackerDataStatic = TrackerData(trackers: [
        "facebook.com": KnownTracker(domain: "facebook.com",
                                     defaultAction: .block,
                                     owner: KnownTracker.Owner(name: "Facebook, Inc.",
                                                               displayName: "Facebook"),
                                     prevalence: 0.278,
                                     subdomains: nil,
                                     categories: ["Advertising"],
                                     rules: [])
    ],
                                  entities: [
                                    "Facebook, Inc": Entity(displayName: "Facebook",
                                                            domains: ["facebook.com"],
                                                            prevalence: 29)
                                  ],
                                  domains: [:],
                                  cnames: nil)
    let customEtag = "custom"
    
    public init(trackerDataManager: TrackerDataManager, privacyConfigManager: PrivacyConfigurationManager) {
        self.trackerDataManager = trackerDataManager
        self.privacyConfigManager = privacyConfigManager
    }
    
    var trackerData: TrackerDataManager.DataSet? {
        return TrackerDataManager.DataSet(tds: trackerDataStatic, etag: customEtag)
    }
    
    var embeddedTrackerData: TrackerDataManager.DataSet {
        return TrackerDataManager.DataSet(tds: trackerDataStatic, etag: customEtag)
    }
    
    var tempListEtag: String {
        privacyConfigManager.privacyConfig.identifier
    }
    
    var tempList: [String] {
        let config = privacyConfigManager.privacyConfig
        var tempUnprotected = config.tempUnprotectedDomains.filter { !$0.trimWhitespace().isEmpty }
        tempUnprotected.append(contentsOf: config.exceptionsList(forFeature: .contentBlocking))
        return tempUnprotected
    }
    
    var allowListEtag: String {
        return privacyConfigManager.privacyConfig.identifier
    }
    
    var allowList: [TrackerException] {
        return Self.transform(allowList: privacyConfigManager.privacyConfig.trackerAllowlist)
    }
    
    var unprotectedSites: [String] {
        return privacyConfigManager.privacyConfig.userUnprotectedDomains
    }
    
    public class func transform(allowList: PrivacyConfigurationData.TrackerAllowlistData) -> [TrackerException] {

        let trackerRules = allowList.values.reduce(into: []) { partialResult, next in
            partialResult.append(contentsOf: next)
        }

        return trackerRules.map { entry in
            if entry.domains.contains("<all>") {
                return TrackerException(rule: entry.rule, matching: .all)
            } else {
                return TrackerException(rule: entry.rule, matching: .domains(entry.domains))
            }
        }
    }
}
