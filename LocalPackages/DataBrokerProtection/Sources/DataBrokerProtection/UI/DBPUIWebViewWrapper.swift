//
//  DBPUIWebViewWrapper.swift
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

import AppKit
import SwiftUI
import WebKit
import BrowserServicesKit

struct DBPUIWebViewWrapper: NSViewRepresentable {
    typealias NSViewType = WKWebView

    let privacyConfig: PrivacyConfigurationManaging?
    let prefs: ContentScopeProperties?

    init(privacyConfig: PrivacyConfigurationManaging? = nil,
         prefs: ContentScopeProperties? = nil) {
        self.privacyConfig = privacyConfig
        self.prefs = prefs
    }

    func makeNSView(context: Context) -> WKWebView {
        guard let privacyConfig = privacyConfig else { return WKWebView() }
        guard let prefs = prefs else { return WKWebView() }

        let configuration = WKWebViewConfiguration()
        configuration.applyDBPUIConfiguration(privacyConfig: privacyConfig, prefs: prefs)
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        return WKWebView(frame: .zero, configuration: configuration)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: URL(string: "about:blank")!)
        webView.load(request)
    }
}
