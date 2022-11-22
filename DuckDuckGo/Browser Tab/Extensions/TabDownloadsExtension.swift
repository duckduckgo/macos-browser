//
//  TabDownloadsExtension.swift
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

import Foundation
import WebKit

final class TabDownloadsExtension: NavigationResponder {

    private weak var tab: Tab?

    init(tab: Tab) {
        self.tab = tab
    }

    func webView(_ webView: WebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {

        var isDownloadLinkAction: Bool {
            // TODO: move NSApp modifier options check to dependedncies
            navigationAction.navigationType == .linkActivated && NSApp.isOptionPressed && !NSApp.isCommandPressed
        }

        if navigationAction.shouldDownload || isDownloadLinkAction {
            return .download
        }

        return .next
    }

    func webView(_ webView: WebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy? {
        guard !navigationResponse.canShowMIMEType || navigationResponse.shouldDownload else { return .next }

        if navigationResponse.response.isSuccessfulHTTPURLResponse {
            // register the navigationResponse for legacy _WKDownload to be called back on the Tab
            // further download will be passed to webView:navigationResponse:didBecomeDownload:
            return .download(navigationResponse, using: webView)
            // prevent download twice
            // TODO: redirect(ro: .privateScheme(.download_succecss(navigationResponse.response.url)))
        }

        return .next
    }

    func webView(_ webView: WebView, navigationAction: WKNavigationAction, didBecome download: WebKitDownload) {
        FileDownloadManager.shared.add(download, delegate: tab?.delegate, location: .auto, postflight: .none)
    }

    func webView(_ webView: WebView, navigationResponse: WKNavigationResponse, didBecome download: WebKitDownload) {
        FileDownloadManager.shared.add(download, delegate: tab?.delegate, location: .auto, postflight: .none)

        // Note this can result in tabs being left open, e.g. download button on this page:
        // https://en.wikipedia.org/wiki/Guitar#/media/File:GuitareClassique5.png
        // Safari closes new tabs that were opened and then create a download instantly.
        if webView.backForwardList.currentItem == nil, self.tab?.parentTab != nil {
            DispatchQueue.main.async { [weak webView] in
                webView?.close()
            }
        }
    }

}
