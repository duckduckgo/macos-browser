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

import WebKit
import os
import Common
import UserScript

protocol YoutubeOverlayUserScriptDelegate: AnyObject {
    func youtubeOverlayUserScriptDidRequestDuckPlayer(with url: URL)
}

final class YoutubeOverlayUserScript: NSObject, UserScript {

    typealias MessageReplyHandler = (String?) -> Void
    typealias MessageHandler = (YoutubeMessage, @escaping MessageReplyHandler) -> Void

    enum MessageNames: String, CaseIterable {
        case setUserValues
        case readUserValues
        case openDuckPlayer
    }

    struct WebkitMessagingConfig: Encodable {
        var hasModernWebkitAPI: Bool
        var webkitMessageHandlerNames: [String]
        let secret: String
    }

    /// Values that the Frontend can use to determine the current state.
    public struct UserValues: Codable {
        let privatePlayerMode: PrivatePlayerMode
        let overlayInteracted: Bool
    }

    var injectionTime: WKUserScriptInjectionTime = .atDocumentStart
    var forMainFrameOnly: Bool = true

    var messageNames: [String] {
        MessageNames.allCases.map(\.rawValue)
    }

    weak var delegate: YoutubeOverlayUserScriptDelegate?

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

    func hostForMessage(_ message: YoutubeMessage) -> String {
        hostProvider.hostForMessage(message)
    }

    let encrypter: YoutubeEncrypter
    let hostProvider: YoutubeHostProvider
    let generatedSecret: String = UUID().uuidString

    init(
        preferences: PrivatePlayerPreferences = .shared,
        encrypter: YoutubeEncrypter = AESGCMYoutubeOverlayEncrypter(),
        hostProvider: SecurityOriginHostProvider = SecurityOriginHostProvider()
    ) {
        self.hostProvider = hostProvider
        self.encrypter = encrypter
        self.privatePlayerPreferences = preferences
    }

    struct UserValuesNotification: Encodable {
        let userValuesNotification: UserValues
    }

    func userValuesUpdated(userValues: UserValues, inWebView webView: WKWebView) {
        let outgoing = UserValuesNotification(userValuesNotification: userValues)
        guard let json = try? JSONEncoder().encode(outgoing).utf8String() else {
            assertionFailure("YoutubeOverlayUserScript: could not convert UserValues into JSON")
            return
        }
        let js = "window.onUserValuesChanged?.(\(json));"
        evaluate(js: js, inWebView: webView)
    }

    func encodeUserValues() -> String? {
        let uv = UserValues(
                privatePlayerMode: privatePlayerPreferences.privatePlayerMode,
                overlayInteracted: privatePlayerPreferences.youtubeOverlayInteracted
        )
        guard let json = try? JSONEncoder().encode(uv).utf8String() else {
            assertionFailure("YoutubeOverlayUserScript: could not convert UserValues into JSON")
            return ""
        }
        return json
    }

    // MARK: - Private

    fileprivate func isMessageFromVerifiedOrigin(_ message: YoutubeMessage) -> Bool {
        message.messageHost.droppingWwwPrefix() == "youtube.com"
    }

    private func handleSetUserValues(message: YoutubeMessage, _ replyHandler: @escaping MessageReplyHandler) {
        guard let userValues: UserValues = DecodableHelper.decode(from: message.messageBody) else {
            assertionFailure("YoutubeOverlayUserScript: expected JSON representation of UserValues")
            return
        }

        privatePlayerPreferences.youtubeOverlayInteracted = userValues.overlayInteracted
        privatePlayerPreferences.privatePlayerMode = userValues.privatePlayerMode

        replyHandler(encodeUserValues())
    }

    private func handleReadUserValues(message: YoutubeMessage, _ replyHandler: @escaping MessageReplyHandler) {
        replyHandler(encodeUserValues())
    }

    private func handleOpenDuckPlayer(message: YoutubeMessage, _ replyHandler: @escaping MessageReplyHandler) {
        guard let dict = message.messageBody as? [String: Any],
              let href = dict["href"] as? String,
              let url = href.url else {
            assertionFailure("YoutubeOverlayUserScript: expected URL")
            return
        }
        delegate?.youtubeOverlayUserScriptDidRequestDuckPlayer(with: url)
    }

    private func evaluate(js: String, inWebView webView: WKWebView) {
        if #available(macOS 11.0, *) {
            webView.evaluateJavaScript(js, in: nil, in: WKContentWorld.defaultClient)
        } else {
            webView.evaluateJavaScript(js)
        }
    }

    private func messageHandlerFor(_ messageName: String) -> MessageHandler? {
        guard let message = MessageNames(rawValue: messageName) else {
            assertionFailure("YoutubeOverlayUserScript: Failed to parse User Script message: \(messageName)")
            return nil
        }

        switch message {

        case .setUserValues:
            return handleSetUserValues
        case .readUserValues:
            return handleReadUserValues
        case .openDuckPlayer:
            return handleOpenDuckPlayer
        }
    }

    private let privatePlayerPreferences: PrivatePlayerPreferences
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

        guard let messageHandler = messageHandlerFor(message.messageName) else {
            // Unsupported message fail silently
            return
        }

        guard let body = message.messageBody as? [String: Any],
              let messageHandling = body["messageHandling"] as? [String: Any],
              let secret = messageHandling["secret"] as? String,
              // If this does not match the page is playing shenanigans.
              secret == generatedSecret
        else {
            return
        }

        messageHandler(message) { reply in
            guard let reply = reply,
                  let messageHandling = body["messageHandling"] as? [String: Any],
                  let key = messageHandling["key"] as? [UInt8],
                  let iv = messageHandling["iv"] as? [UInt8],
                  let methodName = messageHandling["methodName"] as? String,
                  let encryption = try? self.encrypter.encryptReply(reply, key: key, iv: iv)
            else {
                return
            }

            let ciphertext = encryption.ciphertext.withUnsafeBytes { bytes in
                        return bytes.map {
                            String($0)
                        }
                    }
                    .joined(separator: ",")

            let tag = encryption.tag.withUnsafeBytes { bytes in
                        return bytes.map {
                            String($0)
                        }
                    }
                    .joined(separator: ",")

            let script = """
                         (() => {
                             window.\(methodName) && window.\(methodName)({
                                 ciphertext: [\(ciphertext)],
                                 tag: [\(tag)]
                             });
                         })();
                         """

            assert(message.messageWebView != nil)
            dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
            message.messageWebView?.evaluateJavaScript(script)
        }
    }
}
