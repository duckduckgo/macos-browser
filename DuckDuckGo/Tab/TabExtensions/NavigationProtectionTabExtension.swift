//
//  NavigationProtectionTabExtension.swift
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
import Combine
import Common
import Foundation
import Navigation
import WebKit

final class NavigationProtectionTabExtension {

    let contentBlocking: AnyContentBlocking

    private static let debugEvents = EventMapping<AMPProtectionDebugEvents> { event, _, _, _ in
        switch event {
        case .ampBlockingRulesCompilationFailed:
            Pixel.fire(.ampBlockingRulesCompilationFailed)
        }
    }

    lazy var linkProtection: LinkProtection = {
        LinkProtection(privacyManager: contentBlocking.privacyConfigurationManager,
                       contentBlockingManager: contentBlocking.contentBlockingManager,
                       errorReporting: Self.debugEvents)
    }()

    lazy var referrerTrimming: ReferrerTrimming = {
        ReferrerTrimming(privacyManager: contentBlocking.privacyConfigurationManager,
                         contentBlockingManager: contentBlocking.contentBlockingManager,
                         tld: contentBlocking.tld)
    }()

    @MainActor
    @Published var isAMPProtectionExtracting: Bool = false

    init(contentBlocking: AnyContentBlocking) {
        self.contentBlocking = contentBlocking

    }

}

extension NavigationProtectionTabExtension: NavigationResponder {

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        // We don‘t handle opening new tabs here because a new Tab is opened in
        // Tab+Navigation and it will run through this procedure again for its NavigationAction

        guard !navigationAction.navigationType.isBackForward,
              navigationAction.isForMainFrame
        else { return .next }

        let rewrittenTrackingLinkUrl = await linkProtection.requestTrackingLinkRewrite(initiatingURL: navigationAction.sourceFrame.url,
                                                                                       destinationURL: navigationAction.url,
                                                                                       updateIsExtracting: { self.isAMPProtectionExtracting = $0 })
        guard !Task.isCancelled else { return .cancel }

        if let rewrittenTrackingLinkUrl {
            return .redirectInvalidatingBackItemIfNeeded(navigationAction) {
                $0.load(URLRequest(url: rewrittenTrackingLinkUrl))
            }
        }

        if let request = referrerTrimming.trimReferrer(for: navigationAction.request, originUrl: navigationAction.sourceFrame.url) {
            return .redirectInvalidatingBackItemIfNeeded(navigationAction) {
                $0.load(request)
            }
        }

        if let request = GPCRequestFactory().requestForGPC(basedOn: navigationAction.request,
                                                           config: contentBlocking.privacyConfigurationManager.privacyConfig,
                                                           gpcEnabled: PrivacySecurityPreferences.shared.gpcEnabled) {
            return .redirectInvalidatingBackItemIfNeeded(navigationAction) {
                $0.load(request)
            }
        }

        return .next
    }

    @MainActor
    func didStart(_ navigation: Navigation) {
        linkProtection.cancelOngoingExtraction()
        linkProtection.setMainFrameUrl(navigation.url)
        referrerTrimming.onBeginNavigation(to: navigation.url)
    }

    @MainActor
    func navigationDidFinish(_ navigation: Navigation) {
        if isAMPProtectionExtracting {
            isAMPProtectionExtracting = false
        }
        linkProtection.setMainFrameUrl(nil)
        referrerTrimming.onFinishNavigation()
    }

    @MainActor
    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        guard navigation.isCurrent else { return }
        linkProtection.setMainFrameUrl(nil)
        referrerTrimming.onFailedNavigation()
    }

}

extension LinkProtection {

    @MainActor
    public func requestTrackingLinkRewrite(initiatingURL: URL?,
                                           destinationURL: URL,
                                           updateIsExtracting: @escaping (Bool) -> Void) async -> URL? {
        await withCheckedContinuation { continuation in
            let didRewriteLink = {
                requestTrackingLinkRewrite(initiatingURL: initiatingURL, destinationURL: destinationURL, onStartExtracting: {
                    updateIsExtracting(true)
                }) {
                    updateIsExtracting(false)
                } onLinkRewrite: { url in
                    continuation.resume(returning: url) // <---
                } policyDecisionHandler: { allowNavigationAction in
                    if allowNavigationAction {
                        continuation.resume(returning: nil)
                    } // else: will handle in onLinkRewrite: ^^
                } // -> returns true if will process link rewriting
            }()
            if !didRewriteLink {
                // if it won‘t rewrite: resume navigation action
                continuation.resume(returning: nil)
            }
        }
    }

}

protocol NavigationProtectionExtensionProtocol: AnyObject, NavigationResponder {
    var linkProtection: LinkProtection { get }
    var isAMPProtectionExtractingPublisher: AnyPublisher<Bool, Never> { get }
    func getCleanURL(from url: URL) async -> URL
}
extension NavigationProtectionTabExtension: TabExtension, NavigationProtectionExtensionProtocol {
    func getPublicProtocol() -> NavigationProtectionExtensionProtocol { self }

    var isAMPProtectionExtractingPublisher: AnyPublisher<Bool, Never> {
        $isAMPProtectionExtracting.eraseToAnyPublisher()
    }

    @MainActor
    public func getCleanURL(from url: URL) async -> URL {
        await linkProtection.getCleanURL(from: url, onStartExtracting: {
            isAMPProtectionExtracting = true
        }, onFinishExtracting: { [self /*async holds us*/] in
            self.isAMPProtectionExtracting = false
        })
    }

}
extension TabExtensions {
    var navigationProtection: NavigationProtectionExtensionProtocol? {
        resolve(NavigationProtectionTabExtension.self)
    }
}

extension Tab {
    var linkProtection: LinkProtection {
        self.navigationProtection!.linkProtection
    }
    var isAMPProtectionExtractingPublisher: AnyPublisher<Bool, Never> {
        self.navigationProtection?.isAMPProtectionExtractingPublisher ?? Just(false).eraseToAnyPublisher()
    }
}
