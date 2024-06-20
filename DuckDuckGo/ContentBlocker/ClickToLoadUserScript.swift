//
//  ClickToLoadUserScript.swift
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
import Common
import UserScript

protocol ClickToLoadUserScriptDelegate: AnyObject {

    func clickToLoadUserScriptAllowFB() -> Bool
}

final class ClickToLoadUserScript: NSObject, WKNavigationDelegate, Subfeature {
    weak var broker: UserScriptMessageBroker?
    weak var webView: WKWebView?

    weak var delegate: ClickToLoadUserScriptDelegate?

#if DEBUG
    var devMode: Bool = true
#else
    var devMode: Bool = false
#endif

    // this isn't an issue to be set to 'all' because the page
    public let messageOriginPolicy: MessageOriginPolicy = .all
    public let featureName: String = "clickToLoad"

    // MARK: - Subfeature

    public func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    // MARK: - MessageNames

    enum MessageNames: String, CaseIterable {
        case getClickToLoadState
        case unblockClickToLoadContent
        case updateFacebookCTLBreakageFlags
        case addDebugFlag
    }

    public func handler(forMethodNamed methodName: String) -> Handler? {
        switch MessageNames(rawValue: methodName) {
        case .getClickToLoadState:
            return handleGetClickToLoadState
        case .unblockClickToLoadContent:
            return handleUnblockClickToLoadContent
        case .updateFacebookCTLBreakageFlags:
            return handleDebugFlagsMock
        case .addDebugFlag:
            return handleDebugFlagsMock
        default:
            assertionFailure("ClickToLoadUserScript: Failed to parse User Script message: \(methodName)")
            return nil
        }
    }

    @MainActor
    private func handleGetClickToLoadState(params: Any, message: UserScriptMessage) -> Encodable? {
        webView = message.messageWebView
        return [
            "devMode": devMode,
            "youtubePreviewsEnabled": false
        ]
    }

    @MainActor
    private func handleUnblockClickToLoadContent(params: Any, message: UserScriptMessage) -> Encodable? {
        guard let delegate = delegate else { return false }

        // only worry about CTL FB for now
        return delegate.clickToLoadUserScriptAllowFB()
    }

    @MainActor
    private func handleDebugFlagsMock(params: Any, message: UserScriptMessage) -> Encodable? {
        // breakage flags not supported on Mac yet
        return nil
    }

    @MainActor
    public func displayClickToLoadPlaceholders() {
        guard let webView else { return }

        broker?.push(method: "displayClickToLoadPlaceholders", params: ["ruleAction": ["block"]], for: self, into: webView)
    }
}
