//
//  DarkReaderUserScript.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit
import WebKit

final class AdaptiveDarkModeUserScript: NSObject, StaticUserScript {

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    static var forMainFrameOnly: Bool { false }
    static var source: String = AdaptiveDarkModeUserScript.loadJS("darkreader", from: .main)
    static var script: WKUserScript = AdaptiveDarkModeUserScript.makeWKUserScript()
    var messageNames: [String] { [""] }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        assertionFailure("Didn't expect to get a script message from Dark Reader")
    }
    
    func refreshDarkReaderScript(enabled: Bool, webView: WKWebView) {
        let call = generateDarkReaderCall(enabled: enabled)
        evaluate(js: "DarkReader.setFetchMethod(window.fetch)", inWebView: webView)
        evaluate(js: call, inWebView: webView)
    }
    
    private func evaluate(js: String, inWebView webView: WKWebView) {
        if #available(macOS 11.0, *) {
            webView.evaluateJavaScript(js, in: nil, in: WKContentWorld.defaultClient)
        } else {
            webView.evaluateJavaScript(js)
        }
    }
    
    private var defaultAppearanceSettings: String {
        return """
            {
                mode: 1,
                brightness: 100,
                contrast: 100,
                grayscale: 0,
                sepia: 0,
            }
        """
    }
    
    private var redditSettings: String {
        
        #"""
        {
            "url": [
                "reddit.com"
            ],
            "invert": [
                "[role=\"slider\"]",
                "video ~ div [style^=\"height\"]"
            ],
            "css": "[role=\"slider\"] > div:nth-child(4) {\n    background-color: ${#0079d3} !important;\n}\n[style^=\"--background\"] {\n    --background: ${#FFFFFF} !important;\n}\n[style^=\"--canvas\"] {\n    --canvas: ${#DAE0E6} !important;\n}\n[style^=\"--pseudo-before-background\"] {\n    --pseudo-before-background: ${#DAE0E6} !important;\n}\n[style^=\"--comments-overlay-background\"] {\n    --comments-overlay-background: ${#DAE0E6} !important;\n}\n[style^=\"--commentswrapper-gradient-color\"] {\n    --comments-overlay-background: ${#DAE0E6} !important;\n}\n[style^=\"--fakelightbox-overlay-background\"] {\n    --fakelightbox-overlay-background: ${#DAE0E6} !important;\n}\n.md p>a[href=\"#s\"]::after, a[href=\"#s\"]::after {\n    color: #000;\n}\nheader a[aria-label=\"Home\"] svg:last-child g,\nheader > div > div + div a[href] *,\nheader > div > div + div button[aria-label] * {\n    fill: var(--darkreader-neutral-text) !important;\n}\n#COIN_PURCHASE_DROPDOWN_ID > div {\n    background: linear-gradient(180deg,hsla(0,0%,100%,.1) 45.96%,hsla(0,0%,100%,.57) 46%,hsla(0,0%,100%,0) 130%),${gold} !important;\n}\n#COIN_PURCHASE_DROPDOWN_ID > div > span {\n    color: ${white} !important;\n}\n.md-spoiler-text:not([data-revealed])::selection {\n    color: transparent !important;\n    background-color: var(--darkreader-bg--newCommunityTheme-metaText) !important;\n}\ndiv[role=\"menu\"][style^=\"position: fixed\"] button button[role=\"switch\"][aria-checked=\"false\"] {\n    background-color: ${gray} !important;\n}\ndiv[role=\"menu\"][style^=\"position: fixed\"] button button[role=\"switch\"] > div {\n    background-color: ${black} !important;\n}",
            "ignoreInlineStyle": [],
            "ignoreImageAnalysis": []
        }
"""#
        
    }
    
    private func generateDarkReaderCall(enabled: Bool) -> String {
        if enabled {
            return "DarkReader.enable(\(defaultAppearanceSettings), \(redditSettings));"
        } else {
            return "DarkReader.disable()"
        }
    }
    
}
