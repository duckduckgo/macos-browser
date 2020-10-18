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

import Foundation
import WebKit

protocol FaviconUserScriptDelegate: AnyObject {

    func faviconUserScript(_ faviconUserScript: FaviconUserScript, didFindFavicon faviconUrl: URL)

}

class FaviconUserScript: UserScript {

    weak var delegate: FaviconUserScriptDelegate?

    init() {
        super.init(source: Self.source,
                   messageNames: Self.messageNames,
                   injectionTime: .atDocumentEnd,
                   forMainFrameOnly: true)
    }

    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let urlString = message.body as? String, let url = URL(string: urlString) {
            delegate?.faviconUserScript(self, didFindFavicon: url)
        }
    }
    
}

extension FaviconUserScript {

    static let messageNames = ["faviconFound"]
    static let source = """

(function() {

    function getFavicon() {
        var favicons = findFavicons()
        return favicons[favicons.length - 1];
    };

    function findFavicons() {

         var selectors = {
            "link[rel~='icon']": 0,
            "link[rel='apple-touch-icon']": 1,
            "link[rel='apple-touch-icon-precomposed']": 2
        };

        var favicons = [];
        for (var selector in selectors) {
            var icons = document.head.querySelectorAll(selector);
            for (var i = 0; i < icons.length; i++) {
                var href = icons[i].href;

                // Exclude SVGs since we can't handle them
                if (href.indexOf("svg") >= 0 || (icons[i].type && icons[i].type.indexOf("svg") >= 0)) {
                    continue;
                }

                favicons.push(href)
            }
        }
        return favicons;
    };

    try {
        var favicon = getFavicon();
        webkit.messageHandlers.faviconFound.postMessage(favicon);
    } catch(error) {
        // webkit might not be defined
    }

}) ();

"""

}
