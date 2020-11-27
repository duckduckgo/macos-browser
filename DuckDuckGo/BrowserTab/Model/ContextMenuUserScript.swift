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

protocol ContextMenuDelegate: AnyObject {

    func contextMenuUserScript(_ script: ContextMenuUserScript, showContextMenuAt position: NSPoint, forElements elements: [ContextMenuElement])

}

class ContextMenuUserScript: UserScript {

    weak var delegate: ContextMenuDelegate?

    init() {
        super.init(source: Self.source,
                   messageNames: Self.messageNames,
                   injectionTime: .atDocumentEnd,
                   forMainFrameOnly: true)
    }

    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        guard let dict = message.body as? [String: Any],
              let point = point(from: dict)
              else { return }

        print(#function, dict)

        delegate?.contextMenuUserScript(self, showContextMenuAt: point, forElements: elements(from: dict))

    }

    private func point(from dict: [String: Any]) -> NSPoint? {
        guard let position = dict["position"] as? [String: Int],
              let x = position["x"],
              let y = position["y"] else { return nil }
        return NSPoint(x: x, y: y)
    }

    private func elements(from dict: [String: Any]) -> [ContextMenuElement] {
        guard let elements = dict["elements"] as? [[String: String]] else { return [] }
        return elements.compactMap { dict -> ContextMenuElement? in
            guard let urlString = dict["url"],
                  let url = URL(string: urlString) else { return nil }

            switch dict["tagName"] {
            case "A":
                return .link(url: url)

            case "IMG":
                return .image(url: url)

            default:
                return nil
            }
        }
    }

}

extension ContextMenuUserScript {

    static let messageNames = ["contextMenu"]
    static let source = """
(function() {

    function linkFrom(element) {
        return {
            "tagName": "A",
            "url": element.href
        };
    }

    function findParentLink(element) {
        var parent;
        while (parent = element.parentElement) {
            if (parent.tagName === "A") {
                return linkFrom(parent);
            }
            element = parent;
        }
        return null;
    }

    document.addEventListener("contextmenu", function(e) {

        // Allow context menu for PDFs
        if (document.contentType.endsWith("/pdf") && document.plugins.length > 0) {
            return;
        }

        // Otherwise, never show the default context menu to avoid user confusion, even if something goes wrong after this.
        e.preventDefault();

        var context = {
            "position": {
                "x": e.clientX,
                "y": e.clientY
            },
            "elements": [
            ]
        };

        if (e.srcElement.tagName === "A") {
            context.elements.push(linkFrom(e.srcElement));
        } else {
            if (e.srcElement.tagName === "IMG") {
                context.elements.push({
                    "tagName": "IMG",
                    "url": e.srcElement.src
                });
            }

            var parentLink = findParentLink(e.srcElement);
            if (parentLink) {
                context.elements.push(parentLink);
            }
        }

        webkit.messageHandlers.contextMenu.postMessage(context);
    });

}) ();
"""

}
