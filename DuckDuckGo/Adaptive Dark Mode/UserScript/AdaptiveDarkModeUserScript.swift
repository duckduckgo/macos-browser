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
    
    private func generateDarkReaderCall(enabled: Bool) -> String {
        if enabled {
            return "DarkReader.enable(\(defaultAppearanceSettings));"
        } else {
            return "DarkReader.disable()"
        }
    }
    
}
