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
import UserScript
import TrackerRadarKit
import PrivacyDashboard

protocol OLDPrivacyDashboardUserScriptDelegate: AnyObject {

    func userScript(_ userScript: OLDPrivacyDashboardUserScript, didSetPermission permission: PermissionType, to state: PermissionAuthorizationState)
    func userScript(_ userScript: OLDPrivacyDashboardUserScript, setPermission permission: PermissionType, paused: Bool)
}

final class OLDPrivacyDashboardUserScript {

    enum MessageNames: String, CaseIterable {
        case privacyDashboardSetPermission
        case privacyDashboardSetPermissionPaused
    }

    weak var delegate: OLDPrivacyDashboardUserScriptDelegate?
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageType = MessageNames(rawValue: message.name) else {
            assertionFailure("PrivacyDashboardUserScript: unexpected message name \(message.name)")
            return
        }

        switch messageType {
        case .privacyDashboardSetPermission:
            handleSetPermission(message: message)

        case .privacyDashboardSetPermissionPaused:
            handleSetPermissionPaused(message: message)
            
        }
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
    
    ///

    typealias AuthorizationState = [(permission: PermissionType, state: PermissionAuthorizationState)]
    func setPermissions(_ usedPermissions: Permissions,
                        authorizationState: AuthorizationState,
                        domain: String,
                        in webView: WKWebView) {

        let allowedPermissions = authorizationState.map { item in
            [
                "key": item.permission.rawValue,
                "icon": item.permission.jsStyle,
                "title": item.permission.jsTitle,
                "permission": item.state.rawValue,
                "used": usedPermissions[item.permission] != nil,
                "paused": usedPermissions[item.permission] == .paused,
                "options": PermissionAuthorizationState.allCases.compactMap { decision -> [String: String]? in
                    // don't show Permanently Allow if can't persist Granted Decision
                    switch decision {
                    case .grant:
                        guard item.permission.canPersistGrantedDecision else { return nil }
                    case .deny:
                        guard item.permission.canPersistDeniedDecision else { return nil }
                    case .ask: break
                    }
                    return [
                        "id": decision.rawValue,
                        "title": String(format: decision.localizedFormat(for: item.permission), domain)
                    ]
                }
            ]
        }
        guard let allowedPermissionsJson = (try? JSONSerialization.data(withJSONObject: allowedPermissions,
                                                                        options: []))?.utf8String()
        else {
            assertionFailure("PrivacyDashboardUserScript: could not serialize permissions object")
            return
        }

        evaluate(js: "window.onChangeAllowedPermissions(\(allowedPermissionsJson))", in: webView)
    }

    func setIsPendingUpdates(_ isPendingUpdates: Bool, webView: WKWebView) {
        evaluate(js: "window.onIsPendingUpdates(\(isPendingUpdates))", in: webView)
    }

    private func evaluate(js: String, in webView: WKWebView) {
        webView.evaluateJavaScript(js)
    }

}

extension PermissionAuthorizationState {
    func localizedFormat(for permission: PermissionType) -> String {
        switch (permission, self) {
        case (.popups, .ask):
            return UserText.privacyDashboardPopupsAlwaysAsk
        case (_, .ask):
            return UserText.privacyDashboardPermissionAsk
        case (_, .grant):
            return UserText.privacyDashboardPermissionAlwaysAllow
        case (_, .deny):
            return UserText.privacyDashboardPermissionAlwaysDeny
        }
    }
}

extension PermissionType {

    var jsStyle: String {
        switch self {
        case .camera, .microphone, .geolocation, .popups:
            return self.rawValue
        case .externalScheme:
            return "externalScheme"
        }
    }

    var jsTitle: String {
        switch self {
        case .camera, .microphone, .geolocation, .popups:
            return self.localizedDescription
        case .externalScheme:
            return String(format: UserText.permissionExternalSchemeOpenFormat, self.localizedDescription)
        }
    }

}
