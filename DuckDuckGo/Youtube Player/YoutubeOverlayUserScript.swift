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
import BrowserServicesKit

protocol YoutubeOverlayUserScriptDelegate: AnyObject {
    func youtubeOverlayUserScriptDidRequestDuckPlayer(with url: URL)
}

final class YoutubeOverlayUserScript: NSObject, ContentScopeScriptsSubFeature {

    var allowedOrigins: AllowedOrigins = .only([
        .exact(hostname: "www.youtube.com"),
        .exact(hostname: "duckduckgo.com"),
    ])

    enum MessageNames: String, CaseIterable {
        case setUserValues
        case readUserValues
        case openDuckPlayer
        case sendDuckPlayerPixel
    }

    struct YoutubeUserScriptConfig: Encodable {
        let webkitMessagingConfig: WebkitMessagingConfig
    }

    // This conforms to https://duckduckgo.github.io/content-scope-utils/classes/Webkit_Messaging.WebkitMessagingConfig.html
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

    init(preferences: PrivatePlayerPreferences = .shared) {
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

    public func messageHandlerForFeature(_ messageName: String) -> MessageHandlerSubFeature? {
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
        case .sendDuckPlayerPixel:
            return handleSendJSPixel
        }
    }

    // MARK: - Private

    private func handleSetUserValues(messageBody: [String: Any], _ replyHandler: @escaping MessageReplyHandler) {
        guard let userValues: UserValues = DecodableHelper.decode(from: messageBody) else {
            assertionFailure("YoutubeOverlayUserScript: expected JSON representation of UserValues")
            return
        }

        privatePlayerPreferences.youtubeOverlayInteracted = userValues.overlayInteracted
        privatePlayerPreferences.privatePlayerMode = userValues.privatePlayerMode

        replyHandler(encodeUserValues())
    }

    private func handleReadUserValues(messageBody: [String: Any], _ replyHandler: @escaping MessageReplyHandler) {
        replyHandler(encodeUserValues())
    }

    private func handleOpenDuckPlayer(messageBody: [String: Any], _ replyHandler: @escaping MessageReplyHandler) {
        guard let dict = messageBody as? [String: Any],
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

    private let privatePlayerPreferences: PrivatePlayerPreferences
}

extension YoutubeOverlayUserScript {
    public enum JSPixel: String {
        case overlay = "overlay"
        case playUse = "play.use"
        case playDoNotUse = "play.do_not_use"

        public var pixelName: String {
            self.rawValue
        }
    }

    func handleSendJSPixel(_ messageBody: [String: Any], replyHandler: @escaping MessageReplyHandler) {
        defer {
            replyHandler(nil)
        }

        guard let body = messageBody as? [String: Any],
              let pixelName = body["pixelName"] as? String,
              let knownPixel = JSPixel(rawValue: pixelName) else {
            assertionFailure("Not accepting an unknown pixel name")
            return
        }

        let pixelParameters = body["params"] as? [String: String]

        Pixel.fire(.duckPlayerJSPixel(knownPixel), withAdditionalParameters: pixelParameters)
    }
}
