//
//  YoutubeOverlayUserScript.swift
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
import os

final class YoutubeOverlayUserScript: NSObject, StaticUserScript {

    enum MessageNames: String, CaseIterable {
        case setUserValues
        case readUserValues
    }

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    static var forMainFrameOnly: Bool { true }
    static var source: String = YoutubeOverlayUserScript.loadJS("youtube-inject-bundle", from: .main)
    static var script: WKUserScript = YoutubeOverlayUserScript.makeWKUserScript()
    var messageNames: [String] { MessageNames.allCases.map(\.rawValue) }

    // Values that the Frontend can use to determine the current state.
    public struct UserValues: Codable {
        let privatePlayerMode: PrivatePlayerMode;
        let overlayInteracted: Bool;
    }

    struct UserValuesNotification: Encodable {
        let userValuesNotification: UserValues;
    }

    func userValuesUpdated(userValues: UserValues, inWebView webView: WKWebView) {
        let message = UserValuesNotification(userValuesNotification: userValues);
        guard let json = try? JSONEncoder().encode(message), let jsonString = String(data: json, encoding: .utf8) else {
            assertionFailure("YoutubeOverlayUserScript: could not convert UserValues into JSON")
            return
        }
        let js = "window.postMessage(\(jsonString));"
        evaluate(js: js, inWebView: webView)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // TODO: Are we supporting 10.x?
    }

    private func handleSetUserValues(message: WKScriptMessage, _ replyHandler: @escaping (Any?, String?) -> Void) {
        guard let userValues: UserValues = decode(from: message.body) else {
            assertionFailure("YoutubeOverlayUserScript: expected JSON representation of UserValues")
            return
        }

        PrivacySecurityPreferences.shared.youtubeOverlayInteracted = userValues.overlayInteracted;
        PrivacySecurityPreferences.shared.privatePlayerMode = userValues.privatePlayerMode;

        replyHandler(encodeUserValues(), nil)
    }

    private func handleAlwaysOpenSettings(message: WKScriptMessage) {
        guard let alwaysOpenOnPrivatePlayer = message.body as? Bool else {
            assertionFailure("YoutubePlayerUserScript: expected Bool")
            return
        }

        print("Always open \(alwaysOpenOnPrivatePlayer)")
        PrivacySecurityPreferences.shared.privatePlayerMode = .enabled
    }

    private func handleReadUserValues(message: WKScriptMessage, _ replyHandler: @escaping (Any?, String?) -> Void) {
        replyHandler(encodeUserValues(), nil)
    }

    func encodeUserValues() -> String? {
        let uv = UserValues(
                privatePlayerMode: PrivacySecurityPreferences.shared.privatePlayerMode,
                overlayInteracted: PrivacySecurityPreferences.shared.youtubeOverlayInteracted
        );
        guard let json = try? JSONEncoder().encode(uv), let jsonString = String(data: json, encoding: .utf8) else {
            assertionFailure("YoutubeOverlayUserScript: could not convert UserValues into JSON")
            return ""
        }
        return jsonString
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

@available(iOS 14, *)
@available(macOS 11, *)
extension YoutubeOverlayUserScript: WKScriptMessageHandlerWithReply {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard let messageType = MessageNames(rawValue: message.name) else {
            assertionFailure("YoutubeOverlayUserScript: unexpected message name \(message.name)")
            return
        }

        switch messageType {
        case .setUserValues:
            handleSetUserValues(message: message, replyHandler)
        case .readUserValues:
            handleReadUserValues(message: message, replyHandler)
        }
    }
}

func decode<Input: Any, Target: Decodable>(from input: Input) -> Target? {
    do {
        let json = try JSONSerialization.data(withJSONObject: input)
        return try JSONDecoder().decode(Target.self, from: json)
    } catch {
        os_log(.error, "Error decoding message body: %{public}@", error.localizedDescription)
        return nil
    }
}