//
//  FindInPageModel.swift
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

import Foundation
import WebKit

final class FindInPageModel: NSObject {

    @Published private(set) var text: String = ""
    @Published private(set) var currentSelection: Int = 1
    @Published private(set) var matchesFound: Int = 0
    @Published private(set) var isVisible: Bool = false

    weak var webView: WKWebView?

    func update(currentSelection: Int?, matchesFound: Int?) {
        self.currentSelection = currentSelection ?? self.currentSelection
        self.matchesFound = matchesFound ?? self.matchesFound
    }

    func show(with webView: WKWebView) {
        self.webView = webView
        webView.setValue(self, forKey: "findDelegate")
        isVisible = true
    }

    func close() {
        isVisible = false
    }

    func find(_ text: String) {
        self.text = text
        webView?._find(text, options: [.caseInsensitive, .showFindIndicator, .showHighlight, .showOverlay, .determineMatchIndex, .wrapAround], maxCount: .max)
//        evaluate("window.__firefox__.find('\(text.escapedJavaScriptString())')")
    }

    func findDone() {
//        evaluate("window.__firefox__.findDone()")
        webView?.perform(NSSelectorFromString("_hideFindUI"))
    }

    func findNext() {
            webView?._find(text, options: [.caseInsensitive, .showFindIndicator, .showHighlight, .showOverlay, .determineMatchIndex], maxCount: .max)
//        evaluate("window.__firefox__.findNext()")
    }

    func findPrevious() {
        webView?._find(text, options: [.caseInsensitive, .showFindIndicator, .showHighlight, .showOverlay, .determineMatchIndex, .wrapAround, .backwards], maxCount: .max)
//        evaluate("window.__firefox__.findPrevious()")
    }

    private func evaluate(_ js: String) {
        if #available(macOS 11.0, *) {
            webView?.evaluateJavaScript(js, in: nil, in: WKContentWorld.defaultClient)
        } else {
            webView?.evaluateJavaScript(js)
        }
    }

}

extension FindInPageModel /* _WKFindDelegate */ {

    @objc(_webView:didFindMatches:forString:withMatchIndex:)
    func webView(_ webView: WKWebView, didFind matchesFound: Int, for string: String, withMatchIndex matchIndex: Int) {
        Swift.print("didFindMatches:", matchesFound, "for:", string, "withMatchIndex:", matchIndex)
        self.update(currentSelection: matchIndex, matchesFound: matchesFound)
    }


}
