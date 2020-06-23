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

protocol BrowserTabViewControllerDelegate: AnyObject {

    func browserTabViewController(_ browserTabViewController: BrowserTabViewController, urlDidChange urlViewModel: URLViewModel?)

}

class BrowserTabViewController: NSViewController {

    @IBOutlet weak var webView: WKWebView!

    weak var delegate: BrowserTabViewControllerDelegate?

    var urlViewModel: URLViewModel? {
        didSet {
            reload()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.url) {
            urlChanged()
            return
        }

        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }

    deinit {
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
    }

    private func reload() {
        if let urlViewModel = urlViewModel {
            os_log("%s: load %s", log: OSLog.Category.general, type: .debug, self.className, urlViewModel.url.absoluteString)

            let request = URLRequest(url: urlViewModel.url)
            webView.load(request)
        }
    }

    private func urlChanged() {
        var urlViewModel: URLViewModel?
        if let url = webView.url {
            urlViewModel = URLViewModel(url: url)
        }

        delegate?.browserTabViewController(self, urlDidChange: urlViewModel)
    }

}

extension BrowserTabViewController: WKNavigationDelegate {

}

extension BrowserTabViewController: WKUIDelegate {

}
