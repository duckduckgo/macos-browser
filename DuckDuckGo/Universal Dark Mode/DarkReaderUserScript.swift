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

final class DarkReaderUserScript: NSObject, StaticUserScript {

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    static var forMainFrameOnly: Bool { false }
    static var source: String = DarkReaderUserScript.loadJS("darkreader", from: .main)
    static var script: WKUserScript = DarkReaderUserScript.makeWKUserScript()
    var messageNames: [String] { [""] }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        assertionFailure("Didn't expect to get a script message from Dark Reader")
    }
    
    func refreshDarkReaderScript(from settings: DarkReaderScriptSettings = .shared, webView: WKWebView) {
        let call = generateDarkReaderCall(from: settings)
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
    
    private func generateDarkReaderCall(from settings: DarkReaderScriptSettings) -> String {
        switch settings.status {
        case .auto:
            return "DarkReader.auto(\(settings.appearanceSettingsJSON()));"
        case .enabled:
            return "DarkReader.enable(\(settings.appearanceSettingsJSON()));"
        case .disabled:
            return "DarkReader.disable()"
        }
    }
    
}
