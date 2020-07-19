//
//  BrowserTabViewController.swift
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
import Combine

class BrowserTabViewController: NSViewController {

    @IBOutlet weak var webView: WKWebView!

    let tabViewModel: TabViewModel
    let historyViewModel: HistoryViewModel
    var webViewStateObserver: WebViewStateObserver?
    var urlCancelable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("BrowserTabViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabViewModel: TabViewModel, historyViewModel: HistoryViewModel) {
        self.tabViewModel = tabViewModel
        self.historyViewModel = historyViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        tabViewModel.tab.actionDelegate = self

        webViewStateObserver = WebViewStateObserver(webView: webView, tabViewModel: tabViewModel)
        bindUrl()
    }

    private func bindUrl() {
        urlCancelable = tabViewModel.tab.$url.sinkAsync { _ in self.reloadWebViewIfNeeded() }
    }

    private func reloadWebViewIfNeeded() {
        if webView.url == tabViewModel.tab.url { return }

        if let url = tabViewModel.tab.url {
            os_log("%s: load %s", log: OSLog.Category.general, type: .debug, className, url.absoluteString)

            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    private func saveWebsiteVisit() {
        if let url = webView.url {
            historyViewModel.history.saveWebsiteVisit(url: url, title: webView.title, date: NSDate.now as Date)
        }
    }

}

extension BrowserTabViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        saveWebsiteVisit()
    }

}

extension BrowserTabViewController: WKUIDelegate {

}

extension BrowserTabViewController: TabActionDelegate {

    func tabForwardAction(_ tab: Tab) {
        webView.goForward()
    }

    func tabBackAction(_ tab: Tab) {
        webView.goBack()
    }

    func tabReloadAction(_ tab: Tab) {
        webView.reload()
    }

}
