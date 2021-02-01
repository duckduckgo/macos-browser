//
//  FindInPageUserScript.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import WebKit

final class FindInPageUserScript: UserScript {

    var model: FindInPageModel?

    init() {
        super.init(source: Self.source,
                   messageNames: Self.messageNames,
                   injectionTime: .atDocumentEnd,
                   forMainFrameOnly: false)
    }

    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any] else { return }
        let currentResult = dict["currentResult"] as? Int
        let totalResults = dict["totalResults"] as? Int
        model?.update(currentSelection: currentResult, matchesFound: totalResults)
    }

    func find(text: String, inWebView webView: WKWebView) {
        evaluate(js: "window.__firefox__.find('\(text)')", inWebView: webView)
    }

    func done(withWebView webView: WKWebView) {
        evaluate(js: "window.__firefox__.findDone()", inWebView: webView)
    }

    func next(withWebView webView: WKWebView) {
        evaluate(js: "window.__firefox__.findNext()", inWebView: webView)
    }

    func previous(withWebView webView: WKWebView) {
        evaluate(js: "window.__firefox__.findPrevious()", inWebView: webView)
    }

    private func evaluate(js: String, inWebView webView: WKWebView) {
        if #available(OSX 11.0, *) {
            webView.evaluateJavaScript(js, in: nil, in: WKContentWorld.defaultClient)
        } else {
            webView.evaluateJavaScript(js)
        }
    }

}

extension FindInPageUserScript {

    static let messageNames = ["findInPageHandler"]
    static let source = UserScript.loadJS("findinpage")

}
