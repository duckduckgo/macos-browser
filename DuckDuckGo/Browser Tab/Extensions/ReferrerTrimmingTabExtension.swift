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

    func webView(_ webView: WebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        guard navigationAction.isTargetingMainFrame,
              navigationAction.navigationType != .backForward,
              let newRequest = referrerTrimming.trimReferrer(forNavigation: navigationAction, originUrl: navigationAction.sourceFrame.request.url)
        else {
            return .next
        }

        // TODO: Can it be POST so we need webView.load(request)?
        // in fact we need to differentiate between redirect for committed navigations and for not
        return .redirect(request: newRequest)
    }

    func webView(_ webView: WebView, didStart navigation: WKNavigation, with request: URLRequest) {
        referrerTrimming.onBeginNavigation(to: webView.url)
    }

    func webView(_ webView: WebView, didFinish navigation: WKNavigation, with request: URLRequest) {
        referrerTrimming.onFinishNavigation()
    }

    func webView(_ webView: WebView, navigation: WKNavigation, with request: URLRequest, didFailWith error: Error) {
        referrerTrimming.onFailedNavigation()
    }

}
