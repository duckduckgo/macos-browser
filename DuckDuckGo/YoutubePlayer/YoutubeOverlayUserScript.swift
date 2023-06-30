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
import Common
import UserScript

protocol YoutubeOverlayUserScriptDelegate: AnyObject {
    func youtubeOverlayUserScriptDidRequestDuckPlayer(with url: URL, in webView: WKWebView)
}

final class YoutubeOverlayUserScript: NSObject, Subfeature {

    weak var broker: UserScriptMessageBroker?
    weak var delegate: YoutubeOverlayUserScriptDelegate?
    weak var webView: WKWebView?
    let messageOriginPolicy: MessageOriginPolicy = .only(rules: [
        .exact(hostname: "www.youtube.com"),
        .exact(hostname: "duckduckgo.com")
    ])
    public var featureName: String = "duckPlayer"

    // MARK: - Subfeature

    func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    // MARK: - MessageNames

    enum MessageNames: String, CaseIterable {
        case setUserValues
        case getUserValues
        case openDuckPlayer
        case sendDuckPlayerPixel
    }

    func handler(forMethodNamed methodName: String) -> Subfeature.Handler? {
        switch MessageNames(rawValue: methodName) {
        case .setUserValues:
            return DuckPlayer.shared.handleSetUserValues
        case .getUserValues:
            return DuckPlayer.shared.handleGetUserValues
        case .openDuckPlayer:
            return handleOpenDuckPlayer
        case .sendDuckPlayerPixel:
            return handleSendJSPixel
        default:
            assertionFailure("YoutubeOverlayUserScript: Failed to parse User Script message: \(methodName)")
            return nil
        }
    }

    public func userValuesUpdated(userValues: UserValues) {
        guard let webView = webView else {
            return assertionFailure("Could not access webView")
        }
        broker?.push(method: "onUserValuesChanged", params: userValues, for: self, into: webView)
    }

    // MARK: - Private Methods

    @MainActor
    private func handleOpenDuckPlayer(params: Any, message: UserScriptMessage) -> Encodable? {
        guard let dict = params as? [String: Any],
              let href = dict["href"] as? String,
              let url = href.url,
              let webView = message.messageWebView
        else {
            assertionFailure("YoutubeOverlayUserScript: expected URL")
            return nil
        }
        self.delegate?.youtubeOverlayUserScriptDidRequestDuckPlayer(with: url, in: webView)
        return nil
    }

    // MARK: - UserValuesNotification

    struct UserValuesNotification: Encodable {
        let userValuesNotification: UserValues
    }
}

extension YoutubeOverlayUserScript {
    @MainActor
    func handleSendJSPixel(params: Any, message: UserScriptMessage) -> Encodable? {
        // Temporary pixel for first time user uses Duck Player
        if !Pixel.isNewUser {
            return nil
        }
        guard let body = message.messageBody as? [String: Any] else {
            return nil
        }
        let pixelName = body["pixelName"] as? String
        if pixelName == "play.use" {
            let repetition = Pixel.Event.Repetition(key: Pixel.Event.watchInDuckPlayerInitial.name)
            if repetition == .initial {
                Pixel.fire(.watchInDuckPlayerInitial)
            }
        }
        return nil
    }
}
