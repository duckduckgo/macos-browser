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
    func permissions(_ permissions: [PermissionType], requestedForDomain domain: String, url: URL?, decisionHandler: @escaping (Bool) -> Void)
}
extension PermissionModel: PermissionModelProtocol {}

final class ExternalAppSchemeHandler {

    private let workspace: Workspace
    private let permissionModel: PermissionModelProtocol

    private var externalSchemeOpenedPerPageLoad = false

    private var lastUserEnteredValue: String?
    private var cancellable: AnyCancellable?

    init(workspace: Workspace, permissionModel: PermissionModelProtocol, contentPublisher: some Publisher<Tab.TabContent, Never>) {
        self.workspace = workspace
        self.permissionModel = permissionModel

        cancellable = contentPublisher.sink { [weak self] tabContent in
            if case .url(_, credential: .none, userEntered: .some(let userEnteredValue)) = tabContent {
                self?.lastUserEnteredValue = userEnteredValue
            }
        }
    }

}

extension ExternalAppSchemeHandler: NavigationResponder {

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        let externalUrl = navigationAction.url
        guard externalUrl.isExternalSchemeLink, let scheme = externalUrl.scheme else { return .next }
        // prevent opening twice for session restoration/tab reopening requests
        guard navigationAction.request.cachePolicy != .returnCacheDataElseLoad else {
            return .cancel
        }

        // can OS open the external url?
        guard workspace.urlForApplication(toOpen: externalUrl) != nil else {
            // search if external URL can‘t be opened but entered by user
            if navigationAction.isUserEnteredUrl,
               let searchUrl = URL.makeSearchUrl(from: lastUserEnteredValue ?? externalUrl.absoluteString),
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
        // make the web view First Responder first if it‘s not
        navigationAction.targetFrame?.webView?.makeMeFirstResponder()
        navigationAction.targetFrame?.webView?.removeFocusFromWebView()

        if let targetSecurityOrigin = navigationAction.targetFrame?.securityOrigin,
           navigationAction.sourceFrame.securityOrigin != targetSecurityOrigin {
            return .cancel
        }

        let permissionType = PermissionType.externalScheme(scheme: scheme)
        // use domain from the url for user-entered app schemes, otherwise use current website domain
        let domain = navigationAction.isUserEnteredUrl ? navigationAction.url.host ?? "" : navigationAction.sourceFrame.securityOrigin.host
        permissionModel.permissions([permissionType], requestedForDomain: domain, url: externalUrl) { [workspace] isGranted in
            if isGranted {
                workspace.open(externalUrl)
            }
        }

        return .cancel
    }

    func willStart(_ navigation: Navigation) {
        externalSchemeOpenedPerPageLoad = false
    }

    func navigationDidFinish(_ navigation: Navigation) {
        lastUserEnteredValue = nil
    }

    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        guard navigation.isCurrent else { return }
        lastUserEnteredValue = nil
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
