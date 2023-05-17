//
//  DataBrokerWebViewHandler.swift
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

@MainActor
final class DataBrokerWebViewHandler {
    var webView: WKWebView?
    let webViewConfiguration: WKWebViewConfiguration
    let userContentController: DataBrokerUserContentController?

    init(delegate: DataBrokerMessagingDelegate) {
        let privacyFeatures = PrivacyFeatures

        let configuration = WKWebViewConfiguration()
        configuration.applyDataBrokerConfiguration(contentBlocking: privacyFeatures.contentBlocking, delegate: delegate)
        self.webViewConfiguration = configuration

        let userContentController = configuration.userContentController as? DataBrokerUserContentController
        assert(userContentController != nil)
        self.userContentController = userContentController
    }

    func test() {
        webView = WebView(frame: CGRect(origin: .zero, size: CGSize(width: 1024, height: 1024)), configuration: webViewConfiguration)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), styleMask: [.titled],
            backing: .buffered, defer: false
        )
        window.title = "Debug"
        window.contentView = self.webView
        window.makeKeyAndOrderFront(nil)

        self.webView?.load(URLRequest(url: URL(string: "https://www.example.com")!))
    }

    func sendAction() {
        Task {
            self.userContentController?.dataBrokerUserScripts.dataBrokerMessaging.sendAction(action: "")
        }
    }
}
