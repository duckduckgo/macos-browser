//
//  ErrorPageTabExtension.swift
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

protocol SSLErrorPageScriptProvider {
    var sslErrorPageUserScript: SSLErrorPageUserScript? { get }
}

extension UserScripts: SSLErrorPageScriptProvider {}

final class ErrorPageTabExtension {
    weak var webView: ErrorPageTabExtensionNavigationDelegate?
    private weak var sslErrorPageUserScript: SSLErrorPageUserScript?
    private var shouldBypassSSLError = false
    private var urlCredentialCreator: URLCredentialCreating
    private var featureFlagger: FeatureFlagger

    private var cancellables = Set<AnyCancellable>()

    init(
        webViewPublisher: some Publisher<WKWebView, Never>,
        scriptsPublisher: some Publisher<some SSLErrorPageScriptProvider, Never>,
        urlCredentialCreator: URLCredentialCreating = URLCredentialCreator(),
        featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger) {
            self.featureFlagger = featureFlagger
            self.urlCredentialCreator = urlCredentialCreator
            webViewPublisher.sink { [weak self] webView in
                self?.webView = webView
            }.store(in: &cancellables)
            scriptsPublisher.sink { [weak self] scripts in
                self?.sslErrorPageUserScript = scripts.sslErrorPageUserScript
                self?.sslErrorPageUserScript?.delegate = self
            }.store(in: &cancellables)
        }

    @MainActor
    private func loadSSLErrorHTML(url: URL, alternate: Bool, errorCode: Int) {
        let domain: String = url.host ?? url.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true)
        let html = SSLErrorPageHTMLTemplate(domain: domain, errorCode: errorCode).makeHTMLFromTemplate()
        webView?.loadAlternateHTML(html, baseURL: .error, forUnreachableURL: url)
        loadHTML(html: html, url: url, alternate: alternate)
    }

    @MainActor
    private func loadErrorHTML(_ error: WKError, header: String, forUnreachableURL url: URL, alternate: Bool) {
        let html = ErrorPageHTMLTemplate(error: error, header: header).makeHTMLFromTemplate()
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

extension ErrorPageTabExtension: NavigationResponder {
    @MainActor
    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        let url = error.failingUrl ?? navigation.url
        guard navigation.isCurrent else { return }

        if !error.isFrameLoadInterrupted, !error.isNavigationCancelled {
            // when already displaying the error page and reload navigation fails again: don‘t navigate, just update page HTML
            guard let webView else { return }
            let shouldPerformAlternateNavigation = navigation.url != webView.url || navigation.navigationAction.targetFrame?.url != .error

            if featureFlagger.isFeatureOn(.sslCertificatesBypass),
               error.errorCode == NSURLErrorServerCertificateUntrusted,
               let errorCode = error.userInfo["_kCFStreamErrorCodeKey"] as? Int {
                sslErrorPageUserScript?.failingURL = url
                loadSSLErrorHTML(url: url, alternate: shouldPerformAlternateNavigation, errorCode: errorCode)
            } else {
                loadErrorHTML(error, header: UserText.errorPageHeader, forUnreachableURL: url, alternate: shouldPerformAlternateNavigation)
            }
        }
    }

    @MainActor
    func navigationDidFinish(_ navigation: Navigation) {
        sslErrorPageUserScript?.isEnabled = navigation.url == sslErrorPageUserScript?.failingURL
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

extension ErrorPageTabExtension: SSLErrorPageUserScriptDelegate {
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
}

protocol ErrorPageTabExtensionProtocol: AnyObject, NavigationResponder {}

extension ErrorPageTabExtension: TabExtension, ErrorPageTabExtensionProtocol {
    typealias PublicProtocol = ErrorPageTabExtensionProtocol
    func getPublicProtocol() -> PublicProtocol { self }
}

extension TabExtensions {
    var errorPage: ErrorPageTabExtensionProtocol? {
        resolve(ErrorPageTabExtension.self)
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
