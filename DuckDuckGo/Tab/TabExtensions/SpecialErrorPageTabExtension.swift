//
//  SpecialErrorPageTabExtension.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import ContentScopeScripts
import Foundation
import MaliciousSiteProtection
import Navigation
import os
import PixelKit
import SpecialErrorPages
import WebKit

protocol SpecialErrorPageScriptProvider {
    var specialErrorPageUserScript: SpecialErrorPageUserScript? { get }
}

extension UserScripts: SpecialErrorPageScriptProvider {}

final class SpecialErrorPageTabExtension {

    private let urlCredentialCreator: URLCredentialCreating
    private let featureFlagger: FeatureFlagger
    private let detector: MaliciousSiteDetecting
    private let tld = TLD()

    @MainActor private weak var webView: ErrorPageTabExtensionNavigationDelegate?
    @MainActor private weak var specialErrorPageUserScript: SpecialErrorPageUserScript?
    private let closeTab: () -> Void

    @MainActor private var exemptions: [URL: MaliciousSiteProtection.ThreatKind] = [:]
    @MainActor private var shouldBypassSSLError = false
    @MainActor private(set) var state = MaliciousSiteProtectionState()
    @MainActor private(set) var errorData: SpecialErrorData?

    private var cancellables = Set<AnyCancellable>()

    init(webViewPublisher: some Publisher<some ErrorPageTabExtensionNavigationDelegate, Never>,
         scriptsPublisher: some Publisher<some SpecialErrorPageScriptProvider, Never>,
         closeTab: @escaping () -> Void,
         urlCredentialCreator: URLCredentialCreating = URLCredentialCreator(),
         featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger,
         maliciousSiteDetector: some MaliciousSiteDetecting) {

        self.featureFlagger = featureFlagger
        self.urlCredentialCreator = urlCredentialCreator
        self.detector = maliciousSiteDetector
        self.closeTab = closeTab

        webViewPublisher.sink { [weak self] webView in
            MainActor.assumeIsolated {
                self?.webView = webView
            }
        }.store(in: &cancellables)
        scriptsPublisher.sink { [weak self] scripts in
            MainActor.assumeIsolated {
                self?.specialErrorPageUserScript = scripts.specialErrorPageUserScript
                self?.specialErrorPageUserScript?.delegate = self
            }
        }.store(in: &cancellables)
    }

}

extension SpecialErrorPageTabExtension: NavigationResponder {

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        let url = navigationAction.url

        // An edge case for if a site gets flagged as malicious, the user clicks through the warning,
        // and then the malicious page redirects to a site that isn't flagged.
        //
        // We want to ensure the new site is still marked as dangerous in the privacy dashboard.
        // So we basically flag all URLs in the redirect chain as malicious (and exempted) too.
        //
        // There may be cases where this is a bad idea, for example a malicious site that redirects to a socialnetwork.com -
        // but if a flagged site sends you somewhere, you should still be cautious of that site so we want it to remain flagged.
        if let threatKind = state.bypassedMaliciousSiteThreatKind, navigationAction.navigationType == .other {
            exemptions[url] = threatKind
        }
        state.bypassedMaliciousSiteThreatKind = exemptions[url]

        if state.bypassedMaliciousSiteThreatKind != .none || url.isDuckDuckGo || url.isDuckURLScheme {
            state.currentMalicousSiteThreatKind = .none
            return .next
        }

        guard let threatKind = await detector.evaluate(url) else {
            state.currentMalicousSiteThreatKind = .none
            return .next
        }

        state.currentMalicousSiteThreatKind = threatKind

        return redirectMaliciousNavigationAction(navigationAction, with: threatKind)
    }

    @MainActor
    private func redirectMaliciousNavigationAction(_ navigationAction: NavigationAction, with threatKind: MaliciousSiteProtection.ThreatKind) -> NavigationActionPolicy? {
        // Check if the main frame target is available; if not, handle as an iframe navigation
        guard let mainFrame = navigationAction.mainFrameTarget else {
            return redirectMaliciousIframeNavigationAction(navigationAction, with: threatKind)
        }

        let url = navigationAction.url

        // Generate a custom duck://error page URL that will be handled by DuckURLSchemeHandler
        // DuckURLSchemeHandler will decode the error and fail the custom URL scheme navigation task with the error,
        // which will then navigate to a special error page (`Tab.swift: navigation(_:didFailWith:)`)
        let errorUrl = URL.specialErrorPage(failingUrl: url, kind: threatKind.errorPageKind)

        return .redirect(mainFrame) { navigator in
            navigator.load(URLRequest(url: errorUrl))
        }
    }

    @MainActor
    private func redirectMaliciousIframeNavigationAction(_ navigationAction: NavigationAction, with threatKind: MaliciousSiteProtection.ThreatKind) -> NavigationActionPolicy? {
        PixelKit.fire(MaliciousSiteProtection.Event.iframeLoaded(category: threatKind))

        // Extract the URL of the source frame (the iframe) that initiated the navigation action
        let iframeTopUrl = navigationAction.sourceFrame.url

        // Generate a custom duck://error page URL that will be handled by DuckURLSchemeHandler
        // DuckURLSchemeHandler will decode the error and fail the custom URL scheme navigation task with the error,
        // which will then navigate to a special error page (`Tab.swift: navigation(_:didFailWith:)`)
        let errorUrl = URL.specialErrorPage(failingUrl: iframeTopUrl, kind: threatKind.errorPageKind)

        // Load the error URL in the web view main frame to display the custom error page instead of currently loaded website
        _ = webView?.load(URLRequest(url: errorUrl))

        return .cancel
    }

    func willStart(_ navigation: Navigation) {
        errorData = nil
    }

    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        guard navigation.isCurrent else { return }
        guard let url = error.failingUrl else {
            self.errorData = nil
            return
        }

        switch error as NSError {
        case let error as MaliciousSiteError:
            // Set the error data that will be sent to the error page on load (`SpecialErrorPageUserScript.swift: initialSetup`)
            errorData = .maliciousSite(kind: error.threatKind, url: url)

        case is URLError where error.isServerCertificateUntrusted:
            guard let errorType = error.sslErrorType else {
                assertionFailure("Missing SSL error type")
                errorData = nil
                return
            }

            let domain: String = url.host ?? url.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true)
            errorData = .ssl(type: errorType, domain: domain, eTldPlus1: tld.eTLDplus1(domain))

        default:
            errorData = nil
        }
    }

    @MainActor
    func navigationDidFinish(_ navigation: Navigation) {
        guard navigation.isCurrent else { return }
        specialErrorPageUserScript?.isEnabled = (errorData != nil && navigation.navigationAction.navigationType == .alternateHtmlLoad)
    }

    @MainActor
    func didReceive(_ challenge: URLAuthenticationChallenge, for navigation: Navigation?) async -> AuthChallengeDisposition? {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else { return nil }
        guard shouldBypassSSLError else { return nil }
        guard navigation?.url == webView?.url else { return nil }
        guard let credential = urlCredentialCreator.urlCredentialFrom(trust: challenge.protectionSpace.serverTrust) else { return nil }

        shouldBypassSSLError = false
        return .credential(credential)
    }

}

extension SpecialErrorPageTabExtension: SpecialErrorPageUserScriptDelegate {

    // Special error page "Leave site" button action
    func leaveSiteAction() {
        guard let errorData, let webView else { return }
        switch errorData {
        case .maliciousSite:
            closeAndOpenNewTab()
        case .ssl:
            if webView.canGoBack {
                _=webView.goBack()
            } else {
                closeAndOpenNewTab()
            }
        }
    }

    private func closeAndOpenNewTab() {
        Task { @MainActor in
            await self.webView?.openNewTabFromErrorPage()
            self.closeTab()
        }
    }

    // Special error page "Visit site" button action
    func visitSiteAction() {
        defer {
            webView?.reloadPageFromErrorPage()
        }
        guard let errorData, let webView, let url = webView.url else { return }
        switch errorData {
        case .maliciousSite(kind: let threatKind, url: _):
            PixelKit.fire(MaliciousSiteProtection.Event.visitSite(category: threatKind))

            exemptions[url] = threatKind
            state.bypassedMaliciousSiteThreatKind = threatKind
            state.currentMalicousSiteThreatKind = .none

        case .ssl:
            shouldBypassSSLError = true
        }
    }

    // Special error page "More info" expanded
    func advancedInfoPresented() {}
}

protocol SpecialErrorPageTabExtensionProtocol: AnyObject, NavigationResponder {
    var state: MaliciousSiteProtectionState { get }
}

extension SpecialErrorPageTabExtension: TabExtension, SpecialErrorPageTabExtensionProtocol {
    typealias PublicProtocol = SpecialErrorPageTabExtensionProtocol
    func getPublicProtocol() -> PublicProtocol { self }
}

extension TabExtensions {
    var specialErrorPage: SpecialErrorPageTabExtensionProtocol? {
        resolve(SpecialErrorPageTabExtension.self)
    }
}

protocol ErrorPageTabExtensionNavigationDelegate: AnyObject {
    var url: URL? { get }
    var canGoBack: Bool { get }
    func load(_ request: URLRequest) -> WKNavigation?
    func goBack() -> WKNavigation?
    func close()
    @MainActor func reloadPageFromErrorPage()
    @MainActor func openNewTabFromErrorPage() async
}

extension ErrorPageTabExtensionNavigationDelegate {

    @MainActor func reloadPageFromErrorPage() {
        guard let webView = self as? WKWebView, let url = webView.url else { return }
        // reloading creates an extra back history record;
        // `webView.go(to: backForwardList.currentItem)` breaks downloads as we don‘t load “Back” requests (with `returnCacheElseLoad` cache policy)
        webView.evaluateJavaScript("location.replace('\(url.absoluteString.escapedJavaScriptString())')", in: nil, in: .defaultClient)
    }

    @MainActor func openNewTabFromErrorPage() async {
        guard let webView = self as? WKWebView else { return }
        try? await webView.evaluateJavaScript("window.open('\(URL.newtab.absoluteString.escapedJavaScriptString())', '_blank')") as Void?
    }
}

extension WKWebView: ErrorPageTabExtensionNavigationDelegate { }

protocol URLCredentialCreating {
    func urlCredentialFrom(trust: SecTrust?) -> URLCredential?
}

struct URLCredentialCreator: URLCredentialCreating {
    func urlCredentialFrom(trust: SecTrust?) -> URLCredential? {
        if let trust {
            return URLCredential(trust: trust)
        }
        return nil
    }
}
