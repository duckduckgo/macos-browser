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

    // Tab will be closed when opening an external app if:
    // - Currently loaded page is the first navigation of the Tab (back history is empty) or there‘s no page loaded
    // - The page is open in a new tab (link clicked on another Tab or NSApp opened a URL) and not triggered by a user entering a URL in a new Tab
    // - External Scheme Navigation Action was not initiated by user (URL is not user-entered)
    // The flag is true by default and reset when non-initial navigation is performed
    private var shouldCloseTabOnExternalAppOpen = true

    private var lastUserEnteredValue: String?
    private var cancellable: AnyCancellable?

    init(workspace: Workspace, permissionModel: PermissionModelProtocol, contentPublisher: some Publisher<Tab.TabContent, Never>) {
        self.workspace = workspace
        self.permissionModel = permissionModel

        cancellable = contentPublisher.sink { [weak self] tabContent in
            self?.lastUserEnteredValue = tabContent.userEnteredValue
        }
    }

}

extension ExternalAppSchemeHandler: NavigationResponder {

    @MainActor func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        let externalUrl = navigationAction.url
        // only proceed with non-external-scheme navigations
        guard externalUrl.isExternalSchemeLink, let scheme = externalUrl.scheme else {
            // is it the first navigation?
            if navigationAction.isForMainFrame, navigationAction.fromHistoryItemIdentity != nil {
                // don‘t close tab when opening an app for non-initial navigations
                shouldCloseTabOnExternalAppOpen = false
            }
            // proceed with regular navigation
            return .next
        }

        // don‘t close tab for user-entered URLs
        if let mainFrameNavigationAction = navigationAction.mainFrameNavigation?.navigationAction,
           (mainFrameNavigationAction.redirectHistory?.first ?? mainFrameNavigationAction).isUserEnteredUrl == true {
            shouldCloseTabOnExternalAppOpen = false
        }
        // only close tab when "Always Open" is on (so the callback would be called synchronously)
        defer {
            if navigationAction.isForMainFrame {
                shouldCloseTabOnExternalAppOpen = false
            }
        }

        // prevent opening twice for session restoration/tab reopening requests
        guard ![.returnCacheDataElseLoad, .returnCacheDataDontLoad]
            .contains((navigationAction.mainFrameNavigation?.navigationAction.redirectHistory?.first
                       ?? navigationAction.mainFrameNavigation?.navigationAction
                       ?? navigationAction).request.cachePolicy) else {
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
           !targetSecurityOrigin.host.isEmpty,
           navigationAction.sourceFrame.securityOrigin != targetSecurityOrigin {
            return .cancel
        }

        let permissionType = PermissionType.externalScheme(scheme: scheme)
        // Check for cross-origin redirects first, then use domain from the url for user-entered app schemes, then use current website domain
        let redirectDomain = navigationAction.redirectHistory?.reversed().first(where: { $0.url.host != navigationAction.url.host })?.url.host
        let domain = redirectDomain ?? (navigationAction.isUserEnteredUrl ? navigationAction.url.host ?? "" : navigationAction.sourceFrame.securityOrigin.host)
        permissionModel.permissions([permissionType], requestedForDomain: domain, url: externalUrl) { [workspace] isGranted in
            if isGranted {
                workspace.open(externalUrl)
                // if "Always allow" is set and this is the only navigation in the tab: close the tab
                if self.shouldCloseTabOnExternalAppOpen == true, let webView = navigationAction.targetFrame?.webView {
                    webView.close()
                }
            }
        }
        return .cancel
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
