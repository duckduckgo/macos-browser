//
//  PrivacyDashboardUserScript.swift
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
import os
import BrowserServicesKit

protocol PrivacyDashboardUserScriptDelegate: AnyObject {

    func userScript(_ userScript: PrivacyDashboardUserScript, didChangeProtectionStateTo protectionState: Bool)
    func userScript(_ userScript: PrivacyDashboardUserScript, didSetPermission permission: PermissionType, to state: PermissionAuthorizationState)
    func userScript(_ userScript: PrivacyDashboardUserScript, setPermission permission: PermissionType, paused: Bool)

}

final class PrivacyDashboardUserScript: NSObject {

    enum MessageNames: String, CaseIterable {
        case privacyDashboardSetProtection
        case privacyDashboardFirePixel
        case privacyDashboardSetPermission
        case privacyDashboardSetPermissionPaused
    }

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    static var forMainFrameOnly: Bool { false }
    var messageNames: [String] { MessageNames.allCases.map(\.rawValue) }

    weak var delegate: PrivacyDashboardUserScriptDelegate?
    weak var model: FindInPageModel?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageType = MessageNames(rawValue: message.name) else {
            assertionFailure("PrivacyDashboardUserScript: unexpected message name \(message.name)")
            return
        }

        switch messageType {
        case .privacyDashboardSetProtection:
            handleSetProtection(message: message)

        case .privacyDashboardFirePixel:
            handleFirePixel(message: message)

        case .privacyDashboardSetPermission:
            handleSetPermission(message: message)

        case .privacyDashboardSetPermissionPaused:
            handleSetPermissionPaused(message: message)
        }
    }

    private func handleSetProtection(message: WKScriptMessage) {
        guard let protectionIsActive = message.body as? Bool else {
            assertionFailure("privacyDashboardSetProtection: expected Bool")
            return
        }

        delegate?.userScript(self, didChangeProtectionStateTo: protectionIsActive)
    }

    private func handleFirePixel(message: WKScriptMessage) {
        guard let pixel = message.body as? String else {
            assertionFailure("privacyDashboardFirePixel: expected Pixel String")
            return
        }

        Pixel.shared?.fire(pixelNamed: pixel)
    }

    private func handleSetPermission(message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let permission = (dict["permission"] as? String).flatMap(PermissionType.init(rawValue:)),
              let state = (dict["value"] as? String).flatMap(PermissionAuthorizationState.init(rawValue:))
        else {
            assertionFailure("privacyDashboardSetPermission: expected { permission: PermissionType, value: PermissionAuthorizationState }")
            return
        }

        delegate?.userScript(self, didSetPermission: permission, to: state)
    }

    private func handleSetPermissionPaused(message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let permission = (dict["permission"] as? String).flatMap(PermissionType.init(rawValue:)),
              let paused = dict["paused"] as? Bool
        else {
            assertionFailure("handleSetPermissionPaused: expected { permission: PermissionType, paused: Bool }")
            return
        }

        delegate?.userScript(self, setPermission: permission, paused: paused)

    }

    func setTrackerBlocking(_ trackerBlockingEnabled: Bool, in webView: WKWebView) {
        evaluate(js: "window.onChangeTrackerBlocking(\(trackerBlockingEnabled))", in: webView)
    }

    func setPermissions(_ usedPermissions: Permissions,
                        authorizationState: [PermissionType: PermissionAuthorizationState],
                        domain: String,
                        in webView: WKWebView) {

        let dict = authorizationState.reduce(into: [String: Any]()) {
            $0[$1.key.rawValue] = [
                "title": $1.key.localizedDescription,
                "permission": $1.value.rawValue,
                "used": usedPermissions.permissions[$1.key] != nil,
                "paused": usedPermissions.permissions[$1.key]?.isPaused ?? false,
                "options": PermissionAuthorizationState.allCases.map {
                    [
                        "id": $0.rawValue,
                        "title": String(format: $0.localizedFormat, domain)
                    ]
                }
            ]
        }
        guard let arg = (try? JSONSerialization.data(withJSONObject: dict, options: []))?.utf8String() else {
            assertionFailure("PrivacyDashboardUserScript: could not serialize permissions object")
            return
        }
        evaluate(js: "window.onChangeAllowedPermissions(\(arg))", in: webView)
    }

    private func evaluate(js: String, in webView: WKWebView) {
        if #available(macOS 11.0, *) {
            webView.evaluateJavaScript(js, in: nil, in: WKContentWorld.defaultClient)
        } else {
            webView.evaluateJavaScript(js)
        }
    }

}

extension PermissionAuthorizationState {
    var localizedFormat: String {
        switch self {
        case .ask:
            return UserText.permissionAlwaysAskFormat
        case .grant:
            return UserText.permissionAlwaysAllowFormat
        case .deny:
            return UserText.permissionAlwaysDenyFormat
        }
    }
}
