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
import ContentBlocking
import UserScript
import PrivacyDashboard

protocol TabDelegate: ContentOverlayUserScriptDelegate {
    func tabWillStartNavigation(_ tab: Tab, isUserInitiated: Bool)
    func tabDidStartNavigation(_ tab: Tab)
    func tab(_ tab: Tab, createdChild childTab: Tab, of kind: NewWindowPolicy)

    func tab(_ tab: Tab, requestedOpenExternalURL url: URL, forUserEnteredURL userEntered: Bool) -> Bool
    func tab(_ tab: Tab, promptUserForCookieConsent result: @escaping (Bool) -> Void)

    func tabPageDOMLoaded(_ tab: Tab)
    func closeTab(_ tab: Tab)

    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect?

}

// swiftlint:disable type_body_length
final class Tab: NSObject, Identifiable, ObservableObject {

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

    weak var delegate: TabDelegate? {
        didSet {
            userScripts?.autofillScript.currentOverlayTab = delegate
        }
    }

    private let cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?
    let pinnedTabsManager: PinnedTabsManager
    let privacyConfigurationManager: PrivacyConfigurationManaging
    private let contentBlockerRulesManager: ContentBlockerRulesManagerProtocol
    private let privatePlayer: PrivatePlayer

    private let webViewConfiguration: WKWebViewConfiguration
    private(set) lazy var extensions = TabExtensions(self)

    @Published
    private(set) var userContentController: UserContentController?
    var userScripts: UserScripts? {
        userContentController?.contentBlockingAssets?.userScripts as? UserScripts
    }
    var userScriptsPublisher: AnyPublisher<UserScripts?, Never> {
        $userContentController
            .compactMap { $0?.$contentBlockingAssets }
            .switchToLatest()
            .map { $0?.userScripts as? UserScripts }
            .eraseToAnyPublisher()
    }

    private lazy var clicksSubject = PassthroughSubject<NSPoint, Never>()
    var clicksPublisher: AnyPublisher<NSPoint, Never> {
        clicksSubject.eraseToAnyPublisher()
    }

    convenience init(content: TabContent,
                     faviconManagement: FaviconManagement = FaviconManager.shared,
                     webCacheManager: WebCacheManager = WebCacheManager.shared,
                     webViewConfiguration: WKWebViewConfiguration? = nil,
                     historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
                     pinnedTabsManager: PinnedTabsManager = WindowControllersManager.shared.pinnedTabsManager,
                     privacyConfigurationManager: (PrivacyConfigurationManaging & AnyObject)? = nil,
                     contentBlockerRulesManager: ContentBlockerRulesManagerProtocol? = nil,
                     privatePlayer: PrivatePlayer? = nil,
                     cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter? = ContentBlockingAssetsCompilationTimeReporter.shared,
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

#if DEBUG
        let contentBlockingAssetsPublisher = AppDelegate.isRunningTests ? PassthroughSubject().eraseToAnyPublisher() : ContentBlocking.shared.userContentUpdating.userContentBlockingAssets!
        let contentBlockerRulesManager = contentBlockerRulesManager
        ?? (AppDelegate.isRunningTests
            ? ((NSClassFromString("ContentBlockerRulesManagerMock") as? (NSObject).Type)!.init() as? ContentBlockerRulesManagerProtocol)!
            : ContentBlocking.shared.contentBlockingManager)
        let privacyConfigurationManager: (PrivacyConfigurationManaging & AnyObject) = privacyConfigurationManager
        ?? (AppDelegate.isRunningTests
            ? ((NSClassFromString("MockPrivacyConfigurationManager") as? (NSObject).Type)!.init() as? (PrivacyConfigurationManaging & AnyObject))!
            : ContentBlocking.shared.privacyConfigurationManager)
        let privatePlayer = privatePlayer
        ?? (AppDelegate.isRunningTests ? PrivatePlayer.mock(withMode: .enabled) : PrivatePlayer.shared)
#else
        let contentBlockingAssetsPublisher = ContentBlocking.shared.userContentUpdating.userContentBlockingAssets!
        let contentBlockerRulesManager = contentBlockerRulesManager ?? ContentBlocking.shared.contentBlockingManager
        let privacyConfigurationManager = privacyConfigurationManager ?? ContentBlocking.shared.privacyConfigurationManager
        let privatePlayer = privatePlayer ?? PrivatePlayer.shared
#endif
        self.init(content: content,
                  faviconManagement: faviconManagement,
                  webCacheManager: webCacheManager,
                  webViewConfiguration: webViewConfiguration,
                  historyCoordinating: historyCoordinating,
                  pinnedTabsManager: pinnedTabsManager,
                  privacyConfigurationManager: privacyConfigurationManager,
                  contentBlockerRulesManager: contentBlockerRulesManager,
                  contentBlockingAssetsPublisher: contentBlockingAssetsPublisher,
                  privatePlayer: privatePlayer,
                  cbaTimeReporter: cbaTimeReporter,
                  localHistory: localHistory,
                  title: title,
                  error: error,
                  favicon: favicon,
                  sessionStateData: sessionStateData,
                  interactionStateData: interactionStateData,
                  parentTab: parentTab,
                  shouldLoadInBackground: shouldLoadInBackground,
                  canBeClosedWithBack: canBeClosedWithBack,
                  lastSelectedAt: lastSelectedAt,
                  currentDownload: currentDownload,
                  webViewFrame: webViewFrame)
    }

    init(content: TabContent,
         faviconManagement: FaviconManagement,
         webCacheManager: WebCacheManager,
         webViewConfiguration: WKWebViewConfiguration?,
         historyCoordinating: HistoryCoordinating,
         pinnedTabsManager: PinnedTabsManager,
         privacyConfigurationManager: PrivacyConfigurationManaging,
         contentBlockerRulesManager: ContentBlockerRulesManagerProtocol,
         contentBlockingAssetsPublisher: some Publisher<some UserContentControllerNewContent, Never>,
         privatePlayer: PrivatePlayer,
         cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?,
         localHistory: Set<String>,
         title: String?,
         error: Error?,
         favicon: NSImage?,
         sessionStateData: Data?,
         interactionStateData: Data?,
         parentTab: Tab?,
         shouldLoadInBackground: Bool,
         canBeClosedWithBack: Bool,
         lastSelectedAt: Date?,
         currentDownload: URL?,
         webViewFrame: CGRect
    ) {

        self.content = content
        self.faviconManagement = faviconManagement
        self.historyCoordinating = historyCoordinating
        self.pinnedTabsManager = pinnedTabsManager
        self.privacyConfigurationManager = privacyConfigurationManager
        self.contentBlockerRulesManager = contentBlockerRulesManager
        self.privatePlayer = privatePlayer
        self.cbaTimeReporter = cbaTimeReporter
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
        configuration.applyStandardConfiguration(assetsPublisher: contentBlockingAssetsPublisher, privacyConfigurationManager: privacyConfigurationManager)
        self.webViewConfiguration = configuration
        self.userContentController = (configuration.userContentController as? UserContentController)!

        webView = WebView(frame: webViewFrame, configuration: configuration)
        webView.allowsLinkPreview = false
        permissions = PermissionModel()

        super.init()

        userContentController!.delegate = self
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
        cleanUpBeforeClosing()
        webView.configuration.userContentController.removeAllUserScripts()
    }

    func cleanUpBeforeClosing() {
        if content.isUrl, let url = webView.url {
            historyCoordinating.commitChanges(url: url)
        }
        webView.stopLoading()
        webView.stopMediaCapture()
        webView.stopAllMediaPlayback()
        webView.fullscreenWindowController?.close()

        cbaTimeReporter?.tabWillClose(self.instrumentation.currentTabIdentifier)
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
                historyCoordinating.commitChanges(url: oldUrl)
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

        if let newContent = privatePlayer.overrideContent(content, for: self) {
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

    /// an Interactive Dialog request (alert/open/save/print) made by a page to be published and presented asynchronously
    @Published
    var userInteractionDialog: UserDialog? {
        didSet {
            guard let request = userInteractionDialog?.request else { return }
            request.addCompletionHandler { [weak self, weak request] _ in
                if self?.userInteractionDialog?.request === request {
                    self?.userInteractionDialog = nil
                }
            }
        }
    }

    weak private(set) var parentTab: Tab?
    private var _canBeClosedWithBack: Bool
    var canBeClosedWithBack: Bool {
        // Reset canBeClosedWithBack on any WebView navigation
        _canBeClosedWithBack = _canBeClosedWithBack && parentTab != nil && !webView.canGoBack && !webView.canGoForward
        return _canBeClosedWithBack
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
            FileDownloadManager.shared.add(download, delegate: self, location: promptForLocation ? .prompt : .auto, postflight: .none)
        }
    }

    func saveWebContentAs() {
        webView.getMimeType { [weak self] mimeType in
            guard let self else { return }
            let webView = self.webView
            guard case .some(.html) = mimeType.flatMap(UTType.init(mimeType:)) else {
                if let url = webView.url {
                    self.download(from: url, promptForLocation: true)
                }
                return
            }

            let dialog = UserDialogType.savePanel(.init(SavePanelParameters(suggestedFilename: webView.suggestedFilename,
                                                                            fileTypes: [.html, .webArchive, .pdf])) { result in
                guard let (url, fileType) = try? result.get() else { return }
                webView.exportWebContent(to: url, as: fileType.flatMap(WKWebView.ContentExportType.init) ?? .html)
            })
            self.userInteractionDialog = UserDialog(sender: .user, dialog: dialog)
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

        if privatePlayer.goBackSkippingLastItemIfNeeded(for: webView) {
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
        LinkProtection(privacyManager: self.privacyConfigurationManager,
                       contentBlockingManager: self.contentBlockerRulesManager,
                       errorReporting: Self.debugEvents)
    }()
    
    lazy var referrerTrimming: ReferrerTrimming = {
        ReferrerTrimming(privacyManager: self.privacyConfigurationManager,
                         contentBlockingManager: self.contentBlockerRulesManager,
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

            if privatePlayer.goBackAndLoadURLIfNeeded(for: self) {
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

        if privatePlayer.shouldSkipLoadingURL(for: self) {
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
        webView.uiDelegate = self
        webView.contextMenuDelegate = extensions.contextMenu
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        userContentController!.delegate = self
        permissions.webView = webView

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
    let faviconManagement: FaviconManagement

    private func handleFavicon() {
        if content.isPrivatePlayer {
            favicon = .privatePlayer
            return
        }

        guard faviconManagement.areFaviconsLoaded else { return }

        guard content.isUrl, let url = content.url else {
            favicon = nil
            return
        }

        if let cachedFavicon = faviconManagement.getCachedFavicon(for: url, sizeCategory: .small)?.image {
            if cachedFavicon != favicon {
                favicon = cachedFavicon
            }
        } else {
            favicon = nil
        }
    }

    // MARK: - Global & Local History

    private var historyCoordinating: HistoryCoordinating
    private var shouldStoreNextVisit = true
    private(set) var localHistory: Set<String>

    func addVisit(of url: URL) {
        guard shouldStoreNextVisit else {
            shouldStoreNextVisit = true
            return
        }

        // Add to global history
        historyCoordinating.addVisit(of: url)

        // Add to local history
        if let host = url.host, !host.isEmpty {
            localHistory.insert(host.droppingWwwPrefix())
        }
    }

    func updateVisitTitle(_ title: String, url: URL) {
        historyCoordinating.updateTitleIfNeeded(title: title, url: url)
    }

    // MARK: - Youtube Player
    
    private weak var youtubeOverlayScript: YoutubeOverlayUserScript?
    private weak var youtubePlayerScript: YoutubePlayerUserScript?
    private var youtubePlayerCancellables: Set<AnyCancellable> = []

    func setUpYoutubeScriptsIfNeeded() {
        guard privatePlayer.isAvailable else {
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
            privatePlayer.$mode
                .dropFirst()
                .sink { [weak self] playerMode in
                    guard let self = self else {
                        return
                    }
                    let userValues = YoutubeOverlayUserScript.UserValues(
                        privatePlayerMode: playerMode,
                        overlayInteracted: self.privatePlayer.overlayInteracted
                    )
                    self.youtubeOverlayScript?.userValuesUpdated(userValues: userValues, inWebView: self.webView)
                }
                .store(in: &youtubePlayerCancellables)
        }

        if url?.isPrivatePlayerScheme == true {
            youtubePlayerScript?.isEnabled = true

            if canPushMessagesToJS {
                privatePlayer.$mode
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
    @Published private(set) var privacyInfo: PrivacyInfo?
    private var previousPrivacyInfosByURL: [String: PrivacyInfo] = [:]
    private var didGoBackForward: Bool = false

    private func resetDashboardInfo() {
        if let url = content.url {
            if didGoBackForward, let privacyInfo = previousPrivacyInfosByURL[url.absoluteString] {
                self.privacyInfo = privacyInfo
                didGoBackForward = false
            } else {
                privacyInfo = makePrivacyInfo(url: url)
            }
        } else {
            privacyInfo = nil
        }
    }
    
    private func makePrivacyInfo(url: URL) -> PrivacyInfo? {
        guard let host = url.host else { return nil }
        
        let entity = ContentBlocking.shared.trackerDataManager.trackerData.findEntity(forHost: host)
        
        privacyInfo = PrivacyInfo(url: url,
                                  parentEntity: entity,
                                  protectionStatus: makeProtectionStatus(for: host))
        
        previousPrivacyInfosByURL[url.absoluteString] = privacyInfo
        
        return privacyInfo
    }
    
    private func resetConnectionUpgradedTo(navigationAction: WKNavigationAction) {
        let isOnUpgradedPage = navigationAction.request.url == privacyInfo?.connectionUpgradedTo
        if !navigationAction.isTargetingMainFrame || isOnUpgradedPage { return }
        privacyInfo?.connectionUpgradedTo = nil
    }

    private func setConnectionUpgradedTo(_ upgradedUrl: URL, navigationAction: WKNavigationAction) {
        if !navigationAction.isTargetingMainFrame { return }
        privacyInfo?.connectionUpgradedTo = upgradedUrl
    }

    public func setMainFrameConnectionUpgradedTo(_ upgradedUrl: URL?) {
        if upgradedUrl == nil { return }
        privacyInfo?.connectionUpgradedTo = upgradedUrl
    }
    
    private func makeProtectionStatus(for host: String) -> ProtectionStatus {
        let config = ContentBlocking.shared.privacyConfigurationManager.privacyConfig
        
        let isTempUnprotected = config.isTempUnprotected(domain: host)
        let isAllowlisted = config.isUserUnprotected(domain: host)
        
        var enabledFeatures: [String] = []
        
        if !config.isInExceptionList(domain: host, forFeature: .contentBlocking) {
            enabledFeatures.append(PrivacyFeature.contentBlocking.rawValue)
        }
        
        return ProtectionStatus(unprotectedTemporary: isTempUnprotected,
                                enabledFeatures: enabledFeatures,
                                allowlisted: isAllowlisted,
                                denylisted: false)
    }

}

extension Tab: UserContentControllerDelegate {

    func userContentController(_ userContentController: UserContentController, didInstallContentRuleLists contentRuleLists: [String: WKContentRuleList], userScripts: UserScriptsProvider, updateEvent: ContentBlockerRulesManager.UpdateEvent) {
        guard let userScripts = userScripts as? UserScripts else { fatalError("Unexpected UserScripts") }

        userScripts.debugScript.instrumentation = instrumentation
        userScripts.faviconScript.delegate = self
        userScripts.surrogatesScript.delegate = self
        userScripts.contentBlockerRulesScript.delegate = self
        userScripts.clickToLoadScript.delegate = self
        userScripts.pageObserverScript.delegate = self
        userScripts.printingUserScript.delegate = self
        if #available(macOS 11, *) {
            userScripts.autoconsentUserScript?.delegate = self
        }
        youtubeOverlayScript = userScripts.youtubeOverlayScript
        youtubeOverlayScript?.delegate = self
        youtubePlayerScript = userScripts.youtubePlayerUserScript
        setUpYoutubeScriptsIfNeeded()
    }

}

extension Tab: BrowserTabViewControllerClickDelegate {

    func browserTabViewController(_ browserTabViewController: BrowserTabViewController, didClickAtPoint point: NSPoint) {
        clicksSubject.send(point)
    }

}

extension Tab: PageObserverUserScriptDelegate {

    func pageDOMLoaded() {
        self.delegate?.tabPageDOMLoaded(self)
    }

}

extension Tab: FaviconUserScriptDelegate {

    func faviconUserScript(_ faviconUserScript: FaviconUserScript,
                           didFindFaviconLinks faviconLinks: [FaviconUserScript.FaviconLink],
                           for documentUrl: URL) {
        faviconManagement.handleFaviconLinks(faviconLinks, documentUrl: documentUrl) { favicon in
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
        guard let url = webView.url else { return }
        
        privacyInfo?.trackerInfo.addDetectedTracker(tracker, onPageWithURL: url)
        extensions.adClickAttribution?.logic.onRequestDetected(request: tracker)
        historyCoordinating.addDetectedTracker(tracker, onURL: url)
    }

    func contentBlockerRulesUserScript(_ script: ContentBlockerRulesUserScript, detectedThirdPartyRequest request: DetectedRequest) {
        privacyInfo?.trackerInfo.add(detectedThirdPartyRequest: request)
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
        guard let url = webView.url else { return }
        
        privacyInfo?.trackerInfo.addInstalledSurrogateHost(host, for: tracker, onPageWithURL: url)
        privacyInfo?.trackerInfo.addDetectedTracker(tracker, onPageWithURL: url)
        
        historyCoordinating.addDetectedTracker(tracker, onURL: url)
    }
}

extension Tab: WKNavigationDelegate {

    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        webViewDidReceiveChallengePublisher.send()
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic {
            let dialog = UserDialogType.basicAuthenticationChallenge(.init(challenge.protectionSpace) { result in
                let (disposition, credential) = (try? result.get()) ?? (nil, nil)
                completionHandler(disposition ?? .cancelAuthenticationChallenge, credential)
            })
            self.userInteractionDialog = UserDialog(sender: .page(domain: challenge.protectionSpace.host), dialog: dialog)
            return
        }

        completionHandler(.performDefaultHandling, nil)
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        isBeingRedirected = true
        resetDashboardInfo()
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
        static let ddgClientHeaderKey = "X-DuckDuckGo-Client"
        static let ddgClientHeaderValue = "macOS"
    }

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    @MainActor
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {

        if let policy = privatePlayer.decidePolicy(for: navigationAction, in: self) {
            return policy
        }

        if navigationAction.request.url?.isFileURL == true {
            return .allow
        }

        // source frame is actually nullable here so we‘re using #keyPath
        let sourceWebView = navigationAction.value(forKeyPath: #keyPath(WKNavigationAction.sourceFrame.webView)) as? WKWebView
        // temporary hack to check is it the original navigation or redirect
        let isRedirect = navigationAction.value(forKeyPath: "_isRedirect") as? Bool ?? false

        let isLinkActivated = webView === sourceWebView
            && !isRedirect
            && navigationAction.navigationType == .linkActivated

        let isNavigatingAwayFromPinnedTab: Bool = {
            let isNavigatingToAnotherDomain = navigationAction.request.url?.host != url?.host
            let isPinned = pinnedTabsManager.isTabPinned(self)
            return isLinkActivated && isPinned && isNavigatingToAnotherDomain
        }()

        let isMiddleButtonClicked = navigationAction.buttonNumber == Constants.webkitMiddleClick

        // to be modularized later on, see https://app.asana.com/0/0/1203268245242140/f
        let isRequestingNewTab = (isLinkActivated && NSApp.isCommandPressed) || isMiddleButtonClicked || isNavigatingAwayFromPinnedTab
        let shouldSelectNewTab = NSApp.isShiftPressed || (isNavigatingAwayFromPinnedTab && !isMiddleButtonClicked && !NSApp.isCommandPressed)

        didGoBackForward = (navigationAction.navigationType == .backForward)
        
        // This check needs to happen before GPC checks. Otherwise the navigation type may be rewritten to `.other`
        // which would skip link rewrites.
        if navigationAction.navigationType != .backForward {
            let navigationActionPolicy = await linkProtection
                .requestTrackingLinkRewrite(
                    initiatingURL: webView.url,
                    destinationURL: navigationAction.request.url!,
                    onStartExtracting: { if !isRequestingNewTab { isAMPProtectionExtracting = true }},
                    onFinishExtracting: { [weak self] in self?.isAMPProtectionExtracting = false },
                    onLinkRewrite: { [weak self] url in
                        guard let self = self else { return }
                        if isRequestingNewTab || !navigationAction.isTargetingMainFrame {
                            let tab = Tab(content: .url(url), parentTab: self)
                            self.delegate?.tab(self, createdChild: tab, of: .tab(selected: shouldSelectNewTab || !navigationAction.isTargetingMainFrame))
                        } else {
                            webView.load(url)
                        }
                    })
            if let navigationActionPolicy = navigationActionPolicy, navigationActionPolicy == false {
                return .cancel
            }
        }

        webView.customUserAgent = UserAgent.for(navigationAction.request.url)

        if navigationAction.isTargetingMainFrame, navigationAction.request.mainDocumentURL?.host != lastUpgradedURL?.host {
            lastUpgradedURL = nil
        }

        if navigationAction.isTargetingMainFrame, navigationAction.navigationType == .backForward {
            extensions.adClickAttribution?.logic.onBackForwardNavigation(mainFrameURL: webView.url)
        }

        if navigationAction.isTargetingMainFrame, navigationAction.navigationType != .backForward {
            if let newRequest = referrerTrimming.trimReferrer(forNavigation: navigationAction,
                                                              originUrl: webView.url ?? navigationAction.sourceFrame.webView?.url) {
                if isRequestingNewTab {
                    let tab = Tab(content: newRequest.url.map { .contentFromURL($0) } ?? .none, parentTab: self)
                    self.delegate?.tab(self, createdChild: tab, of: .tab(selected: shouldSelectNewTab))
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
                let tab = Tab(content: navigationAction.request.url.map { .contentFromURL($0) } ?? .none, parentTab: self)
                delegate?.tab(self, createdChild: tab, of: .tab(selected: shouldSelectNewTab))
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

            // request if OS can handle extenrnal url
            self.host(webView.url?.host, requestedOpenExternalURL: url)
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
        
        if navigationAction.isTargetingMainFrame,
           navigationAction.request.url?.isDuckDuckGo == true,
           navigationAction.request.value(forHTTPHeaderField: Constants.ddgClientHeaderKey) == nil,
           navigationAction.navigationType != .backForward {
            
            var request = navigationAction.request
            request.setValue(Constants.ddgClientHeaderValue, forHTTPHeaderField: Constants.ddgClientHeaderKey)
            _ = webView.load(request)
            return .cancel
        }

        toggleFBProtection(for: url)
        willPerformNavigationAction(navigationAction)

        return .allow
    }

    private func host(_ host: String?, requestedOpenExternalURL url: URL) {
        let searchForExternalUrl = { [weak self] in
            // Redirect after handing WebView.url update after cancelling the request
            DispatchQueue.main.async {
                guard let self, let url = URL.makeSearchUrl(from: url.absoluteString) else { return }
                self.update(url: url)
            }
        }

        guard self.delegate?.tab(self, requestedOpenExternalURL: url, forUserEnteredURL: userEnteredUrl) == true else {
            // search if external URL can‘t be opened but entered by user
            if userEnteredUrl {
                searchForExternalUrl()
            }
            return
        }

        let permissionType = PermissionType.externalScheme(scheme: url.scheme ?? "")

        permissions.permissions([permissionType], requestedForDomain: host, url: url) { [weak self, userEnteredUrl] granted in
            guard granted, let self else {
                // search if denied but entered by user
                if userEnteredUrl {
                    searchForExternalUrl()
                }
                return
            }
            // handle opening extenral URL
            NSWorkspace.shared.open(url)
            self.permissions.permissions[permissionType].externalSchemeOpened()
        }
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
            cbaTimeReporter?.tabWillWaitForRulesCompilation(self.instrumentation.currentTabIdentifier)
            await userContentController?.awaitContentBlockingAssetsInstalled()
            cbaTimeReporter?.reportWaitTimeForTabFinishedWaitingForRules(self.instrumentation.currentTabIdentifier)
        } else {
            cbaTimeReporter?.reportNavigationDidNotWaitForRules()
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
            extensions.adClickAttribution?.detection.on2XXResponse(url: webView.url)
        }
        
        await extensions.adClickAttribution?.logic.onProvisionalNavigation()

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
        extensions.adClickAttribution?.detection.onStartNavigation(url: webView.url)
    }

    @MainActor
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isBeingRedirected = false
        invalidateSessionStateData()
        webViewDidFinishNavigationPublisher.send()
        if isAMPProtectionExtracting { isAMPProtectionExtracting = false }
        linkProtection.setMainFrameUrl(nil)
        referrerTrimming.onFinishNavigation()
        extensions.adClickAttribution?.detection.onDidFinishNavigation(url: webView.url)
        extensions.adClickAttribution?.logic.onDidFinishNavigation(host: webView.url?.host)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Failing not captured. Seems the method is called after calling the webview's method goBack()
        // https://app.asana.com/0/1199230911884351/1200381133504356/f
        //        hasError = true

        isBeingRedirected = false
        invalidateSessionStateData()
        linkProtection.setMainFrameUrl(nil)
        referrerTrimming.onFailedNavigation()
        extensions.adClickAttribution?.detection.onDidFailNavigation()
        webViewDidFailNavigationPublisher.send()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        switch error {
        case URLError.notConnectedToInternet,
             URLError.networkConnectionLost:
            guard let failingUrl = error.failingUrl else { break }
            historyCoordinating.markFailedToLoadUrl(failingUrl)
        default: break
        }

        self.error = error
        isBeingRedirected = false
        linkProtection.setMainFrameUrl(nil)
        referrerTrimming.onFailedNavigation()
        extensions.adClickAttribution?.detection.onDidFailNavigation()
        webViewDidFailNavigationPublisher.send()
    }

    @available(macOS 11.3, *) // objc doesn‘t care about availability
    @objc(webView:navigationAction:didBecomeDownload:)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        FileDownloadManager.shared.add(download, delegate: self, location: .auto, postflight: .none)
    }

    @available(macOS 11.3, *) // objc doesn‘t care about availability
    @objc(webView:navigationResponse:didBecomeDownload:)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        FileDownloadManager.shared.add(download, delegate: self, location: .auto, postflight: .none)

        // Note this can result in tabs being left open, e.g. download button on this page:
        // https://en.wikipedia.org/wiki/Guitar#/media/File:GuitareClassique5.png
        // Safari closes new tabs that were opened and then create a download instantly.
        if self.webView.backForwardList.currentItem == nil,
           self.parentTab != nil {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.closeTab(self!)
            }
        }
    }

    @objc(_webView:didStartProvisionalLoadWithRequest:inFrame:)
    func webView(_ webView: WKWebView, didStartProvisionalLoadWithRequest request: URLRequest, in frame: WKFrameInfo) {
        guard frame.isMainFrame else { return }
        self.mainFrameLoadState = .provisional
    }

    @objc(_webView:didCommitLoadWithRequest:inFrame:)
    func webView(_ webView: WKWebView, didCommitLoadWithRequest request: URLRequest, in frame: WKFrameInfo) {
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
    func webView(_ webView: WKWebView, didFinishLoadWithRequest request: URLRequest, in frame: WKFrameInfo) {
        guard frame.isMainFrame else { return }
        self.mainFrameLoadState = .finished

        StatisticsLoader.shared.refreshRetentionAtb(isSearch: request.url?.isDuckDuckGoSearch == true)
    }

    @objc(_webView:didFailProvisionalLoadWithRequest:inFrame:withError:)
    func webView(_ webView: WKWebView,
                 didFailProvisionalLoadWithRequest request: URLRequest,
                 in frame: WKFrameInfo,
                 withError error: Error) {
        guard frame.isMainFrame else { return }
        self.mainFrameLoadState = .finished
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Pixel.fire(.debug(event: .webKitDidTerminate))
    }

    @objc(_webView:contextMenuDidCreateDownload:)
    func webView(_ webView: WKWebView, contextMenuDidCreate download: WebKitDownload) {
        let location: FileDownloadManager.DownloadLocationPreference
            = extensions.contextMenu?.shouldAskForDownloadLocation() == false ? .auto : .prompt
        FileDownloadManager.shared.add(download, delegate: self, location: location, postflight: .none)
    }

}

extension Tab: FileDownloadManagerDelegate {

    func chooseDestination(suggestedFilename: String?, directoryURL: URL?, fileTypes: [UTType], callback: @escaping (URL?, UTType?) -> Void) {
        let dialog = UserDialogType.savePanel(.init(SavePanelParameters(suggestedFilename: suggestedFilename,
                                                                        fileTypes: fileTypes)) { result in
            guard case let .success(.some( (url: url, fileType: fileType) )) = result else {
                callback(nil, nil)
                return
            }
            callback(url, fileType)
        })
        userInteractionDialog = UserDialog(sender: .user, dialog: dialog)
    }

    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect? {
        self.delegate?.fileIconFlyAnimationOriginalRect(for: downloadTask)
    }

}

fileprivate extension WKNavigationResponse {
    var shouldDownload: Bool {
        let contentDisposition = (response as? HTTPURLResponse)?.allHeaderFields["Content-Disposition"] as? String
        return contentDisposition?.hasPrefix("attachment") ?? false
    }
}

@available(macOS 11, *)
extension Tab: AutoconsentUserScriptDelegate {
    func autoconsentUserScript(consentStatus: CookieConsentInfo) {
        self.privacyInfo?.cookieConsentManaged = consentStatus
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
            let tab = Tab(content: content, parentTab: self)
            self.delegate?.tab(self, createdChild: tab, of: .tab(selected: shouldSelectNewTab))
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
