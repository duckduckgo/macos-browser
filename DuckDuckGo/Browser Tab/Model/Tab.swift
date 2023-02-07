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
import Navigation
import TrackerRadarKit
import ContentBlocking
import UserScript
import Common
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
@dynamicMemberLookup
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
    private struct ExtensionDependencies: TabExtensionDependencies {
        let privacyFeatures: PrivacyFeaturesProtocol
        let historyCoordinating: HistoryCoordinating
    }

    fileprivate weak var delegate: TabDelegate?
    func setDelegate(_ delegate: TabDelegate) { self.delegate = delegate }

    private let navigationDelegate = DistributedNavigationDelegate(logger: .navigation)

    private let cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?
    private let statisticsLoader: StatisticsLoader?
    let pinnedTabsManager: PinnedTabsManager
    private let privatePlayer: PrivatePlayer
    private let privacyFeatures: AnyPrivacyFeatures
    private var contentBlocking: AnyContentBlocking { privacyFeatures.contentBlocking }

    private let webViewConfiguration: WKWebViewConfiguration

    private var extensions: TabExtensions
    // accesing TabExtensions‘ Public Protocols projecting tab.extensions.extensionName to tab.extensionName
    // allows extending Tab functionality while maintaining encapsulation
    subscript<Extension>(dynamicMember keyPath: KeyPath<TabExtensions, Extension?>) -> Extension? {
        self.extensions[keyPath: keyPath]
    }

    @Published
    private(set) var userContentController: UserContentController?

    convenience init(content: TabContent,
                     faviconManagement: FaviconManagement = FaviconManager.shared,
                     webCacheManager: WebCacheManager = WebCacheManager.shared,
                     webViewConfiguration: WKWebViewConfiguration? = nil,
                     historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
                     pinnedTabsManager: PinnedTabsManager = WindowControllersManager.shared.pinnedTabsManager,
                     privatePlayer: PrivatePlayer? = nil,
                     cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter? = ContentBlockingAssetsCompilationTimeReporter.shared,
                     statisticsLoader: StatisticsLoader? = nil,
                     extensionsBuilder: TabExtensionsBuilderProtocol = TabExtensionsBuilder.default,
                     localHistory: Set<String> = Set<String>(),
                     title: String? = nil,
                     favicon: NSImage? = nil,
                     interactionStateData: Data? = nil,
                     parentTab: Tab? = nil,
                     shouldLoadInBackground: Bool = false,
                     canBeClosedWithBack: Bool = false,
                     lastSelectedAt: Date? = nil,
                     currentDownload: URL? = nil,
                     webViewFrame: CGRect = .zero
    ) {

        let privatePlayer = privatePlayer
            ?? (AppDelegate.isRunningTests ? PrivatePlayer.mock(withMode: .enabled) : PrivatePlayer.shared)
        let statisticsLoader = statisticsLoader
            ?? (AppDelegate.isRunningTests ? nil : StatisticsLoader.shared)

        self.init(content: content,
                  faviconManagement: faviconManagement,
                  webCacheManager: webCacheManager,
                  webViewConfiguration: webViewConfiguration,
                  historyCoordinating: historyCoordinating,
                  pinnedTabsManager: pinnedTabsManager,
                  privacyFeatures: PrivacyFeatures,
                  privatePlayer: privatePlayer,
                  extensionsBuilder: extensionsBuilder,
                  cbaTimeReporter: cbaTimeReporter,
                  statisticsLoader: statisticsLoader,
                  localHistory: localHistory,
                  title: title,
                  favicon: favicon,
                  interactionStateData: interactionStateData,
                  parentTab: parentTab,
                  shouldLoadInBackground: shouldLoadInBackground,
                  canBeClosedWithBack: canBeClosedWithBack,
                  lastSelectedAt: lastSelectedAt,
                  currentDownload: currentDownload,
                  webViewFrame: webViewFrame)
    }

    // swiftlint:disable:next function_body_length
    init(content: TabContent,
         faviconManagement: FaviconManagement,
         webCacheManager: WebCacheManager,
         webViewConfiguration: WKWebViewConfiguration?,
         historyCoordinating: HistoryCoordinating,
         pinnedTabsManager: PinnedTabsManager,
         privacyFeatures: some PrivacyFeaturesProtocol,
         privatePlayer: PrivatePlayer,
         extensionsBuilder: TabExtensionsBuilderProtocol,
         cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?,
         statisticsLoader: StatisticsLoader?,
         localHistory: Set<String>,
         title: String?,
         favicon: NSImage?,
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
        self.privacyFeatures = privacyFeatures
        self.privatePlayer = privatePlayer
        self.cbaTimeReporter = cbaTimeReporter
        self.statisticsLoader = statisticsLoader
        self.localHistory = localHistory
        self.title = title
        self.favicon = favicon
        self.parentTab = parentTab
        self._canBeClosedWithBack = canBeClosedWithBack
        self.interactionStateData = interactionStateData
        self.lastSelectedAt = lastSelectedAt
        self.currentDownload = currentDownload

        let configuration = webViewConfiguration ?? WKWebViewConfiguration()
        configuration.applyStandardConfiguration(contentBlocking: privacyFeatures.contentBlocking)
        self.webViewConfiguration = configuration
        let userContentController = configuration.userContentController as? UserContentController
        assert(userContentController != nil)
        self.userContentController = userContentController

        webView = WebView(frame: webViewFrame, configuration: configuration)
        webView.allowsLinkPreview = false
        permissions = PermissionModel()

        let userScriptsPublisher = _userContentController.projectedValue
            .compactMap { $0?.$contentBlockingAssets }
            .switchToLatest()
            .map { $0?.userScripts as? UserScripts }
            .eraseToAnyPublisher()

        var userContentControllerProvider: UserContentControllerProvider?
        self.extensions = extensionsBuilder
            .build(with: (tabIdentifier: instrumentation.currentTabIdentifier,
                          userScriptsPublisher: userScriptsPublisher,
                          inheritedAttribution: parentTab?.adClickAttribution?.currentAttributionState,
                          userContentControllerProvider: {  userContentControllerProvider?() },
                          permissionModel: permissions,
                          privacyInfoPublisher: _privacyInfo.projectedValue.eraseToAnyPublisher()
                         ),
                   dependencies: ExtensionDependencies(privacyFeatures: privacyFeatures,
                                                       historyCoordinating: historyCoordinating))

        super.init()

        userContentControllerProvider = { [weak self] in self?.userContentController }

        setupNavigationDelegate()
        userContentController?.delegate = self
        setupWebView(shouldLoadInBackground: shouldLoadInBackground)

        if favicon == nil {
            handleFavicon()
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onDuckDuckGoEmailSignOut),
                                               name: .emailDidSignOut,
                                               object: nil)
    }

    override func awakeAfter(using decoder: NSCoder) -> Any? {
        for tabExtension in self.extensions {
            (tabExtension as? (any NSCodingExtension))?.awakeAfter(using: decoder)
        }
        return self
    }

    func encodeExtensions(with coder: NSCoder) {
        for tabExtension in self.extensions {
            (tabExtension as? (any NSCodingExtension))?.encode(using: coder)
        }
    }

    func openChild(with content: TabContent, of kind: NewWindowPolicy) {
        guard let delegate else {
            assertionFailure("no delegate set")
            return
        }
        let tab = Tab(content: content, parentTab: self, shouldLoadInBackground: true, canBeClosedWithBack: kind.isSelectedTab)
        delegate.tab(self, createdChild: tab, of: kind)
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

#if DEBUG
    var shouldDisableLongDecisionMakingChecks: Bool = false
#endif

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

    @Published private(set) var content: TabContent {
        didSet {
            handleFavicon()
            invalidateInteractionStateData()
            if let oldUrl = oldValue.url {
                historyCoordinating.commitChanges(url: oldUrl)
            }
            error = nil
            userInteractionDialog = nil
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
    @PublishedAfter var error: WKError? {
        didSet {
            switch error {
            case .some(URLError.notConnectedToInternet),
                 .some(URLError.networkConnectionLost):
                guard let failingUrl = error?.failingUrl else { break }
                historyCoordinating.markFailedToLoadUrl(failingUrl)
            default:
                break
            }
        }
    }
    let permissions: PermissionModel

    /// an Interactive Dialog request (alert/open/save/print) made by a page to be published and presented asynchronously
    @Published
    var userInteractionDialog: UserDialog? {
        didSet {
            guard let request = userInteractionDialog?.request else { return }
            request.addCompletionHandler { [weak self, weak request] _ in
                if let self, let request, self.userInteractionDialog?.request === request {
                    self.userInteractionDialog = nil
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

    var interactionStateData: Data?

    func invalidateInteractionStateData() {
        interactionStateData = nil
    }

    func getActualInteractionStateData() -> Data? {
        if let interactionStateData = interactionStateData {
            return interactionStateData
        }

        guard webView.url != nil else { return nil }

        if #available(macOS 12.0, *) {
            self.interactionStateData = (webView.interactionState as? Data)
        } else {
            self.interactionStateData = try? webView.sessionStateData()
        }

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
    private var externalSchemeOpenedPerPageLoad = false

    @Published private(set) var canGoForward: Bool = false
    @Published private(set) var canGoBack: Bool = false

    @MainActor(unsafe)
    private func updateCanGoBackForward(withCurrentNavigation currentNavigation: Navigation? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))
        let currentNavigation = currentNavigation ?? navigationDelegate.currentNavigation

        // “freeze” back-forward buttons updates when current backForwardListItem is being popped..
        if webView.backForwardList.currentItem?.identity == currentNavigation?.navigationAction.fromHistoryItemIdentity
            // ..or during the following developer-redirect navigation
            || currentNavigation?.navigationAction.navigationType == .redirect(.developer) {
            return
        }

        let canGoBack = webView.canGoBack || self.error != nil
        let canGoForward = webView.canGoForward && self.error == nil

        if canGoBack != self.canGoBack {
            self.canGoBack = canGoBack
        }
        if canGoForward != self.canGoForward {
            self.canGoForward = canGoForward
        }
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
        userInteractionDialog = nil
        webView.goBack()
    }

    func goForward() {
        guard canGoForward else { return }
        shouldStoreNextVisit = false
        webView.goForward()
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
        userInteractionDialog = nil
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
        LinkProtection(privacyManager: contentBlocking.privacyConfigurationManager,
                       contentBlockingManager: contentBlocking.contentBlockingManager,
                       errorReporting: Self.debugEvents)
    }()

    lazy var referrerTrimming: ReferrerTrimming = {
        ReferrerTrimming(privacyManager: contentBlocking.privacyConfigurationManager,
                         contentBlockingManager: contentBlocking.contentBlockingManager,
                         tld: contentBlocking.tld)
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
            let didRestore = restoreInteractionStateDataIfNeeded()

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
    private func restoreInteractionStateDataIfNeeded() -> Bool {
        var didRestore: Bool = false
        if let interactionStateData = self.interactionStateData {
            if contentURL.isFileURL {
                _ = webView.loadFileURL(contentURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
            }

            if #available(macOS 12.0, *) {
                webView.interactionState = interactionStateData
                didRestore = true
            } else {
                do {
                    try webView.restoreSessionState(from: interactionStateData)
                    didRestore = true
                } catch {
                    os_log("Tab:setupWebView could not restore session state %s", "\(error)")
                }
            }
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

    private var webViewCancellables = Set<AnyCancellable>()

    private func setupWebView(shouldLoadInBackground: Bool) {
        webView.navigationDelegate = navigationDelegate
        webView.uiDelegate = self
        webView.contextMenuDelegate = self.contextMenuManager
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

        permissions.webView = webView

        webViewCancellables.removeAll()

        webView.observe(\.superview, options: .old) { [weak self] _, change in
            // if the webView is being added to superview - reload if needed
            if case .some(.none) = change.oldValue {
                Task { @MainActor [weak self] in
                    await self?.reloadIfNeeded()
                }
            }
        }.store(in: &webViewCancellables)

        webView.observe(\.canGoBack) { [weak self] _, _ in
            self?.updateCanGoBackForward()
        }.store(in: &webViewCancellables)

        webView.observe(\.canGoForward) { [weak self] _, _ in
            self?.updateCanGoBackForward()
        }.store(in: &webViewCancellables)

        navigationDelegate.$currentNavigation.sink { [weak self] navigation in
            self?.updateCanGoBackForward(withCurrentNavigation: navigation)
        }.store(in: &webViewCancellables)

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

        let entity = contentBlocking.trackerDataManager.trackerData.findEntity(forHost: host)

        privacyInfo = PrivacyInfo(url: url,
                                  parentEntity: entity,
                                  protectionStatus: makeProtectionStatus(for: host))

        previousPrivacyInfosByURL[url.absoluteString] = privacyInfo

        return privacyInfo
    }

    private func resetConnectionUpgradedTo(navigationAction: NavigationAction) {
        let isOnUpgradedPage = navigationAction.url == privacyInfo?.connectionUpgradedTo
        if navigationAction.isForMainFrame && !isOnUpgradedPage {
            privacyInfo?.connectionUpgradedTo = nil
        }
    }

    public func setMainFrameConnectionUpgradedTo(_ upgradedUrl: URL?) {
        guard let upgradedUrl else { return }
        privacyInfo?.connectionUpgradedTo = upgradedUrl
    }

    private func makeProtectionStatus(for host: String) -> ProtectionStatus {
        let config = contentBlocking.privacyConfigurationManager.privacyConfig

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
        guard let url = URL(string: tracker.pageUrl) else { return }

        privacyInfo?.trackerInfo.addDetectedTracker(tracker, onPageWithURL: url)
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

extension Tab/*: NavigationResponder*/ { // to be moved to Tab+Navigation.swift

    @MainActor
    func didReceive(_ challenge: URLAuthenticationChallenge, for navigation: Navigation?) async -> AuthChallengeDisposition? {
        webViewDidReceiveChallengePublisher.send()

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic else { return nil }

        let (request, future) = BasicAuthDialogRequest.future(with: challenge.protectionSpace)
        self.userInteractionDialog = UserDialog(sender: .page(domain: challenge.protectionSpace.host), dialog: .basicAuthenticationChallenge(request))
        do {
            return try await future.get()
        } catch {
            return .cancel
        }
    }

    @MainActor
    func didCommit(_ navigation: Navigation) {
        if content.isUrl, navigation.url == content.url {
            addVisit(of: navigation.url)
        }
        webViewDidCommitNavigationPublisher.send()
    }

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        preferences.userAgent = UserAgent.for(navigationAction.url)

        if let policy = privatePlayer.decidePolicy(for: navigationAction, in: self) {
            return policy
        }

        if navigationAction.url.isFileURL {
            return .allow
        }

        let isLinkActivated = !navigationAction.isTargetingNewWindow
            && navigationAction.navigationType.isLinkActivated

        let isNavigatingAwayFromPinnedTab: Bool = {
            let isNavigatingToAnotherDomain = navigationAction.url.host != url?.host
            let isPinned = pinnedTabsManager.isTabPinned(self)
            return isLinkActivated && isPinned && isNavigatingToAnotherDomain && navigationAction.isForMainFrame
        }()

        // to be modularized later on, see https://app.asana.com/0/0/1203268245242140/f
        let isRequestingNewTab = (isLinkActivated && NSApp.isCommandPressed) || navigationAction.navigationType.isMiddleButtonClick || isNavigatingAwayFromPinnedTab
        let shouldSelectNewTab = NSApp.isShiftPressed || (isNavigatingAwayFromPinnedTab && !navigationAction.navigationType.isMiddleButtonClick && !NSApp.isCommandPressed)

        didGoBackForward = navigationAction.navigationType.isBackForward

        // This check needs to happen before GPC checks. Otherwise the navigation type may be rewritten to `.other`
        // which would skip link rewrites.
        if !navigationAction.navigationType.isBackForward {
            let navigationActionPolicy = await linkProtection
                .requestTrackingLinkRewrite(
                    initiatingURL: webView.url,
                    destinationURL: navigationAction.url,
                    onStartExtracting: { if !isRequestingNewTab { isAMPProtectionExtracting = true }},
                    onFinishExtracting: { [weak self] in self?.isAMPProtectionExtracting = false },
                    onLinkRewrite: { [weak self] url in
                        guard let self = self else { return }
                        if isRequestingNewTab || !navigationAction.isForMainFrame {
                            self.openChild(with: .url(url), of: .tab(selected: shouldSelectNewTab || !navigationAction.isForMainFrame))
                        } else {
                            self.webView.load(url)
                        }
                    })
            if let navigationActionPolicy = navigationActionPolicy, navigationActionPolicy == false {
                return .cancel
            }
        }

        if navigationAction.isForMainFrame, navigationAction.request.mainDocumentURL?.host != lastUpgradedURL?.host {
            lastUpgradedURL = nil
        }

        if navigationAction.isForMainFrame, !navigationAction.navigationType.isBackForward {
            if let newRequest = referrerTrimming.trimReferrer(for: navigationAction.request, originUrl: navigationAction.sourceFrame.url) {
                if isRequestingNewTab {
                    self.openChild(with: newRequest.url.map { .contentFromURL($0) } ?? .none, of: .tab(selected: shouldSelectNewTab))
                } else {
                    _ = webView.load(newRequest)
                }
                return .cancel
            }
        }

        if navigationAction.isForMainFrame,
           !navigationAction.navigationType.isBackForward,
           !isRequestingNewTab,
           let request = GPCRequestFactory().requestForGPC(basedOn: navigationAction.request,
                                                           config: contentBlocking.privacyConfigurationManager.privacyConfig,
                                                           gpcEnabled: PrivacySecurityPreferences.shared.gpcEnabled) {

            return .redirect(navigationAction, invalidatingBackItemIfNeededFor: webView) {
                $0.load(request)
            }
        }

        if navigationAction.isForMainFrame,
           navigationAction.url != currentDownload || navigationAction.isUserInitiated {
            currentDownload = nil
        }

        self.resetConnectionUpgradedTo(navigationAction: navigationAction)

        if isRequestingNewTab {
            self.openChild(with: .contentFromURL(navigationAction.url), of: .tab(selected: shouldSelectNewTab))
            return .cancel

        } else if navigationAction.shouldDownload
                    || (isLinkActivated && NSApp.isOptionPressed && !NSApp.isCommandPressed) {
            // register the navigationAction for legacy _WKDownload to be called back on the Tab
            // further download will be passed to webView:navigationAction:didBecomeDownload:
            return .download(navigationAction.url, using: webView) { [weak self] download in
                self?.navigationAction(navigationAction, didBecome: download)
            }
        }

        guard navigationAction.url.scheme != nil else { return .allow }

        if navigationAction.url.isExternalSchemeLink {
            // request if OS can handle extenrnal url
            self.host(webView.url?.host, requestedOpenExternalURL: navigationAction.url)
            return .cancel
        }

        if navigationAction.isForMainFrame,
           case .success(let upgradedURL) = await privacyFeatures.httpsUpgrade.upgrade(url: navigationAction.url) {

            if lastUpgradedURL != upgradedURL {
                urlDidUpgrade(to: upgradedURL)
                return .redirect(navigationAction, invalidatingBackItemIfNeededFor: webView) {
                    $0.load(URLRequest(url: upgradedURL))
                }
            }
        }

        if !navigationAction.url.isDuckDuckGo {
            await prepareForContentBlocking()
        }

        toggleFBProtection(for: navigationAction.url)

        return .next
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

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

    private func urlDidUpgrade(to upgradedUrl: URL) {
        lastUpgradedURL = upgradedUrl
        privacyInfo?.connectionUpgradedTo = upgradedUrl
    }

    @MainActor
    private func prepareForContentBlocking() async {
        // Ensure Content Blocking Assets (WKContentRuleList&UserScripts) are installed
        if userContentController?.contentBlockingAssetsInstalled == false
           && contentBlocking.privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking) {
            cbaTimeReporter?.tabWillWaitForRulesCompilation(self.instrumentation.currentTabIdentifier)
#if DEBUG
            shouldDisableLongDecisionMakingChecks = true
            defer { // swiftlint:disable:this inert_defer
                shouldDisableLongDecisionMakingChecks = false
            }
#endif

            await userContentController?.awaitContentBlockingAssetsInstalled()
            cbaTimeReporter?.reportWaitTimeForTabFinishedWaitingForRules(self.instrumentation.currentTabIdentifier)
        } else {
            cbaTimeReporter?.reportNavigationDidNotWaitForRules()
        }
    }

    private func toggleFBProtection(for url: URL) {
        // Enable/disable FBProtection only after UserScripts are installed (awaitContentBlockingAssetsInstalled)
        let privacyConfiguration = contentBlocking.privacyConfigurationManager.privacyConfig

        let featureEnabled = privacyConfiguration.isFeature(.clickToPlay, enabledForDomain: url.host)
        setFBProtection(enabled: featureEnabled)
    }

    @MainActor
    func willStart(_ navigation: Navigation) {
        if error != nil { error = nil }

        externalSchemeOpenedPerPageLoad = false
        delegate?.tabWillStartNavigation(self, isUserInitiated: navigation.navigationAction.isUserInitiated)

        if navigation.navigationAction.navigationType.isRedirect {
            resetDashboardInfo()
        }
    }

    @MainActor
    func decidePolicy(for navigationResponse: NavigationResponse) async -> NavigationResponsePolicy? {
        userEnteredUrl = false // subsequent requests will be navigations

        if !navigationResponse.canShowMIMEType || navigationResponse.shouldDownload {
            if navigationResponse.isForMainFrame {
                guard currentDownload != navigationResponse.url else {
                    // prevent download twice
                    return .cancel
                }
                currentDownload = navigationResponse.url
            }

            if navigationResponse.isSuccessful == true {
                // register the navigationResponse for legacy _WKDownload to be called back on the Tab
                // further download will be passed to webView:navigationResponse:didBecomeDownload:
                return .download(navigationResponse.url, using: webView) {  [weak self] download in
                    self?.navigationResponse(navigationResponse, didBecome: download)
                }
            }
        }

        return .next
    }

    @MainActor
    func didStart(_ navigation: Navigation) {
        delegate?.tabDidStartNavigation(self)
        userInteractionDialog = nil

        // Unnecessary assignment triggers publishing
        if error != nil { error = nil }

        invalidateInteractionStateData()
        resetDashboardInfo()
        linkProtection.cancelOngoingExtraction()
        linkProtection.setMainFrameUrl(navigation.url)
        referrerTrimming.onBeginNavigation(to: navigation.url)
    }

    @MainActor
    func navigationDidFinish(_ navigation: Navigation) {
        invalidateInteractionStateData()
        webViewDidFinishNavigationPublisher.send()
        if isAMPProtectionExtracting { isAMPProtectionExtracting = false }
        linkProtection.setMainFrameUrl(nil)
        referrerTrimming.onFinishNavigation()
        setUpYoutubeScriptsIfNeeded()
        statisticsLoader?.refreshRetentionAtb(isSearch: navigation.url.isDuckDuckGoSearch)

        if navigation.isCurrent {
            // Clear “frozen” back-forward buttons state on new navigation after upgrading to HTTPS or GPC from Client Redirect
            webView.frozenCanGoForward = nil
            webView.frozenCanGoBack = nil
        }
    }

    @MainActor
    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        if navigation.isCurrent {
            self.error = error
        }

        invalidateInteractionStateData()
        linkProtection.setMainFrameUrl(nil)
        referrerTrimming.onFailedNavigation()
        webViewDidFailNavigationPublisher.send()

        if navigation.isCurrent {
            // Clear “frozen” back-forward buttons state on new navigation after upgrading to HTTPS or GPC from Client Redirect
            webView.frozenCanGoForward = nil
            webView.frozenCanGoBack = nil
        }
    }

    @MainActor
    func navigationAction(_ navigationAction: NavigationAction, didBecome download: WebKitDownload) {
        FileDownloadManager.shared.add(download, delegate: self, location: .auto, postflight: .none)
    }

    @MainActor
    func navigationResponse(_ navigationResponse: NavigationResponse, didBecome download: WebKitDownload) {
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

    func webContentProcessDidTerminate(with reason: WKProcessTerminationReason?) {
        Pixel.fire(.debug(event: .webKitDidTerminate, error: NSError(domain: "WKProcessTerminated", code: reason?.rawValue ?? -1)))
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
            self.openChild(with: content, of: .tab(selected: shouldSelectNewTab))
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

// "protected" properties meant to access otherwise private properties from Tab extensions
extension Tab {

    static var objcDelegateKeyPath: String { #keyPath(objcDelegate) }
    @objc private var objcDelegate: Any? { delegate }

    static var objcNavigationDelegateKeyPath: String { #keyPath(objcNavigationDelegate) }
    @objc private var objcNavigationDelegate: Any? { navigationDelegate }

}
