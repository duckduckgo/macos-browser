//
//  ClickToLoadRulesSplitter.swift
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
        public static let tdsRuleListPrefix = "TDS_"

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
        let (mainTrackers, ctlTrackers) = processCTLActions(trackerData.tds.trackers)
        if !ctlTrackers.isEmpty {
           let trackerDataWithoutBlockCTL = makeTrackerData(using: mainTrackers, originalTDS: trackerData.tds)
           let trackerDataWithBlockCTL = makeTrackerData(using: ctlTrackers, originalTDS: trackerData.tds)

           return (
               (tds: trackerDataWithoutBlockCTL, etag: Constants.tdsRuleListPrefix + trackerData.etag),
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

    private func processCTLActions(_ trackers: [String: KnownTracker]) -> (mainTrackers: [String: KnownTracker], ctlTrackers: [String: KnownTracker]) {
        var mainTDSTrackers: [String: KnownTracker] = [:]
        var ctlTrackers: [String: KnownTracker] = [:]

        for (key, tracker) in trackers {
            if let rules = tracker.rules as [KnownTracker.Rule]? {
                var normalRules: [KnownTracker.Rule] = []
                var ctlRules: [KnownTracker.Rule] = []

                for ruleIndex in rules.indices.reversed() {
                    if let action = rules[ruleIndex].action, action == .blockCtlFB {
                        ctlRules.insert(rules[ruleIndex], at: 0)
                    } else {
                        normalRules.insert(rules[ruleIndex], at: 0)
                    }
                }

                if !ctlRules.isEmpty {
                    // if we found some CTL rules, split out into its own list
                    let mainTracker = KnownTracker(domain: tracker.domain,
                        defaultAction: tracker.defaultAction,
                        owner: tracker.owner,
                        prevalence: tracker.prevalence,
                        subdomains: tracker.subdomains,
                        categories: tracker.categories,
                        rules: normalRules)
                    let ctlTracker = KnownTracker(domain: tracker.domain,
                        defaultAction: tracker.defaultAction,
                        owner: tracker.owner,
                        prevalence: tracker.prevalence,
                        subdomains: tracker.subdomains,
                        categories: tracker.categories,
                        rules: ctlRules)
                    mainTDSTrackers[key] = mainTracker
                    ctlTrackers[key] = ctlTracker
                } else {
                    // copy tracker as-is
                    mainTDSTrackers[key] = tracker
                }
            }
        }

        return (mainTDSTrackers, ctlTrackers)
    }

//    private func filterTrackersWithoutCTLAction(_ trackers: [String: KnownTracker]) -> [String: KnownTracker] {
//        trackers.filter { (_, tracker) in tracker.containsCTLActions == false }
//    }
//
//    private func filterTrackersWithCTLAction(_ trackers: [String: KnownTracker]) -> [String: KnownTracker] {
//        return Dictionary(uniqueKeysWithValues: trackers.filter { (_, tracker) in
//            return tracker.containsCTLActions == true
//        }.map { (trackerKey, trackerValue) in
//            // Modify the tracker here
//            if let rules = trackerValue.rules as [KnownTracker.Rule]? {
//                let updatedRules = rules.map { (ruleValue) in
//                    var action = ruleValue.action
//                    if action == .blockCtlFB {
//                        if ruleValue.surrogate != nil {
//                            action = nil
//                        } else {
//                            action = .block
//                        }
//                    }
//                    let newRule = KnownTracker.Rule(rule: ruleValue.rule,
//                                       surrogate: ruleValue.surrogate,
//                                        action: action,
//                                       options: ruleValue.options,
//                                       exceptions: ruleValue.exceptions)
//                    return newRule
//                }
//                let updatedTracker = KnownTracker(domain: trackerValue.domain,
//                    defaultAction: trackerValue.defaultAction,
//                    owner: trackerValue.owner,
//                    prevalence: trackerValue.prevalence,
//                    subdomains: trackerValue.subdomains,
//                    categories: trackerValue.categories,
//                    rules: updatedRules)
//
//                return (trackerKey, updatedTracker)
//            }
//
//            return (trackerKey, trackerValue)
//        })
//    }

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
