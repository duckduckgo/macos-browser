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

final class FindInPageModel {

    weak var webView: WKWebView?
    @Published private(set) var text: String = ""
    @Published private(set) var currentSelection: Int = 1
    @Published private(set) var matchesFound: Int = 0
    @Published private(set) var visible: Bool = false

    func update(currentSelection: Int?, matchesFound: Int?) {
        self.currentSelection = currentSelection ?? self.currentSelection
        self.matchesFound = matchesFound ?? self.matchesFound
    }

    func show() {
        visible = true
    }

    func hide() {
        visible = false
    }

    func find(_ text: String) {
        self.text = text
        evaluate("window.__firefox__.find('\(text.escapedJavaScriptString())')")
    }

    func findDone() {
        evaluate("window.__firefox__.findDone()")
    }

    func findNext() {
        evaluate("window.__firefox__.findNext()")
    }

    func findPrevious() {
        evaluate("window.__firefox__.findPrevious()")
    }

    private func evaluate(_ js: String) {
        if #available(macOS 11.0, *) {
            webView?.evaluateJavaScript(js, in: nil, in: WKContentWorld.defaultClient)
        } else {
            webView?.evaluateJavaScript(js)
        }
    }

}
