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
import Combine

protocol TabDelegate: class {

    func tabDidStartNavigation(_ tab: Tab)
    func tab(_ tab: Tab, requestedNewTab url: URL?, selected: Bool)
    func tab(_ tab: Tab, requestedFileDownload download: FileDownload)
    func tab(_ tab: Tab, willShowContextMenuAt position: NSPoint, image: URL?, link: URL?)

}

final class Tab: NSObject {

    weak var delegate: TabDelegate?

    init(faviconService: FaviconService = LocalFaviconService.shared,
         webViewConfiguration: WebViewConfiguration? = nil,
         url: URL? = nil,
         title: String? = nil,
         error: Error? = nil,
         favicon: NSImage? = nil,
         sessionStateData: Data? = nil) {

        self.faviconService = faviconService

        self.url = url
        self.title = title
        self.error = error
        self.favicon = favicon
        self.sessionStateData = sessionStateData

        // Apply required configuration changes after state restoration.
        webViewConfiguration?.applyStandardConfiguration()
        webView = WebView(frame: CGRect.zero, configuration: webViewConfiguration ?? WKWebViewConfiguration.makeConfiguration())

        super.init()

        setupWebView()
        if webView.configuration.userContentController.userScripts.isEmpty {
            installUserScripts()
        }

        if let favicon = favicon,
           let host = url?.host {
            faviconService.storeIfNeeded(favicon: favicon, for: host, isFromUserScript: false)
        }

        subscribeToTrackerBlockerConfigUpdatedEvents()
    }

    deinit {
        userScripts.remove(from: webView)
    }

    let webView: WebView

    @Published var url: URL? {
        didSet {
            if oldValue?.host != url?.host {
                fetchFavicon(nil, for: url?.host, isFromUserScript: false)
            }
        }
    }

    @Published var title: String?
    @Published var error: Error?

    weak var findInPage: FindInPageModel? {
        didSet {
            attachFindInPage()
        }
    }

    var sessionStateData: Data?

    func invalidateSessionStateData() {
        sessionStateData = nil
    }

    func getActualSessionStateData() -> Data? {
        if let sessionStateData = sessionStateData {
            return sessionStateData
        }
        // collect and cache actual SessionStateData on demand and store until invalidated
        self.sessionStateData = (try? webView.sessionStateData())
        return self.sessionStateData
    }

    // Used to track if an error was caused by a download navigation.
    private var currentDownload: FileDownload?

    // Used as the request context for HTML 5 downloads
    private var lastMainFrameRequest: URLRequest?

    private let instrumentation = TabInstrumentation()

    var isHomepageLoaded: Bool {
        url == nil || url == URL.emptyPage
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
        if let error = error, let failingUrl = error.failingUrl {
            webView.load(failingUrl)
            return
        }

        webView.reload()
    }

    func stopLoading() {
        webView.stopLoading()
    }

    private func setupWebView() {
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        if let sessionStateData = sessionStateData {
            do {
                try webView.restoreSessionState(from: sessionStateData)
            } catch {
                os_log("Tab:setupWebView could not restore session state %s", "\(error)")
            }
        }
    }

    // MARK: - WebView Reconfiguration

    private var trackerBlockerConfigUpdatedCancellable: AnyCancellable?

    private func subscribeToTrackerBlockerConfigUpdatedEvents() {
        trackerBlockerConfigUpdatedCancellable = ConfigurationManager.shared.trackerBlockerDataUpdatedPublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
            self?.reconfigureWebView()
        }
    }

    private func reconfigureWebView() {
        webView.configuration.reinstallContentBlocker()
        userScripts.remove(from: webView)
        userScripts = UserScripts()
        installUserScripts()
    }

    // MARK: - Favicon

    @Published var favicon: NSImage?
    let faviconService: FaviconService

    private func fetchFavicon(_ faviconURL: URL?, for host: String?, isFromUserScript: Bool) {
        if favicon != nil {
            favicon = nil
        }

        guard let host = host else {
            return
        }

        faviconService.fetchFavicon(faviconURL, for: host, isFromUserScript: isFromUserScript) { (image, error) in
            guard error == nil, let image = image else {
                return
            }

            self.favicon = image
        }
    }

    // MARK: - User Scripts

    var userScripts = UserScripts()

    private func installUserScripts() {
        userScripts.debugScript.instrumentation = instrumentation
        userScripts.faviconScript.delegate = self
        userScripts.html5downloadScript.delegate = self
        userScripts.contextMenuScript.delegate = self
        userScripts.contentBlockerScript.delegate = self
        userScripts.contentBlockerRulesScript.delegate = self

        attachFindInPage()

        userScripts.install(into: webView)
    }

    // MARK: Find in Page

    var findInPageCancellable: AnyCancellable?
    private func subscribeToFindInPageTextChange() {
        findInPageCancellable?.cancel()
        if let findInPage = findInPage {
            findInPageCancellable = findInPage.$text.receive(on: DispatchQueue.main).sink { [weak self] text in
                self?.find(text: text)
            }
        }
    }

    private func attachFindInPage() {
        userScripts.findInPageScript.model = findInPage
        subscribeToFindInPageTextChange()
    }

}

extension Tab: ContextMenuDelegate {

    func contextMenu(forUserScript script: ContextMenuUserScript, willShowAt position: NSPoint, image: URL?, link: URL?) {
        delegate?.tab(self, willShowContextMenuAt: position, image: image, link: link)
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

        faviconService.fetchFavicon(faviconUrl, for: host, isFromUserScript: true) { (image, error) in
            guard error == nil, let image = image else {
                return
            }

            self.favicon = image
        }
    }

}

extension Tab: ContentBlockerUserScriptDelegate {

    func contentBlockerUserScriptShouldProcessTrackers(_ script: UserScript) -> Bool {
        // Not used until site rating support is implemented.
        return true
    }

    func contentBlockerUserScript(_ script: ContentBlockerUserScript, detectedTracker tracker: DetectedTracker, withSurrogate host: String) {
        // Not used until site rating support is implemented.
    }

    func contentBlockerUserScript(_ script: UserScript, detectedTracker tracker: DetectedTracker) {
        // Not used until site rating support is implemented.
    }

}

extension Tab: WKNavigationDelegate {

    struct ErrorCodes {
        static let frameLoadInterrupted = 102
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        updateUserAgentForDomain(navigationAction.request.url?.host)

        if navigationAction.isTargetingMainFrame() {
            lastMainFrameRequest = navigationAction.request
            currentDownload = nil
        }

        let isLinkActivated = navigationAction.navigationType == .linkActivated
        if isLinkActivated && NSApp.isCommandPressed {
            decisionHandler(.cancel)
            delegate?.tab(self, requestedNewTab: navigationAction.request.url, selected: NSApp.isShiftPressed)
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
            if isUpgradable, let upgradedUrl = url.toHttps() {
                self?.webView.load(upgradedUrl)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        let policy = navigationResponsePolicyForDownloads(navigationResponse)
        decisionHandler(policy)

    }

    private func updateUserAgentForDomain(_ host: String?) {
        let domain = host ?? ""
        webView.customUserAgent = UserAgent.forDomain(domain)
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
            self.currentDownload = download
            return .cancel
        }

        return .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        delegate?.tabDidStartNavigation(self)

        // Unnecessary assignment triggers publishing
        if error != nil { error = nil }

        self.invalidateSessionStateData()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.invalidateSessionStateData()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        #warning("Failing not captured. Seems the method is called after calling the webview's method goBack()")
//        hasError = true

        self.invalidateSessionStateData()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if currentDownload != nil && (error as NSError).code == ErrorCodes.frameLoadInterrupted {
            currentDownload = nil
            os_log("didFailProvisionalNavigation due to download %s", type: .debug, currentDownload?.request.url?.absoluteString ?? "")
            return
        }

        self.error = error
    }

}

extension Tab {

    private func find(text: String) {
        userScripts.findInPageScript.find(text: text, inWebView: webView)
    }

    func findDone() {
        userScripts.findInPageScript.done(withWebView: webView)
    }

    func findNext() {
        userScripts.findInPageScript.next(withWebView: webView)
    }

    func findPrevious() {
        userScripts.findInPageScript.previous(withWebView: webView)
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
