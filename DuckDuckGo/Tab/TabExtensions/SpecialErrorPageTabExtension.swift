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
import ContentScopeScripts
import BrowserServicesKit
import SpecialErrorPages
import Common

protocol SpecialErrorPageScriptProvider {
    var specialErrorPageUserScript: SpecialErrorPageUserScript? { get }
}

public enum SSLErrorType: String {
    case expired
    case wrongHost
    case selfSigned
    case invalid

    static func forErrorCode(_ errorCode: Int) -> Self {
        switch Int32(errorCode) {
        case errSSLCertExpired:
            return .expired
        case errSSLHostNameMismatch:
            return .wrongHost
        case errSSLXCertChainInvalid:
            return .selfSigned
        default:
            return .invalid
        }
    }
}

extension UserScripts: SpecialErrorPageScriptProvider {}

final class SpecialErrorPageTabExtension {
    weak var webView: ErrorPageTabExtensionNavigationDelegate?
    private weak var specialErrorPageUserScript: SpecialErrorPageUserScript?
    private var shouldBypassSSLError = false
    private var urlCredentialCreator: URLCredentialCreating
    private var featureFlagger: FeatureFlagger
    private let tld = TLD()

    private var cancellables = Set<AnyCancellable>()

    var errorData: SpecialErrorData?
    var failingURL: URL?

    init(
        webViewPublisher: some Publisher<WKWebView, Never>,
        scriptsPublisher: some Publisher<some SpecialErrorPageScriptProvider, Never>,
        urlCredentialCreator: URLCredentialCreating = URLCredentialCreator(),
        featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger) {
            self.featureFlagger = featureFlagger
            self.urlCredentialCreator = urlCredentialCreator
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
        webView?.loadAlternateHTML(html, baseURL: .error, forUnreachableURL: url)
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
        guard shouldBypassSSLError else { return nil}
        guard navigation?.url == webView?.url else { return nil }
        guard let credential = urlCredentialCreator.urlCredentialFrom(trust: challenge.protectionSpace.serverTrust) else { return nil }

        shouldBypassSSLError = false
        return .credential(credential)
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
        shouldBypassSSLError = true
        _ = webView?.reloadPage()
    }

    func advancedInfoPresented() {}
}

protocol ErrorPageTabExtensionProtocol: AnyObject, NavigationResponder {}

extension SpecialErrorPageTabExtension: TabExtension, ErrorPageTabExtensionProtocol {
    typealias PublicProtocol = ErrorPageTabExtensionProtocol
    func getPublicProtocol() -> PublicProtocol { self }
}

extension TabExtensions {
    var errorPage: ErrorPageTabExtensionProtocol? {
        resolve(SpecialErrorPageTabExtension.self)
    }
}

protocol ErrorPageTabExtensionNavigationDelegate: AnyObject {
    var url: URL? { get }
    var canGoBack: Bool { get }
    func loadAlternateHTML(_ html: String, baseURL: URL, forUnreachableURL failingURL: URL)
    func setDocumentHtml(_ html: String)
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
