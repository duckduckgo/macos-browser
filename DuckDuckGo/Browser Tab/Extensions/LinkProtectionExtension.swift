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

final class LinkProtectionExtension: TabExtension {

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

    init() {}
    func attach(to tab: Tab) {
    }

}

extension LinkProtectionExtension: NavigationResponder {

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        guard navigationAction.isForMainFrame,
              navigationAction.navigationType != .backForward,
              let url = navigationAction.request.url
        else { return .next }

        // TODO: breaking POST requests, make asana if valid
        // TODO: Only do this for new user-intent requests
        var cleanURL = await linkProtection.getCleanURL(from: url)
        cleanURL = await linkProtection.requestTrackingLinkRewrite(navigationAction: navigationAction) ?? cleanURL

        if cleanURL != url {
            return .redirect(to: cleanURL)
        }
        return .next
    }

    func didStart(_ navigation: Navigation) {
        linkProtection.cancelOngoingExtraction()
        linkProtection.setMainFrameUrl(navigation.request.url)
    }

    func navigationDidFinishOrReceivedClientRedirect(_ navigation: Navigation) {
        linkProtection.setMainFrameUrl(nil)
    }

    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
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
    func requestTrackingLinkRewrite(navigationAction: NavigationAction,
                                    onStartExtracting: () -> Void = {},
                                    onFinishExtracting: @escaping () -> Void = {}) async -> URL? {
        await withCheckedContinuation { continuation in
            var resultURL: URL?
            let didRewriteLink = requestTrackingLinkRewrite(initiatingURL: navigationAction.sourceFrame.url,
                                                            destinationURL: navigationAction.url,
                                                            onStartExtracting: onStartExtracting,
                                                            onFinishExtracting: onFinishExtracting,
                                                            onLinkRewrite: { url in
                resultURL = url

            }) { navigationActionPolicy in
                continuation.resume(returning: navigationActionPolicy ? nil : resultURL)
            }

            if !didRewriteLink {
                continuation.resume(returning: nil)
            }
        }
    }

}
