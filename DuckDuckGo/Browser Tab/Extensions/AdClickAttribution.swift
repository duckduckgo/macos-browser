//
//  AdClickAttribution.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import os.log
import Combine
import Common
import ContentBlocking
import Foundation
import BrowserServicesKit

final class AdClickAttributionTabExtension: TabExtension {

    private weak var tab: Tab?
    private var cancellables = Set<AnyCancellable>()

    private static func makeAdClickAttributionFeature(with privacyConfigurationManager: PrivacyConfigurationManaging) -> AdClickAttributionFeature {
        AdClickAttributionFeature(with: privacyConfigurationManager)
    }
    private static func makeAdClickAttributionDetection(featureConfig: AdClickAttributing) -> AdClickAttributionDetection {
#if DEBUG
        if AppDelegate.isRunningTests {
            return AdClickAttributionDetection(feature: featureConfig,
                                               tld: TLD(),
                                               eventReporting: nil,
                                               errorReporting: nil,
                                               log: .disabled)
        }
#endif
        return AdClickAttributionDetection(feature: featureConfig,
                                           tld: ContentBlocking.shared.tld,
                                           eventReporting: ContentBlocking.shared.attributionEvents,
                                           errorReporting: ContentBlocking.shared.attributionDebugEvents,
                                           log: OSLog.attribution)

    }

    private static func makeAdClickAttributionLogic(featureConfig: AdClickAttributing) -> AdClickAttributionLogic {
#if DEBUG
        if AppDelegate.isRunningTests {
            let rulesProvider: AdClickAttributionRulesProviding =
                ((NSClassFromString("EmptyAttributionRulesProver") as? (NSObject).Type)!.init() as? AdClickAttributionRulesProviding)!

            return AdClickAttributionLogic(featureConfig: featureConfig,
                                           rulesProvider: rulesProvider,
                                           tld: TLD(),
                                           eventReporting: nil,
                                           errorReporting: nil,
                                           log: .disabled)
        }
#endif
        return AdClickAttributionLogic(featureConfig: ContentBlocking.shared.adClickAttribution,
                                       rulesProvider: ContentBlocking.shared.adClickAttributionRulesProvider,
                                       tld: ContentBlocking.shared.tld,
                                       eventReporting: ContentBlocking.shared.attributionEvents,
                                       errorReporting: ContentBlocking.shared.attributionDebugEvents,
                                       log: OSLog.attribution)
    }

    private(set) var detection: AdClickAttributionDetection!
    private(set) var logic: AdClickAttributionLogic!

    static var currentRules: () -> [ContentBlockerRulesManager.Rules] = { ContentBlocking.shared.contentBlockingManager.currentRules }

    private var state: AdClickAttributionLogic.State? {
        logic.state
    }

    init() {}

    public var currentAttributionState: AdClickAttributionLogic.State? {
        logic.state
    }

    func attach(to tab: Tab) {
        self.tab = tab

        let adClickAttributionFeature = Self.makeAdClickAttributionFeature(with: tab.privacyConfigurationManager)
        self.detection = Self.makeAdClickAttributionDetection(featureConfig: adClickAttributionFeature)
        self.logic = Self.makeAdClickAttributionLogic(featureConfig: adClickAttributionFeature)

        logic.delegate = self
        detection.delegate = logic

        if let state = tab.parentTab?.extensions.adClickAttribution?.state {
            logic.applyInheritedAttribution(state: state)
        }

        tab.userContentController.$contentBlockingAssets
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.logic.onRulesChanged(latestRules: Self.currentRules())
            }
            .store(in: &cancellables)

        tab.$privacyInfo.compactMap { $0?.$trackerInfo }
            .switchToLatest()
            .scan((old: Set<DetectedRequest>(), new: tab.privacyInfo?.trackerInfo.trackers ?? [])) {
                ($0.new, $1.trackers)
            }
            .sink { [weak self] (old, new) in
                for tracker in new.subtracting(old) {
                    self?.logic.onRequestDetected(request: tracker)
                }
            }
            .store(in: &cancellables)
    }

}

extension AdClickAttributionTabExtension: AdClickAttributionLogicDelegate {

    func attributionLogic(_ logic: AdClickAttributionLogic,
                          didRequestRuleApplication rules: ContentBlockerRulesManager.Rules?,
                          forVendor vendor: String?) {
        guard let userContentController = tab?.userContentController,
              let userScripts = userContentController.contentBlockingAssets?.userScripts as? UserScripts
        else {
            assertionFailure("UserScripts not loaded")
            return
        }

        let contentBlockerRulesScript = userScripts.contentBlockerRulesScript
        let attributedTempListName = AdClickAttributionRulesProvider.Constants.attributedTempRuleListName

        guard ContentBlocking.shared.privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking)
        else {
            userContentController.removeLocalContentRuleList(withIdentifier: attributedTempListName)
            contentBlockerRulesScript.currentAdClickAttributionVendor = nil
            contentBlockerRulesScript.supplementaryTrackerData = []
            return
        }

        contentBlockerRulesScript.currentAdClickAttributionVendor = vendor
        if let rules = rules {

            let globalListName = DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName
            let globalAttributionListName = AdClickAttributionRulesSplitter.blockingAttributionRuleListName(forListNamed: globalListName)

            if vendor != nil {
                userContentController.installLocalContentRuleList(rules.rulesList, identifier: attributedTempListName)
                try? userContentController.disableGlobalContentRuleList(withIdentifier: globalAttributionListName)
            } else {
                userContentController.removeLocalContentRuleList(withIdentifier: attributedTempListName)
                try? userContentController.enableGlobalContentRuleList(withIdentifier: globalAttributionListName)
            }

            contentBlockerRulesScript.supplementaryTrackerData = [rules.trackerData]
        } else {
            contentBlockerRulesScript.supplementaryTrackerData = []
        }
    }

}
