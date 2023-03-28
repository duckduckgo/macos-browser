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
import WebKit
import os
import Common
import UserScript

protocol YoutubeOverlayUserScriptDelegate: AnyObject {
    func youtubeOverlayUserScriptDidRequestDuckPlayer(with url: URL, in webView: WKWebView)
}

final class YoutubeOverlayUserScript: NSObject, UserScript, UserScriptMessageEncryption {

    enum MessageNames: String, CaseIterable {
        case setUserValues
        case readUserValues
        case openDuckPlayer
    }

    // This conforms to https://duckduckgo.github.io/content-scope-utils/classes/Webkit_Messaging.WebkitMessagingConfig.html
    struct WebkitMessagingConfig: Encodable {
        var hasModernWebkitAPI: Bool
        var webkitMessageHandlerNames: [String]
        let secret: String
    }

    /// Values that the Frontend can use to determine the current state.
    public struct UserValues: Codable {
        enum CodingKeys: String, CodingKey {
            case duckPlayerMode = "privatePlayerMode"
            case overlayInteracted
        }
        let duckPlayerMode: DuckPlayerMode
        let overlayInteracted: Bool
    }

    var injectionTime: WKUserScriptInjectionTime = .atDocumentStart
    var forMainFrameOnly: Bool = true

    var messageNames: [String] {
        MessageNames.allCases.map(\.rawValue)
    }

    weak var delegate: YoutubeOverlayUserScriptDelegate?
    weak var webView: WKWebView?

    lazy var runtimeValues: String = {
        var runtime = WebkitMessagingConfig(
                hasModernWebkitAPI: false,
                webkitMessageHandlerNames: self.messageNames,
                secret: generatedSecret
        )
        if #available(macOS 11.0, *) {
            runtime.hasModernWebkitAPI = true
        }
        guard let json = try? JSONEncoder().encode(runtime).utf8String() else {
            assertionFailure("YoutubeOverlayUserScript: could not convert RuntimeInjectedValues")
            return ""
        }
        return json
    }()

    lazy var source: String = {
        var js = YoutubeOverlayUserScript.loadJS("youtube-inject-bundle", from: .main)
        js = js.replacingOccurrences(of: "$WebkitMessagingConfig$", with: runtimeValues)
        return js
    }()

    let encrypter: UserScriptEncrypter
    let hostProvider: UserScriptHostProvider
    let generatedSecret: String = UUID().uuidString

    init(
        preferences: DuckPlayerPreferences = .shared,
        encrypter: UserScriptEncrypter = AESGCMUserScriptEncrypter(),
        hostProvider: UserScriptHostProvider = SecurityOriginHostProvider()
    ) {
        self.hostProvider = hostProvider
        self.encrypter = encrypter
        self.duckPlayerPreferences = preferences
    }

    struct UserValuesNotification: Encodable {
        let userValuesNotification: UserValues
    }

    func userValuesUpdated(userValues: UserValues) {
        let outgoing = UserValuesNotification(userValuesNotification: userValues)
        guard let json = try? JSONEncoder().encode(outgoing).utf8String() else {
            assertionFailure("YoutubeOverlayUserScript: could not convert UserValues into JSON")
            return
        }
        let js = "window.onUserValuesChanged?.(\(json));"
        evaluate(js: js)
    }

    func setAlwaysOpenInDuckPlayer(_ enabled: Bool) {
        let value = enabled ? "true" : "false"
        let js = "window.postMessage({ alwaysOpenSetting: \(value) });"
        evaluate(js: js)
    }

    func encodeUserValues() -> String? {
        let uv = UserValues(
                duckPlayerMode: duckPlayerPreferences.duckPlayerMode,
                overlayInteracted: duckPlayerPreferences.youtubeOverlayInteracted
        )
        guard let json = try? JSONEncoder().encode(uv).utf8String() else {
            assertionFailure("YoutubeOverlayUserScript: could not convert UserValues into JSON")
            return ""
        }
        return json
    }

    func messageHandlerFor(_ messageName: String) -> MessageHandler? {
        switch MessageNames(rawValue: messageName) {
        case .setUserValues:
            return handleSetUserValues
        case .readUserValues:
            return handleReadUserValues
        case .openDuckPlayer:
            return handleOpenDuckPlayer
        default:
            assertionFailure("YoutubeOverlayUserScript: Failed to parse User Script message: \(messageName)")
            return nil
        }
    }

    // MARK: - Private

    fileprivate func isMessageFromVerifiedOrigin(_ message: UserScriptMessage) -> Bool {
        hostProvider.hostForMessage(message).droppingWwwPrefix() == "youtube.com"
    }

    private func handleSetUserValues(message: UserScriptMessage, _ replyHandler: @escaping MessageReplyHandler) {
        guard let userValues: UserValues = DecodableHelper.decode(from: message.messageBody) else {
            assertionFailure("YoutubeOverlayUserScript: expected JSON representation of UserValues")
            return
        }

        duckPlayerPreferences.youtubeOverlayInteracted = userValues.overlayInteracted
        duckPlayerPreferences.duckPlayerMode = userValues.duckPlayerMode

        replyHandler(encodeUserValues())
    }

    private func handleReadUserValues(message: UserScriptMessage, _ replyHandler: @escaping MessageReplyHandler) {
        replyHandler(encodeUserValues())
    }

    private func handleOpenDuckPlayer(message: UserScriptMessage, _ replyHandler: @escaping MessageReplyHandler) {
        guard let dict = message.messageBody as? [String: Any],
              let href = dict["href"] as? String,
              let url = href.url,
              let webView = message.messageWebView
        else {
            assertionFailure("YoutubeOverlayUserScript: expected URL")
            return
        }
        delegate?.youtubeOverlayUserScriptDidRequestDuckPlayer(with: url, in: webView)
    }

    private func evaluate(js: String) {
        guard let webView else {
            assertionFailure("WebView not set")
            return
        }
        if #available(macOS 11.0, *) {
            webView.evaluateJavaScript(js, in: nil, in: WKContentWorld.defaultClient)
        } else {
            webView.evaluateJavaScript(js)
        }
    }

    private let duckPlayerPreferences: DuckPlayerPreferences
}

@available(macOS 11, *)
extension YoutubeOverlayUserScript: WKScriptMessageHandlerWithReply {

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {

        guard isMessageFromVerifiedOrigin(message) else {
            return
        }

        guard let messageHandler = messageHandlerFor(message.name) else {
            // Unsupported message fail silently
            return
        }

        messageHandler(message) {
            replyHandler($0, nil)
        }
    }

}

// MARK: - Fallback for macOS 10.15

extension YoutubeOverlayUserScript: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        guard isMessageFromVerifiedOrigin(message) else {
            return
        }

        processEncryptedMessage(message, from: userContentController)
    }
}
