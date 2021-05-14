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
import os.log

protocol HTML5DownloadDelegate: AnyObject {

    func startDownload(_ userScript: HTML5DownloadUserScript, from: URL, withSuggestedName: String?)
    func startDownload(_ userScript: HTML5DownloadUserScript, data: Data, mimeType: String, suggestedName: String?, sourceURL: URL?)

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
              let name = dict["download"]
        else {
            assertionFailure("HTML5DownloadUserScript: unexpected message body")
            return
        }

        var mime = ""
        if href.hasPrefix("data:"),
           let data = Data(dataHref: href, mimeType: &mime) {

            let sourceURL = dict["source"].flatMap(URL.init(string:))
            delegate?.startDownload(self, data: data, mimeType: mime, suggestedName: name, sourceURL: sourceURL)

        } else if let url = URL(string: href) {
            delegate?.startDownload(self, from: url, withSuggestedName: name)

        } else {
            os_log("HTML5DownloadUserScript: could not download from %s", type: .error, href)
        }
    }

    static let source = """
(function() {

    document.addEventListener("click", function(e) {
        if (e.srcElement.tagName !== "A" || !e.srcElement.hasAttribute("download")) return;

        // https://stackoverflow.com/questions/61702414/wkwebview-how-to-handle-blob-url#61703086
        if (event.target.matches('a[href^="blob:"]'))
            (async el=>{
                const url = el.href;
                const download = el.download;
                const blob = await fetch(url).then(r => r.blob());

                var fr = new FileReader();
                fr.onload = function(e) {
                    webkit.messageHandlers.downloadFile.postMessage({
                        "href": e.target.result,
                        "download": download,
                        "source": url
                    });
                }
                fr.readAsDataURL(blob);
            })(event.target);
        else
            webkit.messageHandlers.downloadFile.postMessage({
                "href": e.srcElement.href,
                "download": e.srcElement.download
            });
        e.preventDefault();
    });

}) ();
"""

}
