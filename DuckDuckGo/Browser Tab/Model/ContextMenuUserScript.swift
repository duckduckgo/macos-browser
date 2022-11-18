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
import BrowserServicesKit
import UserScript

protocol ContextMenuUserScriptDelegate: AnyObject {
    func willShowContextMenu(withSelectedText: String)
}

final class ContextMenuUserScript: NSObject, StaticUserScript {

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    static var forMainFrameOnly: Bool { false }
    static var script: WKUserScript = ContextMenuUserScript.makeWKUserScript()
    var messageNames: [String] { ["contextMenu"] }

    weak var delegate: ContextMenuUserScriptDelegate?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let selectedText = message.body as? String else { return }
        delegate?.willShowContextMenu(withSelectedText: selectedText)
    }

    static let source = """
    (function() {
        document.addEventListener("contextmenu", function(e) {
            webkit.messageHandlers.contextMenu.postMessage(window.getSelection().toString());
        }, true);
    }) ();
    """

}
