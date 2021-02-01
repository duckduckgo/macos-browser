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

    func contextMenu(forUserScript script: ContextMenuUserScript, willShowAt position: NSPoint, image: URL?, link: URL?)

}

final class ContextMenuUserScript: UserScript {

    weak var delegate: ContextMenuDelegate?

    var lastAnchor: URL?
    var lastImage: URL?

    init() {
        super.init(source: Self.source,
                   messageNames: Self.messageNames,
                   injectionTime: .atDocumentEnd,
                   forMainFrameOnly: true)
    }

    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        guard let dict = message.body as? [String: Any],
              let point = point(from: dict) else { return }

        var image: URL?
        var link: URL?

        guard let elements = dict["elements"] as? [[String: String]] else { return }
        elements.forEach { dict in

            guard let url = dict["url"] else { return }

            switch dict["tagName"] {
            case "A":
                link = URL(string: url)

            case "IMG":
                image = URL(string: url)

            default: break
            }
        }

        delegate?.contextMenu(forUserScript: self, willShowAt: point, image: image, link: link)
    }

    private func point(from dict: [String: Any]) -> NSPoint? {
        guard let position = dict["position"] as? [String: Int],
              let x = position["x"],
              let y = position["y"] else { return nil }
        return NSPoint(x: x, y: y)
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
