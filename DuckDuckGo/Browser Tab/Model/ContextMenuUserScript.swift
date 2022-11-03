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

protocol ContextMenuUserScriptDelegate: AnyObject {

    func willShowContextMenu(at position: NSPoint, with context: ContextMenuUserScript.Context)

}

final class ContextMenuUserScript: NSObject, StaticUserScript {

    enum Element {
        case link(url: URL?, title: String?)
        case image(URL?)
        case video(URL?)
        case other(tag: String, html: String?)
    }
    struct Context {
        let elements: [Element]
        let selectedText: String?
        let frame: WKFrameInfo

        var link: (url: URL?, title: String?)? {
            for item in elements {
                if case let .link(url: url, title: title) = item {
                    return (url, title)
                }
            }
            return nil
        }
        var videoURL: URL? {
            for item in elements {
                if case .video(let url) = item {
                    return url
                }
            }
            return nil
        }
    }

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    static var forMainFrameOnly: Bool { false }
    static var script: WKUserScript = ContextMenuUserScript.makeWKUserScript()
    var messageNames: [String] { ["contextMenu"] }

    weak var delegate: ContextMenuUserScriptDelegate?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        guard let dict = message.body as? [String: Any],
              let point = point(from: dict) else { return }

        var elements = [Element]()
        let selectedText = dict["selectedText"] as? String

        guard let elementsArray = dict["elements"] as? [[String: String]] else { return }
        elementsArray.forEach { dict in

            guard let url = dict["url"] else { return }

            switch dict["tagName"] {
            case "A":
                elements.append(.link(url: URL(string: url), title: dict["title"]))

            case "IMG":
                elements.append(.image(URL(string: url)))
                
            case "VIDEO":
                elements.append(.video(URL(string: url)))

            case let .some(tagName):
                elements.append(.other(tag: tagName, html: dict["html"]))

            default: break
            }
        }

        let context = Context(elements: elements, selectedText: selectedText, frame: message.frameInfo)
        delegate?.willShowContextMenu(at: point, with: context)
    }

    private func point(from dict: [String: Any]) -> NSPoint? {
        guard let position = dict["position"] as? [String: Int],
              let x = position["x"],
              let y = position["y"] else { return nil }
        return NSPoint(x: x, y: y)
    }

    static let source = """
(function() {

    function linkFrom(element) {
        return {
            "tagName": "A",
            "url": element.href,
            "title": element.textContent
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
            ],
            "selectedText": window.getSelection().toString()
        };

        if (e.srcElement.tagName === "A") {
            context.elements.push(linkFrom(e.srcElement));
        } else {
            if (e.srcElement.tagName === "IMG") {
                context.elements.push({
                    "tagName": "IMG",
                    "url": e.srcElement.src
                });
            } else if (e.srcElement.tagName === "VIDEO") {
                console.log("Got video");
                context.elements.push({
                    "tagName": "VIDEO",
                    "url": e.srcElement.currentSrc
                });
            } else {
                context.elements.push({
                    "tagName": e.srcElement.tagName,
                    "url": e.srcElement.outerHTML
                });
            }

            var parentLink = findParentLink(e.srcElement);
            if (parentLink) {
                context.elements.push(parentLink);
            }
        }

        webkit.messageHandlers.contextMenu.postMessage(context);
    }, true);

}) ();
"""

}
