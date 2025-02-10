//
//  HistoryWebViewModel.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import HistoryView
import WebKit

/**
 * This class manages a dedicated web view for displaying History View.
 *
 * It initializes History View user script, the domain-specific web view configuration
 * and then sets up a new web view with that configuration. It also serves
 * as a navigation delegate for the web view, blocking all navigations other than
 * to the History page.
 *
 * This class is inspired by `DBPUIViewModel` and a sibling to `NewTabPageWebViewModel`.
 */
@MainActor
final class HistoryWebViewModel: NSObject {
    let historyViewUserScript: HistoryViewUserScript
    let webView: WebView
    private var windowCancellable: AnyCancellable?

    init(featureFlagger: FeatureFlagger, actionsManager: HistoryViewActionsManager) {
        historyViewUserScript = HistoryViewUserScript()
        actionsManager.registerUserScript(historyViewUserScript)

        let configuration = WKWebViewConfiguration()
        configuration.applyHistoryWebViewConfiguration(with: featureFlagger, historyViewUserScript: historyViewUserScript)
        webView = WebView(frame: .zero, configuration: configuration)

        super.init()

        webView.navigationDelegate = self
        webView.load(URLRequest(url: URL.history))
        historyViewUserScript.webView = webView

        windowCancellable = webView.publisher(for: \.window)
            .map { $0 != nil }
            .sink { isOnScreen in
                if isOnScreen {
                    NotificationCenter.default.post(name: .historyWebViewDidAppear, object: nil)
                }
            }
    }
}

extension HistoryWebViewModel: WKNavigationDelegate {
    /// Allow loading all URLs with `duck` scheme and `history` host.
    /// Deny all other URLs.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        let isDuckScheme = navigationAction.request.url?.isDuckURLScheme == true
        let isHistoryHost = navigationAction.request.url?.host == URL.history.host
        return (isDuckScheme && isHistoryHost) ? .allow : .cancel
    }
}

extension Notification.Name {
    static var historyWebViewDidAppear = Notification.Name("historyWebViewDidAppear")
}

extension WKWebViewConfiguration {

    @MainActor
    func applyHistoryWebViewConfiguration(with featureFlagger: FeatureFlagger, historyViewUserScript: HistoryViewUserScript) {
        if urlSchemeHandler(forURLScheme: URL.NavigationalScheme.duck.rawValue) == nil {
            setURLSchemeHandler(
                DuckURLSchemeHandler(featureFlagger: featureFlagger, isHistorySpecialPageSupported: true),
                forURLScheme: URL.NavigationalScheme.duck.rawValue
            )
        }
        preferences[.developerExtrasEnabled] = true
        self.userContentController = HistoryViewUserContentController(historyViewUserScript: historyViewUserScript)
     }
}
