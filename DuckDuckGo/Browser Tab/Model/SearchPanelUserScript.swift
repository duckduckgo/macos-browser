//
//  SearchPanelUserScript.swift
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

import BrowserServicesKit
import WebKit

protocol SearchPanelUserScriptDelegate: AnyObject {
    func searchPanelUserScript(_ searchPanelUserScript: SearchPanelUserScript, didSelectSearchResult url: URL)
}

final class SearchPanelUserScript: NSObject, UserScript {

    public weak var delegate: SearchPanelUserScriptDelegate?

    lazy var source: String = SearchPanelUserScript.loadJS("search-panel", from: .main)

    let injectionTime: WKUserScriptInjectionTime = .atDocumentStart
    let forMainFrameOnly: Bool = true
    let messageNames: [String] = ["selectedSearchResult"]

    func highlightSearchResult(with url: URL, inWebView webView: WKWebView) {
        let js = "window.postMessage({ highlightSearchResult: \(url.absoluteString) });"
        evaluate(js: js, inWebView: webView)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "selectedSearchResult",
              let urlString = message.body as? String,
              let url = URL(string: urlString)
        else {
            return
        }
        delegate?.searchPanelUserScript(self, didSelectSearchResult: url)
    }

    private func evaluate(js: String, inWebView webView: WKWebView) {
        if #available(macOS 11.0, *) {
            webView.evaluateJavaScript(js, in: nil, in: WKContentWorld.defaultClient)
        } else {
            webView.evaluateJavaScript(js)
        }
    }
}
