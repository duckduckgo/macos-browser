//
//  WebViewTabUpdater.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Cocoa
import WebKit
import os.log

class WebViewTabUpdater: NSObject {

    let webView: WKWebView
    let tab: Tab

    init(webView: WKWebView, tab: Tab) {
        self.webView = webView
        self.tab = tab
        super.init()

        observeWebview()
    }

    private func observeWebview() {
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
    }

    // swiftlint:disable block_based_kvo
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else {
            os_log("%s: keyPath not provided", log: OSLog.Category.general, type: .error, className)
            return
        }

        switch keyPath {
        case #keyPath(WKWebView.url): tab.url = webView.url
        case #keyPath(WKWebView.canGoBack): tab.canGoBack = webView.canGoBack
        case #keyPath(WKWebView.canGoForward): tab.canGoForward = webView.canGoForward
        default:
            os_log("%s: keyPath %s not handled", log: OSLog.Category.general, type: .error, className, keyPath)
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    // swiftlint:enable block_based_kvo

}
