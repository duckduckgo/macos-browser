//
//  FaviconUserScript.swift
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

protocol FaviconUserScriptDelegate: AnyObject {

    func faviconUserScript(_ faviconUserScript: FaviconUserScript,
                           didFindFaviconLinks faviconLinks: [FaviconUserScript.FaviconLink],
                           for documentUrl: URL)

}

final class FaviconUserScript: NSObject, StaticUserScript {

    struct FaviconLink {
        let href: String
        let rel: String
    }

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentEnd }
    static var forMainFrameOnly: Bool { true }
    static var script: WKUserScript = FaviconUserScript.makeWKUserScript()
    var messageNames: [String] { ["faviconFound"] }

    weak var delegate: FaviconUserScriptDelegate?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let favicons = body["favicons"] as? [[String: Any]],
              let documentUrlString = body["documentUrl"] as? String else {
                  assertionFailure("FaviconUserScript: Bad message body")
                  return
              }

        let faviconLinks = favicons.compactMap { favicon -> FaviconLink? in
            if let href = favicon["href"] as? String,
               let rel = favicon["rel"] as? String {
                return FaviconLink(href: href, rel: rel)
            } else {
                assertionFailure("FaviconUserScript: Failed to get favicon link data")
                return nil
            }
        }

        guard let documentUrl = URL(string: documentUrlString) else {
            assertionFailure("FaviconUserScript: Failed to make URL from string")
            return
        }

        delegate?.faviconUserScript(self, didFindFaviconLinks: faviconLinks, for: documentUrl)
    }

    static let source = """
(function() {
    function getFavicon() {
        return findFavicons()[0];
    };

    function findFavicons() {
         var selectors = [
            "link[rel='favicon']",
            "link[rel*='icon']",
            "link[rel='apple-touch-icon']",
            "link[rel='apple-touch-icon-precomposed']"
        ];
        var favicons = [];
        while (selectors.length > 0) {
            var selector = selectors.pop()
            var icons = document.head.querySelectorAll(selector);
            for (var i = 0; i < icons.length; i++) {
                var href = icons[i].href;
                var rel = icons[i].rel;

                // Exclude SVGs since we can't handle them
                if (href.indexOf("svg") >= 0 || (icons[i].type && icons[i].type.indexOf("svg") >= 0)) {
                    continue;
                }
                favicons.push({ href: href, rel: rel });
            }
        }
        return favicons;
    };
    try {
        var favicons = findFavicons();
        webkit.messageHandlers.faviconFound.postMessage({ favicons: favicons, documentUrl: document.URL });
    } catch(error) {
        // webkit might not be defined
    }
}) ();
"""

}
