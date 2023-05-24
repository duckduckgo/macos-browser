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

import BrowserServicesKit
import Combine
import Common
import ContentBlocking
import Foundation
import Navigation
import UserScript
import WebKit

protocol TabDelegate: ContentOverlayUserScriptDelegate {
    func tabWillStartNavigation(_ tab: Tab, isUserInitiated: Bool)
    func tabDidStartNavigation(_ tab: Tab)
    func tab(_ tab: Tab, createdChild childTab: Tab, of kind: NewWindowPolicy)

    func tabPageDOMLoaded(_ tab: Tab)
    func closeTab(_ tab: Tab)

}

protocol NewWindowPolicyDecisionMaker {
    func decideNewWindowPolicy(for navigationAction: WKNavigationAction) -> NavigationDecision?
}

// swiftlint:disable:next type_body_length
@dynamicMemberLookup final class Tab: NSObject, Identifiable, ObservableObject, Injectable {

    enum TabContent: Equatable {
        case homePage
        case url(URL, credential: URLCredential? = nil, userEntered: String? = nil)
        case preferences(pane: PreferencePaneIdentifier?)
        case bookmarks
        case onboarding
        case none

        static func contentFromURL(_ url: URL?, userEntered: String? = nil) -> TabContent {
            if url == .homePage {
                return .homePage
            } else if url == .welcome {
                return .onboarding
            } else if url == .preferences {
                return .anyPreferencePane
            } else if let preferencePane = url.flatMap(PreferencePaneIdentifier.init(url:)) {
                return .preferences(pane: preferencePane)
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
            case .url, .homePage, .none: return nil
            case .preferences: return UserText.tabPreferencesTitle
            case .bookmarks: return UserText.tabBookmarksTitle
            case .onboarding: return UserText.tabOnboardingTitle
            }
        }

        var url: URL? {
            userEditableUrl
        }
        var userEditableUrl: URL? {
            switch self {
            case .url(let url, credential: _, userEntered: _) where !(url.isDuckPlayer || url.isDuckPlayerScheme):
                return url
            default:
                return nil
            }
        }

        var urlForWebView: URL? {
            switch self {
            case .url(let url, credential: _, userEntered: _):
                return url
            case .homePage:
                return .homePage
            case .preferences(pane: .some(let pane)):
                return .preferencePane(pane)
            case .preferences(pane: .none):
                return .preferences
            case .bookmarks:
                return .blankPage
            case .onboarding:
                return .welcome
            case .none:
                return nil
            }
        }

        var isUrl: Bool {
            switch self {
            case .url:
                return true
            default:
                return false
            }
        }

        var userEnteredValue: String? {
            switch self {
            case .url(_, credential: _, userEntered: let userEnteredValue):
                return userEnteredValue
            default:
                return nil
            }
        }

        var isUserEnteredUrl: Bool {
            userEnteredValue != nil
        }

        var displaysContentInWebView: Bool {
            isUrl
        }

    }
    private struct ExtensionDependencies: TabExtensionDependencies {
        let privacyFeatures: PrivacyFeaturesProtocol
        let historyCoordinating: HistoryCoordinating
        var workspace: Workspace
        var cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?
        let duckPlayer: DuckPlayer
        var downloadManager: FileDownloadManagerProtocol
    }

    fileprivate weak var delegate: TabDelegate?
    func setDelegate(_ delegate: TabDelegate) { self.delegate = delegate }

    private let navigationDelegate = DistributedNavigationDelegate(log: .navigation)
    private var newWindowPolicyDecisionMakers: [NewWindowPolicyDecisionMaker]?
    private var onNewWindow: ((WKNavigationAction?) -> NavigationDecision)?

    private let statisticsLoader: StatisticsLoader?
    private let internalUserDecider: InternalUserDecider?

    @Injected
    var pinnedTabsManager: PinnedTabsManager

    private let webViewConfiguration: WKWebViewConfiguration

    private var extensions: TabExtensions
    // accesing TabExtensions‘ Public Protocols projecting tab.extensions.extensionName to tab.extensionName
    // allows extending Tab functionality while maintaining encapsulation
    subscript<Extension>(dynamicMember keyPath: KeyPath<TabExtensions, Extension?>) -> Extension? {
        self.extensions[keyPath: keyPath]
    }

    @Published
    private(set) var userContentController: UserContentController?

    @MainActor
    convenience init(content: TabContent,
                     faviconManagement: FaviconManagement = FaviconManager.shared,
                     webCacheManager: WebCacheManager = WebCacheManager.shared,
                     webViewConfiguration: WKWebViewConfiguration? = nil,
                     historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
                     pinnedTabsManager: PinnedTabsManager? = nil,
                     workspace: Workspace = NSWorkspace.shared,
                     privacyFeatures: AnyPrivacyFeatures? = nil,
                     duckPlayer: DuckPlayer? = nil,
                     downloadManager: FileDownloadManagerProtocol = FileDownloadManager.shared,
                     permissionManager: PermissionManagerProtocol = PermissionManager.shared,
                     geolocationService: GeolocationServiceProtocol = GeolocationService.shared,
                     cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter? = ContentBlockingAssetsCompilationTimeReporter.shared,
                     statisticsLoader: StatisticsLoader? = nil,
                     extensionsBuilder: TabExtensionsBuilderProtocol = TabExtensionsBuilder.default,
                     title: String? = nil,
                     favicon: NSImage? = nil,
                     interactionStateData: Data? = nil,
                     parentTab: Tab? = nil,
                     shouldLoadInBackground: Bool = false,
                     isBurner: Bool = false,
                     shouldLoadFromCache: Bool = false,
                     canBeClosedWithBack: Bool = false,
                     lastSelectedAt: Date? = nil,
                     webViewSize: CGSize = CGSize(width: 1024, height: 768)
    ) {

        let duckPlayer = duckPlayer
            ?? (NSApp.isRunningUnitTests ? DuckPlayer.mock(withMode: .enabled) : DuckPlayer.shared)
        let statisticsLoader = statisticsLoader
            ?? (NSApp.isRunningUnitTests ? nil : StatisticsLoader.shared)
        let privacyFeatures = privacyFeatures ?? PrivacyFeatures
        let internalUserDecider = (NSApp.delegate as? AppDelegate)?.internalUserDecider
        var faviconManager = faviconManagement
        if isBurner {
            faviconManager = FaviconManager(cacheType: .inMemory)
        }

        self.init(content: content,
                  faviconManagement: faviconManager,
                  webCacheManager: webCacheManager,
                  webViewConfiguration: webViewConfiguration,
                  historyCoordinating: historyCoordinating,
                  pinnedTabsManager: pinnedTabsManager ?? WindowControllersManager.shared.pinnedTabsManager,
                  workspace: workspace,
                  privacyFeatures: privacyFeatures,
                  duckPlayer: duckPlayer,
                  downloadManager: downloadManager,
                  permissionManager: permissionManager,
                  geolocationService: geolocationService,
                  extensionsBuilder: extensionsBuilder,
                  cbaTimeReporter: cbaTimeReporter,
                  statisticsLoader: statisticsLoader,
                  internalUserDecider: internalUserDecider,
                  title: title,
                  favicon: favicon,
                  interactionStateData: interactionStateData,
                  parentTab: parentTab,
                  shouldLoadInBackground: shouldLoadInBackground,
                  isBurner: isBurner,
                  shouldLoadFromCache: shouldLoadFromCache,
                  canBeClosedWithBack: canBeClosedWithBack,
                  lastSelectedAt: lastSelectedAt,
                  webViewSize: webViewSize)
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    init(content: TabContent,
         faviconManagement: FaviconManagement,
         webCacheManager: WebCacheManager,
         webViewConfiguration: WKWebViewConfiguration?,
         historyCoordinating: HistoryCoordinating,
         pinnedTabsManager: PinnedTabsManager,
         workspace: Workspace,
         privacyFeatures: AnyPrivacyFeatures,
         duckPlayer: DuckPlayer,
         downloadManager: FileDownloadManagerProtocol,
         permissionManager: PermissionManagerProtocol,
         geolocationService: GeolocationServiceProtocol,
         extensionsBuilder: TabExtensionsBuilderProtocol,
         cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?,
         statisticsLoader: StatisticsLoader?,
         internalUserDecider: InternalUserDecider?,
         title: String?,
         favicon: NSImage?,
         interactionStateData: Data?,
         parentTab: Tab?,
         shouldLoadInBackground: Bool,
         isBurner: Bool,
         shouldLoadFromCache: Bool,
         canBeClosedWithBack: Bool,
         lastSelectedAt: Date?,
         webViewSize: CGSize
    ) {

        self.content = content
        self.faviconManagement = faviconManagement
        self.pinnedTabsManager = pinnedTabsManager
        self.statisticsLoader = statisticsLoader
        self.internalUserDecider = internalUserDecider
        self.title = title
        self.favicon = favicon
        self.parentTab = parentTab
        self.isBurner = isBurner
        self._canBeClosedWithBack = canBeClosedWithBack
        self.interactionState = (interactionStateData != nil || shouldLoadFromCache) ? .loadCachedFromTabContent(interactionStateData) : .none
        self.lastSelectedAt = lastSelectedAt

        let configuration = webViewConfiguration ?? WKWebViewConfiguration()
        configuration.applyStandardConfiguration(contentBlocking: privacyFeatures.contentBlocking,
                                                 isBurner: isBurner)
        self.webViewConfiguration = configuration
        let userContentController = configuration.userContentController as? UserContentController
        assert(userContentController != nil)
        self.userContentController = userContentController

        webView = WebView(frame: CGRect(origin: .zero, size: webViewSize), configuration: configuration)
        webView.allowsLinkPreview = false
        permissions = PermissionModel(permissionManager: permissionManager,
                                      geolocationService: geolocationService)

        let userContentControllerPromise = Future<UserContentController, Never>.promise()
        let userScriptsPublisher = userContentControllerPromise.future
            .compactMap { $0.$contentBlockingAssets }
            .switchToLatest()
            .map { $0?.userScripts as? UserScripts }
            .eraseToAnyPublisher()

        let webViewPromise = Future<WKWebView, Never>.promise()
        var tabGetter: () -> Tab? = { nil }
        self.extensions = extensionsBuilder
            .build(with: (tabIdentifier: instrumentation.currentTabIdentifier,
                          isTabPinned: { tabGetter().map { tab in pinnedTabsManager.isTabPinned(tab) } ?? false },
                          isTabBurner: isBurner,
                          contentPublisher: _content.projectedValue.eraseToAnyPublisher(),
                          titlePublisher: _title.projectedValue.eraseToAnyPublisher(),
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
                                                       duckPlayer: duckPlayer,
                                                       downloadManager: downloadManager))

        super.init()
        tabGetter = { [weak self] in self }
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

        addDeallocationChecks(for: webView)
    }

#if DEBUG
    func addDeallocationChecks(for webView: WKWebView) {
        let processPool = webView.configuration.processPool
        let webViewValue = NSValue(nonretainedObject: webView)

        webView.onDeinit { [weak self] in
            // Tab should deallocate with the WebView
            self?.assertObjectDeallocated(after: 1.0)

            // unregister WebView from the ProcessPool
            processPool.webViewsUsingProcessPool.remove(webViewValue)

            if processPool.webViewsUsingProcessPool.isEmpty {
                // when the last WebView is deallocated the ProcessPool should be deallocated
                processPool.assertObjectDeallocated(after: 1)
                // by the moment the ProcessPool is dead all the UserContentControllers that were using it should be deallocated
                let knownUserContentControllers = processPool.knownUserContentControllers
                processPool.onDeinit {
                    for controller in knownUserContentControllers {
                        assert(controller.userContentController == nil, "\(controller) has not been deallocated")
                    }
                }
            }
        }
        // ProcessPool will be alive while there are WebViews using it
        processPool.webViewsUsingProcessPool.insert(webViewValue)
        processPool.knownUserContentControllers.insert(.init(userContentController: webView.configuration.userContentController))
    }
#else
    @inlinable func addDeallocationChecks(for webView: WKWebView) {}
#endif

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

    func openChild(with url: URL, of kind: NewWindowPolicy) {
        self.onNewWindow = { _ in
            .allow(kind)
        }
        webView.loadInNewWindow(url)
    }

    @objc func onDuckDuckGoEmailSignOut(_ notification: Notification) {
        guard let url = webView.url else { return }
        if EmailUrls().isDuckDuckGoEmailProtection(url: url) {
            webView.evaluateJavaScript("window.postMessage({ emailProtectionSignedOut: true }, window.origin);")
        }
    }

    deinit {
        cleanUpBeforeClosing(onDeinit: true)
    }

    func cleanUpBeforeClosing() {
        cleanUpBeforeClosing(onDeinit: false)
    }

    @MainActor(unsafe)
    private func cleanUpBeforeClosing(onDeinit: Bool) {
        let job = { [webView, userContentController] in
            webView.stopLoading()
            webView.stopMediaCapture()
            webView.stopAllMediaPlayback()
            webView.fullscreenWindowController?.close()

            userContentController?.cleanUpBeforeClosing()
            webView.assertObjectDeallocated(after: 4.0)
        }
        if !onDeinit {
            // Tab should be deallocated shortly after burning
            self.assertObjectDeallocated(after: 4.0)
        }
        guard Thread.isMainThread else {
            DispatchQueue.main.async { job() }
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

    // MARK: - Properties

    let webView: WebView

    var contentChangeEnabled = true

    var isLazyLoadingInProgress = false

    let isBurner: Bool

    @Published private(set) var content: TabContent {
        didSet {
            if !content.displaysContentInWebView && oldValue.displaysContentInWebView {
                webView.stopLoading()
                webView.stopMediaCapture()
                webView.stopAllMediaPlayback()
            }
            handleFavicon()
            invalidateInteractionStateData()
            error = nil
        }
    }

    @discardableResult
    func setContent(_ newContent: TabContent) -> Task<ExpectedNavigation?, Never>? {
        guard contentChangeEnabled else { return nil }

        let oldContent = self.content
        let newContent: TabContent = {
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
    func setUrl(_ url: URL?, userEntered: String?) -> Task<ExpectedNavigation?, Never>? {
        if url == .welcome {
            OnboardingViewModel().restart()
        }
        return self.setContent(.contentFromURL(url, userEntered: userEntered))
    }

    private func handleUrlDidChange() {
        if let url = webView.url {
            let content = TabContent.contentFromURL(url)

            if self.content.isUrl, self.content.url == url {
                // ignore content updates when tab.content has userEntered or credential set but equal url as it comes from the WebView url updated event
            } else if content != self.content {
                self.content = content
            }
        }
        self.updateTitle() // The title might not change if webView doesn't think anything is different so update title here as well
    }

    var lastSelectedAt: Date?

    @Published var title: String?

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
            if error == nil || error?.isFrameLoadInterrupted == true || error?.isNavigationCancelled == true {
                return
            }
            webView.stopLoading()
            webView.stopMediaCapture()
            webView.stopAllMediaPlayback()
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
    @Published private(set) var canReload: Bool = false

    private func updateCanGoBackForward() {
        updateCanGoBackForward(withCurrentNavigation: navigationDelegate.currentNavigation)
    }

    // published $currentNavigation emits nil before actual currentNavigation property is set to nil, that‘s why default `= nil` argument can‘t be used here
    @MainActor(unsafe)
    private func updateCanGoBackForward(withCurrentNavigation currentNavigation: Navigation?) {
        dispatchPrecondition(condition: .onQueue(.main))

        // “freeze” back-forward buttons updates when current backForwardListItem is being popped..
        if webView.canGoForward
            // coming back to the same backForwardList item from where started
            && (webView.backForwardList.currentItem?.identity == currentNavigation?.navigationAction.fromHistoryItemIdentity
                // ..or during the following developer-redirect navigation
                || currentNavigation?.navigationAction.navigationType == .redirect(.developer)) {
            return
        }

        let canGoBack = webView.canGoBack || self.error != nil
        let canGoForward = webView.canGoForward && self.error == nil
        let canReload = (self.content.urlForWebView?.scheme ?? URL.NavigationalScheme.about.rawValue) != URL.NavigationalScheme.about.rawValue

        if canGoBack != self.canGoBack {
            self.canGoBack = canGoBack
        }
        if canGoForward != self.canGoForward {
            self.canGoForward = canGoForward
        }
        if canReload != self.canReload {
            self.canReload = canReload
        }
    }

    @MainActor
    @discardableResult
    func goBack() -> ExpectedNavigation? {
        guard canGoBack else {
            if canBeClosedWithBack {
                delegate?.closeTab(self)
            }
            return nil
        }

        guard error == nil else {
            return webView.navigator()?.reload(withExpectedNavigationType: .reload)
        }

        userInteractionDialog = nil
        return webView.navigator()?.goBack(withExpectedNavigationType: .backForward(distance: -1))
    }

    @MainActor
    @discardableResult
    func goForward() -> ExpectedNavigation? {
        guard canGoForward else { return nil }
        return webView.navigator()?.goForward(withExpectedNavigationType: .backForward(distance: 1))
    }

    func go(to item: WKBackForwardListItem) {
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

        if webView.url == nil, content.isUrl {
            // load from cache or interactionStateData when called by lazy loader
            Task { @MainActor [weak self] in
                await self?.reloadIfNeeded(shouldLoadInBackground: true)
            }
        } else {
            webView.reload()
        }
    }

    @MainActor
    @discardableResult
    private func reloadIfNeeded(shouldLoadInBackground: Bool = false) async -> ExpectedNavigation? {
        let content = self.content
        guard let url = content.urlForWebView,
              url.scheme.map(URL.NavigationalScheme.init) != .about else { return nil }

        if shouldReload(url, shouldLoadInBackground: shouldLoadInBackground) {
            let didRestore = restoreInteractionStateDataIfNeeded()

            guard !didRestore else { return nil }

            let navigationType: NavigationType
            if content.isUserEnteredUrl {
                navigationType = .custom(.userEnteredUrl)
            } else if interactionState.shouldLoadFromCache {
                navigationType = .sessionRestoration
            } else {
                navigationType = .custom(.tabContentUpdate)
            }

            if url.isFileURL {
                return webView.navigator(distributedNavigationDelegate: navigationDelegate)
                    .loadFileURL(url, allowingReadAccessTo: URL(fileURLWithPath: "/"), withExpectedNavigationType: navigationType)
            }

            var request = URLRequest(url: url, cachePolicy: interactionState.shouldLoadFromCache ? .returnCacheDataElseLoad : .useProtocolCachePolicy)
            if #available(macOS 12.0, *),
               content.isUserEnteredUrl {
                request.attribution = .user
            }
            invalidateInteractionStateData()

            return webView.navigator(distributedNavigationDelegate: navigationDelegate)
                .load(request, withExpectedNavigationType: navigationType)
        }
        return nil
    }

    @MainActor
    private func shouldReload(_ url: URL, shouldLoadInBackground: Bool) -> Bool {
        // don‘t reload in background unless shouldLoadInBackground
        guard url.isValid,
              (webView.superview != nil || shouldLoadInBackground),
              // don‘t reload when already loaded
              webView.url != url,
              webView.url != (content.isUrl ? content.urlForWebView : nil)
        else {
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

        if let url = content.urlForWebView, url.isFileURL {
            // request file system access before restoration
            _ = webView.loadFileURL(url, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        }

        if #available(macOS 12.0, *) {
            webView.interactionState = interactionStateData
        } else {
            do {
                try webView.restoreSessionState(from: interactionStateData)
            } catch {
                os_log("Tab:setupWebView could not restore session state %s", type: .error, "\(error)")
                return false
            }
        }
        invalidateInteractionStateData()

        return true
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
        guard let url = content.userEditableUrl,
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
            self?.updateTitle()
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
        guard content.isUrl, let url = content.urlForWebView else {
            favicon = nil
            return
        }

        if url.isDuckPlayer || url.isDuckPlayerScheme {
            favicon = .duckPlayer
            return
        }

        guard faviconManagement.areFaviconsLoaded else { return }

        if let cachedFavicon = faviconManagement.getCachedFavicon(for: url, sizeCategory: .small)?.image {
            if cachedFavicon != favicon {
                favicon = cachedFavicon
            }
        } else {
            favicon = nil
        }
    }

}

extension Tab: UserContentControllerDelegate {

    @MainActor
    func userContentController(_ userContentController: UserContentController, didInstallContentRuleLists contentRuleLists: [String: WKContentRuleList], userScripts: UserScriptsProvider, updateEvent: ContentBlockerRulesManager.UpdateEvent) {
        os_log("didInstallContentRuleLists", log: .contentBlocking, type: .info)
        guard let userScripts = userScripts as? UserScripts else { fatalError("Unexpected UserScripts") }

        userScripts.debugScript.instrumentation = instrumentation
        userScripts.faviconScript.delegate = self
        userScripts.pageObserverScript.delegate = self
        userScripts.printingUserScript.delegate = self
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
        webViewDidCommitNavigationPublisher.send()
    }

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
                self.content = .url(navigationAction.url.removingBasicAuthCredential(), credential: credential, userEntered: nil)
                // reload URL without credentials
                request.url = self.content.url!
                navigator.load(request)
            }
        }

        if navigationAction.isForMainFrame {
            preferences.userAgent = UserAgent.for(navigationAction.url)
        }
        guard navigationAction.url.scheme != nil else { return .allow }

        return .next
    }

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
    }

    @MainActor
    func navigationDidFinish(_ navigation: Navigation) {
        invalidateInteractionStateData()
        webViewDidFinishNavigationPublisher.send()
        statisticsLoader?.refreshRetentionAtb(isSearch: navigation.url.isDuckDuckGoSearch)
    }

    @MainActor
    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        if navigation.isCurrent {
            self.error = error
        }

        invalidateInteractionStateData()
        webViewDidFailNavigationPublisher.send()
    }

    func webContentProcessDidTerminate(with reason: WKProcessTerminationReason?) {
        Pixel.fire(.debug(event: .webKitDidTerminate, error: NSError(domain: "WKProcessTerminated", code: reason?.rawValue ?? -1)))
    }

}

extension Tab: NewWindowPolicyDecisionMaker {

    func decideNewWindowPolicy(for navigationAction: WKNavigationAction) -> NavigationDecision? {
        defer {
            onNewWindow = nil
        }
        return onNewWindow?(navigationAction)
    }

}

extension Tab: TabDataClearing {
    @MainActor
    func prepareForDataClearing(caller: TabDataCleaner) {
        webViewCancellables.removeAll()

        webView.stopLoading()
        (webView.configuration.userContentController as? UserContentController)?.cleanUpBeforeClosing()

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

    static var objcNewWindowPolicyDecisionMakersKeyPath: String { #keyPath(objcNewWindowPolicyDecisionMakers) }
    @objc private var objcNewWindowPolicyDecisionMakers: Any? {
        get {
            newWindowPolicyDecisionMakers
        }
        set {
            newWindowPolicyDecisionMakers = newValue as? [NewWindowPolicyDecisionMaker] ?? {
                assertionFailure("\(String(describing: newValue)) is not [NewWindowPolicyDecisionMaker]")
                return nil
            }()
        }
    }

}
