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
    weak var webView: ErrorPageTabExtensionNavigationDelegate?
    private weak var specialErrorPageUserScript: SpecialErrorPageUserScript?
    private var shouldBypassSSLError = false
    private var urlCredentialCreator: URLCredentialCreating
    private var featureFlagger: FeatureFlagger
    private var detector: MaliciousSiteDetecting
    private(set) var state = MaliciousSiteProtectionState()
    private var errorPageType: SpecialErrorKind?
    private var exemptions: [URL: MaliciousSiteProtection.ThreatKind] = [:]
    private let tld = TLD()

    private var cancellables = Set<AnyCancellable>()

    var errorData: SpecialErrorData?
    var failingURL: URL?

    init(
        webViewPublisher: some Publisher<WKWebView, Never>,
        scriptsPublisher: some Publisher<some SpecialErrorPageScriptProvider, Never>,
        urlCredentialCreator: URLCredentialCreating = URLCredentialCreator(),
        featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger,
        maliciousSiteDetector: some MaliciousSiteDetecting) {
            self.featureFlagger = featureFlagger
            self.urlCredentialCreator = urlCredentialCreator
            self.detector = maliciousSiteDetector
            webViewPublisher.sink { [weak self] webView in
                self?.webView = webView
            }.store(in: &cancellables)
            scriptsPublisher.sink { [weak self] scripts in
                self?.specialErrorPageUserScript = scripts.specialErrorPageUserScript
                self?.specialErrorPageUserScript?.delegate = self
            }.store(in: &cancellables)
        }

    @MainActor private func loadSSLErrorHTML(url: URL, alternate: Bool) {
        let html = SpecialErrorPageHTMLTemplate.htmlFromTemplate
        loadHTML(html: html, url: url, alternate: alternate)
    }

    @MainActor
    private func loadHTML(html: String, url: URL, alternate: Bool) {
        if alternate {
            webView?.loadAlternateHTML(html, baseURL: .error, forUnreachableURL: url)
        } else {
            webView?.setDocumentHtml(html)
        }
    }
}

extension SpecialErrorPageTabExtension: NavigationResponder {
    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        handleExemptions(for: navigationAction)

        let url = navigationAction.url
        if state.bypassedMaliciousSiteThreatKind != .none || url.isDuckDuckGo || url.isDuckURLScheme {
            state.currentMalicousSiteThreatKind = .none
            return .next
        }

        guard let threatKind = await detector.evaluate(url) else {
            state.currentMalicousSiteThreatKind = .none
            return .next
        }

        state.currentMalicousSiteThreatKind = threatKind

        return redirect(navigationAction, with: threatKind)
    }

    private func handleExemptions(for navigationAction: NavigationAction) {
        let url = navigationAction.url
        // An edge case for if a site gets flagged as malicious, the user clicks through the warning,
        // and then the malicious page redirects to a site that isn't flagged.
        //
        // We want to ensure the new site is still marked as dangerous in the privacy dashboard.
        // So we basically flag all URLs in the redirect chain as malicious (and exempted) too.
        //
        // There may be cases where this is a bad idea, for example a malicious site that redirects to a socialnetwork.com -
        // but if a flagged site sends you somewhere, you should still be cautious of that site so we want it to remain flagged.
        if let threatKind = state.bypassedMaliciousSiteThreatKind, navigationAction.navigationType == .other { // TODO: Validate this .other handler works for actual .redirect-s
            exemptions[url] = threatKind
        }
        state.bypassedMaliciousSiteThreatKind = exemptions[url]
    }

    @MainActor
    private func redirect(_ navigationAction: NavigationAction, with threatKind: MaliciousSiteProtection.ThreatKind) -> NavigationActionPolicy? {
        let domain: String
        let errorPageType = threatKind.errorPageType
        self.errorPageType = errorPageType
        guard let mainFrame = navigationAction.mainFrameTarget else {
            return redirectMaliciousIframe(navigationAction, with: threatKind)
        }

        let url = navigationAction.url
        failingURL = url
        domain = url.host ?? url.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true)
        errorData = SpecialErrorData(kind: errorPageType, domain: domain, eTldPlus1: tld.eTLDplus1(failingURL?.host))
        let errorUrl = URL.errorUrl(with: threatKind, failingUrl: url)
        return .redirect(mainFrame) { navigator in
            navigator.load(URLRequest(url: errorUrl))
        }
    }

    @MainActor
    private func redirectMaliciousIframe(_ navigationAction: NavigationAction, with threatKind: MaliciousSiteProtection.ThreatKind) -> NavigationActionPolicy? {
        PixelKit.fire(MaliciousSiteProtection.Event.iframeLoaded)

        let iframeTopUrl = navigationAction.sourceFrame.url
        failingURL = iframeTopUrl
        let domain = iframeTopUrl.host ?? iframeTopUrl.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true)
        errorData = SpecialErrorData(kind: threatKind.errorPageType, domain: domain, eTldPlus1: tld.eTLDplus1(failingURL?.host))

        let errorUrl = URL.errorUrl(with: threatKind, failingUrl: iframeTopUrl)
        _ = webView?.load(URLRequest(url: errorUrl))
        return .none
    }

    @MainActor
    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        let url = error.failingUrl ?? navigation.url
        guard navigation.isCurrent else { return }
        guard error.errorCode != NSURLErrorCannotFindHost else { return }

        if !error.isFrameLoadInterrupted, !error.isNavigationCancelled {
            guard let webView else { return }
            let shouldPerformAlternateNavigation = navigation.url != webView.url || navigation.navigationAction.targetFrame?.url != .error
            if featureFlagger.isFeatureOn(.sslCertificatesBypass),
               error.errorCode == NSURLErrorServerCertificateUntrusted,
               let errorCode = error.userInfo["_kCFStreamErrorCodeKey"] as? Int {
                errorPageType = .ssl
                failingURL = url
                let domain: String = url.host ?? url.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true)
                errorData = SpecialErrorData(kind: .ssl, errorType: SSLErrorType.forErrorCode(errorCode).rawValue, domain: domain, eTldPlus1: tld.eTLDplus1(failingURL?.host))
                loadSSLErrorHTML(url: url, alternate: shouldPerformAlternateNavigation)
            }
        }
    }

    @MainActor
    func navigationDidFinish(_ navigation: Navigation) {
        specialErrorPageUserScript?.isEnabled = navigation.url == failingURL
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
private extension URL {

    @MainActor
    static func errorUrl(with threatKind: MaliciousSiteProtection.ThreatKind, failingUrl: URL) -> URL {
        let urlString = failingUrl.absoluteString.utf8data
        let encodedURL = URLTokenValidator.base64URLEncode(data: urlString)
        let token = URLTokenValidator.shared.generateToken(for: failingUrl)
        let errorURLString = "duck://error?reason=phishing&url=\(encodedURL)&token=\(token)"
        return URL(string: errorURLString)!
    }

}

extension SpecialErrorPageTabExtension: SpecialErrorPageUserScriptDelegate {
    func leaveSite() {
        guard webView?.canGoBack == true else {
            webView?.close()
            return
        }
        _ = webView?.goBack()
    }

    func visitSite() {
        defer {
            webView?.reloadPage()
        }
        guard let webView, let url = webView.url, let errorPageType else { return }
        let threatKind: MaliciousSiteProtection.ThreatKind
        switch errorPageType {
        case .phishing:
            threatKind = .phishing
        // case .malware:
        //     threatKind = .malware
        case .ssl:
            shouldBypassSSLError = true
            return
        }

        PixelKit.fire(MaliciousSiteProtection.Event.visitSite)

        exemptions[url] = threatKind
        state.bypassedMaliciousSiteThreatKind = threatKind
        state.currentMalicousSiteThreatKind = .none
    }

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
    var errorPage: SpecialErrorPageTabExtensionProtocol? {
        resolve(SpecialErrorPageTabExtension.self)
    }
}

protocol ErrorPageTabExtensionNavigationDelegate: AnyObject {
    var url: URL? { get }
    var canGoBack: Bool { get }
    func loadAlternateHTML(_ html: String, baseURL: URL, forUnreachableURL failingURL: URL)
    func setDocumentHtml(_ html: String)
    func load(_ request: URLRequest) -> WKNavigation?
    func goBack() -> WKNavigation?
    func close()
    @discardableResult
    func reloadPage() -> WKNavigation?
}

extension ErrorPageTabExtensionNavigationDelegate {
    func reloadPage() -> WKNavigation? {
        guard let wevView = self as? WKWebView else { return nil }
        if let item = wevView.backForwardList.currentItem {
            return wevView.go(to: item)
        }
        return nil
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
