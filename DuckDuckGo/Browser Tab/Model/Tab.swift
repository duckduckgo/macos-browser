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

// swiftlint:disable file_length

import Cocoa
import WebKit
import os
import Combine
import BrowserServicesKit
import TrackerRadarKit

protocol TabDelegate: FileDownloadManagerDelegate, ContentOverlayUserScriptDelegate {
    func tabWillStartNavigation(_ tab: Tab, isUserInitiated: Bool)
    func tabDidStartNavigation(_ tab: Tab)
    func tab(_ tab: Tab, requestedNewTabWith content: Tab.TabContent, selected: Bool)
    // swiftlint:disable:next function_parameter_count
    func tab(_ tab: Tab, willShowContextMenuAt position: NSPoint, image: URL?, title: String?, link: URL?, selectedText: String?)
    func tab(_ tab: Tab, requestedOpenExternalURL url: URL, forUserEnteredURL: Bool)
    func tab(_ tab: Tab, requestedSaveAutofillData autofillData: AutofillData)
    func tab(_ tab: Tab,
             requestedBasicAuthenticationChallengeWith protectionSpace: URLProtectionSpace,
             completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)

    func tab(_ tab: Tab, didChangeHoverLink url: URL?)

    func tabPageDOMLoaded(_ tab: Tab)
    func closeTab(_ tab: Tab)
    func tab(_ tab: Tab, promptUserForCookieConsent result: @escaping (Bool) -> Void)
}

extension DependencyProvider<Tab> {
    var windowControllersManager: WindowControllersManager { WindowControllersManager.shared }
    var faviconManagement: FaviconManagement { FaviconManager.shared }
    var webCacheManager: WebCacheManager { WebCacheManager.shared }
    var historyCoordinating: HistoryCoordinating { HistoryCoordinator.shared }
    var pinnedTabsManager: PinnedTabsManager { windowControllersManager.pinnedTabsManager }
    var privatePlayer: PrivatePlayer { .shared }
    var cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter? { .shared }
    var workspace: NSWorkspace { .shared }

    var extensionsBuilder: ExtensionsBuilder { TabExtensionsBuilder() }

}

// swiftlint:disable:next type_body_length
final class Tab: NSObject, Identifiable, ObservableObject, DependencyProviderClient {

    enum TabContent: Equatable {
        case homePage
        case url(URL)
        case privatePlayer(videoID: String, timestamp: String?)
        case preferences(pane: PreferencePaneIdentifier?)
        case bookmarks
        case onboarding
        case none

        static func contentFromURL(_ url: URL?) -> TabContent {
            if url == .homePage {
                return .homePage
            } else if url == .welcome {
                return .onboarding
            } else if url == .preferences {
                return .anyPreferencePane
            } else if let preferencePane = url.flatMap(PreferencePaneIdentifier.init(url:)) {
                return .preferences(pane: preferencePane)
            } else if let privatePlayerContent = PrivatePlayer.shared.tabContent(for: url) {
                return privatePlayerContent
            } else {
                return .url(url ?? .blankPage)
            }
        }

        static var displayableTabTypes: [TabContent] {
            // Add new displayable types here
            let displayableTypes = [TabContent.anyPreferencePane, .bookmarks]

            return displayableTypes.sorted { first, second in
                guard let firstTitle = first.title, let secondTitle = second.title else {
                    return true // Arbitrary sort order, only non-standard tabs are displayable.
                }
                return firstTitle.localizedStandardCompare(secondTitle) == .orderedAscending
            }
        }

        /// Convenience accessor for `.preferences` Tab Content with no particular pane selected,
        /// i.e. the currently selected pane is decided internally by `PreferencesViewController`.
        static let anyPreferencePane: Self = .preferences(pane: nil)

        var isDisplayable: Bool {
            switch self {
            case .preferences, .bookmarks:
                return true
            default:
                return false
            }
        }

        func matchesDisplayableTab(_ other: TabContent) -> Bool {
            switch (self, other) {
            case (.preferences, .preferences):
                return true
            case (.bookmarks, .bookmarks):
                return true
            default:
                return false
            }
        }

        var title: String? {
            switch self {
            case .url, .homePage, .privatePlayer, .none: return nil
            case .preferences: return UserText.tabPreferencesTitle
            case .bookmarks: return UserText.tabBookmarksTitle
            case .onboarding: return UserText.tabOnboardingTitle
            }
        }

        var url: URL? {
            switch self {
            case .url(let url):
                return url
            case .privatePlayer(let videoID, let timestamp):
                return .privatePlayer(videoID, timestamp: timestamp)
            default:
                return nil
            }
        }

        var isUrl: Bool {
            switch self {
            case .url, .privatePlayer:
                return true
            default:
                return false
            }
        }

        var isPrivatePlayer: Bool {
            switch self {
            case .privatePlayer:
                return true
            default:
                return false
            }
        }
    }

    weak var autofillScript: WebsiteAutofillUserScript?
    weak var delegate: TabDelegate? {
        didSet {
            autofillScript?.currentOverlayTab = delegate
        }
    }
    
    var isPinned: Bool {
        return dependencyProvider.pinnedTabsManager.isTabPinned(self)
    }

    private(set) var extensions = DynamicTabExtensions()

    init(content: TabContent,
         webViewConfiguration: WKWebViewConfiguration? = nil,
         localHistory: Set<String> = Set<String>(),
         title: String? = nil,
         error: Error? = nil,
         favicon: NSImage? = nil,
         sessionStateData: Data? = nil,
         interactionStateData: Data? = nil,
         parentTab: Tab? = nil,
         shouldLoadInBackground: Bool = false,
         canBeClosedWithBack: Bool = false,
         lastSelectedAt: Date? = nil,
         currentDownload: URL? = nil,
         webViewFrame: CGRect = .zero
    ) {

        self.content = content
        self.localHistory = localHistory
        self.title = title
        self.error = error
        self.favicon = favicon
        self.parentTab = parentTab
        self._canBeClosedWithBack = canBeClosedWithBack
        self.sessionStateData = sessionStateData
        self.interactionStateData = interactionStateData
        self.lastSelectedAt = lastSelectedAt
        self.currentDownload = currentDownload

        let configuration = webViewConfiguration ?? WKWebViewConfiguration()
        configuration.applyStandardConfiguration()
        
        webView = WebView(frame: webViewFrame, configuration: configuration)
        webView.allowsLinkPreview = false
        permissions = PermissionModel(webView: webView)

        super.init()

        dependencyProvider.extensionsBuilder.buildExtensions(into: &extensions, for: self)

        setupWebView(shouldLoadInBackground: shouldLoadInBackground)
        if favicon == nil {
            handleFavicon()
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onDuckDuckGoEmailSignOut),
                                               name: .emailDidSignOut,
                                               object: nil)
    }

    @objc func onDuckDuckGoEmailSignOut(_ notification: Notification) {
        guard let url = webView.url else { return }
        if EmailUrls().isDuckDuckGoEmailProtection(url: url) {
            webView.evaluateJavaScript("window.postMessage({ emailProtectionSignedOut: true }, window.origin);")
        }
    }

    deinit {
        if content.isUrl, let url = webView.url {
            dependencyProvider.historyCoordinating.commitChanges(url: url)
        }
        webView.stopLoading()
        webView.stopMediaCapture()
        webView.stopAllMediaPlayback()
        webView.fullscreenWindowController?.close()
        webView.configuration.userContentController.removeAllUserScripts()

        dependencyProvider.cbaTimeReporter?.tabWillClose(self.instrumentation.currentTabIdentifier)
    }

    var userContentController: UserContentController? {
        webView.configuration.userContentController as? UserContentController
    }
    var userScripts: UserScripts? {
        userContentController?.contentBlockingAssets?.userScripts as? UserScripts
    }
    var userScriptsPublisher: AnyPublisher<UserScripts?, Never>? {
        userContentController?.$contentBlockingAssets.map { $0?.userScripts as? UserScripts }.eraseToAnyPublisher()
    }

    // MARK: - Event Publishers

    let webViewDidReceiveChallengePublisher = PassthroughSubject<Void, Never>()
    let webViewDidCommitNavigationPublisher = PassthroughSubject<Void, Never>()
    let webViewDidFinishNavigationPublisher = PassthroughSubject<Void, Never>()
    let webViewDidFailNavigationPublisher = PassthroughSubject<Void, Never>()

    @MainActor
    @Published var isAMPProtectionExtracting: Bool = false

    // MARK: - Properties

    let webView: WebView

    private var lastUpgradedURL: URL?

    var userEnteredUrl = false

    var contentChangeEnabled = true

    var fbBlockingEnabled = true

    var isLazyLoadingInProgress = false

    private var isBeingRedirected: Bool = false

    @Published private(set) var content: TabContent {
        didSet {
            handleFavicon()
            invalidateSessionStateData()
            if let oldUrl = oldValue.url {
                dependencyProvider.historyCoordinating.commitChanges(url: oldUrl)
            }
            error = nil
            Task {
                await reloadIfNeeded(shouldLoadInBackground: true)
            }

            if let title = content.title {
                self.title = title
            }
        }
    }

    func setContent(_ content: TabContent) {
        guard contentChangeEnabled else {
            return
        }

        lastUpgradedURL = nil

        if let newContent = dependencyProvider.privatePlayer.overrideContent(content, for: self) {
            self.content = newContent
            return
        }

        switch (self.content, content) {
        case (.preferences(pane: .some), .preferences(pane: nil)):
            // prevent clearing currently selected pane (for state persistence purposes)
            break
        default:
            if self.content != content {
                self.content = content
            }
        }
    }
    
    var lastSelectedAt: Date?

    @Published var title: String?
    @Published var error: Error?
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

    @available(macOS, obsoleted: 12.0, renamed: "interactionStateData")
    var sessionStateData: Data?
    var interactionStateData: Data?

    func invalidateSessionStateData() {
        sessionStateData = nil
        interactionStateData = nil
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
    
    @available(macOS 12, *)
    func getActualInteractionStateData() -> Data? {
        if let interactionStateData = interactionStateData {
            return interactionStateData
        }

        guard webView.url != nil else { return nil }
        
        self.interactionStateData = (webView.interactionState as? Data)
        
        return self.interactionStateData
    }

    func update(url: URL?, userEntered: Bool = true) {
        if url == .welcome {
            OnboardingViewModel().restart()
        }
        self.content = .contentFromURL(url)

        // This function is called when the user has manually typed in a new address, which should reset the login detection flow.
        userEnteredUrl = userEntered
    }

    // Used to track if an error was caused by a download navigation.
    private(set) var currentDownload: URL?

    func download(from url: URL, promptForLocation: Bool = true) {
        webView.startDownload(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { download in
            FileDownloadManager.shared.add(download, delegate: self.delegate, location: promptForLocation ? .prompt : .auto, postflight: .none)
        }
    }

    func saveWebContentAs(completionHandler: ((Result<URL, Error>) -> Void)? = nil) {
        webView.getMimeType { mimeType in
            if case .some(.html) = mimeType.flatMap(UTType.init(mimeType:)) {
                self.delegate?.chooseDestination(suggestedFilename: self.webView.suggestedFilename,
                                                 directoryURL: DownloadsPreferences().effectiveDownloadLocation,
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
    private var mainFrameLoadState: FrameLoadState = .finished {
        didSet {
            if mainFrameLoadState == .finished {
                setUpYoutubeScriptsIfNeeded()
            }
        }
    }
    private var clientRedirectedDuringNavigationURL: URL?
    private var externalSchemeOpenedPerPageLoad = false

    var canGoForward: Bool {
        webView.canGoForward
    }

    func goForward() {
        guard canGoForward else { return }
        shouldStoreNextVisit = false
        webView.goForward()
    }

    var canGoBack: Bool {
        webView.canGoBack || error != nil
    }

    func goBack() {
        guard canGoBack else {
            if canBeClosedWithBack {
                delegate?.closeTab(self)
            }
            return
        }

        guard error == nil else {
            webView.reload()
            return
        }

        shouldStoreNextVisit = false

        if dependencyProvider.privatePlayer.goBackSkippingLastItemIfNeeded(for: webView) {
            return
        }
        webView.goBack()
    }

    func go(to item: WKBackForwardListItem) {
        shouldStoreNextVisit = false
        webView.go(to: item)
    }

    func openHomePage() {
        content = .homePage
    }

    func startOnboarding() {
        content = .onboarding
    }

    func reload() {
        currentDownload = nil
        if let error = error, let failingUrl = error.failingUrl {
            webView.load(failingUrl)
            return
        }

        if webView.url == nil, let url = content.url {
            webView.load(url)
        } else if case .privatePlayer = content, let url = content.url {
            webView.load(url)
        } else {
            webView.reload()
        }
    }

    @discardableResult
    private func setFBProtection(enabled: Bool) -> Bool {
        guard self.fbBlockingEnabled != enabled else { return false }
        guard let userContentController = userContentController else {
            assertionFailure("Missing UserContentController")
            return false
        }
        if enabled {
            do {
                try userContentController.enableGlobalContentRuleList(withIdentifier: ContentBlockerRulesLists.Constants.clickToLoadRulesListName)
            } catch {
                assertionFailure("Missing FB List")
                return false
            }
        } else {
            do {
                try userContentController.disableGlobalContentRuleList(withIdentifier: ContentBlockerRulesLists.Constants.clickToLoadRulesListName)
            } catch {
                assertionFailure("FB List was not enabled")
                return false
            }
        }
        self.fbBlockingEnabled = enabled

        return true
    }

    private static let debugEvents = EventMapping<AMPProtectionDebugEvents> { event, _, _, _ in
        switch event {
        case .ampBlockingRulesCompilationFailed:
            Pixel.fire(.ampBlockingRulesCompilationFailed)
        }
    }

    lazy var linkProtection: LinkProtection = {
        LinkProtection(privacyManager: ContentBlocking.shared.privacyConfigurationManager,
                       contentBlockingManager: ContentBlocking.shared.contentBlockingManager,
                       errorReporting: Self.debugEvents)
    }()
    
    lazy var referrerTrimming: ReferrerTrimming = {
        ReferrerTrimming(privacyManager: ContentBlocking.shared.privacyConfigurationManager,
                         contentBlockingManager: ContentBlocking.shared.contentBlockingManager,
                         tld: ContentBlocking.shared.tld)
    }()

    @MainActor
    private func reloadIfNeeded(shouldLoadInBackground: Bool = false) async {
        guard content.url != nil else {
            return
        }

        let url: URL = await {
            if contentURL.isFileURL {
                return contentURL
            }
            return await linkProtection.getCleanURL(from: contentURL, onStartExtracting: {
                isAMPProtectionExtracting = true
            }, onFinishExtracting: { [weak self]
                in self?.isAMPProtectionExtracting = false
            })
        }()
        if shouldLoadURL(url, shouldLoadInBackground: shouldLoadInBackground) {
            let didRestore: Bool
            
            if #available(macOS 12.0, *) {
                didRestore = restoreInteractionStateDataIfNeeded() || restoreSessionStateDataIfNeeded()
            } else {
                didRestore = restoreSessionStateDataIfNeeded()
            }

            if dependencyProvider.privatePlayer.goBackAndLoadURLIfNeeded(for: self) {
                return
            }

            if !didRestore {
                if url.isFileURL {
                    _ = webView.loadFileURL(url, allowingReadAccessTo: URL(fileURLWithPath: "/"))
                } else {
                    webView.load(url)
                }
            }
        }
    }

    @MainActor
    private var contentURL: URL {
        switch content {
        case .url(let value):
            return value
        case .privatePlayer(let videoID, let timestamp):
            return .privatePlayer(videoID, timestamp: timestamp)
        case .homePage:
            return .homePage
        default:
            return .blankPage
        }
    }

    @MainActor
    private func shouldLoadURL(_ url: URL, shouldLoadInBackground: Bool = false) -> Bool {
        // don‘t reload in background unless shouldLoadInBackground
        guard url.isValid,
              (webView.superview != nil || shouldLoadInBackground),
              // don‘t reload when already loaded
              webView.url != url,
              webView.url != content.url
        else {
            return false
        }

        if dependencyProvider.privatePlayer.shouldSkipLoadingURL(for: self) {
            return false
        }

        // if content not loaded inspect error
        switch error {
        case .none, // no error
            // error due to connection failure
             .some(URLError.notConnectedToInternet),
             .some(URLError.networkConnectionLost):
            return true
        case .some:
            // don‘t autoreload on other kinds of errors
            return false
        }
    }

    @MainActor
    @available(macOS, obsoleted: 12.0, renamed: "restoreInteractionStateDataIfNeeded")
    private func restoreSessionStateDataIfNeeded() -> Bool {
        var didRestore: Bool = false
        if let sessionStateData = self.sessionStateData {
            if contentURL.isFileURL {
                _ = webView.loadFileURL(contentURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
            }
            do {
                try webView.restoreSessionState(from: sessionStateData)
                didRestore = true
            } catch {
                os_log("Tab:setupWebView could not restore session state %s", "\(error)")
            }
        }
        
        return didRestore
    }
    
    @MainActor
    @available(macOS 12, *)
    private func restoreInteractionStateDataIfNeeded() -> Bool {
        var didRestore: Bool = false
        if let interactionStateData = self.interactionStateData {
            if contentURL.isFileURL {
                _ = webView.loadFileURL(contentURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
            }
            
            webView.interactionState = interactionStateData
            didRestore = true
        }
        
        return didRestore
    }

    private func addHomePageToWebViewIfNeeded() {
        guard !AppDelegate.isRunningTests else { return }
        if content == .homePage && webView.url == nil {
            webView.load(.homePage)
        }
    }

    func stopLoading() {
        webView.stopLoading()
    }

    func requestFireproofToggle() {
        guard let url = content.url,
              let host = url.host
        else { return }

        _ = FireproofDomains.shared.toggle(domain: host)
    }

    private var superviewObserver: NSKeyValueObservation?

    private func setupWebView(shouldLoadInBackground: Bool) {
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        userContentController?.delegate = self

        superviewObserver = webView.observe(\.superview, options: .old) { [weak self] _, change in
            // if the webView is being added to superview - reload if needed
            if case .some(.none) = change.oldValue {
                Task { @MainActor [weak self] in
                    await self?.reloadIfNeeded()
                }
            }
        }

        // background tab loading should start immediately
        Task { @MainActor in
            await reloadIfNeeded(shouldLoadInBackground: shouldLoadInBackground)
            if !shouldLoadInBackground {
                addHomePageToWebViewIfNeeded()
            }
        }
    }

    // MARK: - Favicon

    @Published var favicon: NSImage?

    private func handleFavicon() {
        if content.isPrivatePlayer {
            favicon = .privatePlayer
            return
        }

        guard dependencyProvider.faviconManagement.areFaviconsLoaded else { return }

        guard content.isUrl, let url = content.url else {
            favicon = nil
            return
        }

        if let cachedFavicon = dependencyProvider.faviconManagement.getCachedFavicon(for: url, sizeCategory: .small)?.image {
            if cachedFavicon != favicon {
                favicon = cachedFavicon
            }
        } else {
            favicon = nil
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

    // MARK: - Find in Page

    weak var findInPageScript: FindInPageUserScript?
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
        findInPageScript?.model = findInPage
        subscribeToFindInPageTextChange()
    }

    // MARK: - Global & Local History

    private var shouldStoreNextVisit = true
    private(set) var localHistory: Set<String>

    func addVisit(of url: URL) {
        guard shouldStoreNextVisit else {
            shouldStoreNextVisit = true
            return
        }

        // Add to global history
        dependencyProvider.historyCoordinating.addVisit(of: url)

        // Add to local history
        if let host = url.host, !host.isEmpty {
            localHistory.insert(host.droppingWwwPrefix())
        }
    }

    func updateVisitTitle(_ title: String, url: URL) {
        dependencyProvider.historyCoordinating.updateTitleIfNeeded(title: title, url: url)
    }

    // MARK: - Youtube Player
    
    private weak var youtubeOverlayScript: YoutubeOverlayUserScript?
    private weak var youtubePlayerScript: YoutubePlayerUserScript?
    private var youtubePlayerCancellables: Set<AnyCancellable> = []

    func setUpYoutubeScriptsIfNeeded() {
        guard PrivatePlayer.shared.isAvailable else {
            return
        }

        youtubePlayerCancellables.removeAll()

        // only send push updates on macOS 11+ where it's safe to call window.* messages in the browser
        let canPushMessagesToJS: Bool = {
            if #available(macOS 11, *) {
                return true
            } else {
                return false
            }
        }()

        if webView.url?.host?.droppingWwwPrefix() == "youtube.com" && canPushMessagesToJS {
            dependencyProvider.privatePlayer.$mode
                .dropFirst()
                .sink { [weak self] playerMode in
                    guard let self = self else {
                        return
                    }
                    let userValues = YoutubeOverlayUserScript.UserValues(
                        privatePlayerMode: playerMode,
                        overlayInteracted: self.dependencyProvider.privatePlayer.overlayInteracted
                    )
                    self.youtubeOverlayScript?.userValuesUpdated(userValues: userValues, inWebView: self.webView)
                }
                .store(in: &youtubePlayerCancellables)
        }

        if url?.isPrivatePlayerScheme == true {
            youtubePlayerScript?.isEnabled = true

            if canPushMessagesToJS {
                dependencyProvider.privatePlayer.$mode
                    .map { $0 == .enabled }
                    .sink { [weak self] shouldAlwaysOpenPrivatePlayer in
                        guard let self = self else {
                            return
                        }
                        self.youtubePlayerScript?.setAlwaysOpenInPrivatePlayer(shouldAlwaysOpenPrivatePlayer, inWebView: self.webView)
                    }
                    .store(in: &youtubePlayerCancellables)
            }
        } else {
            youtubePlayerScript?.isEnabled = false
        }
    }
    
    // MARK: - Dashboard Info

    @Published private(set) var trackerInfo: TrackerInfo?
    @Published private(set) var serverTrust: ServerTrust?
    @Published private(set) var connectionUpgradedTo: URL?
    @Published private(set) var cookieConsentManaged: CookieConsentInfo?

    private func resetDashboardInfo() {
        trackerInfo = TrackerInfo()
        if self.serverTrust?.host != content.url?.host {
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

extension Tab: UserContentControllerDelegate {

    func userContentController(_ userContentController: UserContentController, didInstallContentRuleLists contentRuleLists: [String: WKContentRuleList], userScripts: UserScriptsProvider, updateEvent: ContentBlockerRulesManager.UpdateEvent) {
        guard let userScripts = userScripts as? UserScripts else { fatalError("Unexpected UserScripts") }

        userScripts.debugScript.instrumentation = instrumentation
        userScripts.faviconScript.delegate = self
        userScripts.contextMenuScript.delegate = self
        userScripts.surrogatesScript.delegate = self
        userScripts.contentBlockerRulesScript.delegate = self
        userScripts.clickToLoadScript.delegate = self
        userScripts.autofillScript.currentOverlayTab = self.delegate
        userScripts.autofillScript.emailDelegate = emailManager
        userScripts.autofillScript.vaultDelegate = vaultManager
        self.autofillScript = userScripts.autofillScript
        userScripts.pageObserverScript.delegate = self
        userScripts.hoverUserScript.delegate = self
        if #available(macOS 11, *) {
            userScripts.autoconsentUserScript?.delegate = self
        }
        youtubeOverlayScript = userScripts.youtubeOverlayScript
        youtubeOverlayScript?.delegate = self
        youtubePlayerScript = userScripts.youtubePlayerUserScript
        setUpYoutubeScriptsIfNeeded()

        findInPageScript = userScripts.findInPageScript
        attachFindInPage()
    }

}

extension Tab: BrowserTabViewControllerClickDelegate {

    func browserTabViewController(_ browserTabViewController: BrowserTabViewController, didClickAtPoint: NSPoint) {
        guard let autofillScript = autofillScript else { return }
        autofillScript.clickPoint = didClickAtPoint
    }

}

extension Tab: PageObserverUserScriptDelegate {

    func pageDOMLoaded() {
        self.delegate?.tabPageDOMLoaded(self)
    }

}

extension Tab: ContextMenuDelegate {

    // swiftlint:disable:next function_parameter_count
    func contextMenu(forUserScript script: ContextMenuUserScript,
                     willShowAt position: NSPoint,
                     image: URL?,
                     title: String?,
                     link: URL?,
                     selectedText: String?) {
        delegate?.tab(self, willShowContextMenuAt: position, image: image, title: title, link: link, selectedText: selectedText)
    }

}

extension Tab: FaviconUserScriptDelegate {

    func faviconUserScript(_ faviconUserScript: FaviconUserScript,
                           didFindFaviconLinks faviconLinks: [FaviconUserScript.FaviconLink],
                           for documentUrl: URL) {
        dependencyProvider.faviconManagement.handleFaviconLinks(faviconLinks, documentUrl: documentUrl) { favicon in
            guard documentUrl == self.content.url, let favicon = favicon else {
                return
            }
            self.favicon = favicon.image
        }
    }

}

extension Tab: ContentBlockerRulesUserScriptDelegate {

    func contentBlockerRulesUserScriptShouldProcessTrackers(_ script: ContentBlockerRulesUserScript) -> Bool {
        return true
    }

    func contentBlockerRulesUserScriptShouldProcessCTLTrackers(_ script: ContentBlockerRulesUserScript) -> Bool {
        return fbBlockingEnabled
    }
    
    func contentBlockerRulesUserScript(_ script: ContentBlockerRulesUserScript, detectedTracker tracker: DetectedRequest) {
        trackerInfo?.add(detectedTracker: tracker)
        self.extensions.adClickAttribution.logic.onRequestDetected(request: tracker)
        guard let url = URL(string: tracker.pageUrl) else { return }
        dependencyProvider.historyCoordinating.addDetectedTracker(tracker, onURL: url)
    }

    func contentBlockerRulesUserScript(_ script: ContentBlockerRulesUserScript, detectedThirdPartyRequest request: DetectedRequest) {
        trackerInfo?.add(detectedThirdPartyRequest: request)
    }
    
}

extension HistoryCoordinating {

    func addDetectedTracker(_ tracker: DetectedRequest, onURL url: URL) {
        trackerFound(on: url)

        guard tracker.isBlocked,
              let entityName = tracker.entityName else { return }

        addBlockedTracker(entityName: entityName, on: url)
    }

}

extension ContentBlocking {

    func entityName(forDomain domain: String) -> String? {
        var entityName: String?
        var parts = domain.components(separatedBy: ".")
        while parts.count > 1 && entityName == nil {
            let host = parts.joined(separator: ".")
            entityName = trackerDataManager.trackerData.domains[host]
            parts.removeFirst()
        }
        return entityName
    }

}

extension Tab: ClickToLoadUserScriptDelegate {

    func clickToLoadUserScriptAllowFB(_ script: UserScript, replyHandler: @escaping (Bool) -> Void) {
        guard self.fbBlockingEnabled else {
            replyHandler(true)
            return
        }

        if setFBProtection(enabled: false) {
            replyHandler(true)
        } else {
            replyHandler(false)
        }
    }
}

extension Tab: SurrogatesUserScriptDelegate {
    func surrogatesUserScriptShouldProcessTrackers(_ script: SurrogatesUserScript) -> Bool {
        return true
    }

    func surrogatesUserScript(_ script: SurrogatesUserScript, detectedTracker tracker: DetectedRequest, withSurrogate host: String) {
        trackerInfo?.add(installedSurrogateHost: host)
        trackerInfo?.add(detectedTracker: tracker)
        guard let url = webView.url else { return }
        dependencyProvider.historyCoordinating.addDetectedTracker(tracker, onURL: url)
    }
}

extension Tab: EmailManagerRequestDelegate { }

extension Tab: SecureVaultManagerDelegate {

    public func secureVaultManagerIsEnabledStatus(_: SecureVaultManager) -> Bool {
        return true
    }
    
    func secureVaultManager(_: SecureVaultManager, promptUserToStoreAutofillData data: AutofillData) {
        delegate?.tab(self, requestedSaveAutofillData: data)
    }
    
    func secureVaultManager(_: SecureVaultManager,
                            promptUserToAutofillCredentialsForDomain domain: String,
                            withAccounts accounts: [SecureVaultModels.WebsiteAccount],
                            withTrigger trigger: AutofillUserScript.GetTriggerType,
                            completionHandler: @escaping (SecureVaultModels.WebsiteAccount?) -> Void) {
        // no-op on macOS
    }

    func secureVaultManager(_: SecureVaultManager, didAutofill type: AutofillType, withObjectId objectId: Int64) {
        Pixel.fire(.formAutofilled(kind: type.formAutofillKind))
    }

    func secureVaultManager(_: SecureVaultManager, didRequestAuthenticationWithCompletionHandler handler: @escaping (Bool) -> Void) {
        DeviceAuthenticator.shared.authenticateUser(reason: .autofill) { authenticationResult in
            handler(authenticationResult.authenticated)
        }
    }

    func secureVaultInitFailed(_ error: SecureVaultError) {
        SecureVaultErrorReporter.shared.secureVaultInitFailed(error)
    }
    
    func secureVaultManagerShouldAutomaticallyUpdateCredentialsWithoutUsername(_: SecureVaultManager) -> Bool {
        return true
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

    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        webViewDidReceiveChallengePublisher.send()

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

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        isBeingRedirected = true
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        isBeingRedirected = false
        if content.isUrl, let url = webView.url {
            addVisit(of: url)
        }
        webViewDidCommitNavigationPublisher.send()
    }

    struct Constants {
        static let webkitMiddleClick = 4
    }

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    @MainActor
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
                
        if let policy = dependencyProvider.privatePlayer.decidePolicy(for: navigationAction, in: self) {
            return policy
        }

        if navigationAction.request.url?.isFileURL == true {
            return .allow
        }

        let isLinkActivated = navigationAction.navigationType == .linkActivated
        let isNavigatingAwayFromPinnedTab: Bool = {
            let isNavigatingToAnotherDomain = navigationAction.request.url?.host != url?.host
            let isPinned = dependencyProvider.pinnedTabsManager.isTabPinned(self)
            return isLinkActivated && isPinned && isNavigatingToAnotherDomain
        }()

        let isMiddleButtonClicked = navigationAction.buttonNumber == Constants.webkitMiddleClick
        let isRequestingNewTab = (isLinkActivated && NSApp.isCommandPressed) || isMiddleButtonClicked || isNavigatingAwayFromPinnedTab
        let shouldSelectNewTab = NSApp.isShiftPressed || (isNavigatingAwayFromPinnedTab && !isMiddleButtonClicked && !NSApp.isCommandPressed)

        // This check needs to happen before GPC checks. Otherwise the navigation type may be rewritten to `.other`
        // which would skip link rewrites.
        if navigationAction.navigationType != .backForward {
            let navigationActionPolicy = await linkProtection
                .requestTrackingLinkRewrite(
                    initiatingURL: webView.url,
                    navigationAction: navigationAction,
                    onStartExtracting: { if !isRequestingNewTab { isAMPProtectionExtracting = true }},
                    onFinishExtracting: { [weak self] in self?.isAMPProtectionExtracting = false },
                    onLinkRewrite: { [weak self] url, _ in
                        guard let self = self else { return }
                        if isRequestingNewTab || !navigationAction.isTargetingMainFrame {
                            self.delegate?.tab(
                                self,
                                requestedNewTabWith: .url(url),
                                selected: shouldSelectNewTab || !navigationAction.isTargetingMainFrame
                            )
                        } else {
                            webView.load(url)
                        }
                    })
            if let navigationActionPolicy = navigationActionPolicy, navigationActionPolicy == .cancel {
                return navigationActionPolicy
            }
        }

        webView.customUserAgent = UserAgent.for(navigationAction.request.url)

        if navigationAction.isTargetingMainFrame, navigationAction.request.mainDocumentURL?.host != lastUpgradedURL?.host {
            lastUpgradedURL = nil
        }
        
        if navigationAction.isTargetingMainFrame, navigationAction.navigationType == .backForward {
            self.extensions.adClickAttribution.logic.onBackForwardNavigation(mainFrameURL: webView.url)
        }
        
        if navigationAction.isTargetingMainFrame, navigationAction.navigationType != .backForward {
            if let newRequest = referrerTrimming.trimReferrer(forNavigation: navigationAction,
                                                              originUrl: webView.url ?? navigationAction.sourceFrame.webView?.url) {
                if isRequestingNewTab {
                    delegate?.tab(
                        self,
                        requestedNewTabWith: newRequest.url.map { .contentFromURL($0) } ?? .none,
                        selected: shouldSelectNewTab)
                } else {
                    _ = webView.load(newRequest)
                }
                return .cancel
            }
        }

        if navigationAction.isTargetingMainFrame {
            if navigationAction.navigationType == .backForward,
               self.webView.frozenCanGoForward != nil {

                // Auto-cancel simulated Back action when upgrading to HTTPS or GPC from Client Redirect
                self.webView.frozenCanGoForward = nil
                self.webView.frozenCanGoBack = nil

                return .cancel

            } else if navigationAction.navigationType != .backForward, !isRequestingNewTab,
                      let request = GPCRequestFactory.shared.requestForGPC(basedOn: navigationAction.request) {
                self.invalidateBackItemIfNeeded(for: navigationAction)
                defer {
                    _ = webView.load(request)
                }
                return .cancel
            }
        }

        if navigationAction.isTargetingMainFrame {
            if navigationAction.request.url != currentDownload || navigationAction.isUserInitiated {
                currentDownload = nil
            }
            if navigationAction.request.url != self.clientRedirectedDuringNavigationURL {
                self.clientRedirectedDuringNavigationURL = nil
            }
        }

        self.resetConnectionUpgradedTo(navigationAction: navigationAction)

        if isRequestingNewTab {
            defer {
                delegate?.tab(
                    self,
                    requestedNewTabWith: navigationAction.request.url.map { .contentFromURL($0) } ?? .none,
                    selected: shouldSelectNewTab)
            }
            return .cancel
        } else if isLinkActivated && NSApp.isOptionPressed && !NSApp.isCommandPressed {
            return .download(navigationAction, using: webView)
        }

        guard let url = navigationAction.request.url, url.scheme != nil else {
            self.willPerformNavigationAction(navigationAction)
            return .allow
        }

        if navigationAction.shouldDownload {
            // register the navigationAction for legacy _WKDownload to be called back on the Tab
            // further download will be passed to webView:navigationAction:didBecomeDownload:
            return .download(navigationAction, using: webView)

        } else if url.isExternalSchemeLink {
            // always allow user entered URLs
            if !userEnteredUrl {
                // ignore <iframe src="custom://url">
                // ignore 2nd+ external scheme navigation not initiated by user
                guard navigationAction.sourceFrame.isMainFrame,
                      !self.externalSchemeOpenedPerPageLoad || navigationAction.isUserInitiated
                else { return .cancel }

                self.externalSchemeOpenedPerPageLoad = true
            }
            self.delegate?.tab(self, requestedOpenExternalURL: url, forUserEnteredURL: userEnteredUrl)
            return .cancel
        }

        if navigationAction.isTargetingMainFrame {
            let result = await PrivacyFeatures.httpsUpgrade.upgrade(url: url)
            switch result {
            case let .success(upgradedURL):
                if lastUpgradedURL != upgradedURL {
                    urlDidUpgrade(upgradedURL, navigationAction: navigationAction)
                    return .cancel
                }
            case .failure:
                if !url.isDuckDuckGo {
                    await prepareForContentBlocking()
                }
            }
        }

        toggleFBProtection(for: url)
        willPerformNavigationAction(navigationAction)

        return .allow
    }

    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    private func urlDidUpgrade(_ upgradedURL: URL,
                               navigationAction: WKNavigationAction) {
        lastUpgradedURL = upgradedURL
        invalidateBackItemIfNeeded(for: navigationAction)
        webView.load(upgradedURL)
        setConnectionUpgradedTo(upgradedURL, navigationAction: navigationAction)
    }

    @MainActor
    private func prepareForContentBlocking() async {
        // Ensure Content Blocking Assets (WKContentRuleList&UserScripts) are installed
        if userContentController?.contentBlockingAssetsInstalled == false {
            dependencyProvider.cbaTimeReporter?.tabWillWaitForRulesCompilation(self.instrumentation.currentTabIdentifier)
            await userContentController?.awaitContentBlockingAssetsInstalled()
            dependencyProvider.cbaTimeReporter?.reportWaitTimeForTabFinishedWaitingForRules(self.instrumentation.currentTabIdentifier)
        } else {
            dependencyProvider.cbaTimeReporter?.reportNavigationDidNotWaitForRules()
        }
    }

    private func toggleFBProtection(for url: URL) {
        // Enable/disable FBProtection only after UserScripts are installed (awaitContentBlockingAssetsInstalled)
        let privacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig

        let featureEnabled = privacyConfiguration.isFeature(.clickToPlay, enabledForDomain: url.host)
        setFBProtection(enabled: featureEnabled)
    }

    private func willPerformNavigationAction(_ navigationAction: WKNavigationAction) {
        guard navigationAction.isTargetingMainFrame else { return }

        self.externalSchemeOpenedPerPageLoad = false
        delegate?.tabWillStartNavigation(self, isUserInitiated: navigationAction.isUserInitiated)
    }

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

    @MainActor
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        userEnteredUrl = false // subsequent requests will be navigations
        
        let isSuccessfulResponse = (navigationResponse.response as? HTTPURLResponse)?.validateStatusCode(statusCode: 200..<300) == nil

        if !navigationResponse.canShowMIMEType || navigationResponse.shouldDownload {
            if navigationResponse.isForMainFrame {
                guard currentDownload != navigationResponse.response.url else {
                    // prevent download twice
                    return .cancel
                }
                currentDownload = navigationResponse.response.url
            }

            if isSuccessfulResponse {
                // register the navigationResponse for legacy _WKDownload to be called back on the Tab
                // further download will be passed to webView:navigationResponse:didBecomeDownload:
                return .download(navigationResponse, using: webView)
            }
        }
        
        if navigationResponse.isForMainFrame && isSuccessfulResponse {
            self.extensions.adClickAttribution.detection.on2XXResponse(url: webView.url)
        }
        
        await self.extensions.adClickAttribution.logic.onProvisionalNavigation()

        return .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        delegate?.tabDidStartNavigation(self)

        // Unnecessary assignment triggers publishing
        if error != nil { error = nil }

        invalidateSessionStateData()
        resetDashboardInfo()
        linkProtection.cancelOngoingExtraction()
        linkProtection.setMainFrameUrl(webView.url)
        referrerTrimming.onBeginNavigation(to: webView.url)
        self.extensions.adClickAttribution.detection.onStartNavigation(url: webView.url)
        
    }

    @MainActor
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isBeingRedirected = false
        invalidateSessionStateData()
        webViewDidFinishNavigationPublisher.send()
        if isAMPProtectionExtracting { isAMPProtectionExtracting = false }
        linkProtection.setMainFrameUrl(nil)
        referrerTrimming.onFinishNavigation()
        self.extensions.adClickAttribution.detection.onDidFinishNavigation(url: webView.url)
        self.extensions.adClickAttribution.logic.onDidFinishNavigation(host: webView.url?.host)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Failing not captured. Seems the method is called after calling the webview's method goBack()
        // https://app.asana.com/0/1199230911884351/1200381133504356/f
        //        hasError = true

        isBeingRedirected = false
        invalidateSessionStateData()
        linkProtection.setMainFrameUrl(nil)
        referrerTrimming.onFailedNavigation()
        self.extensions.adClickAttribution.detection.onDidFailNavigation()
        webViewDidFailNavigationPublisher.send()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        switch error {
        case URLError.notConnectedToInternet,
             URLError.networkConnectionLost:
            guard let failingUrl = error.failingUrl else { break }
            dependencyProvider.historyCoordinating.markFailedToLoadUrl(failingUrl)
        default: break
        }

        self.error = error
        isBeingRedirected = false
        linkProtection.setMainFrameUrl(nil)
        referrerTrimming.onFailedNavigation()
        self.extensions.adClickAttribution.detection.onDidFailNavigation()
        webViewDidFailNavigationPublisher.send()
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
    }

    @objc(_webView:didFailProvisionalLoadWithRequest:inFrame:withError:)
    func webView(_ webView: WKWebView,
                 didFailProvisionalLoadWithRequest request: URLRequest,
                 inFrame frame: WKFrameInfo,
                 withError error: Error) {
        guard frame.isMainFrame else { return }
        self.mainFrameLoadState = .finished
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Pixel.fire(.debug(event: .webKitDidTerminate))
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
           self.parentTab != nil {
            DispatchQueue.main.async { [weak delegate=self.delegate] in
                delegate?.closeTab(self)
            }
        }
    }
}

extension Tab {

    private func find(text: String) {
        findInPageScript?.find(text: text, inWebView: webView)
    }

    func findDone() {
        findInPageScript?.done(withWebView: webView)
    }

    func findNext() {
        findInPageScript?.next(withWebView: webView)
    }

    func findPrevious() {
        findInPageScript?.previous(withWebView: webView)
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

@available(macOS 11, *)
extension Tab: AutoconsentUserScriptDelegate {
    func autoconsentUserScript(consentStatus: CookieConsentInfo) {
        self.cookieConsentManaged = consentStatus
    }
    
    func autoconsentUserScriptPromptUserForConsent(_ result: @escaping (Bool) -> Void) {
        delegate?.tab(self, promptUserForCookieConsent: result)
    }
}

extension Tab: YoutubeOverlayUserScriptDelegate {
    func youtubeOverlayUserScriptDidRequestDuckPlayer(with url: URL) {
        let content = Tab.TabContent.contentFromURL(url)
        let isRequestingNewTab = NSApp.isCommandPressed
        if isRequestingNewTab {
            let shouldSelectNewTab = NSApp.isShiftPressed
            self.delegate?.tab(self, requestedNewTabWith: content, selected: shouldSelectNewTab)
        } else {
            setContent(content)
        }
    }
}

extension Tab: TabDataClearing {
    func prepareForDataClearing(caller: TabDataCleaner) {
        webView.stopLoading()
        webView.configuration.userContentController.removeAllUserScripts()

        webView.navigationDelegate = caller
        webView.load(URL(string: "about:blank")!)
    }
}
