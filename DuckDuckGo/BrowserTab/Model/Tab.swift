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
    func tab(_ tab: Tab,
             requestedBasicAuthenticationChallengeWith protectionSpace: URLProtectionSpace,
             completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)

    func tab(_ tab: Tab, didChangeHoverLink url: URL?)

    func tabPageDOMLoaded(_ tab: Tab)
    func closeTab(_ tab: Tab)
}

// swiftlint:disable type_body_length
// swiftlint:disable file_length
final class Tab: NSObject {

    enum TabContent: Equatable {
        case homepage
        case url(URL)
        case preferences
        case bookmarks
        case none

        static var displayableTabTypes: [TabContent] {
            return [TabContent.preferences, .bookmarks].sorted { first, second in
                switch first {
                case .homepage, .url, .preferences, .bookmarks, .none: break
                // !! Replace [TabContent.preferences, .bookmarks] above with new displayable Tab Types if added
                }
                guard let firstTitle = first.title, let secondTitle = second.title else {
                    return true // Arbitrary sort order, only non-standard tabs are displayable.
                }

                return firstTitle.localizedStandardCompare(secondTitle) == .orderedAscending
            }
        }

        var title: String? {
            switch self {
            case .url, .homepage, .none: return nil
            case .preferences: return UserText.tabPreferencesTitle
            case .bookmarks: return UserText.tabBookmarksTitle
            }
        }

        var url: URL? {
            guard case .url(let url) = self else { return nil }
            return url
        }

        var isUrl: Bool {
            if case .url = self {
                return true
            } else {
                return false
            }
        }
    }

    weak var delegate: TabDelegate?

    init(content: TabContent,
         faviconService: FaviconService = LocalFaviconService.shared,
         webCacheManager: WebCacheManager = WebCacheManager.shared,
         webViewConfiguration: WebViewConfiguration? = nil,
         historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
         scriptsSource: ScriptSourceProviding = DefaultScriptSourceProvider.shared,
         visitedDomains: Set<String> = Set<String>(),
         title: String? = nil,
         error: Error? = nil,
         favicon: NSImage? = nil,
         sessionStateData: Data? = nil,
         parentTab: Tab? = nil,
         shouldLoadInBackground: Bool = false,
         canBeClosedWithBack: Bool = false) {

        self.content = content
        self.faviconService = faviconService
        self.historyCoordinating = historyCoordinating
        self.scriptsSource = scriptsSource
        self.visitedDomains = visitedDomains
        self.title = title
        self.error = error
        self.favicon = favicon
        self.parentTab = parentTab
        self._canBeClosedWithBack = canBeClosedWithBack
        self.sessionStateData = sessionStateData

        let configuration = webViewConfiguration ?? WKWebViewConfiguration()
        configuration.applyStandardConfiguration()

        webView = WebView(frame: CGRect.zero, configuration: configuration)
        permissions = PermissionModel(webView: webView)

        super.init()

        setupWebView(shouldLoadInBackground: shouldLoadInBackground)

        // cache session-restored favicon if present
        if let favicon = favicon,
           let host = content.url?.host {
            faviconService.cacheIfNeeded(favicon: favicon, for: host, isFromUserScript: false)
        }
    }

    deinit {
        userScripts?.remove(from: webView.configuration.userContentController)
    }

    // MARK: - Event Publishers

    let webViewDidFinishNavigationPublisher = PassthroughSubject<Void, Never>()

    // MARK: - Properties

    let webView: WebView

    var userEnteredUrl = true

    var contentChangeEnabled = true

    @PublishedAfter private(set) var content: TabContent {
        didSet {
            handleFavicon(oldContent: oldValue)
            invalidateSessionStateData()
            reloadIfNeeded()

            if let title = content.title {
                self.title = title
            }
        }
    }

    func setContent(_ content: TabContent) {
        guard contentChangeEnabled else {
            return
        }

        self.content = content
    }

    @PublishedAfter var title: String?
    @PublishedAfter var error: Error?
    let permissions: PermissionModel

    weak private(set) var parentTab: Tab?
    private var _canBeClosedWithBack: Bool
    var canBeClosedWithBack: Bool {
        // Reset canBeClosedWithBack on any WebView navigation
        _canBeClosedWithBack = _canBeClosedWithBack && parentTab != nil && !webView.canGoBack && !webView.canGoForward
        return _canBeClosedWithBack
    }

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
        self.content = url == .homePage ? .homepage : .url(url ?? .blankPage)

        // This function is called when the user has manually typed in a new address, which should reset the login detection flow.
        userEnteredUrl = userEntered
     }

    // Used to track if an error was caused by a download navigation.
    private var currentDownload: URL?

    func download(from url: URL, promptForLocation: Bool = true) {
        webView.startDownload(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { download in
            FileDownloadManager.shared.add(download, delegate: self.delegate, location: promptForLocation ? .prompt : .auto, postflight: .none)
        }
    }

    func saveWebContentAs(completionHandler: ((Result<URL, Error>) -> Void)? = nil) {
        webView.getMimeType { mimeType in
            if case .some(.html) = mimeType.flatMap(UTType.init(mimeType:)) {
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
    private enum FrameLoadState {
        case provisional
        case committed
        case finished
    }
    private var mainFrameLoadState: FrameLoadState = .finished
    private var clientRedirectedDuringNavigationURL: URL?

    var canGoForward: Bool {
        webView.canGoForward
    }

    func goForward() {
        guard self.canGoForward else { return }
        shouldStoreNextVisit = false
        webView.goForward()
    }

    var canGoBack: Bool {
        webView.canGoBack
    }

    func goBack() {
        guard self.canGoBack else {
            if canBeClosedWithBack {
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
        content = .homepage
    }

    func reload() {
        if let error = error, let failingUrl = error.failingUrl {
            webView.load(failingUrl)
            return
        }

        if webView.url == nil,
           let url = self.content.url {
            webView.load(url)
        } else {
            webView.reload()
        }
    }

    private func reloadIfNeeded(shouldLoadInBackground: Bool = false) {
        let url: URL
        switch self.content {
        case .url(let value):
            url = value
        case .homepage:
            url = .homePage
        default:
            url = .blankPage
        }
        guard webView.superview != nil || shouldLoadInBackground,
              webView.url != url
                // Initial Home Page shouldn't show Back Button
                && webView.url != self.content.url
        else { return }

        if let sessionStateData = self.sessionStateData {
            do {
                try webView.restoreSessionState(from: sessionStateData)
                return
            } catch {
                os_log("Tab:setupWebView could not restore session state %s", "\(error)")
            }
        }
        webView.load(url)
    }

    func stopLoading() {
        webView.stopLoading()
    }

    func requestFireproofToggle() {
        guard let url = content.url,
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

        subscribeToUserScriptChanges()
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

    private func handleFavicon(oldContent: TabContent) {
        if !content.isUrl {
            favicon = nil
        }
        if oldContent.url?.host != content.url?.host {
            fetchFavicon(nil, for: content.url?.host, isFromUserScript: false)
        }
    }

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

    let scriptsSource: ScriptSourceProviding
    private var userScriptsUpdatedCancellable: AnyCancellable?

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
            userScripts.surrogatesScript.delegate = self
            userScripts.contentBlockerRulesScript.delegate = self
            userScripts.autofillScript.emailDelegate = emailManager
            userScripts.autofillScript.vaultDelegate = vaultManager
            userScripts.pageObserverScript.delegate = self
            userScripts.printingUserScript.delegate = self
            userScripts.hoverUserScript.delegate = self

            attachFindInPage()

            userScripts.install(into: webView.configuration.userContentController)
        }
    }

    private func subscribeToUserScriptChanges() {
        userScriptsUpdatedCancellable = scriptsSource.sourceUpdatedPublisher.receive(on: RunLoop.main).sink { [weak self] knownChanges in
            guard let self = self else { return }

            self.userScripts = UserScripts(with: self.scriptsSource)

            if knownChanges?.contains(.unprotectedSites) ?? false {
                self.reload()
            }
        }
    }

    // MARK: - Find in Page

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

    // MARK: - Global & Local History

    private var historyCoordinating: HistoryCoordinating
    private var shouldStoreNextVisit = true
    private(set) var visitedDomains: Set<String>

    func addVisit(of url: URL) {
        guard shouldStoreNextVisit else {
            shouldStoreNextVisit = true
            return
        }

        // Add to global history
        historyCoordinating.addVisit(of: url)

        // Add to local history
        if let host = url.host, !host.isEmpty {
            visitedDomains.insert(host)
        }
    }

    func updateVisitTitle(_ title: String, url: URL) {
        historyCoordinating.updateTitleIfNeeded(title: title, url: url)
    }

    // MARK: - Dashboard Info

    @Published var trackerInfo: TrackerInfo?
    @Published var serverTrust: ServerTrust?
    @Published var connectionUpgradedTo: URL?

    public func resetDashboardInfo(_ url: URL?) {
        trackerInfo = TrackerInfo()
        if self.serverTrust?.host != url?.host {
            serverTrust = nil
        }
    }

    private func resetConnectionUpgradedTo(navigationAction: WKNavigationAction) {
        let isOnUpgradedPage = navigationAction.request.url == connectionUpgradedTo
        if !navigationAction.isTargetingMainFrame || isOnUpgradedPage { return }
        connectionUpgradedTo = nil
    }

    private func setConnectionUpgradedTo(_ upgradedUrl: URL, navigationAction: WKNavigationAction) {
        if !navigationAction.isTargetingMainFrame { return }
        connectionUpgradedTo = upgradedUrl
    }

    public func setMainFrameConnectionUpgradedTo(_ upgradedUrl: URL?) {
        if upgradedUrl == nil { return }
        connectionUpgradedTo = upgradedUrl
    }
    
    // MARK: - Printing
    
    // To avoid webpages invoking the printHandler and overwhelming the browser, this property keeps track of the active
    // print operation and ignores incoming printHandler messages if one exists.
    fileprivate var activePrintOperation: NSPrintOperation?

}

extension Tab: PrintingUserScriptDelegate {

    func printingUserScriptDidRequestPrintController(_ script: PrintingUserScript) {
        guard activePrintOperation == nil else { return }
        
        guard let window = webView.window,
              let printOperation = webView.printOperation()
              else { return }
        
        self.activePrintOperation = printOperation

        if printOperation.view?.frame.isEmpty == true {
            printOperation.view?.frame = webView.bounds
        }

        let selector = #selector(printOperationDidRun(printOperation: success: contextInfo:))
        printOperation.runModal(for: window, delegate: self, didRun: selector, contextInfo: nil)
    }
    
    @objc func printOperationDidRun(printOperation: NSPrintOperation,
                                    success: Bool,
                                    contextInfo: UnsafeMutableRawPointer?) {
        activePrintOperation = nil
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
        guard let host = self.content.url?.host else {
            return
        }

        faviconService.fetchFavicon(faviconUrl, for: host, isFromUserScript: true) { (image, error) in
            guard host == self.content.url?.host else {
                return
            }
            guard error == nil, let image = image else {
                return
            }

            self.favicon = image
        }
    }

}

extension Tab: ContentBlockerRulesUserScriptDelegate {

    func contentBlockerRulesUserScriptShouldProcessTrackers(_ script: ContentBlockerRulesUserScript) -> Bool {
        return true
    }

    func contentBlockerRulesUserScript(_ script: ContentBlockerRulesUserScript, detectedTracker tracker: DetectedTracker) {
        trackerInfo?.add(detectedTracker: tracker)
    }
}

extension Tab: SurrogatesUserScriptDelegate {

    func surrogatesUserScriptShouldProcessTrackers(_ script: SurrogatesUserScript) -> Bool {
        return true
    }

    func surrogatesUserScript(_ script: SurrogatesUserScript, detectedTracker tracker: DetectedTracker, withSurrogate host: String) {
        trackerInfo?.add(installedSurrogateHost: host)

        trackerInfo?.add(detectedTracker: tracker)
    }
}

extension Tab: EmailManagerRequestDelegate { }

extension Tab: SecureVaultManagerDelegate {

    func secureVaultManager(_: SecureVaultManager, promptUserToStoreCredentials credentials: SecureVaultModels.WebsiteCredentials) {
        delegate?.tab(self, requestedSaveCredentials: credentials)
    }

    func secureVaultManager(_: SecureVaultManager, didAutofill type: AutofillType, withObjectId objectId: Int64) {
        Pixel.fire(.formAutofilled(kind: type.formAutofillKind))
    } 

}

extension AutofillType {
    var formAutofillKind: Pixel.Event.FormAutofillKind {
        switch self {
        case .password: return .password
        case .card: return .card
        case .identity: return .identity
        }
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
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic,
           let delegate = delegate {
            delegate.tab(self, requestedBasicAuthenticationChallengeWith: challenge.protectionSpace, completionHandler: completionHandler)
            return
        }

        completionHandler(.performDefaultHandling, nil)
        if let host = webView.url?.host, let serverTrust = challenge.protectionSpace.serverTrust, host == challenge.protectionSpace.host {
            self.serverTrust = ServerTrust(host: host, secTrust: serverTrust)
        }
    }

    struct Constants {
        static let webkitMiddleClick = 4
    }

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        webView.customUserAgent = UserAgent.for(navigationAction.request.url)

        if navigationAction.isTargetingMainFrame {
            if navigationAction.navigationType == .backForward,
               self.webView.frozenCanGoForward != nil {

                // Auto-cancel simulated Back action when upgrading to HTTPS or GPC from Client Redirect
                self.webView.frozenCanGoForward = nil
                self.webView.frozenCanGoBack = nil
                decisionHandler(.cancel)
                return

            } else if navigationAction.navigationType != .backForward,
               let request = GPCRequestFactory.shared.requestForGPC(basedOn: navigationAction.request) {
                self.invalidateBackItemIfNeeded(for: navigationAction)
                decisionHandler(.cancel)
                webView.load(request)
                return
            }
        }

        if navigationAction.isTargetingMainFrame {
            currentDownload = nil
            if navigationAction.request.url != self.clientRedirectedDuringNavigationURL {
                self.clientRedirectedDuringNavigationURL = nil
            }
        }

        self.resetConnectionUpgradedTo(navigationAction: navigationAction)

        let isLinkActivated = navigationAction.navigationType == .linkActivated
        let isMiddleClicked = navigationAction.buttonNumber == Constants.webkitMiddleClick
        if isLinkActivated && NSApp.isCommandPressed || isMiddleClicked {
            decisionHandler(.cancel)
            delegate?.tab(self, requestedNewTab: navigationAction.request.url, selected: NSApp.isShiftPressed)
            return
        } else if isLinkActivated && NSApp.isOptionPressed && !NSApp.isCommandPressed {
            decisionHandler(.download(navigationAction, using: webView))
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
            if let self = self,
               isUpgradable && navigationAction.isTargetingMainFrame,
                let upgradedUrl = url.toHttps() {

                self.invalidateBackItemIfNeeded(for: navigationAction)
                self.webView.load(upgradedUrl)
                self.setConnectionUpgradedTo(upgradedUrl, navigationAction: navigationAction)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    private func invalidateBackItemIfNeeded(for navigationAction: WKNavigationAction) {
        guard let url = navigationAction.request.url,
              url == self.clientRedirectedDuringNavigationURL
        else { return }

        // Cancelled & Upgraded Client Redirect URL leaves wrong backForwardList record
        // https://app.asana.com/0/inbox/1199237043628108/1201280322539473/1201353436736961
        self.webView.goBack()
        self.webView.frozenCanGoBack = self.webView.canGoBack
        self.webView.frozenCanGoForward = false
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

        invalidateSessionStateData()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        invalidateSessionStateData()
        webViewDidFinishNavigationPublisher.send()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Failing not captured. Seems the method is called after calling the webview's method goBack()
        // https://app.asana.com/0/1199230911884351/1200381133504356/f
//        hasError = true

        invalidateSessionStateData()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if currentDownload != nil && (error as NSError).code == ErrorCodes.frameLoadInterrupted {
            currentDownload = nil
            return
        }

        self.error = error

        if (error as NSError).code != ErrorCodes.internetConnectionOffline, let failingUrl = error.failingUrl {
            historyCoordinating.markFailedToLoadUrl(failingUrl)
        }
    }

    @available(macOS 12, *)
    @objc(webView:navigationAction:didBecomeDownload:)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        self.webView(webView, navigationAction: navigationAction, didBecomeDownload: download)
    }

    @available(macOS 12, *)
    @objc(webView:navigationResponse:didBecomeDownload:)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        self.webView(webView, navigationResponse: navigationResponse, didBecomeDownload: download)
    }

    @objc(_webView:didStartProvisionalLoadWithRequest:inFrame:)
    func webView(_ webView: WKWebView, didStartProvisionalLoadWithRequest request: URLRequest, inFrame frame: WKFrameInfo) {
        guard frame.isMainFrame else { return }
        self.mainFrameLoadState = .provisional
    }

    @objc(_webView:didCommitLoadWithRequest:inFrame:)
    func webView(_ webView: WKWebView, didCommitLoadWithRequest request: URLRequest, inFrame frame: WKFrameInfo) {
        guard frame.isMainFrame else { return }
        self.mainFrameLoadState = .committed
    }

    @objc(_webView:willPerformClientRedirectToURL:delay:)
    func webView(_ webView: WKWebView, willPerformClientRedirectToURL url: URL, delay: TimeInterval) {
        if case .committed = self.mainFrameLoadState {
            self.clientRedirectedDuringNavigationURL = url
        }
    }

    @objc(_webView:didFinishLoadWithRequest:inFrame:)
    func webView(_ webView: WKWebView, didFinishLoadWithRequest request: URLRequest, inFrame frame: WKFrameInfo) {
        guard frame.isMainFrame else { return }
        self.mainFrameLoadState = .finished

        StatisticsLoader.shared.refreshRetentionAtb(isSearch: request.url?.isDuckDuckGoSearch == true)

        if [.initial, .dailyFirst].contains(Pixel.Event.Repetition(key: "app_usage")) {
            Pixel.fire(.appUsage)
        }
    }

    @objc(_webView:didFinishLoadWithRequest:inFrame:withError:)
    func webView(_ webView: WKWebView, didFailLoadWithRequest request: URLRequest, inFrame frame: WKFrameInfo, withError error: Error) {
        guard frame.isMainFrame else { return }
        self.mainFrameLoadState = .finished
    }

}
// universal download event handlers for Legacy _WKDownload and modern WKDownload
extension Tab: WKWebViewDownloadDelegate {
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecomeDownload download: WebKitDownload) {
        FileDownloadManager.shared.add(download, delegate: self.delegate, location: .auto, postflight: .none)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecomeDownload download: WebKitDownload) {
        FileDownloadManager.shared.add(download, delegate: self.delegate, location: .auto, postflight: .none)

        // Note this can result in tabs being left open, e.g. download button on this page:
        // https://en.wikipedia.org/wiki/Guitar#/media/File:GuitareClassique5.png
        // Safari closes new tabs that were opened and then create a download instantly.
        if self.webView.backForwardList.currentItem == nil,
           self.parentTab != nil,
           let delegate = delegate {
            DispatchQueue.main.async {
                delegate.closeTab(self)
            }
        }
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

extension Tab: HoverUserScriptDelegate {

    func hoverUserScript(_ script: HoverUserScript, didChange url: URL?) {
        delegate?.tab(self, didChangeHoverLink: url)
    }

}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
