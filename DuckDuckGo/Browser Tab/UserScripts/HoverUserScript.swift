//
//  HoverUserScript.swift
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

protocol HoverUserScriptDelegate: AnyObject {

    func hoverUserScript(_ script: HoverUserScript, didChange url: URL?)

}

final class HoverUserScript: NSObject, UserScript {

    public weak var delegate: HoverUserScriptDelegate?

    public var source: String = """
(function() {

    document.addEventListener("mouseover", function(event) {
        var anchor = event.target.closest('a')
        let href = anchor ? anchor.href : null
        webkit.messageHandlers.hoverHandler.postMessage({ href: href });
    }, true);

}) ();
"""

    public var injectionTime: WKUserScriptInjectionTime = .atDocumentStart
    public var forMainFrameOnly: Bool = false
    public var messageNames: [String] = ["hoverHandler"]

    private(set) var lastURL: URL?

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        guard let dict = message.body as? [String: Any] else { return }

        let url: URL?
        if let href = dict["href"] as? String {
            url = URL(string: href)
        } else {
            url = nil
        }

        if url != lastURL {
            lastURL = url
            delegate?.hoverUserScript(self, didChange: url)
        }
    }

}
