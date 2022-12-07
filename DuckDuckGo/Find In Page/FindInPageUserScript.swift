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
import UserScript

final class FindInPageUserScript: NSObject, StaticUserScript {

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentEnd }
    static var forMainFrameOnly: Bool { false }
    static var source: String = FindInPageUserScript.loadJS("findinpage", from: .main)
    static var script: WKUserScript = FindInPageUserScript.makeWKUserScript()
    var messageNames: [String] { ["findInPageHandler"] }

    weak var model: FindInPageModel?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any] else { return }

        let currentResult = dict["currentResult"] as? Int
        let totalResults = dict["totalResults"] as? Int
        model?.update(currentSelection: currentResult, matchesFound: totalResults)
    }

    func find(_ text: String, in webView: WKWebView) {
        evaluate("window.__firefox__.find('\(text.replacingOccurrences(of: "'", with: "\\\'"))')", in: webView)
    }

    func findDone(in webView: WKWebView) {
        evaluate("window.__firefox__.findDone()", in: webView)
    }

    func findNext(in webView: WKWebView) {
        evaluate("window.__firefox__.findNext()", in: webView)
    }

    func findPrevious(in webView: WKWebView) {
        evaluate("window.__firefox__.findPrevious()", in: webView)
    }

    private func evaluate(_ js: String, in webView: WKWebView) {
        if #available(macOS 11.0, *) {
            webView.evaluateJavaScript(js, in: nil, in: WKContentWorld.defaultClient)
        } else {
            webView.evaluateJavaScript(js)
        }
    }

}
