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

final class AdClickAttributionTabExtension {

    struct Dependencies {
        @Injected(default: ContentBlocking.shared.contentBlockingManager.currentRules) static var currentRules: [ContentBlockerRulesManager.Rules]
    }

    private weak var tab: Tab?
    private var cancellables = Set<AnyCancellable>()

    let detection = ContentBlocking.shared.makeAdClickAttributionDetection()
    let logic = ContentBlocking.shared.makeAdClickAttributionLogic()

    private var state: AdClickAttributionLogic.State? {
        logic.state
    }

    init(tab: Tab) {
        self.tab = tab
        initAttributionLogic(tab: tab)
    }

    public var currentAttributionState: AdClickAttributionLogic.State? {
        logic.state
    }

    private func initAttributionLogic(tab: Tab) {
        logic.delegate = self
        detection.delegate = logic

        if let state = tab.parentTab?.extensions.adClickAttribution?.state {
            logic.applyInheritedAttribution(state: state)
        }

        tab.userContentController.$contentBlockingAssets
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.logic.onRulesChanged(latestRules: Dependencies.currentRules)
            }
            .store(in: &cancellables)

        tab.$trackerInfo
            .scan((old: Set<DetectedRequest>(), new: tab.trackerInfo?.trackers ?? [])) {
                ($0.new, $1?.trackers ?? [])
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

extension AdClickAttributionTabExtension: NavigationResponder {

    func webView(_ webView: WebView, willGoTo backForwardListItem: WKBackForwardListItem, inPageCache: Bool) {
        // TODO: Validate this is really called twice
        guard webView.mainFrameNavigation?.contains(where: {
            if case .willGoToBackForwardListItem(backForwardListItem, inPageCache: inPageCache) = $0 { return true }; return false
        }) == true else { return }
        self.logic.onBackForwardNavigation(mainFrameURL: backForwardListItem.url)
    }

    func webView(_ webView: WebView, didStart navigation: WKNavigation, with request: URLRequest) {
        self.detection.onStartNavigation(url: webView.url)
    }

    func webView(_ webView: WebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy? {
        if navigationResponse.isForMainFrame && navigationResponse.response.isSuccessfulHTTPURLResponse {
            self.detection.on2XXResponse(url: webView.url)
        }

        await self.logic.onProvisionalNavigation()
        return .next
    }

    func webView(_ webView: WebView, didFinish navigation: WKNavigation, with request: URLRequest) {
        self.detection.onDidFinishNavigation(url: webView.url)
        self.logic.onDidFinishNavigation(host: webView.url?.host)
    }

    func webView(_ webView: WebView, navigation: WKNavigation, with request: URLRequest, didFailWith error: Error) {
        self.detection.onDidFailNavigation()
    }

}
