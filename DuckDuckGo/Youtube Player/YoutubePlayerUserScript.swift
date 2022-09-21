//
//  YoutubePlayerUserScript.swift
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

final class YoutubePlayerUserScript: NSObject, StaticUserScript {
    
    enum MessageNames: String, CaseIterable {
        case setAlwaysOpenSettingTo
    }
    
    public var requiresRunInPageContentWorld: Bool {
        return true
    }
    
    static var injectionTime: WKUserScriptInjectionTime { .atDocumentStart}
    static var forMainFrameOnly: Bool { false }
    static var source: String = ""
    static var script: WKUserScript = YoutubePlayerUserScript.makeWKUserScript()
    var messageNames: [String] { MessageNames.allCases.map(\.rawValue) }

    func setAlwaysOpenInPrivatePlayer(_ enabled: Bool, inWebView webView: WKWebView) {
        let value = enabled ? "true" : "false"
        let js = "window.postMessage({ alwaysOpenSetting: \(value) });"
        evaluate(js: js, inWebView: webView)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        guard let messageType = MessageNames(rawValue: message.name) else {
            assertionFailure("YoutubePlayerUserScript: unexpected message name \(message.name)")
            return
        }
        
        switch messageType {
        case .setAlwaysOpenSettingTo:
            handleAlwaysOpenSettings(message: message)
        }
    }
    
    private func handleAlwaysOpenSettings(message: WKScriptMessage) {
        guard let alwaysOpenOnPrivatePlayer = message.body as? Bool else {
            assertionFailure("YoutubePlayerUserScript: expected Bool")
            return
        }
        
        print("Always open \(alwaysOpenOnPrivatePlayer)")
        PrivacySecurityPreferences.shared.privateYoutubePlayerEnabled = alwaysOpenOnPrivatePlayer
    }
    
    func evaluateJSCall(call: String, webView: WKWebView) {
        evaluate(js: call, inWebView: webView)
    }

    private func evaluate(js: String, inWebView webView: WKWebView) {
        if #available(macOS 11.0, *) {
            webView.evaluateJavaScript(js, in: nil, in: WKContentWorld.defaultClient)
        } else {
            webView.evaluateJavaScript(js)
        }
    }
}
