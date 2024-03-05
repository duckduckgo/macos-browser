//
//  ClickToLoadRulesSplitter.swift
//  DuckDuckGo
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import TrackerRadarKit
import BrowserServicesKit

struct ClickToLoadRulesSplitter {

    public enum Constants {

        public static let clickToLoadRuleListPrefix = "CTL_"

    }

    private let rulesList: ContentBlockerRulesList

    init(rulesList: ContentBlockerRulesList) {
        self.rulesList = rulesList
    }

    func split() -> (withoutBlockCTL: ContentBlockerRulesList, withBlockCTL: ContentBlockerRulesList)? {
        let splitTDS = rulesList.trackerData != nil ? split(trackerData: rulesList.trackerData!) : nil
        let splitFallbackTDS = split(trackerData: rulesList.fallbackTrackerData)

        if splitTDS != nil || splitFallbackTDS != nil {
            return (
                ContentBlockerRulesList(name: rulesList.name,
                                        trackerData: splitTDS?.withoutBlockCTL ?? rulesList.trackerData,
                                        fallbackTrackerData: splitFallbackTDS?.withoutBlockCTL ?? rulesList.fallbackTrackerData),
                ContentBlockerRulesList(name: ContentBlockerRulesLists.Constants.clickToLoadRulesListName,
                                        trackerData: splitTDS?.withBlockCTL ?? rulesList.trackerData,
                                        fallbackTrackerData: splitFallbackTDS?.withBlockCTL ?? rulesList.fallbackTrackerData)
            )
        }
        return nil
    }

    private func split(trackerData: TrackerDataManager.DataSet) -> (withoutBlockCTL: TrackerDataManager.DataSet, withBlockCTL: TrackerDataManager.DataSet)? {
        let trackersWithBlockCTL = filterTrackersWithCTLAction(trackerData.tds.trackers)

        if !trackersWithBlockCTL.isEmpty {
            let trackersWithoutBlockCTL = filterTrackersWithoutCTLAction(trackerData.tds.trackers)
            let trackerDataWithoutBlockCTL = makeTrackerData(using: trackersWithoutBlockCTL, originalTDS: trackerData.tds)
            let trackerDataWithBlockCTL = makeTrackerData(using: trackersWithBlockCTL, originalTDS: trackerData.tds)

            return (
                (tds: trackerDataWithoutBlockCTL, etag: Constants.clickToLoadRuleListPrefix + trackerData.etag),
                (tds: trackerDataWithBlockCTL, etag: Constants.clickToLoadRuleListPrefix + trackerData.etag)
            )
        }
        return nil
    }

    private func makeTrackerData(using trackers: [String: KnownTracker], originalTDS: TrackerData) -> TrackerData {
        let entities = originalTDS.extractEntities(for: trackers)
        let domains = extractDomains(from: entities)
        return TrackerData(trackers: trackers,
                           entities: entities,
                           domains: domains,
                           cnames: originalTDS.cnames)
    }

    private func filterTrackersWithoutCTLAction(_ trackers: [String: KnownTracker]) -> [String: KnownTracker] {
        trackers.filter { (_, tracker) in tracker.containsCTLActions == false }
    }

    private func filterTrackersWithCTLAction(_ trackers: [String: KnownTracker]) -> [String: KnownTracker] {
        return Dictionary(uniqueKeysWithValues: trackers.filter { (_, tracker) in
            return tracker.containsCTLActions == true
        }.map { (key, value) in
            var modifiedTracker = value
            // Modify the tracker here
            if modifiedTracker.defaultAction == .blockCtlFB {
                modifiedTracker.defaultAction = .block
            }
            print("RULES BEFORE \(modifiedTracker.rules)")

            if let rules = modifiedTracker.rules as [KnownTracker.Rule]? {
                for ruleIndex in rules.indices {
                    if let action = rules[ruleIndex].action, action == .blockCtlFB {
//                        modifiedTracker.rules?[ruleIndex].action = .block
                        modifiedTracker.rules?[ruleIndex].action = nil
                    }
                }
            }
            print("RULES AFTER \(modifiedTracker.rules)")

            return (key, modifiedTracker)
        })
    }

    private func extractDomains(from entities: [String: Entity]) -> [String: String] {
        var domains = [String: String]()
        for entity in entities {
            for domain in entity.value.domains ?? [] {
                domains[domain] = entity.key
            }
        }
        return domains
    }

}

private extension TrackerData {

    func extractEntities(for trackers: [String: KnownTracker]) -> [String: Entity] {
        let trackerOwners = Set(trackers.values.compactMap { $0.owner?.name })
        let entities = entities.filter { trackerOwners.contains($0.key) }
        return entities
    }

}

private extension KnownTracker {

    var containsCTLActions: Bool {
        if let defaultAction = defaultAction, defaultAction == .blockCtlFB {
            return true
        }

        if let rules = rules {
            for rule in rules {
                if let action = rule.action, action == .blockCtlFB {
                    return true
                }
            }
        }
        return false
    }

}
