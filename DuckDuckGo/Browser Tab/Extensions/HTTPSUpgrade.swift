//
//  HTTPSUpgrade.swift
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

final class HTTPSUpgradeTabExtension: TabExtension {

    private var lastUpgradedURL: URL?
    @Published fileprivate(set) var connectionUpgradedTo: URL?

    init() {}
    func attach(to tab: Tab) {
    }

    private func resetConnectionUpgradedTo(navigationAction: WKNavigationAction) {
        let isOnUpgradedPage = navigationAction.request.url == connectionUpgradedTo
        if !navigationAction.isTargetingMainFrame || isOnUpgradedPage { return }
        connectionUpgradedTo = nil
    }

    private func setConnectionUpgradedTo(_ upgradedUrl: URL, navigationAction: WKNavigationAction) {
        if !navigationAction.isTargetingMainFrame { return }
        connectionUpgradedTo = upgradedUrl
    }

}

extension HTTPSUpgradeTabExtension: NavigationResponder {

    func webView(_ webView: WebView, willStartNavigation navigation: WKNavigation?, with request: URLRequest) {
        lastUpgradedURL = nil
    }

    func webView(_ webView: WebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {

        guard navigationAction.isTargetingMainFrame,
              navigationAction.navigationType != .backForward,
              let url = navigationAction.request.url
        else {
            return .next
        }

        if navigationAction.request.mainDocumentURL?.host != lastUpgradedURL?.host {
            lastUpgradedURL = nil
        }

        if case let .success(upgradedURL) = await PrivacyFeatures.httpsUpgrade.upgrade(url: url), upgradedURL != url {
            lastUpgradedURL = upgradedURL
            setConnectionUpgradedTo(upgradedURL, navigationAction: navigationAction)

            return .redirect(to: upgradedURL)
        }

        self.resetConnectionUpgradedTo(navigationAction: navigationAction)
        return .next
    }

}

extension Tab {
    
    var connectionUpgradedTo: URL? {
        extensions.httpsUpgrade?.connectionUpgradedTo
    }

    var connectionUpgradedToPublisher: AnyPublisher<URL?, Never>? {
        extensions.httpsUpgrade?.$connectionUpgradedTo.eraseToAnyPublisher()
    }

}
