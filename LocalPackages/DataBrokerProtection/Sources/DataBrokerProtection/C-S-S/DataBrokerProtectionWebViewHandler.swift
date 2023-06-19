//
//  DataBrokerProtectionWebViewHandler.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit
import UserScript

@MainActor
internal class DataBrokerProtectionWebViewHandler: NSObject {
    private var activeContinuation: CheckedContinuation<Void, Error>?

    let webViewConfiguration: WKWebViewConfiguration
    let userContentController: DataBrokerUserContentController?

    var webView: WKWebView?
    var window: NSWindow?

    init(privacyConfig: PrivacyConfigurationManaging, prefs: ContentScopeProperties, delegate: CSSCommunicationDelegate) {
        let configuration = WKWebViewConfiguration()
        configuration.applyDataBrokerConfiguration(privacyConfig: privacyConfig, prefs: prefs, delegate: delegate)
        self.webViewConfiguration = configuration

        let userContentController = configuration.userContentController as? DataBrokerUserContentController
        assert(userContentController != nil)
        self.userContentController = userContentController
    }

    func initializeWebView(debug: Bool = true) async {
        webView = WKWebView(frame: CGRect(origin: .zero, size: CGSize(width: 1024, height: 1024)), configuration: webViewConfiguration)
        webView?.navigationDelegate = self

        if debug {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), styleMask: [.titled],
                backing: .buffered, defer: false
            )
            window?.title = "Debug"
            window?.contentView = self.webView
            window?.makeKeyAndOrderFront(nil)
        }

        try? await self.load(url: URL(string: "https://www.duckduckgo.com")!)
    }

    func load(url: URL) async throws {
        webView?.load(url)
        try await waitForWebViewLoad(timeoutInSeconds: 60)
    }

    func finish() {
        webView?.stopLoading()
        webView = nil
    }

    private func waitForWebViewLoad(timeoutInSeconds: Int = 0) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.activeContinuation = continuation

            if timeoutInSeconds > 0 {
                Task {
                    try await Task.sleep(nanoseconds: UInt64(timeoutInSeconds) * NSEC_PER_SEC)
                    if self.activeContinuation != nil {
                        self.activeContinuation?.resume()
                        self.activeContinuation = nil
                    }
                }
            }
        }
    }

    func execute(action: Action, profileData: ProfileQuery) {
        userContentController?.dataBrokerUserScripts.dataBrokerFeature.pushAction(
            method: .onActionReceived,
            webView: self.webView!,
            params: Params(state: State(action: action, profileData: profileData))
        )
    }
}

extension DataBrokerProtectionWebViewHandler: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.activeContinuation?.resume()
        self.activeContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.activeContinuation?.resume(throwing: error)
        self.activeContinuation = nil
    }
}
