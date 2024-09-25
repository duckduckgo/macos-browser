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
import PixelKit

final class NavigationProtectionTabExtension {

    private let contentBlocking: AnyContentBlocking

    private static let debugEvents = EventMapping<AMPProtectionDebugEvents> { event, _, _, _ in
        switch event {
        case .ampBlockingRulesCompilationFailed:
            PixelKit.fire(GeneralPixel.ampBlockingRulesCompilationFailed)
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

    init(contentBlocking: AnyContentBlocking) {
        self.contentBlocking = contentBlocking

    }

    private func resetNavigation() {
        linkProtection.setMainFrameUrl(nil)
        referrerTrimming.onFinishNavigation()
    }

}

extension NavigationProtectionTabExtension: NavigationResponder {

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        // We don‘t handle opening new tabs here because a new Tab is opened in
        // Tab+Navigation and it will run through this procedure again for its NavigationAction

        guard !navigationAction.navigationType.isBackForward,
              navigationAction.isForMainFrame
        else { return .next }
        var isNewlyInitiatedAction: Bool {
            switch navigationAction.navigationType {
            case .custom(.userEnteredUrl),
                 .custom(.loadedByStateRestoration),
                 .custom(.appOpenUrl),
                 .custom(.historyEntry),
                 .custom(.bookmark),
                 .custom(.ui),
                 .custom(.link),
                 .custom(.webViewUpdated),
                 .reload: true
            default: false
            }
        }

        // IMPORTANT: WebView navigationDidFinish event may race with Client Redirect NavigationAction
        // that‘s why it‘s been standardized to delay navigationDidFinish until decidePolicy(for:navigationAction) is handled
        // (see DistributedNavigationDelegate.webView(_:willPerformClientRedirectTo:delay:) method
        // when client redirect happens ReferrerTrimming.state should be `idle`, that‘s why we‘re resetting it here
        if navigationAction.navigationType.redirect?.isClient == true
            // if otherwise newly initiated action is racing with an active navigation - also reset it
            || navigationAction.navigationType == .linkActivated(isMiddleClick: false) || isNewlyInitiatedAction
            || navigationAction.isUserInitiated {

            resetNavigation()
        }

        var request = navigationAction.request

        // getCleanURL for user or ui-initiated navigations
        // https://app.asana.com/0/0/1203538050625396/f
        if isNewlyInitiatedAction {
            let cleanUrl = await linkProtection.getCleanURL(from: request.url!, onStartExtracting: {}, onFinishExtracting: {})
            if cleanUrl != request.url {
                request.url = cleanUrl
            }
        }
        guard !Task.isCancelled else { return .cancel }

        if let newRequest = await linkProtection.requestTrackingLinkRewrite(initiatingURL: navigationAction.sourceFrame.url, destinationRequest: request) {
            request = newRequest
        }
        guard !Task.isCancelled else { return .cancel }

        if let newRequest = referrerTrimming.trimReferrer(for: request, originUrl: navigationAction.sourceFrame.url) {
            request = newRequest
        }

        let isGPCEnabled = WebTrackingProtectionPreferences.shared.isGPCEnabled
        if let newRequest = GPCRequestFactory().requestForGPC(basedOn: request,
                                                              config: contentBlocking.privacyConfigurationManager.privacyConfig,
                                                              gpcEnabled: isGPCEnabled) {
            request = newRequest
        }

        if request != navigationAction.request {
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
        resetNavigation()
    }

    @MainActor
    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        guard navigation.isCurrent else { return }
        resetNavigation()
    }

}

extension LinkProtection {

    @MainActor
    public func requestTrackingLinkRewrite(initiatingURL: URL?,
                                           destinationRequest: URLRequest) async -> URLRequest? {
        await withCheckedContinuation { continuation in
            let didRewriteLink = {
                requestTrackingLinkRewrite(initiatingURL: initiatingURL, destinationRequest: destinationRequest, onStartExtracting: {}, onFinishExtracting: {}) { newRequest in
                    continuation.resume(returning: newRequest) // <---
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
}
extension NavigationProtectionTabExtension: TabExtension, NavigationProtectionExtensionProtocol {
    func getPublicProtocol() -> NavigationProtectionExtensionProtocol { self }
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
}
