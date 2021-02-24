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

class WebViewStateObserver: NSObject {

    weak var webView: WKWebView?
    weak var tabViewModel: TabViewModel?

    init(webView: WKWebView, tabViewModel: TabViewModel) {
        self.webView = webView
        self.tabViewModel = tabViewModel
        super.init()

        matchFlagValues()
        observe(webView: webView)
    }

    deinit {
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.isLoading))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }

    private func matchFlagValues() {
        guard let tabViewModel = tabViewModel else {
            os_log("%s: TabViewModel was released from memory", type: .error, className)
            return
        }

        guard let webView = webView else {
            os_log("%s: TabViewModel was released from memory", type: .error, className)
            return
        }

        tabViewModel.canGoBack = webView.canGoBack
        tabViewModel.canGoForward = webView.canGoForward
        tabViewModel.isLoading = webView.isLoading
    }

    private func observe(webView: WKWebView) {
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else {
            os_log("%s: keyPath not provided", type: .error, className)
            return
        }

        guard let tabViewModel = tabViewModel else {
            os_log("%s: TabViewModel was released from memory", type: .error, className)
            return
        }

        guard let webView = webView else {
            os_log("%s: TabViewModel was released from memory", type: .error, className)
            return
        }

        switch keyPath {
        case #keyPath(WKWebView.url):
            tabViewModel.tab.url = webView.url
            updateTitle() // The title might not change if webView doesn't think anything is different so update title here as well

        case #keyPath(WKWebView.canGoBack): tabViewModel.canGoBack = webView.canGoBack
        case #keyPath(WKWebView.canGoForward): tabViewModel.canGoForward = webView.canGoForward
        case #keyPath(WKWebView.isLoading): tabViewModel.isLoading = webView.isLoading
        case #keyPath(WKWebView.title): updateTitle()
        case #keyPath(WKWebView.estimatedProgress): tabViewModel.progress = webView.estimatedProgress
        default:
            os_log("%s: keyPath %s not handled", type: .error, className, keyPath)
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    private func updateTitle() {
        if webView?.title?.trimmingWhitespaces().isEmpty ?? true {
            tabViewModel?.tab.title = webView?.url?.host?.drop(prefix: "www.")
            return
        }

        tabViewModel?.tab.title = webView?.title
    }

}
