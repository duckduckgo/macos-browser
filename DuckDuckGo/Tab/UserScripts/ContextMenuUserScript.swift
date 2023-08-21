//
//  ContextMenuUserScript.swift
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
import UserScript

protocol ContextMenuUserScriptDelegate: AnyObject {
    func willShowContextMenu(withSelectedText selectedText: String?, linkURL: String?)
}

final class ContextMenuUserScript: NSObject, StaticUserScript {

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    static var forMainFrameOnly: Bool { false }
    static var script: WKUserScript = ContextMenuUserScript.makeWKUserScript()
    var messageNames: [String] { ["contextMenu"] }

    weak var delegate: ContextMenuUserScriptDelegate?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let jsonDataString = message.body as? String else { return }
        guard let jsonData = jsonDataString.data(using: .utf8) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else { return }
        let selectedText = json["selectedText"] as? String
        let linkUrl = json["linkUrl"] as? String
        delegate?.willShowContextMenu(withSelectedText: selectedText, linkURL: linkUrl)
    }

    static let source = """
    (function() {
        document.addEventListener("contextmenu", function(e) {
                var linkUrl = '';
                var selectedText = window.getSelection().toString();

                if (e.target.tagName.toLowerCase() === 'a') {
                    linkUrl = e.target.href;
                }

                var contextData = {
                    selectedText: selectedText,
                    linkUrl: linkUrl
                };

                webkit.messageHandlers.contextMenu.postMessage(JSON.stringify(contextData));
            }, true);
        })();
    """
}
