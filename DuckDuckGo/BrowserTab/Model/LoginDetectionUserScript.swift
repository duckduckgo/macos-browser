//
//  LoginDetectionUserScript.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

protocol LoginFormDetectionDelegate: NSObjectProtocol {

    func loginFormDetectionUserScriptDetectedLoginForm(_ script: LoginFormDetectionUserScript)

}

final class LoginFormDetectionUserScript: NSObject, StaticUserScript {
    weak var delegate: LoginFormDetectionDelegate?

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    static var forMainFrameOnly: Bool { false }
    static var source: String = LoginFormDetectionUserScript.loadJS("login-detection", from: .main)
    static var script: WKUserScript = LoginFormDetectionUserScript.makeWKUserScript()
    var messageNames: [String] { ["loginFormDetected"] }

    /// Some cases require scanning for login forms direction. For instance, forms that directly call `form.submit()` will not trigger the submit event that this script typically uses to detect logins.
    /// Instead, the web view will do some additional monitoring for POST requests that look to be hitting a login URL, and will trigger password field scanning that way.
    func scanForLoginForm(in webView: WKWebView) {
        if #available(macOS 11.0, *) {
            webView.evaluateJavaScript("window.__ddg__.scanForPasswordField()", in: nil, in: .defaultClient)
        } else {
            webView.evaluateJavaScript("window.__ddg__.scanForPasswordField()")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.loginFormDetectionUserScriptDetectedLoginForm(self)
    }
}
