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

import Combine
import Foundation
import BrowserServicesKit

extension Tab {
    var adClickAttribution: AdClickAttributionTabExtension? { extensions.get(AdClickAttributionTabExtension.self) }
}

extension DependencyProvider<AdClickAttributionTabExtension> {
    var currentRules: [ContentBlockerRulesManager.Rules] { ContentBlocking.shared.contentBlockingManager.currentRules }
}

final class AdClickAttributionTabExtension: TabExtension, DependencyProviderClient {

    private weak var tab: Tab?
    private let adClickAttributionDetection = ContentBlocking.shared.makeAdClickAttributionDetection()
    private let adClickAttributionLogic = ContentBlocking.shared.makeAdClickAttributionLogic()
    private var cancellables = Set<AnyCancellable>()

    private var state: AdClickAttributionLogic.State? {
        adClickAttributionLogic.state
    }

    init(tab: Tab) {
        self.tab = tab
        initAttributionLogic(tab: tab)
    }

    private func initAttributionLogic(tab: Tab) {
        let state = tab.parentTab?.adClickAttribution?.state
        adClickAttributionLogic.delegate = self
        adClickAttributionDetection.delegate = adClickAttributionLogic

        if let state = state {
            adClickAttributionLogic.applyInheritedAttribution(state: state)
        }

        tab.userContentController.$contentBlockingAssets
            .sink { [weak self] _ in
                self?.adClickAttributionLogic.onRulesChanged(latestRules: self!.dependencyProvider.currentRules)
            }
            .store(in: &cancellables)

        tab.$trackerInfo
            .scan((old: Set<DetectedRequest>(), new: tab.trackerInfo?.trackers ?? [])) {
                ($0.new, $1?.trackers ?? [])
            }
            .sink { [weak self] (old, new) in
                for tracker in new.subtracting(old) {
                    self?.adClickAttributionLogic.onRequestDetected(request: tracker)
                }
            }
            .store(in: &cancellables)
    }

}

extension AdClickAttributionTabExtension: AdClickAttributionLogicDelegate {

    func attributionLogic(_ logic: AdClickAttributionLogic,
                          didRequestRuleApplication rules: ContentBlockerRulesManager.Rules?,
                          forVendor vendor: String?) {
        let contentBlockerRulesScript = tab?.userScripts?.contentBlockerRulesScript
        let attributedTempListName = AdClickAttributionRulesProvider.Constants.attributedTempRuleListName

        guard ContentBlocking.shared.privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking)
        else {
            tab?.userContentController.removeLocalContentRuleList(withIdentifier: attributedTempListName)
            contentBlockerRulesScript?.currentAdClickAttributionVendor = nil
            contentBlockerRulesScript?.supplementaryTrackerData = []
            return
        }

        contentBlockerRulesScript?.currentAdClickAttributionVendor = vendor
        if let rules = rules {

            let globalListName = DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName
            let globalAttributionListName = AdClickAttributionRulesSplitter.blockingAttributionRuleListName(forListNamed: globalListName)

            if vendor != nil {
                tab?.userContentController.installLocalContentRuleList(rules.rulesList, identifier: attributedTempListName)
                try? tab?.userContentController.disableGlobalContentRuleList(withIdentifier: globalAttributionListName)
            } else {
                tab?.userContentController.removeLocalContentRuleList(withIdentifier: attributedTempListName)
                try? tab?.userContentController.enableGlobalContentRuleList(withIdentifier: globalAttributionListName)
            }

            contentBlockerRulesScript?.supplementaryTrackerData = [rules.trackerData]
        } else {
            contentBlockerRulesScript?.supplementaryTrackerData = []
        }
    }

}

// TODO: Maybe this is not needed
extension AdClickAttributionTabExtension: PartialNavigationPolicyHandler {

    func decidePolicy(for navigationAction: NavigationAction) async -> NavigationActionPolicy? {
        return nil
    }

}
