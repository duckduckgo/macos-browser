//
//  HTML5DownloadUserScript.swift
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

import WebKit
import BrowserServicesKit

protocol HTML5DownloadDelegate: class {

    func startDownload(_ userScript: HTML5DownloadUserScript, from: URL, withSuggestedName: String)

}

final class HTML5DownloadUserScript: NSObject, StaticUserScript {

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentEnd }
    static var forMainFrameOnly: Bool { true }
    static var script: WKUserScript = HTML5DownloadUserScript.makeWKUserScript()
    var messageNames: [String] { ["downloadFile"] }

    weak var delegate: HTML5DownloadDelegate?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: String],
              let href = dict["href"],
              let url = URL(string: href),
              let name = dict["download"]
            else { return }
        delegate?.startDownload(self, from: url, withSuggestedName: name)
    }

    static let source = """
(function() {

    document.addEventListener("click", function(e) {
        if (e.srcElement.tagName !== "A" || !e.srcElement.hasAttribute("download")) return;
        webkit.messageHandlers.downloadFile.postMessage({
            "href": e.srcElement.href,
            "download": e.srcElement.download
        });
        e.preventDefault();
    });

}) ();
"""

}
