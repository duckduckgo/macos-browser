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
import WebKit

/**
 * This class manages
 */
@MainActor
final class NewTabPageWebViewModel: NSObject {
    let newTabPageUserScript: NewTabPageUserScript
    let webView: WebView

    init(featureFlagger: FeatureFlagger, actionsManager: NewTabPageActionsManaging) {
        newTabPageUserScript = NewTabPageUserScript(actionsManager: actionsManager)

        let configuration = WKWebViewConfiguration()
        configuration.applyNewTabPageWebViewConfiguration(with: featureFlagger, newTabPageUserScript: newTabPageUserScript)
        webView = WebView(frame: .zero, configuration: configuration)

        super.init()

        webView.navigationDelegate = self
        webView.load(URLRequest(url: URL.newtab))
        newTabPageUserScript.webView = webView
    }
}

extension NewTabPageWebViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        navigationAction.request.url == .newtab ? .allow : .cancel
    }
}
