//
//  WebExtensionInternalSiteHandler.swift
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

@available(macOS 14.4, *)
protocol WebExtensionInternalSiteHandlerDataSource {

    func webExtensionContextForUrl(_ url: URL) -> _WKWebExtensionContext?

}

@available(macOS 14.4, *)
final class WebExtensionInternalSiteHandler {

    let navigationDelegate = WebExtensionInternalSiteNavigationDelegate()
    var dataSource: WebExtensionInternalSiteHandlerDataSource?

    private var webViewTabCache: Tab?

    @MainActor
    func webViewForExtensionUrl(_ url: URL) -> WebView? {
        guard let configuration = dataSource?.webExtensionContextForUrl(url)?.webViewConfiguration else {
            return nil
        }

        if webViewTabCache == nil {
            webViewTabCache = Tab(content: .url(url, source: .ui),
                                  webViewConfiguration: configuration)
        }
        webViewTabCache?.webView.navigationDelegate = navigationDelegate
        return webViewTabCache?.webView
    }

}
