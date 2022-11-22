//
//  LinkProtectionExtension.swift
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

import BrowserServicesKit
import Foundation
import WebKit

final class LinkProtectionExtension {

    struct Dependencies {
        @Injected(default: ContentBlocking.shared.privacyConfigurationManager) static var privacyManager: PrivacyConfigurationManaging
        @Injected(default: ContentBlocking.shared.contentBlockingManager) static var contentBlockingManager: ContentBlockerRulesManager

        @Injected(.testable) static var debugEvents = EventMapping<AMPProtectionDebugEvents> { event, _, _, _ in
            switch event {
            case .ampBlockingRulesCompilationFailed:
                Pixel.fire(.ampBlockingRulesCompilationFailed)
            }
        }
    }

    fileprivate var linkProtection = LinkProtection(privacyManager: Dependencies.privacyManager,
                                                    contentBlockingManager: Dependencies.contentBlockingManager,
                                                    errorReporting: Dependencies.debugEvents)

}

extension LinkProtectionExtension: NavigationResponder {

    func webView(_ webView: WebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        guard navigationAction.isTargetingMainFrame,
              navigationAction.navigationType != .backForward,
              let url = navigationAction.request.url
        else { return .next }

        // TODO: Only do this for new user-intent requests
        var cleanURL = await linkProtection.getCleanURL(from: url)
        cleanURL = await linkProtection.requestTrackingLinkRewrite(navigationAction: navigationAction) ?? cleanURL

        if cleanURL != url {
            return .redirect(to: cleanURL)
        }
        return .next
    }

    func webView(_ webView: WebView, didStart navigation: WKNavigation, with request: URLRequest) {
        linkProtection.cancelOngoingExtraction()
        linkProtection.setMainFrameUrl(webView.url)
    }

    func webView(_ webView: WebView, didFinish navigation: WKNavigation, with request: URLRequest) {
        linkProtection.setMainFrameUrl(nil)
    }

    func webView(_ webView: WebView, navigation: WKNavigation, with request: URLRequest, didFailWith error: Error) {
        linkProtection.setMainFrameUrl(nil)
    }

}

extension Tab {
    var linkProtection: LinkProtection! {
        extensions.linkProtection?.linkProtection
    }
}

private extension LinkProtection {

    @MainActor
    func getCleanURL(from url: URL) async -> URL {
        await withCheckedContinuation { continuation in
            getCleanURL(from: url, onStartExtracting: {}, onFinishExtracting: {}) { url in
                continuation.resume(returning: url)
            }
        }
    }

    @MainActor
    func requestTrackingLinkRewrite(navigationAction: WKNavigationAction,
                                    onStartExtracting: () -> Void = {},
                                    onFinishExtracting: @escaping () -> Void = {}) async -> URL? {
        await withCheckedContinuation { continuation in
            var resultURL: URL?
            let didRewriteLink = requestTrackingLinkRewrite(initiatingURL: navigationAction.sourceFrame.request.url,
                                                            navigationAction: navigationAction,
                                                            onStartExtracting: onStartExtracting,
                                                            onFinishExtracting: onFinishExtracting,
                                                            onLinkRewrite: { url, _ in
                resultURL = url

            }) { navigationActionPolicy in
                continuation.resume(returning: navigationActionPolicy == .cancel ? resultURL : nil)
            }

            if !didRewriteLink {
                continuation.resume(returning: nil)
            }
        }
    }

}
