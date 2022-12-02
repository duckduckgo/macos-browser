//
//  ExternalSchemeHandler.swift
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

protocol WorkspaceURLHandler {

    @discardableResult
    func open(_ url: URL) -> Bool

    func urlForApplication(toOpen url: URL) -> URL?

}
extension NSWorkspace: WorkspaceURLHandler {}

final class ExternalSchemeHandler: TabExtension {

    @Injected static var workspace: WorkspaceURLHandler = NSWorkspace.shared

    private weak var tab: Tab?
    private var externalSchemeOpenedPerPageLoad = false

    init() {
    }

    func attach(to tab: Tab) {
        self.tab = tab
    }

}

extension ExternalSchemeHandler: NavigationResponder {

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        guard let externalURL = navigationAction.request.url,
              externalURL.isExternalSchemeLink
        else {
            externalSchemeOpenedPerPageLoad = false
            return .next
        }

        // always allow user entered URLs
        if !navigationAction.request.isUserInitiated {
            // ignore <iframe src="custom://url">
            // ignore 2nd+ external scheme navigation not initiated by user
            guard navigationAction.sourceFrame.isMainFrame,
                  !self.externalSchemeOpenedPerPageLoad || navigationAction.isUserInitiated
            else { return .cancel }
            // next page-initiated external URL request will be declined
            self.externalSchemeOpenedPerPageLoad = true
        }

        let websiteURL = navigationAction.sourceFrame.url
        let domain = websiteURL?.host
        let userEntered = navigationAction.isForMainFrame && navigationAction.request.isUserInitiated

        // Another way of detecting whether an app is installed to handle a protocol is described in Asana:
        // https://app.asana.com/0/1201037661562251/1202055908401751/f
        guard Self.workspace.urlForApplication(toOpen: externalURL) != nil else {
            return userEntered ? search(for: externalURL) : .cancel
        }
        tab?.delegate?.removeFirstResponderFromWebView()

        let permissionType = PermissionType.externalScheme(scheme: externalURL.scheme ?? "")
        let permissionRequest = tab?.permissions.request([permissionType], forDomain: domain, url: websiteURL)

        guard await permissionRequest?.get() == true, let tab = tab else {
            return userEntered ? search(for: externalURL) : .cancel
        }

        Self.workspace.open(externalURL)
        tab.permissions.permissions[permissionType].externalSchemeOpened()

        return .cancel
    }

    private func search(for url: URL) -> NavigationActionPolicy {
        guard let searchURL = URL.makeSearchUrl(from: url.absoluteString) else { return .cancel }
        return .redirect(to: searchURL)
    }

}
