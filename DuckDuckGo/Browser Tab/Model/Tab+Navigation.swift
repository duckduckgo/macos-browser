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

import Navigation
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

            // should be the last, for Unit Tests navigation events tracking
            .struct(nullable: testsClosureNavigationResponder)
        )
        navigationDelegate
            .registerCustomDelegateMethodHandler(.weak(self), forSelectorNamed: "_webView:contextMenuDidCreateDownload:")
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
