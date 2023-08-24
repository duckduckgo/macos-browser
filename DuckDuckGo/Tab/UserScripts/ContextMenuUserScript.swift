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
        guard let dict = message.body as? [String: Any] else { return }
        let selectedText = dict["selectedText"] as? String
        let linkUrl = dict["linkUrl"] as? String
        delegate?.willShowContextMenu(withSelectedText: selectedText, linkURL: linkUrl)
    }

    static let source = """
    (function() {
        document.addEventListener("contextmenu", function(e) {
            let anchor = event.target.closest('a');
            let linkUrl = anchor ? anchor.href : null;
            let selectedText = window.getSelection().toString();

            webkit.messageHandlers.contextMenu.postMessage({
                selectedText: selectedText,
                linkUrl: linkUrl
            });
        }, true);
    })();
    """
}
