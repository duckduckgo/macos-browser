//
//  ReferrerTrimmingTabExtension.swift
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

import BrowserServicesKit
import Common
import Foundation
import WebKit

struct ReferrerTrimmingTabExtension: TabExtension {

    struct Dependencies {
        @Injected(default: ContentBlocking.shared.privacyConfigurationManager) static var privacyManager: PrivacyConfigurationManaging
        @Injected(default: ContentBlocking.shared.contentBlockingManager) static var contentBlockingManager: ContentBlockerRulesManager
        @Injected(default: ContentBlocking.shared.tld) static var tld: TLD
    }


    private let referrerTrimming: ReferrerTrimming

    init() {
        referrerTrimming = ReferrerTrimming(privacyManager: Dependencies.privacyManager,
                                            contentBlockingManager: Dependencies.contentBlockingManager,
                                            tld: Dependencies.tld)
    }

    func attach(to tab: Tab) {
    }
    
}

extension ReferrerTrimmingTabExtension: NavigationResponder {

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        guard navigationAction.isForMainFrame,
              navigationAction.navigationType != .backForward,
              let newRequest = referrerTrimming.trimReferrer(for: navigationAction.request, originUrl: navigationAction.sourceFrame.url)
        else {
            return .next
        }

        // TODO: Can it be POST so we need webView.load(request)?
        // in fact we need to differentiate between redirect for committed navigations and for not
        return .redirect(request: newRequest)
    }

    func didStart(_ navigation: Navigation) {
        referrerTrimming.onBeginNavigation(to: navigation.url)
    }

    func navigationDidFinishOrReceivedClientRedirect(_ navigation: Navigation) {
        referrerTrimming.onFinishNavigation()
    }

    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        referrerTrimming.onFailedNavigation()
    }

}
