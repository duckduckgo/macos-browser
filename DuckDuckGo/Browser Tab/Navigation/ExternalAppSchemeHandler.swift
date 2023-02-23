//
//  ExternalAppSchemeHandler.swift
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

import Combine
import Foundation
import Navigation

protocol PermissionModelProtocol {
    func permissions(_ permissions: [PermissionType], requestedForDomain domain: String?, url: URL?, decisionHandler: @escaping (Bool) -> Void)
}
extension PermissionModel: PermissionModelProtocol {}

final class ExternalAppSchemeHandler {

    private let workspace: Workspace
    private let permissionModel: PermissionModelProtocol

    private var externalSchemeOpenedPerPageLoad = false

    init(workspace: Workspace, permissionModel: PermissionModelProtocol) {
        self.workspace = workspace
        self.permissionModel = permissionModel
    }

}

extension ExternalAppSchemeHandler: NavigationResponder {

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        let externalUrl = navigationAction.url
        guard externalUrl.isExternalSchemeLink, let scheme = externalUrl.scheme else { return .next }
        lazy var searchUrl = URL.makeSearchUrl(from: externalUrl.absoluteString)

        // can OS open the external url?
        guard workspace.urlForApplication(toOpen: externalUrl) != nil else {
            // search if external URL can‘t be opened but entered by user
            if navigationAction.isUserEnteredUrl,
               let searchUrl,
               let mainFrame = navigationAction.mainFrameTarget {
                return .redirect(mainFrame) { navigator in
                    navigator.load(URLRequest(url: searchUrl))
                }
            }
            return .cancel
        }

        // Another way of detecting whether an app is installed to handle a protocol is described in Asana:
        // https://app.asana.com/0/1201037661562251/1202055908401751/f
        // removing First Responder focus from the WebView to make the page think the app was opened
        navigationAction.targetFrame?.webView?.removeFocusFromWebView()

        let permissionType = PermissionType.externalScheme(scheme: scheme)
        let domain = navigationAction.sourceFrame.securityOrigin.host

        permissionModel.permissions([permissionType], requestedForDomain: domain, url: externalUrl) { isGranted in
            if isGranted {
                NSWorkspace.shared.open(externalUrl)
            }
        }

        return .cancel
    }

    func willStart(_ navigation: Navigation) {
        externalSchemeOpenedPerPageLoad = false
    }

}

protocol ExternalSchemeHandlerProtocol: AnyObject, NavigationResponder {
}
extension ExternalAppSchemeHandler: TabExtension, ExternalSchemeHandlerProtocol {
    func getPublicProtocol() -> ExternalSchemeHandlerProtocol { self }

}

extension TabExtensions {
    var externalAppSchemeHandler: ExternalSchemeHandlerProtocol? {
        resolve(ExternalAppSchemeHandler.self)
    }
}
