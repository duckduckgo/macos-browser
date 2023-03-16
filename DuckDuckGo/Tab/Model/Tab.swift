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

import BrowserServicesKit
import Combine
import Common
import ContentBlocking
import Foundation
import Navigation
import os.log
import TrackerRadarKit
import UserScript
import WebKit

protocol TabDelegate: ContentOverlayUserScriptDelegate {
    func tabWillStartNavigation(_ tab: Tab, isUserInitiated: Bool)
    func tabDidStartNavigation(_ tab: Tab)
    func tab(_ tab: Tab, createdChild childTab: Tab, of kind: NewWindowPolicy)

    func tabPageDOMLoaded(_ tab: Tab)
    func closeTab(_ tab: Tab)

}

// swiftlint:disable type_body_length
@dynamicMemberLookup
final class Tab: NSObject, Identifiable, ObservableObject {

    enum TabContent: Equatable {
        case homePage
        case url(URL, credential: URLCredential? = nil, userEntered: Bool = false)
        case privatePlayer(videoID: String, timestamp: String?)
        case preferences(pane: PreferencePaneIdentifier?)
        case bookmarks
        case onboarding
        case none

        static func contentFromURL(_ url: URL?, userEntered: Bool = false) -> TabContent {
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
            } else if let url, let credential = url.basicAuthCredential {
                // when navigating to a URL with basic auth username/password, cache it and redirect to a trimmed URL
                return .url(url.removingBasicAuthCredential(), credential: credential, userEntered: userEntered)
            } else {
                return .url(url ?? .blankPage, userEntered: userEntered)
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
            case .url(let url, credential: _, userEntered: _):
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

        var isUserEnteredUrl: Bool {
            switch self {
            case .url(_, credential: _, userEntered: let userEntered):
                return userEntered
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
        var workspace: Workspace
        var cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?
        var downloadManager: FileDownloadManagerProtocol
    }

    fileprivate weak var delegate: TabDelegate?
    func setDelegate(_ delegate: TabDelegate) { self.delegate = delegate }

    private let navigationDelegate = DistributedNavigationDelegate(logger: .navigation)

    private let statisticsLoader: StatisticsLoader?
    private let internalUserDecider: InternalUserDeciding?
    let pinnedTabsManager: PinnedTabsManager
    private let privatePlayer: PrivatePlayer
    private let privacyFeatures: AnyPrivacyFeatures
    private var contentBlocking: AnyContentBlocking { privacyFeatures.contentBlocking }

    // to be wiped out later
    private var detectedTrackersCancellables: AnyCancellable?

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
                     workspace: Workspace = NSWorkspace.shared,
                     privacyFeatures: AnyPrivacyFeatures? = nil,
                     privatePlayer: PrivatePlayer? = nil,
                     downloadManager: FileDownloadManagerProtocol = FileDownloadManager.shared,
                     permissionManager: PermissionManagerProtocol = PermissionManager.shared,
                     geolocationService: GeolocationServiceProtocol = GeolocationService.shared,
                     cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter? = ContentBlockingAssetsCompilationTimeReporter.shared,
                     statisticsLoader: StatisticsLoader? = nil,
                     extensionsBuilder: TabExtensionsBuilderProtocol = TabExtensionsBuilder.default,
                     localHistory: Set<String> = Set<String>(),
                     title: String? = nil,
                     favicon: NSImage? = nil,
                     interactionStateData: Data? = nil,
                     parentTab: Tab? = nil,
                     shouldLoadInBackground: Bool = false,
                     shouldLoadFromCache: Bool = false,
                     canBeClosedWithBack: Bool = false,
                     lastSelectedAt: Date? = nil,
                     webViewFrame: CGRect = .zero
    ) {

        let privatePlayer = privatePlayer
            ?? (NSApp.isRunningUnitTests ? PrivatePlayer.mock(withMode: .enabled) : PrivatePlayer.shared)
        let statisticsLoader = statisticsLoader
            ?? (NSApp.isRunningUnitTests ? nil : StatisticsLoader.shared)
        let privacyFeatures = privacyFeatures ?? PrivacyFeatures
        let internalUserDecider = (NSApp.delegate as? AppDelegate)?.internalUserDecider

        self.init(content: content,
                  faviconManagement: faviconManagement,
                  webCacheManager: webCacheManager,
                  webViewConfiguration: webViewConfiguration,
                  historyCoordinating: historyCoordinating,
                  pinnedTabsManager: pinnedTabsManager,
                  workspace: workspace,
                  privacyFeatures: privacyFeatures,
                  privatePlayer: privatePlayer,
                  downloadManager: downloadManager,
                  permissionManager: permissionManager,
                  geolocationService: geolocationService,
                  extensionsBuilder: extensionsBuilder,
                  cbaTimeReporter: cbaTimeReporter,
                  statisticsLoader: statisticsLoader,
                  internalUserDecider: internalUserDecider,
                  localHistory: localHistory,
                  title: title,
                  favicon: favicon,
                  interactionStateData: interactionStateData,
                  parentTab: parentTab,
                  shouldLoadInBackground: shouldLoadInBackground,
                  shouldLoadFromCache: shouldLoadFromCache,
                  canBeClosedWithBack: canBeClosedWithBack,
                  lastSelectedAt: lastSelectedAt,
                  webViewFrame: webViewFrame)
    }

    // swiftlint:disable:next function_body_length
    init(content: TabContent,
         faviconManagement: FaviconManagement,
         webCacheManager: WebCacheManager,
         webViewConfiguration: WKWebViewConfiguration?,
         historyCoordinating: HistoryCoordinating,
         pinnedTabsManager: PinnedTabsManager,
         workspace: Workspace,
         privacyFeatures: AnyPrivacyFeatures,
         privatePlayer: PrivatePlayer,
         downloadManager: FileDownloadManagerProtocol,
         permissionManager: PermissionManagerProtocol,
         geolocationService: GeolocationServiceProtocol,
         extensionsBuilder: TabExtensionsBuilderProtocol,
         cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?,
         statisticsLoader: StatisticsLoader?,
         internalUserDecider: InternalUserDeciding?,
         localHistory: Set<String>,
         title: String?,
         favicon: NSImage?,
         interactionStateData: Data?,
         parentTab: Tab?,
         shouldLoadInBackground: Bool,
         shouldLoadFromCache: Bool,
         canBeClosedWithBack: Bool,
         lastSelectedAt: Date?,
         webViewFrame: CGRect
    ) {

        self.content = content
        self.faviconManagement = faviconManagement
        self.historyCoordinating = historyCoordinating
        self.pinnedTabsManager = pinnedTabsManager
        self.privacyFeatures = privacyFeatures
        self.privatePlayer = privatePlayer
        self.statisticsLoader = statisticsLoader
        self.internalUserDecider = internalUserDecider
        self.localHistory = localHistory
        self.title = title
        self.favicon = favicon
        self.parentTab = parentTab
        self._canBeClosedWithBack = canBeClosedWithBack
        self.interactionState = (interactionStateData != nil || shouldLoadFromCache) ? .loadCachedFromTabContent(interactionStateData) : .none
        self.lastSelectedAt = lastSelectedAt

        let configuration = webViewConfiguration ?? WKWebViewConfiguration()
        configuration.applyStandardConfiguration(contentBlocking: privacyFeatures.contentBlocking)
        self.webViewConfiguration = configuration
        let userContentController = configuration.userContentController as? UserContentController
        assert(userContentController != nil)
        self.userContentController = userContentController

        webView = WebView(frame: webViewFrame, configuration: configuration)
        webView.allowsLinkPreview = false
        permissions = PermissionModel(permissionManager: permissionManager,
                                      geolocationService: geolocationService)

        let userScriptsPublisher = _userContentController.projectedValue
            .compactMap { $0?.$contentBlockingAssets }
            .switchToLatest()
            .map { $0?.userScripts as? UserScripts }
            .eraseToAnyPublisher()

        let userContentControllerPromise = Future<UserContentController, Never>.promise()
        let webViewPromise = Future<WKWebView, Never>.promise()
        self.extensions = extensionsBuilder
            .build(with: (tabIdentifier: instrumentation.currentTabIdentifier,
                          userScriptsPublisher: userScriptsPublisher,
                          inheritedAttribution: parentTab?.adClickAttribution?.currentAttributionState,
                          userContentControllerFuture: userContentControllerPromise.future,
                          permissionModel: permissions,
                          webViewFuture: webViewPromise.future
                         ),
                   dependencies: ExtensionDependencies(privacyFeatures: privacyFeatures,
                                                       historyCoordinating: historyCoordinating,
                                                       workspace: workspace,
                                                       cbaTimeReporter: cbaTimeReporter,
                                                       downloadManager: downloadManager))

        super.init()
        userContentController.map(userContentControllerPromise.fulfill)

        setupNavigationDelegate()
        userContentController?.delegate = self
        setupWebView(shouldLoadInBackground: shouldLoadInBackground)
        webViewPromise.fulfill(webView)

        if favicon == nil {
            handleFavicon()
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onDuckDuckGoEmailSignOut),
                                               name: .emailDidSignOut,
                                               object: nil)

        self.subscribeToDetectedTrackers()
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
    }

    func cleanUpBeforeClosing() {
        let job = { [content, webView, historyCoordinating] in
            if content.isUrl, let url = webView.url {
                historyCoordinating.commitChanges(url: url)
            }
            webView.stopLoading()
            webView.stopMediaCapture()
            webView.stopAllMediaPlayback()
            webView.fullscreenWindowController?.close()

            webView.configuration.userContentController.removeAllUserScripts()
        }
        guard Thread.isMainThread else {
            DispatchQueue.main.async(execute: job)
            return
        }
        job()
    }

#if DEBUG
    /// set this to true when Navigation-related decision making is expected to take significant time to avoid assertions
    /// used by BSK: Navigation.DistributedNavigationDelegate
    var shouldDisableLongDecisionMakingChecks: Bool = false
    func disableLongDecisionMakingChecks() { shouldDisableLongDecisionMakingChecks = true }
    func enableLongDecisionMakingChecks() { shouldDisableLongDecisionMakingChecks = false }
#else
    func disableLongDecisionMakingChecks() {}
    func enableLongDecisionMakingChecks() {}
#endif

    // MARK: - Event Publishers

    let webViewDidReceiveUserInteractiveChallengePublisher = PassthroughSubject<Void, Never>()
    let webViewDidCommitNavigationPublisher = PassthroughSubject<Void, Never>()
    let webViewDidFinishNavigationPublisher = PassthroughSubject<Void, Never>()
    let webViewDidFailNavigationPublisher = PassthroughSubject<Void, Never>()

    @MainActor
    @Published var isAMPProtectionExtracting: Bool = false

    // MARK: - Properties

    let webView: WebView

    var contentChangeEnabled = true

    var isLazyLoadingInProgress = false

    @Published private(set) var content: TabContent {
        didSet {
            handleFavicon()
            invalidateInteractionStateData()
            if let oldUrl = oldValue.url {
                historyCoordinating.commitChanges(url: oldUrl)
            }
            error = nil
        }
    }

    @discardableResult
    func setContent(_ newContent: TabContent) -> Task<ExpectedNavigation?, Never>? {
        guard contentChangeEnabled else { return nil }

        let oldContent = self.content
        let newContent: TabContent = {
            if let newContent = privatePlayer.overrideContent(newContent, for: self) {
                return newContent
            }
            if case .preferences(pane: .some) = oldContent,
               case .preferences(pane: nil) = newContent {
                // prevent clearing currently selected pane (for state persistence purposes)
                return oldContent
            }
            return newContent
        }()
        guard newContent != self.content else { return nil }
        self.content = newContent

        dismissPresentedAlert()

        if let title = content.title {
            self.title = title
        }

        return Task {
            await reloadIfNeeded(shouldLoadInBackground: true)
        }
    }

    @discardableResult
    func setUrl(_ url: URL?, userEntered: Bool) -> Task<ExpectedNavigation?, Never>? {
        if url == .welcome {
            OnboardingViewModel().restart()
        }
        return self.setContent(.contentFromURL(url, userEntered: userEntered))
    }

    private func handleUrlDidChange() {
        if let url = webView.url {
            let content = TabContent.contentFromURL(url)

            if content.isUrl, !webView.isLoading {
                self.addVisit(of: url)
            }
            if self.content.isUrl, self.content.url == url {
                // ignore content updates when tab.content has userEntered or credential set but equal url
            } else if content != self.content {
                self.content = content
            }
        }
        self.updateTitle() // The title might not change if webView doesn't think anything is different so update title here as well
    }

    var lastSelectedAt: Date?

    @Published var title: String?

    private func handleTitleDidChange() {
        updateTitle()

        if let title = self.title, let url = webView.url {
            historyCoordinating.updateTitleIfNeeded(title: title, url: url)
        }
    }

    private func updateTitle() {
        var title = webView.title?.trimmingWhitespace()
        if title?.isEmpty ?? true {
            title = webView.url?.host?.droppingWwwPrefix()
        }

        if title != self.title {
            self.title = title
        }
    }

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

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loadingProgress: Double = 0.0

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

    private enum InteractionState {
        case none
        case loadCachedFromTabContent(Data?)
        case webViewProvided(Data)

        var data: Data? {
            switch self {
            case .none:
                return nil
            case .loadCachedFromTabContent(let data):
                return data
            case .webViewProvided(let data):
                return data
            }
        }
        var shouldLoadFromCache: Bool {
            if case .loadCachedFromTabContent = self { return true }
            return false
        }
    }
    private var interactionState: InteractionState

    func invalidateInteractionStateData() {
        interactionState = .none
    }

    func getActualInteractionStateData() -> Data? {
        if let interactionStateData = interactionState.data {
            return interactionStateData
        }

        guard webView.url != nil else { return nil }

        if #available(macOS 12.0, *) {
            self.interactionState = (webView.interactionState as? Data).map { .webViewProvided($0) } ?? .none
        } else {
            self.interactionState = (try? webView.sessionStateData()).map { .webViewProvided($0) } ?? .none
        }

        return self.interactionState.data
    }

    private let instrumentation = TabInstrumentation()

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

        // Prevent from a Player reloading loop on back navigation to
        // YT page where the player was enabled (see comment inside)
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
        if let error = error, let failingUrl = error.failingUrl {
            webView.load(URLRequest(url: failingUrl, cachePolicy: .reloadIgnoringLocalCacheData))
            return
        }

        if webView.url == nil, content.url != nil {
            // load from cache or interactionStateData when called by lazy loader
            Task { @MainActor [weak self] in
                await self?.reloadIfNeeded(shouldLoadInBackground: true)
            }
        } else if case .privatePlayer = content, let url = content.url {
            webView.load(URLRequest(url: url))
        } else {
            webView.reload()
        }
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
    @discardableResult
    private func reloadIfNeeded(shouldLoadInBackground: Bool = false) async -> ExpectedNavigation? {
        let content = self.content
        guard content.url != nil else { return nil }

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
        guard content == self.content else { return nil }

        if shouldReload(url, shouldLoadInBackground: shouldLoadInBackground) {
            let didRestore = restoreInteractionStateDataIfNeeded()

            if privatePlayer.goBackAndLoadURLIfNeeded(for: self) {
                return nil
            }

            guard !didRestore else { return nil }

            if url.isFileURL {
                return webView.navigator(distributedNavigationDelegate: navigationDelegate)
                    .loadFileURL(url, allowingReadAccessTo: URL(fileURLWithPath: "/"), withExpectedNavigationType: content.isUserEnteredUrl ? .custom(.userEnteredUrl) : .other)
            }

            var request = URLRequest(url: url, cachePolicy: interactionState.shouldLoadFromCache ? .returnCacheDataElseLoad : .useProtocolCachePolicy)
            if #available(macOS 12.0, *),
               content.isUserEnteredUrl {
                request.attribution = .user
            }
            return webView.navigator(distributedNavigationDelegate: navigationDelegate)
                .load(request, withExpectedNavigationType: content.isUserEnteredUrl ? .custom(.userEnteredUrl) : .other)
        }
        return nil
    }

    @MainActor
    private var contentURL: URL {
        switch content {
        case .url(let value, credential: _, userEntered: _):
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
    private func shouldReload(_ url: URL, shouldLoadInBackground: Bool) -> Bool {
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
        // only restore session from interactionStateData passed to Tab.init
        guard case .loadCachedFromTabContent(.some(let interactionStateData)) = self.interactionState else { return false }

        if contentURL.isFileURL {
            // request file system access before restoration
            _ = webView.loadFileURL(contentURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        }

        if #available(macOS 12.0, *) {
            webView.interactionState = interactionStateData
            return true
        } else {
            do {
                try webView.restoreSessionState(from: interactionStateData)
                return true
            } catch {
                os_log("Tab:setupWebView could not restore session state %s", "\(error)")
            }
        }

        return false
    }

    private func addHomePageToWebViewIfNeeded() {
        guard !NSApp.isRunningUnitTests else { return }
        if content == .homePage && webView.url == nil {
            webView.load(URLRequest(url: .homePage))
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

        webView.observe(\.url) { [weak self] _, _ in
            self?.handleUrlDidChange()
        }.store(in: &webViewCancellables)
        webView.observe(\.title) { [weak self] _, _ in
            self?.handleTitleDidChange()
        }.store(in: &webViewCancellables)

        webView.observe(\.canGoBack) { [weak self] _, _ in
            self?.updateCanGoBackForward()
        }.store(in: &webViewCancellables)

        webView.observe(\.canGoForward) { [weak self] _, _ in
            self?.updateCanGoBackForward()
        }.store(in: &webViewCancellables)

        webView.publisher(for: \.isLoading)
            .assign(to: \.isLoading, onWeaklyHeld: self)
            .store(in: &webViewCancellables)

        webView.publisher(for: \.estimatedProgress)
            .assign(to: \.loadingProgress, onWeaklyHeld: self)
            .store(in: &webViewCancellables)

        webView.publisher(for: \.serverTrust)
            .sink { [weak self] serverTrust in
                self?.privacyInfo?.serverTrust = serverTrust
            }
            .store(in: &webViewCancellables)

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

    private func dismissPresentedAlert() {
        if let userInteractionDialog {
            switch userInteractionDialog.dialog {
            case .jsDialog: self.userInteractionDialog = nil
            default: break
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

}

extension Tab: UserContentControllerDelegate {

    func userContentController(_ userContentController: UserContentController, didInstallContentRuleLists contentRuleLists: [String: WKContentRuleList], userScripts: UserScriptsProvider, updateEvent: ContentBlockerRulesManager.UpdateEvent) {
        guard let userScripts = userScripts as? UserScripts else { fatalError("Unexpected UserScripts") }

        userScripts.debugScript.instrumentation = instrumentation
        userScripts.faviconScript.delegate = self
        userScripts.pageObserverScript.delegate = self
        userScripts.printingUserScript.delegate = self
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

extension Tab {
    // ContentBlockerRulesUserScriptDelegate & ClickToLoadUserScriptDelegate
    // to be refactored to TabExtensions later
    func subscribeToDetectedTrackers() {
        detectedTrackersCancellables = self.trackersPublisher.sink { [weak self] tracker in
            guard let self, let url = self.webView.url else { return }

            switch tracker.type {
            case .tracker:
                self.historyCoordinating.addDetectedTracker(tracker.request, onURL: url)
            case .trackerWithSurrogate:
                self.historyCoordinating.addDetectedTracker(tracker.request, onURL: url)
            case .thirdPartyRequest:
                break
            }
        }
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

extension Tab/*: NavigationResponder*/ { // to be moved to Tab+Navigation.swift

    @MainActor
    func didReceive(_ challenge: URLAuthenticationChallenge, for navigation: Navigation?) async -> AuthChallengeDisposition? {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic else { return nil }

        // send this event only when we're interrupting loading and showing extra UI to the user
        webViewDidReceiveUserInteractiveChallengePublisher.send()

        // when navigating to a URL with basic auth username/password, cache it and redirect to a trimmed URL
        if case .url(let url, .some(let credential), userEntered: let userEntered) = content,
           url.matches(challenge.protectionSpace),
           challenge.previousFailureCount == 0 {

            self.content = .url(url, userEntered: userEntered)
            return .credential(credential)
        }

        let (request, future) = BasicAuthDialogRequest.future(with: challenge.protectionSpace)
        self.userInteractionDialog = UserDialog(sender: .page(domain: challenge.protectionSpace.host), dialog: .basicAuthenticationChallenge(request))
        do {
            disableLongDecisionMakingChecks()
            defer {
                enableLongDecisionMakingChecks()
            }

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
        // allow local file navigations
        if navigationAction.url.isFileURL { return .allow }

        // when navigating to a URL with basic auth username/password, cache it and redirect to a trimmed URL
        if let mainFrame = navigationAction.mainFrameTarget,
           let credential = navigationAction.url.basicAuthCredential {

            return .redirect(mainFrame) { navigator in
                var request = navigationAction.request
                // credential is removed from the URL and set to TabContent to be used on next Challenge
                self.content = .url(navigationAction.url.removingBasicAuthCredential(), credential: credential, userEntered: false)
                // reload URL without credentials
                request.url = self.content.url!
                navigator.load(request)
            }
        }

        if let policy = privatePlayer.decidePolicy(for: navigationAction, in: self) {
            return policy
        }

        let isLinkActivated = !navigationAction.isTargetingNewWindow
            && (navigationAction.navigationType.isLinkActivated || (navigationAction.navigationType == .other && navigationAction.isUserInitiated))

        let isNavigatingAwayFromPinnedTab: Bool = {
            let isNavigatingToAnotherDomain = navigationAction.url.host != url?.host
            let isPinned = pinnedTabsManager.isTabPinned(self)
            return isLinkActivated && isPinned && isNavigatingToAnotherDomain && navigationAction.isForMainFrame
        }()

        // to be modularized later on, see https://app.asana.com/0/0/1203268245242140/f
        let isRequestingNewTab = (isLinkActivated && NSApp.isCommandPressed) || navigationAction.navigationType.isMiddleButtonClick || isNavigatingAwayFromPinnedTab
        let shouldSelectNewTab = NSApp.isShiftPressed || (isNavigatingAwayFromPinnedTab && !navigationAction.navigationType.isMiddleButtonClick && !NSApp.isCommandPressed)

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
                            self.webView.load(URLRequest(url: url))
                        }
                    })
            if let navigationActionPolicy = navigationActionPolicy, navigationActionPolicy == false {
                return .cancel
            }
        }

        if navigationAction.isForMainFrame {
            preferences.userAgent = UserAgent.for(navigationAction.url)
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

            return .redirectInvalidatingBackItemIfNeeded(navigationAction) {
                $0.load(request)
            }
        }

        if isRequestingNewTab {
            self.openChild(with: .contentFromURL(navigationAction.url), of: .tab(selected: shouldSelectNewTab))
            return .cancel

        }

        guard navigationAction.url.scheme != nil else { return .allow }

        return .next
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    @MainActor
    func willStart(_ navigation: Navigation) {
        if error != nil { error = nil }

        delegate?.tabWillStartNavigation(self, isUserInitiated: navigation.navigationAction.isUserInitiated)
    }

    @MainActor
    func decidePolicy(for navigationResponse: NavigationResponse) async -> NavigationResponsePolicy? {
        internalUserDecider?.markUserAsInternalIfNeeded(forUrl: webView.url,
                                                        response: navigationResponse.response as? HTTPURLResponse)

        return .next
    }

    @MainActor
    func didStart(_ navigation: Navigation) {
        delegate?.tabDidStartNavigation(self)
        userInteractionDialog = nil

        // Unnecessary assignment triggers publishing
        if error != nil { error = nil }

        invalidateInteractionStateData()
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
    }

    func webContentProcessDidTerminate(with reason: WKProcessTerminationReason?) {
        Pixel.fire(.debug(event: .webKitDidTerminate, error: NSError(domain: "WKProcessTerminated", code: reason?.rawValue ?? -1)))
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
        webViewCancellables.removeAll()

        webView.stopLoading()
        webView.configuration.userContentController.removeAllUserScripts()

        webView.navigationDelegate = caller
        webView.load(URLRequest(url: .blankPage))
    }
}

// "protected" properties meant to access otherwise private properties from Tab extensions
extension Tab {

    static var objcDelegateKeyPath: String { #keyPath(objcDelegate) }
    @objc private var objcDelegate: Any? { delegate }

    static var objcNavigationDelegateKeyPath: String { #keyPath(objcNavigationDelegate) }
    @objc private var objcNavigationDelegate: Any? { navigationDelegate }

}
