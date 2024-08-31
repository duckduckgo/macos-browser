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

import Foundation
import Navigation
import WebKit
import Combine
import Common
import ContentScopeScripts
import BrowserServicesKit
import PhishingDetection
import PixelKit
import SpecialErrorPages
import os

protocol SpecialErrorPageScriptProvider {
    var specialErrorPageUserScript: SpecialErrorPageUserScript? { get }
}

extension UserScripts: SpecialErrorPageScriptProvider {}

enum ErrorType {
    case phishing
    case ssl
    var description: String {
        switch self {
        case .phishing:
            return "Phishing"
        case .ssl:
            return "SSL"
        }
    }
}

final class SpecialErrorPageTabExtension {
    weak var webView: ErrorPageTabExtensionNavigationDelegate?
    private weak var specialErrorPageUserScript: SpecialErrorPageUserScript?
    private var shouldBypassSSLError = false
    private var urlCredentialCreator: URLCredentialCreating
    private var featureFlagger: FeatureFlagger
    private var phishingDetector: PhishingSiteDetecting
    private var phishingStateManager: PhishingTabStateManager
    private var errorPageType: ErrorType?
    private var phishingURLExemptions: Set<URL> = []
    private let tld = TLD()

    private var cancellables = Set<AnyCancellable>()

    var errorData: SpecialErrorData?
    var failingURL: URL?

    init(
        webViewPublisher: some Publisher<WKWebView, Never>,
        scriptsPublisher: some Publisher<some SpecialErrorPageScriptProvider, Never>,
        urlCredentialCreator: URLCredentialCreating = URLCredentialCreator(),
        featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger,
        phishingDetector: some PhishingSiteDetecting,
        phishingStateManager: PhishingTabStateManager) {
            self.featureFlagger = featureFlagger
            self.urlCredentialCreator = urlCredentialCreator
            self.phishingDetector = phishingDetector
            self.phishingStateManager = phishingStateManager
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
        let url = navigationAction.url
        guard url != URL(string: "about:blank")! else { return .next }
        // Add all non-user-initiated navigations after accepting the risk to our exemptions list
        if phishingStateManager.didBypassError && navigationAction.navigationType == .other {
            phishingURLExemptions.insert(url)
        }
        self.phishingStateManager.didBypassError = phishingURLExemptions.contains(url)

        if self.phishingStateManager.didBypassError || url.isDuckDuckGo || url.isDuckURLScheme {
            return .next
        }

        // Check the URL
        let isMalicious = await phishingDetector.checkIsMaliciousIfEnabled(url: url)
        self.phishingStateManager.isShowingPhishingError = isMalicious
        let errorType = PhishingDetectionError.detected.localizedDescription
        if isMalicious {
            errorPageType = .phishing
            if let mainFrameTarget = navigationAction.mainFrameTarget {
                failingURL = url
                let domain: String = url.host ?? url.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true)
                errorData = SpecialErrorData(kind: .phishing, errorType: errorType, domain: domain, eTldPlus1: tld.eTLDplus1(failingURL?.host))
                if let errorURL = self.generateErrorPageURL(url) {
                    _ = webView?.load(URLRequest(url: errorURL))
                    return .cancel
                }
            } else {
                // Malicious iFrame Detected
                // PixelKit.fire(PhishingDetectionPixels.iframeLoaded)
                let iframeTopUrl = navigationAction.sourceFrame.url
                failingURL = iframeTopUrl
                let domain: String = iframeTopUrl.host ?? iframeTopUrl.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true)
                errorData = SpecialErrorData(kind: .phishing, errorType: errorType, domain: domain, eTldPlus1: tld.eTLDplus1(failingURL?.host))
                if let errorURL = self.generateErrorPageURL(iframeTopUrl) {
                    _ = webView?.load(URLRequest(url: errorURL))
                    return .cancel
                }
                return .next
            }
        }
        errorPageType = nil
        return .next
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
    
    @MainActor
    func generateErrorPageURL(_ url: URL) -> URL? {
        guard let urlString = url.absoluteString.data(using: .utf8) else {
            Logger.phishingDetection.error("Unable to convert error URL to string data.")
            return nil
        }
        let encodedURL = URLTokenValidator.base64URLEncode(data: urlString)
        let token = URLTokenValidator.shared.generateToken(for: url)
        let errorURLString = "duck://error?reason=phishing&url=\(encodedURL)&token=\(token)"
        return URL(string: errorURLString)
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
        if errorPageType == .phishing {
            if let url = webView?.url {
                //PixelKit.fire(PhishingDetectionPixels.visitSite)
                phishingURLExemptions.insert(url)
                self.phishingStateManager.didBypassError = true
                self.phishingStateManager.isShowingPhishingError = false
            }
        } else if errorPageType == .ssl {
            shouldBypassSSLError = true
        }
        _ = webView?.reloadPage()
    }

    func advancedInfoPresented() {}
}

protocol SpecialErrorPageTabExtensionProtocol: AnyObject, NavigationResponder {}

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
