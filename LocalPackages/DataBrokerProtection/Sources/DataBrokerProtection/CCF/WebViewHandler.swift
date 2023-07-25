//
//  WebViewHandler.swift
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
import Common

protocol WebViewHandler: NSObject {
    func initializeWebView(debug: Bool) async
    func load(url: URL) async throws
    func waitForWebViewLoad(timeoutInSeconds: Int) async throws
    func finish() async
    func execute(action: Action, data: CCFRequestData) async
}

@MainActor
final class DataBrokerProtectionWebViewHandler: NSObject, WebViewHandler {
    private var activeContinuation: CheckedContinuation<Void, Error>?

    private let isFakeBroker: Bool
    private let webViewConfiguration: WKWebViewConfiguration
    private let userContentController: DataBrokerUserContentController?

    private var webView: WKWebView?
    private var window: NSWindow?

    init(privacyConfig: PrivacyConfigurationManaging, prefs: ContentScopeProperties, delegate: CCFCommunicationDelegate, isFakeBroker: Bool = false) {
        let configuration = WKWebViewConfiguration()
        configuration.applyDataBrokerConfiguration(privacyConfig: privacyConfig, prefs: prefs, delegate: delegate)
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        self.webViewConfiguration = configuration
        self.isFakeBroker = isFakeBroker

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

        try? await load(url: URL(string: "\(WebViewSchemeHandler.dataBrokerProtectionScheme)://blank")!)
    }

    func load(url: URL) async throws {
        webView?.load(url)
        os_log("Loading URL: %@", log: .action, String(describing: url.absoluteString))
        try await waitForWebViewLoad(timeoutInSeconds: 60)
    }

    func finish() {
        os_log("WebViewHandler finished", log: .action)
        webView?.stopLoading()
        webView = nil
    }

    func waitForWebViewLoad(timeoutInSeconds: Int = 0) async throws {
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

    func execute(action: Action, data: CCFRequestData) {
        os_log("Executing action: %{public}@", log: .action, String(describing: action.actionType.rawValue))

        userContentController?.dataBrokerUserScripts.dataBrokerFeature.pushAction(
            method: .onActionReceived,
            webView: self.webView!,
            params: Params(state: ActionRequest(action: action, data: data))
        )
    }
}

extension DataBrokerProtectionWebViewHandler: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        os_log("WebViewHandler didFinish", log: .action)

        self.activeContinuation?.resume()
        self.activeContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        os_log("WebViewHandler didFail: %{public}@", log: .action, String(describing: error.localizedDescription))
        self.activeContinuation?.resume(throwing: error)
        self.activeContinuation = nil
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if !isFakeBroker {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            guard let serverTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ||
                    challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest {

            let fakeBrokerCredentials = HTTPUtils.fetchFakeBrokerCredentials()
            let credential = URLCredential(user: fakeBrokerCredentials.username, password: fakeBrokerCredentials.password, persistence: .none)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
