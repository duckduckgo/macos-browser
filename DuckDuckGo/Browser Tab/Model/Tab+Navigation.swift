//
//  Tab+Navigation.swift
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

extension Tab: NavigationResponder {

    // "protected"
    private var navigationDelegate: DistributedNavigationDelegate! {
        self.value(forKeyPath: Tab.objcNavigationDelegateKeyPath) as? DistributedNavigationDelegate
    }

    func setupNavigationDelegate() {
        navigationDelegate.setResponders(
            .weak(self),

            .weak(nullable: self.adClickAttribution),

            .weak(nullable: self.privacyDashboard),
            .weak(nullable: self.httpsUpgrade),
            .weak(nullable: self.contentBlockingAndSurrogates),

            .struct(SerpHeadersNavigationResponder()),

            .weak(nullable: self.fbProtection)
        )
        navigationDelegate.registerCustomDelegateMethodHandler(.weak(self), for: #selector(webView(_:contextMenuDidCreate:)))
    }

    func didCancel(_ navigationAction: NavigationAction, with relatedAction: NavigationActionCancellationRelatedAction) {
        if case .redirect(let request) = relatedAction {
            invalidateBackItemIfNeeded(for: navigationAction)
            DispatchQueue.main.async { [weak webView] in
                webView?.load(request)
            }
        }
    }

}

extension Tab: WKNavigationDelegate {

    @objc(_webView:contextMenuDidCreateDownload:)
    func webView(_ webView: WKWebView, contextMenuDidCreate download: WebKitDownload) {
        let location: FileDownloadManager.DownloadLocationPreference
            = self.contextMenuManager?.shouldAskForDownloadLocation() == false ? .auto : .prompt
        FileDownloadManager.shared.add(download, delegate: self, location: location, postflight: .none)
    }

}
