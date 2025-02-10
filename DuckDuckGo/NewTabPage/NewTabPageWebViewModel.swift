//
//  NewTabPageWebViewModel.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import NewTabPage
import WebKit

/**
 * This class manages a dedicated web view for displaying New Tab Page.
 *
 * It initializes NTP user script, the NTP-specific web view configuration
 * and then sets up a new web view with that configuration. It also serves
 * as a navigation delegate for the web view, blocking all navigations other than
 * to the New Tab Page.
 *
 * This class is inspired by `DBPUIViewModel`.
 */
@MainActor
final class NewTabPageWebViewModel: NSObject {
    let newTabPageUserScript: NewTabPageUserScript
    let webView: WebView
    private var cancellables: Set<AnyCancellable> = []

    init(featureFlagger: FeatureFlagger, actionsManager: NewTabPageActionsManager, activeRemoteMessageModel: ActiveRemoteMessageModel) {
        newTabPageUserScript = NewTabPageUserScript()
        actionsManager.registerUserScript(newTabPageUserScript)

        let configuration = WKWebViewConfiguration()
        configuration.applyNewTabPageWebViewConfiguration(with: featureFlagger, newTabPageUserScript: newTabPageUserScript)
        webView = WebView(frame: .zero, configuration: configuration)

        super.init()

        webView.navigationDelegate = self
        webView.load(URLRequest(url: URL.newtab))
        newTabPageUserScript.webView = webView

        webView.publisher(for: \.window)
            .map { $0 != nil }
            .sink { [weak activeRemoteMessageModel] isOnScreen in
                activeRemoteMessageModel?.isViewOnScreen = isOnScreen
                if isOnScreen {
                    NotificationCenter.default.post(name: .newTabPageWebViewDidAppear, object: nil)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .newTabPageModeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.webView.reload()
            }
            .store(in: &cancellables)
    }
}

extension NewTabPageWebViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        navigationAction.request.url == .newtab ? .allow : .cancel
    }
}

extension Notification.Name {
    static var newTabPageWebViewDidAppear = Notification.Name("newTabPageWebViewDidAppear")
}

extension WKWebViewConfiguration {

    @MainActor
    func applyNewTabPageWebViewConfiguration(with featureFlagger: FeatureFlagger, newTabPageUserScript: NewTabPageUserScript) {
        if urlSchemeHandler(forURLScheme: URL.NavigationalScheme.duck.rawValue) == nil {
            setURLSchemeHandler(
                DuckURLSchemeHandler(featureFlagger: featureFlagger, isNTPSpecialPageSupported: true),
                forURLScheme: URL.NavigationalScheme.duck.rawValue
            )
        }
        preferences[.developerExtrasEnabled] = true
        self.userContentController = NewTabPageUserContentController(newTabPageUserScript: newTabPageUserScript)
     }
}
