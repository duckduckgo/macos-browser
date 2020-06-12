//
//  ViewController.swift
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

class BrowserTabViewController: NSViewController {

    @IBOutlet weak var webView: WKWebView!

    var urlViewModel: URLViewModel? {
        didSet {
            reload()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    private func reload() {
        if let urlViewModel = urlViewModel {
            os_log("%s: load %s", log: generalLog, type: .debug, self.className, urlViewModel.url.absoluteString)

            let request = URLRequest(url: urlViewModel.url)
            webView.load(request)
        }
    }

}

extension BrowserTabViewController: WKNavigationDelegate {

}

extension BrowserTabViewController: WKUIDelegate {

}
