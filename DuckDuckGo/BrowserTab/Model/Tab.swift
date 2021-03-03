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
import BrowserServicesKit

protocol TabDelegate: class {

    func tabDidStartNavigation(_ tab: Tab)
    func tab(_ tab: Tab, requestedNewTab url: URL?, selected: Bool)
    func tab(_ tab: Tab, requestedFileDownload download: FileDownload)
    func tab(_ tab: Tab, willShowContextMenuAt position: NSPoint, image: URL?, link: URL?)
    func tab(_ tab: Tab, detectedLogin host: String)
	func tab(_ tab: Tab, requestedOpenExternalURL url: URL, forUserEnteredURL: Bool)

}

final class Tab: NSObject {

    weak var delegate: TabDelegate?

    init(faviconService: FaviconService = LocalFaviconService.shared,
         webCacheManager: WebCacheManager = .shared,
         webViewConfiguration: WebViewConfiguration? = nil,
         url: URL? = nil,
         title: String? = nil,
         error: Error? = nil,
         favicon: NSImage? = nil,
         sessionStateData: Data? = nil,
         shouldLoadInBackground: Bool = false) {

        self.faviconService = faviconService

        self.url = url
        self.title = title
        self.error = error
        self.favicon = favicon
        self.sessionStateData = sessionStateData

        let configuration = webViewConfiguration ?? WKWebViewConfiguration()
        configuration.applyStandardConfiguration()

        webView = WebView(frame: CGRect.zero, configuration: configuration)

        super.init()

        self.loginDetectionService = LoginDetectionService { [weak self] host in
             guard let self = self else { return }
             self.delegate?.tab(self, detectedLogin: host)
         }

        setupWebView(shouldLoadInBackground: shouldLoadInBackground)

        // cache session-restored favicon if present
        if let favicon = favicon,
           let host = url?.host {
            faviconService.storeIfNeeded(favicon: favicon, for: host, isFromUserScript: false)
        }

    }

    deinit {
        userScripts?.remove(from: webView.configuration.userContentController)
    }

    let webView: WebView
	var userEnteredUrl = true

    @Published var url: URL? {
        didSet {
            if oldValue?.host != url?.host {
                fetchFavicon(nil, for: url?.host, isFromUserScript: false)
            }
            invalidateSessionStateData()
            reloadIfNeeded()
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
        guard webView.url != nil else { return nil }
        // collect and cache actual SessionStateData on demand and store until invalidated
        self.sessionStateData = (try? webView.sessionStateData())
        return self.sessionStateData
    }

	func update(url: URL?, userEntered: Bool = true) {
        self.url = url

        // This function is called when the user has manually typed in a new address, which should reset the login detection flow.
		userEnteredUrl = userEntered
		loginDetectionService?.handle(navigationEvent: .userAction)
     }

    // Used to track if an error was caused by a download navigation.
    private var currentDownload: FileDownload?

    // Used as the request context for HTML 5 downloads
    private var lastMainFrameRequest: URLRequest?

    private var loginDetectionService: LoginDetectionService?
    private let instrumentation = TabInstrumentation()

    var isHomepageLoaded: Bool {
        url == nil || url == URL.emptyPage
    }

    func goForward() {
        webView.goForward()
        loginDetectionService?.handle(navigationEvent: .userAction)
    }

    func goBack() {
        webView.goBack()
        loginDetectionService?.handle(navigationEvent: .userAction)
    }

    func openHomepage() {
        url = nil
    }

    func reload() {
        if let error = error, let failingUrl = error.failingUrl {
            webView.load(failingUrl)
            return
        }

        if webView.url == nil,
           let url = self.url {
            webView.load(url)
        } else {
            webView.reload()
        }
        loginDetectionService?.handle(navigationEvent: .userAction)
    }

    private func reloadIfNeeded(shouldLoadInBackground: Bool = false) {
        guard webView.superview != nil || shouldLoadInBackground,
            webView.url != self.url
        else { return }

        if let sessionStateData = self.sessionStateData {
            do {
                try webView.restoreSessionState(from: sessionStateData)
                return
            } catch {
                os_log("Tab:setupWebView could not restore session state %s", "\(error)")
            }
        }
        if let url = self.url {
            webView.load(url)
        } else {
            webView.load(URL.emptyPage)
        }
    }

    func stopLoading() {
        webView.stopLoading()
    }

    func requestFireproofToggle() {
         guard let host = url?.host else { return }
         FireproofDomains.shared.toggle(domain: host)
     }

    private var superviewObserver: NSKeyValueObservation?

    private func setupWebView(shouldLoadInBackground: Bool) {
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        subscribeToUserScripts()
        subscribeToOpenExternalUrlEvents()

        superviewObserver = webView.observe(\.superview, options: .old) { [weak self] _, change in
            // if the webView is being added to superview - reload if needed
            if case .some(.none) = change.oldValue {
                self?.reloadIfNeeded()
            }
        }

        // background tab loading should start immediately
        reloadIfNeeded(shouldLoadInBackground: shouldLoadInBackground)
    }

    // MARK: - Open External URL

    let externalUrlHandler = ExternalURLHandler()
    var openExternalUrlEventsCancellable: AnyCancellable?

    private func subscribeToOpenExternalUrlEvents() {
        openExternalUrlEventsCancellable = externalUrlHandler.openExternalUrlPublisher.sink { [weak self] in
            if let self = self {
                self.delegate?.tab(self, requestedOpenExternalURL: $0, forUserEnteredURL: self.userEnteredUrl)
            }
        }
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

    private var userScriptsUpdatedCancellable: AnyCancellable?

    private var userScripts: UserScripts! {
        willSet {
            if let userScripts = userScripts {
                userScripts.remove(from: webView.configuration.userContentController)
            }
        }
        didSet {
            userScripts.debugScript.instrumentation = instrumentation
            userScripts.faviconScript.delegate = self
            userScripts.html5downloadScript.delegate = self
            userScripts.contextMenuScript.delegate = self
            userScripts.loginDetectionUserScript.delegate = self
            userScripts.contentBlockerScript.delegate = self
            userScripts.contentBlockerRulesScript.delegate = self

            attachFindInPage()

            userScripts.install(into: webView.configuration.userContentController)
        }
    }

    private func subscribeToUserScripts() {
        userScriptsUpdatedCancellable = UserScriptsManager.shared
            .$userScripts
            .map(UserScripts.init(copy:))
            .weakAssign(to: \.userScripts, on: self)
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

extension Tab: LoginFormDetectionDelegate {

     func loginFormDetectionUserScriptDetectedLoginForm(_ script: LoginFormDetectionUserScript) {
         guard let url = webView.url else { return }
         loginDetectionService?.handle(navigationEvent: .detectedLogin(url: url))
     }

 }

extension Tab: WKNavigationDelegate {

    struct ErrorCodes {
        static let frameLoadInterrupted = 102
    }

    struct Constants {
        static let webkitMiddleClick = 4
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        updateUserAgentForDomain(navigationAction.request.url?.host)

        // Check if a POST request is being made, and if it matches the appearance of a login request.
        if let method = navigationAction.request.httpMethod, method == "POST", navigationAction.request.url?.isLoginURL ?? false {
            userScripts.loginDetectionUserScript.scanForLoginForm(in: webView)
        }

        if navigationAction.isTargetingMainFrame() {
            lastMainFrameRequest = navigationAction.request
            currentDownload = nil
        }

        let isLinkActivated = navigationAction.navigationType == .linkActivated
        let isMiddleClicked = navigationAction.buttonNumber == Constants.webkitMiddleClick
        if isLinkActivated && NSApp.isCommandPressed || isMiddleClicked {
            decisionHandler(.cancel)
            delegate?.tab(self, requestedNewTab: navigationAction.request.url, selected: NSApp.isShiftPressed)
            return
        }

        guard let url = navigationAction.request.url, let urlScheme = url.scheme else {
            decisionHandler(.allow)
            return
        }

        if externalUrlHandler.isExternal(scheme: urlScheme) {
            // ignore <iframe src="custom://url"> but allow via address bar
            let fromFrame = !(navigationAction.sourceFrame.isMainFrame || self.userEnteredUrl)

            externalUrlHandler.handle(url: url,
                                      onPage: webView.url,
                                      fromFrame: fromFrame,
                                      triggeredByUser: navigationAction.navigationType == .linkActivated)

            decisionHandler(.cancel)
            return
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
		userEnteredUrl = false // subsequent requests will be navigations
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

        if let url = webView.url {
             loginDetectionService?.handle(navigationEvent: .pageBeganLoading(url: url))
         }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.invalidateSessionStateData()
        loginDetectionService?.handle(navigationEvent: .pageFinishedLoading)
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

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
         guard let url = webView.url else { return }
         loginDetectionService?.handle(navigationEvent: .redirect(url: url))
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
