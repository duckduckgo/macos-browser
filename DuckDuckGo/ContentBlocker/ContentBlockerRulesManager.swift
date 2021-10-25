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

    private let blockingRulesSubject = CurrentValueSubject<WKContentRuleList?, Never>(nil)
    var blockingRules: AnyPublisher<WKContentRuleList?, Never> {
        blockingRulesSubject.eraseToAnyPublisher()
    }

    let privacyConfiguration: PrivacyConfigurationManagment
    
    private init(privacyConfiguration: PrivacyConfigurationManagment = PrivacyConfigurationManager.shared) {
        self.privacyConfiguration = privacyConfiguration
        compileRules()
    }

    func compileRules(completion: ((WKContentRuleList?) -> Void)? = nil) {
        let trackerData = TrackerRadarManager.shared.trackerData
        let unprotectedDomains = loadUnprotectedDomains()
        let protectionStore = DomainsProtectionUserDefaultsStore()
        let userDisabledProtection = protectionStore.unprotectedDomains

        DispatchQueue.global(qos: .background).async {
            self.compileRules(with: trackerData,
                              withExceptions: Array(userDisabledProtection),
                              andTemporaryUnprotectedDomains: unprotectedDomains,
                              completion: completion)
        }
    }

    private func loadUnprotectedDomains() -> [String] {
        let tempUnprotected = privacyConfiguration.tempUnprotectedDomains
        let contentBlockingExceptions = privacyConfiguration.exceptionsList(forFeature: .contentBlocking)
        
        return (tempUnprotected + contentBlockingExceptions).filter { !$0.isEmpty }
    }

    private func compileRules(with trackerData: TrackerData,
                              withExceptions exceptions: [String],
                              andTemporaryUnprotectedDomains tempUnprotectedDomains: [String],
                              completion: ((WKContentRuleList?) -> Void)?) {

        let rules = ContentBlockerRulesBuilder(trackerData: trackerData).buildRules(withExceptions: exceptions,
                                                                                    andTemporaryUnprotectedDomains: tempUnprotectedDomains)
        guard let store = WKContentRuleListStore.default() else {
            assert(false, "Failed to access the default WKContentRuleListStore for rules compiliation checking")
            return
        }
        guard let data = try? JSONEncoder().encode(rules),
              let encoded = String(data: data, encoding: .utf8)
        else {
            assert(false, "Could not encode ContentBlockerRule list")
            return
        }

        store.compileContentRuleList(forIdentifier: "tds", encodedContentRuleList: encoded) { [weak self] ruleList, error in
            guard let self = self else {
                assert(false, "self is gone")
                return
            }

            self.blockingRulesSubject.send(ruleList)
            completion?(ruleList)
            if let error = error {
                os_log("Failed to compile rules %{public}s", type: .error, error.localizedDescription)
            }
        }
    }

}
