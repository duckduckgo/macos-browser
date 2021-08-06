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

protocol TabDelegate: FileDownloadManagerDelegate {
    func tabDidStartNavigation(_ tab: Tab)
    func tab(_ tab: Tab, requestedNewTab url: URL?, selected: Bool)
    func tab(_ tab: Tab, willShowContextMenuAt position: NSPoint, image: URL?, link: URL?, selectedText: String?)
	func tab(_ tab: Tab, requestedOpenExternalURL url: URL, forUserEnteredURL: Bool)
    func tab(_ tab: Tab, requestedSaveCredentials credentials: SecureVaultModels.WebsiteCredentials)

    func tabPageDOMLoaded(_ tab: Tab)
    func closeTab(_ tab: Tab)
}

// swiftlint:disable type_body_length
// swiftlint:disable file_length
final class Tab: NSObject {

    enum TabType: Int, CaseIterable {
        case standard = 0
        case preferences = 1
        case bookmarks = 2

        static func rawValue(_ type: Int?) -> TabType {
            let tabType = type ?? TabType.standard.rawValue
            return TabType(rawValue: tabType) ?? .standard
        }

        static var displayableTabTypes: [TabType] {
            let cases = TabType.allCases.filter { $0 != .standard }
            return cases.sorted { first, second in
                guard let firstTitle = first.title, let secondTitle = second.title else {
                    return true // Arbitrary sort order, only non-standard tabs are displayable.
                }

                return firstTitle.localizedStandardCompare(secondTitle) == .orderedAscending
            }
        }

        var title: String? {
            switch self {
            case .standard: return nil
            case .preferences: return UserText.tabPreferencesTitle
            case .bookmarks: return UserText.tabBookmarksTitle
            }
        }

        var focusTabAddressBarWhenSelected: Bool {
            switch self {
            case .standard: return true
            case .preferences: return false
            case .bookmarks: return false
            }
        }
    }

    weak var delegate: TabDelegate?

    init(tabType: TabType = .standard,
         faviconService: FaviconService = LocalFaviconService.shared,
         webCacheManager: WebCacheManager = .shared,
         webViewConfiguration: WebViewConfiguration? = nil,
         historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
         url: URL? = nil,
         title: String? = nil,
         error: Error? = nil,
         favicon: NSImage? = nil,
         sessionStateData: Data? = nil,
         parentTab: Tab? = nil,
         shouldLoadInBackground: Bool = false,
         canGoBackToClose: Bool = false) {

        self.tabType = tabType
        self.faviconService = faviconService
        self.historyCoordinating = historyCoordinating
        self.url = url
        self.title = title
        self.error = error
        self.favicon = favicon
        self.parentTab = parentTab
        self.canGoBackToClose = canGoBackToClose
        self.sessionStateData = sessionStateData

        let configuration = webViewConfiguration ?? WKWebViewConfiguration()
        configuration.applyStandardConfiguration()

        webView = WebView(frame: CGRect.zero, configuration: configuration)

        super.init()

        setupWebView(shouldLoadInBackground: shouldLoadInBackground)

        // cache session-restored favicon if present
        if let favicon = favicon,
           let host = url?.host {
            faviconService.cacheIfNeeded(favicon: favicon, for: host, isFromUserScript: false)
        }
    }

    deinit {
        userScripts?.remove(from: webView.configuration.userContentController)
    }

    let webView: WebView
    private(set) var tabType: TabType
    var userEnteredUrl = true

    @PublishedAfter var url: URL? {
        didSet {
            if url != nil {
                tabType = .standard
            }

            if oldValue?.host != url?.host {
                fetchFavicon(nil, for: url?.host, isFromUserScript: false)
            }

            invalidateSessionStateData()
            reloadIfNeeded()
        }
    }

    @PublishedAfter var title: String?
    @PublishedAfter var error: Error?

    weak private(set) var parentTab: Tab?
    var canGoBackToClose: Bool

    weak var findInPage: FindInPageModel? {
        didSet {
            attachFindInPage()
        }
    }

    var sessionStateData: Data?

    func set(tabType: TabType) {
        self.tabType = tabType

        if let title = tabType.title {
            self.title = title
        }
    }

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
     }

    // Used to track if an error was caused by a download navigation.
    private var currentDownload: URL?

    func download(from url: URL, promptForLocation: Bool = true) {
        webView.startDownload(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { download in
            FileDownloadManager.shared.add(download, delegate: self.delegate, promptForLocation: promptForLocation, postflight: .reveal)
        }
    }

    func saveWebContentAs(completionHandler: ((Result<URL, Error>) -> Void)? = nil) {
        webView.getMimeType { mimeType in
            if case .html = mimeType.flatMap(UTType.init(mimeType:)) ?? .html {
                self.delegate?.chooseDestination(suggestedFilename: self.webView.suggestedFilename,
                                                 directoryURL: DownloadPreferences().selectedDownloadLocation,
                                                 fileTypes: [.html, .webArchive, .pdf]) { url, fileType in
                    guard let url = url else {
                        completionHandler?(.failure(URLError(.cancelled)))
                        return
                    }
                    self.webView.exportWebContent(to: url,
                                                  as: fileType.flatMap(WKWebView.ContentExportType.init) ?? .html,
                                                  completionHandler: completionHandler)
                }
            } else if let url = self.webView.url {
                assert(completionHandler == nil, "Completion handling not implemented for downloaded content, use WebKitDownloadTask.output")
                self.download(from: url, promptForLocation: true)
            }
        }
    }

    private let instrumentation = TabInstrumentation()

    var isHomepageShown: Bool {
        url == nil || url == URL.emptyPage
    }

    var isBookmarksShown: Bool {
        (url == nil || url == URL.emptyPage) && tabType == .bookmarks
    }

    func goForward() {
        shouldStoreNextVisit = false
        webView.goForward()
    }

    func goBack() {
        guard self.webView.canGoBack else {
            if self.parentTab != nil {
                delegate?.closeTab(self)
            }
            return
        }

        shouldStoreNextVisit = false
        webView.goBack()
    }

    func go(to item: WKBackForwardListItem) {
        shouldStoreNextVisit = false
        webView.go(to: item)
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
        guard let url = url,
              let host = url.host
        else { return }

        let added = FireproofDomains.shared.toggle(domain: host)
        if added {
            Pixel.fire(.fireproof(kind: .init(url: url), suggested: .manual))
        }
     }

    private var superviewObserver: NSKeyValueObservation?

    private func setupWebView(shouldLoadInBackground: Bool) {
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

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
    
    lazy var emailManager: EmailManager = {
        let emailManager = EmailManager()
        emailManager.requestDelegate = self
        return emailManager
    }()

    lazy var vaultManager: SecureVaultManager = {
        let manager = SecureVaultManager()
        manager.delegate = self
        return manager
    }()

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
            userScripts.contextMenuScript.delegate = self
            userScripts.contentBlockerScript.delegate = self
            userScripts.contentBlockerRulesScript.delegate = self
            userScripts.autofillScript.emailDelegate = emailManager
            userScripts.autofillScript.vaultDelegate = vaultManager
            userScripts.pageObserverScript.delegate = self

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

    // MARK: - History

    private var historyCoordinating: HistoryCoordinating
    private var shouldStoreNextVisit = true

    func addVisit(of url: URL) {
        canGoBackToClose = false
        guard shouldStoreNextVisit else {
            shouldStoreNextVisit = true
            return
        }
        historyCoordinating.addVisit(of: url)
    }

    func updateVisitTitle(_ title: String, url: URL) {
        historyCoordinating.updateTitleIfNeeded(title: title, url: url)
    }

}

extension Tab: PageObserverUserScriptDelegate {

    func pageDOMLoaded() {
        self.delegate?.tabPageDOMLoaded(self)
    }

}

extension Tab: ContextMenuDelegate {

    func contextMenu(forUserScript script: ContextMenuUserScript,
                     willShowAt position: NSPoint,
                     image: URL?,
                     link: URL?,
                     selectedText: String?) {
        delegate?.tab(self, willShowContextMenuAt: position, image: image, link: link, selectedText: selectedText)
    }

}

extension Tab: FaviconUserScriptDelegate {

    func faviconUserScript(_ faviconUserScript: FaviconUserScript, didFindFavicon faviconUrl: URL) {
        guard let host = self.url?.host else {
            return
        }

        faviconService.fetchFavicon(faviconUrl, for: host, isFromUserScript: true) { (image, error) in
            guard host == self.url?.host else {
                return
            }
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

extension Tab: EmailManagerRequestDelegate {

    // swiftlint:disable function_parameter_count
    func emailManager(_ emailManager: EmailManager,
                      requested url: URL,
                      method: String,
                      headers: [String: String],
                      parameters: [String: String]?,
                      httpBody: Data?,
                      timeoutInterval: TimeInterval,
                      completion: @escaping (Data?, Error?) -> Void) {
        let currentQueue = OperationQueue.current

        let finalURL: URL

        if let parameters = parameters {
            finalURL = (try? url.addParameters(parameters)) ?? url
        } else {
            finalURL = url
        }

        var request = URLRequest(url: finalURL, timeoutInterval: timeoutInterval)
        request.allHTTPHeaderFields = headers
        request.httpMethod = method
        request.httpBody = httpBody
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            currentQueue?.addOperation {
                completion(data, error)
            }
        }.resume()
    }
    // swiftlint:enable function_parameter_count
    
}

extension Tab: SecureVaultManagerDelegate {

    func secureVaultManager(_: SecureVaultManager, promptUserToStoreCredentials credentials: SecureVaultModels.WebsiteCredentials) {
        delegate?.tab(self, requestedSaveCredentials: credentials)
    }

}

extension Tab: WKNavigationDelegate {

    struct ErrorCodes {
        static let frameLoadInterrupted = 102
        static let internetConnectionOffline = -1009
    }
    
    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let url = webView.url, EmailUrls().shouldAuthenticateWithEmailCredentials(url: url) {
            completionHandler(.useCredential, URLCredential(user: "dax", password: "qu4ckqu4ck!", persistence: .none))
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }

    struct Constants {
        static let webkitMiddleClick = 4
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        webView.customUserAgent = UserAgent.for(navigationAction.request.url)

        if navigationAction.isTargetingMainFrame {
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

        if navigationAction.shouldDownload {
            // register the navigationAction for legacy _WKDownload to be called back on the Tab
            // further download will be passed to webView:navigationAction:didBecomeDownload:
            decisionHandler(.download(navigationAction, using: webView))
            return

        } else if externalUrlHandler.isExternal(scheme: urlScheme) {
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

        if !navigationResponse.canShowMIMEType || navigationResponse.shouldDownload {
            if navigationResponse.isForMainFrame {
                currentDownload = navigationResponse.response.url
            }
            // register the navigationResponse for legacy _WKDownload to be called back on the Tab
            // further download will be passed to webView:navigationResponse:didBecomeDownload:
            decisionHandler(.download(navigationResponse, using: webView))

        } else {
            decisionHandler(.allow)
        }
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
        // Failing not captured. Seems the method is called after calling the webview's method goBack()
        // https://app.asana.com/0/1199230911884351/1200381133504356/f
//        hasError = true

        self.invalidateSessionStateData()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if currentDownload != nil && (error as NSError).code == ErrorCodes.frameLoadInterrupted {
            currentDownload = nil

            // Note this can result in tabs being left open, e.g. download button on this page:
            // https://en.wikipedia.org/wiki/Guitar#/media/File:GuitareClassique5.png
            // Safari closes new tabs that were opened and then create a download instantly.
            if self.webView.canGoBack == false,
               self.parentTab != nil {
                delegate?.closeTab(self)
            }

            return
        }

        self.error = error

        if (error as NSError).code != ErrorCodes.internetConnectionOffline, let failingUrl = error.failingUrl {
            historyCoordinating.markFailedToLoadUrl(failingUrl)
        }
    }

    @available(macOS 11.3, *)
    @objc(webView:navigationAction:didBecomeDownload:)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        self.webView(webView, navigationAction: navigationAction, didBecomeDownload: download)
    }

    @available(macOS 11.3, *)
    @objc(webView:navigationResponse:didBecomeDownload:)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        self.webView(webView, navigationResponse: navigationResponse, didBecomeDownload: download)
    }

}
// universal download event handlers for Legacy _WKDownload and modern WKDownload
extension Tab: WKWebViewDownloadDelegate {
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecomeDownload download: WebKitDownload) {
        FileDownloadManager.shared.add(download, delegate: self.delegate, promptForLocation: false, postflight: .reveal)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecomeDownload download: WebKitDownload) {
        FileDownloadManager.shared.add(download, delegate: self.delegate, promptForLocation: false, postflight: .reveal)
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

// swiftlint:enable type_body_length
// swiftlint:enable file_length
