//
//  ClickToLoad.swift
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
import Combine
import Foundation
import WebKit

final class ClickToLoad {
    
    private weak var tab: Tab?
    private var userScriptsCancellable: AnyCancellable?
    @Injected(default: ContentBlocking.shared.privacyConfigurationManager) private var privacyConfigurationManager: PrivacyConfigurationManaging

    private(set) var fbBlockingEnabled = true

    init(tab: Tab) {
        userScriptsCancellable = tab.userScriptsPublisher.sink { [weak self] userScripts in
            userScripts?.clickToLoadScript.delegate = self
        }
    }

    @discardableResult
    private func setFBProtection(enabled: Bool) -> Bool {
        guard self.fbBlockingEnabled != enabled else { return false }
        if enabled {
            do {
                try tab?.userContentController.enableGlobalContentRuleList(withIdentifier: ContentBlockerRulesLists.Constants.clickToLoadRulesListName)
            } catch {
                assertionFailure("Missing FB List")
                return false
            }
        } else {
            do {
                try tab?.userContentController.disableGlobalContentRuleList(withIdentifier: ContentBlockerRulesLists.Constants.clickToLoadRulesListName)
            } catch {
                assertionFailure("FB List was not enabled")
                return false
            }
        }
        self.fbBlockingEnabled = enabled

        return true
    }

    private func updateFBProtectionEnabled(for url: URL) {
        // Enable/disable FBProtection only after UserScripts are installed (awaitContentBlockingAssetsInstalled)
        let featureEnabled = privacyConfigurationManager.privacyConfig.isFeature(.clickToPlay, enabledForDomain: url.host)
        setFBProtection(enabled: featureEnabled)
    }

}

extension ClickToLoad: ClickToLoadUserScriptDelegate {

    func clickToLoadUserScriptAllowFB(_ script: ClickToLoadUserScript, replyHandler: @escaping (Bool) -> Void) {
        guard self.fbBlockingEnabled else {
            replyHandler(true)
            return
        }

        if setFBProtection(enabled: false) {
            replyHandler(true)
        } else {
            replyHandler(false)
        }
    }

}

extension ClickToLoad: NavigationResponder {

    func webView(_: WebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        navigationAction.request.url.map(updateFBProtectionEnabled(for:))

        return .next
    }

}
