//
//  Tab.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Cocoa
import WebKit
import os

protocol TabDelegate: class {
    func tabDidStartNavigation(_ tab: Tab)
    func tab(_ tab: Tab, requestedNewTab url: URL?)
    func tab(_ tab: Tab, requestedFileDownload download: FileDownload)
}

class Tab: NSObject {

    weak var delegate: TabDelegate?

    init(faviconService: FaviconService = LocalFaviconService.shared) {
        self.faviconService = faviconService
        webView = WebView(frame: CGRect.zero, configuration: WKWebViewConfiguration.makeConfiguration())

        super.init()

        setupWebView()
        setupUserScripts()
    }

    deinit {
        webView.stopLoading()
    }

    let webView: WebView

    @Published var url: URL? {
        didSet {
            if oldValue?.host != url?.host {
                fetchFavicon(nil, for: url?.host)
            }
        }
    }

    @Published var title: String?
    @Published var hasError: Bool = false

    // Used to track if an error was caused by a download navigation.
    var download: FileDownload?

    var isHomepageLoaded: Bool {
        url == nil || url == URL.emptyPage
    }

    // Used as the request context for HTML 5 downloads
    private var lastMainFrameRequest: URLRequest?
    private var mainFrameNavigations = [WKNavigation]()

    func load(url: URL) {
        load(urlRequest: URLRequest(url: url))
    }

    private func load(urlRequest: URLRequest) {
        webView.stopLoading()
        webView.load(urlRequest)
    }

    func goForward() {
        webView.goForward()
    }

    func goBack() {
        webView.goBack()
    }

    func openHomepage() {
        url = nil
    }

    func reload() {
        webView.reload()
    }

    func stopLoading() {
        webView.stopLoading()
    }

    private func setupWebView() {
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = UserAgent.safari
    }

    // MARK: - Favicon

    @Published var favicon: NSImage?
    let faviconService: FaviconService

    private func fetchFavicon(_ faviconURL: URL?, for host: String?) {
        favicon = nil

        guard let host = host else {
            return
        }

        faviconService.fetchFavicon(faviconURL, for: host) { (image, error) in
            guard error == nil, let image = image else {
                return
            }

            self.favicon = image
        }
    }

    // MARK: - User Scripts

    let faviconScript = FaviconUserScript()
    let html5downloadScript = HTML5DownloadUserScript()

    private func setupUserScripts() {
        faviconScript.delegate = self
        html5downloadScript.delegate = self

        webView.configuration.userContentController.add(userScript: faviconScript)
        webView.configuration.userContentController.add(userScript: html5downloadScript)
    }

}

extension Tab: HTML5DownloadDelegate {

    func startDownload(_ userScript: HTML5DownloadUserScript, from url: URL, withSuggestedName name: String) {
        var request = lastMainFrameRequest ?? URLRequest(url: url)
        request.url = url
        delegate?.tab(self, requestedFileDownload: FileDownload(request: request, suggestedName: name))
    }

}

extension Tab: FaviconUserScriptDelegate {

    func faviconUserScript(_ faviconUserScript: FaviconUserScript, didFindFavicon faviconUrl: URL) {
        guard let host = url?.host else {
            return
        }

        faviconService.fetchFavicon(faviconUrl, for: host) { (image, error) in
            guard error == nil, let image = image else {
                return
            }

            self.favicon = image
        }
    }

}

extension Tab: WKNavigationDelegate {

    struct ErrorCodes {
        static let frameLoadInterrupted = 102
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        if navigationAction.isTargetingMainFrame() {
            lastMainFrameRequest = navigationAction.request
            download = nil
        }

        let isCommandPressed = NSApp.currentEvent?.modifierFlags.contains(.command) ?? false
        let isLinkActivated = navigationAction.navigationType == .linkActivated

        if isLinkActivated && isCommandPressed {
            decisionHandler(.cancel)
            delegate?.tab(self, requestedNewTab: navigationAction.request.url)
            return
        }

        guard let url = navigationAction.request.url, let urlScheme = url.scheme else {
            decisionHandler(.allow)
            return
        }

        #warning("Temporary implementation copied from the prototype. Only for internal release!")
        if !["https", "http", "about", "data"].contains(urlScheme) {
            let openResult = NSWorkspace.shared.open(url)
            if openResult {
                decisionHandler(.cancel)
                return
            }
        }

        HTTPSUpgrade.shared.isUpgradeable(url: url) { [weak self] isUpgradable in
            if isUpgradable, let upgradedUrl = self?.upgradeUrl(url) {
                self?.load(url: upgradedUrl)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }

    private func upgradeUrl(_ url: URL) -> URL? {
        if let upgradedUrl: URL = url.toHttps() {
            return upgradedUrl
        }

        return nil
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        let policy = navigationResponsePolicyForDownloads(navigationResponse)
        decisionHandler(policy)

    }

    private func navigationResponsePolicyForDownloads(_ navigationResponse: WKNavigationResponse) -> WKNavigationResponsePolicy {
        guard navigationResponse.isForMainFrame else {
            return .allow
        }

        if (!navigationResponse.canShowMIMEType || navigationResponse.shouldDownload),
           let request = lastMainFrameRequest {
            let download = FileDownload(request: request, suggestedName: navigationResponse.response.suggestedFilename)
            delegate?.tab(self, requestedFileDownload: download)
            // Flag this here, because interrupting the frame load will cause an error and we need to know
            self.download = download
            return .cancel
        }

        return .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        delegate?.tabDidStartNavigation(self)
        if hasError { hasError = false }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        #warning("Failing not captured. Seems the method is called after calling the webview's method goBack()")
//        hasError = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if download != nil && (error as NSError).code == ErrorCodes.frameLoadInterrupted {
            // This error was most likely due to a download.
            return
        }

        hasError = true
    }

}

fileprivate extension WKWebViewConfiguration {

    static func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.allowsAirPlayForMediaPlayback = true
        return configuration
    }

}

fileprivate extension WKNavigationResponse {
    var shouldDownload: Bool {
        let contentDisposition = (response as? HTTPURLResponse)?.allHeaderFields["Content-Disposition"] as? String
        return contentDisposition?.hasPrefix("attachment") ?? false
    }
}

fileprivate extension WKNavigationAction {
    func isTargetingMainFrame() -> Bool {
        return targetFrame?.isMainFrame ?? false
    }
}
