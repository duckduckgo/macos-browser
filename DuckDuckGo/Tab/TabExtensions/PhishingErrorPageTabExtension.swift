//
//  PhishingErrorPageTabExtension.swift
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

protocol PhishingErrorPageScriptProvider {
    var phishingErrorPageUserScript: PhishingErrorPageUserScript? { get }
}

extension UserScripts: PhishingErrorPageScriptProvider {}

final class PhishingErrorPageTabExtension {
    weak var webView: ErrorPageTabExtensionNavigationDelegate?
    private var urlCredentialCreator: URLCredentialCreating
    private weak var phishingErrorPageUserScript: PhishingErrorPageUserScript?
    private var exemptionsList: [String] = ["about:blank", "https://duckduckgo.com"]
    private var featureFlagger: FeatureFlagger
    private var cancellables = Set<AnyCancellable>()
    private var detectionManager: PhishingDetectionManager

    init(
        webViewPublisher: some Publisher<WKWebView, Never>,
        urlCredentialCreator: URLCredentialCreating = URLCredentialCreator(),
        scriptsPublisher: some Publisher<some PhishingErrorPageScriptProvider, Never>,
        featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger,
        phishingDetectionManager: PhishingDetectionManager) {
            self.detectionManager = phishingDetectionManager
            self.featureFlagger = featureFlagger
            self.urlCredentialCreator = urlCredentialCreator
            webViewPublisher.sink { [weak self] webView in
                self?.webView = webView
            }.store(in: &cancellables)
            scriptsPublisher.sink { [weak self] scripts in
                self?.phishingErrorPageUserScript = scripts.phishingErrorPageUserScript
                self?.phishingErrorPageUserScript?.delegate = self
            }.store(in: &cancellables)
        }

    @MainActor
    private func loadPhishingErrorHTML(url: URL) {
        let domain: String = url.host ?? url.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true)
        let html = PhishingErrorPageHTMLTemplate(domain: domain).makeHTMLFromTemplate()
        webView?.loadAlternateHTML(html, baseURL: .error, forUnreachableURL: url)
    }

    @MainActor
    private func loadErrorHTML(_ error: WKError, header: String, forUnreachableURL url: URL) {
        let html = ErrorPageHTMLTemplate(error: error, header: header).makeHTMLFromTemplate()
        webView?.loadAlternateHTML(html, baseURL: .error, forUnreachableURL: url)
    }

}

extension PhishingErrorPageTabExtension: NavigationResponder {
    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        let urlString = navigationAction.url.absoluteString
        if exemptionsList.contains(urlString) {
            return .allow
        }
        // Check the URL
        let isMalicious = await detectionManager.isMalicious(url: navigationAction.url)
        if isMalicious {
            loadPhishingErrorHTML(url: navigationAction.url)
            return .cancel
        }
        return .allow
    }
}

protocol PhishingErrorPageTabExtensionProtocol: AnyObject, NavigationResponder {}

extension PhishingErrorPageTabExtension: TabExtension, PhishingErrorPageTabExtensionProtocol {
    typealias PublicProtocol = PhishingErrorPageTabExtensionProtocol
    func getPublicProtocol() -> PublicProtocol { self }
}

extension TabExtensions {
    var phishingErrorPage: PhishingErrorPageTabExtensionProtocol? {
        resolve(PhishingErrorPageTabExtension.self)
    }
}

extension PhishingErrorPageTabExtension: PhishingErrorPageUserScriptDelegate {
    func leaveSite() {
        guard webView?.canGoBack == true else {
            webView?.close()
            return
        }
        _ = webView?.goBack()
    }

    func visitSite() {
        let urlString = webView?.url?.absoluteString
        exemptionsList.append(urlString!)
        _ = webView?.reloadPage()
    }
}
