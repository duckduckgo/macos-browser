//
//  ContentBlockerRulesManager.swift
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
import WebKit
import os.log
import TrackerRadarKit
import Combine

final class ContentBlockerRulesManager {

    static let shared = ContentBlockerRulesManager()

    @Published private(set) var blockingRules: Loadable<WKContentRuleList?>

    private let store: WKContentRuleListStore = {
        guard let store = WKContentRuleListStore.default() else {
            assert(false, "Failed to access the default WKContentRuleListStore for rules compiliation checking")
            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("contentRules")
            return WKContentRuleListStore(url: url)
        }
        return store
    }()

    private static let identifier = "tds"

    private init() {
        self.blockingRules = .loading

        // try loading rules from previous session
        store.lookUpContentRuleList(forIdentifier: Self.identifier) { [weak self] (ruleList, _) in
            dispatchPrecondition(condition: .onQueue(.main))
            guard let self = self else { return }

            if let rules = ruleList {
                self.blockingRules = .loaded(rules)
            } else {
                self.compileRules()
            }
        }
    }

    func compileRules(completion: ((WKContentRuleList?) -> Void)? = nil) {
        let trackerData = TrackerRadarManager.shared.trackerData

        // run initial rules compilation initiated from main thread with higher priority
        let qos: DispatchQoS.QoSClass = Thread.isMainThread ? .userInitiated : .background
        DispatchQueue.global(qos: qos).async {
            self.compileRules(with: trackerData, completion: completion)
        }
    }

    private func compileRules(with trackerData: TrackerData, completion: ((WKContentRuleList?) -> Void)?) {
        let rules = ContentBlockerRulesBuilder(trackerData: trackerData).buildRules(withExceptions: [],
                                                                                    andTemporaryUnprotectedDomains: [])

        guard let data = try? JSONEncoder().encode(rules),
              let encoded = String(data: data, encoding: .utf8)
        else {
            assert(false, "Could not encode ContentBlockerRule list")
            return
        }

        store.compileContentRuleList(forIdentifier: Self.identifier, encodedContentRuleList: encoded) { [weak self] ruleList, error in
            guard let self = self else {
                assert(false, "self is gone")
                return
            }

            switch self.blockingRules {
            // only populate rules when never loaded before
            case .loading, .loaded(.none),
                 // or when actually loaded
                 .loaded(.some) where ruleList != nil:
                self.blockingRules = .loaded(ruleList)
            case .loaded(.some):
                // don't populate if had loaded some before and failed to compile
                break
            }

            completion?(ruleList)
            if let error = error {
                os_log("Failed to compile rules %{public}s", type: .error, error.localizedDescription)
            }
        }
    }

}
