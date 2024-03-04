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
import History

#if SUBSCRIPTION
import Subscription
#endif

#if NETWORK_PROTECTION
import NetworkProtection
import NetworkProtectionIPC
#endif

// swiftlint:disable file_length

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
@dynamicMemberLookup final class Tab: NSObject, Identifiable, ObservableObject {

    enum TabContent: Equatable {
        case newtab
        case url(URL, credential: URLCredential? = nil, source: URLSource)
        case settings(pane: PreferencePaneIdentifier?)
        case bookmarks
        case onboarding
        case none
        case dataBrokerProtection
        case subscription(URL)

        enum URLSource: Equatable {
            case pendingStateRestoration
            case loadedByStateRestoration
            case userEntered(String, downloadRequested: Bool = false)
            case historyEntry
            case bookmark
            case ui
            case link
            case appOpenUrl
            case reload

            case webViewUpdated

            var userEnteredValue: String? {
                if case .userEntered(let userEnteredValue, _) = self {
                    userEnteredValue
                } else {
                    nil
                }
            }

            var isUserEnteredUrl: Bool {
                userEnteredValue != nil
            }

            var navigationType: NavigationType {
                switch self {
                case .userEntered(_, downloadRequested: true):
                    .custom(.userRequestedPageDownload)
                case .userEntered:
                    .custom(.userEnteredUrl)
                case .pendingStateRestoration:
                    .sessionRestoration
                case .loadedByStateRestoration, .appOpenUrl, .historyEntry, .bookmark, .ui, .link, .webViewUpdated:
                    .custom(.tabContentUpdate)
                case .reload:
                    .reload
                }
            }

            var cachePolicy: URLRequest.CachePolicy {
                switch self {
                case .pendingStateRestoration, .historyEntry:
                    .returnCacheDataElseLoad
                case .reload, .loadedByStateRestoration:
                    .reloadIgnoringCacheData
                case .userEntered, .bookmark, .ui, .link, .appOpenUrl, .webViewUpdated:
                    .useProtocolCachePolicy
                }
            }

        }

        // swiftlint:disable:next cyclomatic_complexity
        static func contentFromURL(_ url: URL?, source: URLSource) -> TabContent {
            switch url {
            case URL.newtab, URL.Invalid.aboutNewtab, URL.Invalid.duckHome:
                return .newtab
            case URL.welcome, URL.Invalid.aboutWelcome:
                return .onboarding
            case URL.settings, URL.Invalid.aboutPreferences, URL.Invalid.aboutConfig, URL.Invalid.aboutSettings, URL.Invalid.duckConfig, URL.Invalid.duckPreferences:
                return .anySettingsPane
            case URL.bookmarks, URL.Invalid.aboutBookmarks:
                return .bookmarks
            case URL.dataBrokerProtection:
                return .dataBrokerProtection
            case URL.Invalid.aboutHome:
                guard let customURL = URL(string: StartupPreferences.shared.formattedCustomHomePageURL) else {
                    return .newtab
                }
                return .url(customURL, source: source)
            default: break
            }

#if SUBSCRIPTION
            if let url {
                if url.isChild(of: URL.subscriptionBaseURL) || url.isChild(of: URL.identityTheftRestoration) {
                    return .subscription(url)
                }
            }
#endif

            if let settingsPane = url.flatMap(PreferencePaneIdentifier.init(url:)) {
                return .settings(pane: settingsPane)
            } else if let url, let credential = url.basicAuthCredential {
                // when navigating to a URL with basic auth username/password, cache it and redirect to a trimmed URL
                return .url(url.removingBasicAuthCredential(), credential: credential, source: source)
            } else {
                return .url(url ?? .blankPage, source: source)
            }
        }

        static var displayableTabTypes: [TabContent] {
            // Add new displayable types here
            let displayableTypes = [TabContent.anySettingsPane, .bookmarks]

            return displayableTypes.sorted { first, second in
                guard let firstTitle = first.title, let secondTitle = second.title else {
                    return true // Arbitrary sort order, only non-standard tabs are displayable.
                }
                return firstTitle.localizedStandardCompare(secondTitle) == .orderedAscending
            }
        }

        /// Convenience accessor for `.preferences` Tab Content with no particular pane selected,
        /// i.e. the currently selected pane is decided internally by `PreferencesViewController`.
        static let anySettingsPane: Self = .settings(pane: nil)

        var isDisplayable: Bool {
            switch self {
            case .settings, .bookmarks, .dataBrokerProtection:
                return true
            default:
                return false
            }
        }

        func matchesDisplayableTab(_ other: TabContent) -> Bool {
            switch (self, other) {
            case (.settings, .settings):
                return true
            case (.bookmarks, .bookmarks):
                return true
            case (.dataBrokerProtection, .dataBrokerProtection):
                return true
            default:
                return false
            }
        }

        var title: String? {
            switch self {
            case .url, .newtab, .none: return nil
            case .settings: return UserText.tabPreferencesTitle
            case .bookmarks: return UserText.tabBookmarksTitle
            case .onboarding: return UserText.tabOnboardingTitle
            case .dataBrokerProtection: return UserText.tabDataBrokerProtectionTitle
            case .subscription: return nil
            }
        }

        var url: URL? {
            userEditableUrl
        }
        var userEditableUrl: URL? {
            switch self {
            case .url(let url, credential: _, source: _) where !(url.isDuckPlayer || url.isDuckURLScheme):
                return url
            default:
                return nil
            }
        }

        var urlForWebView: URL? {
            switch self {
            case .url(let url, credential: _, source: _):
                return url
            case .newtab:
                return .newtab
            case .settings(pane: .some(let pane)):
                return .settingsPane(pane)
            case .settings(pane: .none):
                return .settings
            case .bookmarks:
                return .bookmarks
            case .onboarding:
                return .welcome
            case .dataBrokerProtection:
                return .dataBrokerProtection
            case .subscription(let url):
                return url
            case .none:
                return nil
            }
        }

        var isUrl: Bool {
            switch self {
            case .url, .subscription:
                return true
            default:
                return false
            }
        }

        var userEnteredValue: String? {
            switch self {
            case .url(_, credential: _, source: let source):
                return source.userEnteredValue
            default:
                return nil
            }
        }

        var isUserEnteredUrl: Bool {
            userEnteredValue != nil
        }

        var isUserRequestedPageDownload: Bool {
            if case .url(_, credential: _, source: .userEntered(_, downloadRequested: true)) = self {
                return true
            } else {
                return false
            }
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
    let pinnedTabsManager: PinnedTabsManager

#if NETWORK_PROTECTION
    private var tunnelController: NetworkProtectionIPCTunnelController?
#endif

    private let webViewConfiguration: WKWebViewConfiguration

    let startupPreferences: StartupPreferences

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
                     burnerMode: BurnerMode = .regular,
                     canBeClosedWithBack: Bool = false,
                     lastSelectedAt: Date? = nil,
                     webViewSize: CGSize = CGSize(width: 1024, height: 768),
                     startupPreferences: StartupPreferences = StartupPreferences.shared
    ) {

        let duckPlayer = duckPlayer
            ?? (NSApp.runType.requiresEnvironment ? DuckPlayer.shared : DuckPlayer.mock(withMode: .enabled))
        let statisticsLoader = statisticsLoader
            ?? (NSApp.runType.requiresEnvironment ? StatisticsLoader.shared : nil)
        let privacyFeatures = privacyFeatures ?? PrivacyFeatures
        let internalUserDecider = NSApp.delegateTyped.internalUserDecider
        var faviconManager = faviconManagement
        if burnerMode.isBurner {
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
                  burnerMode: burnerMode,
                  canBeClosedWithBack: canBeClosedWithBack,
                  lastSelectedAt: lastSelectedAt,
                  webViewSize: webViewSize,
                  startupPreferences: startupPreferences)
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
         burnerMode: BurnerMode,
         canBeClosedWithBack: Bool,
         lastSelectedAt: Date?,
         webViewSize: CGSize,
         startupPreferences: StartupPreferences
    ) {

        self.content = content
        self.faviconManagement = faviconManagement
        self.pinnedTabsManager = pinnedTabsManager
        self.statisticsLoader = statisticsLoader
        self.internalUserDecider = internalUserDecider
        self.title = title
        self.favicon = favicon
        self.parentTab = parentTab
        self.burnerMode = burnerMode
        self._canBeClosedWithBack = canBeClosedWithBack
        self.interactionState = interactionStateData.map(InteractionState.loadCachedFromTabContent) ?? .none
        self.lastSelectedAt = lastSelectedAt
        self.startupPreferences = startupPreferences

        let configuration = webViewConfiguration ?? WKWebViewConfiguration()
        configuration.applyStandardConfiguration(contentBlocking: privacyFeatures.contentBlocking,
                                                 burnerMode: burnerMode)
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
                          isTabBurner: burnerMode.isBurner,
                          contentPublisher: _content.projectedValue.eraseToAnyPublisher(),
                          setContent: { tabGetter()?.setContent($0) },
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

        emailDidSignOutCancellable = NotificationCenter.default.publisher(for: .emailDidSignOut)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.onDuckDuckGoEmailSignOut(notification)
            }

#if NETWORK_PROTECTION
        netPOnboardStatusCancellabel = DefaultNetworkProtectionVisibility().onboardStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] onboardingStatus in
                guard onboardingStatus == .completed else { return }

                let machServiceName = Bundle.main.vpnMenuAgentBundleId
                let ipcClient = TunnelControllerIPCClient(machServiceName: machServiceName)
                ipcClient.register()

                self?.tunnelController = NetworkProtectionIPCTunnelController(ipcClient: ipcClient)
            }
#endif

        self.audioState = webView.audioState()
        addDeallocationChecks(for: webView)
    }

#if DEBUG
    func addDeallocationChecks(for webView: WKWebView) {
        let processPool = webView.configuration.processPool
        let webViewValue = NSValue(nonretainedObject: webView)

        webView.onDeinit { [weak self] in
            // Tab should deallocate with the WebView
            self?.ensureObjectDeallocated(after: 1.0, do: .interrupt)

            // unregister WebView from the ProcessPool
            processPool.webViewsUsingProcessPool.remove(webViewValue)

            if processPool.webViewsUsingProcessPool.isEmpty {
                // when the last WebView is deallocated the ProcessPool should be deallocated
                processPool.ensureObjectDeallocated(after: 1, do: .log)
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
            webView.stopAllMedia(shouldStopLoading: true)

            userContentController?.cleanUpBeforeClosing()
#if DEBUG
            if case .normal = NSApp.runType {
                webView.assertObjectDeallocated(after: 4.0)
            }
#endif
        }
#if DEBUG
        if !onDeinit, case .normal = NSApp.runType {
            // Tab should be deallocated shortly after burning
            self.assertObjectDeallocated(after: 4.0)
        }
#endif
        guard Thread.isMainThread else {
            DispatchQueue.main.async { job() }
            return
        }
        job()
    }

    func stopAllMediaAndLoading() {
        webView.stopAllMedia(shouldStopLoading: true)
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

    let webViewDidStartNavigationPublisher = PassthroughSubject<Void, Never>()
    let webViewDidReceiveUserInteractiveChallengePublisher = PassthroughSubject<Void, Never>()
    let webViewDidReceiveRedirectPublisher = PassthroughSubject<Void, Never>()
    let webViewDidCommitNavigationPublisher = PassthroughSubject<Void, Never>()
    let webViewDidFinishNavigationPublisher = PassthroughSubject<Void, Never>()

    // MARK: - Properties

    let webView: WebView

    var contentChangeEnabled = true

    var isLazyLoadingInProgress = false

    let burnerMode: BurnerMode

    @PublishedAfter private(set) var content: TabContent {
        didSet {
            if !content.displaysContentInWebView && oldValue.displaysContentInWebView {
                webView.stopAllMedia(shouldStopLoading: false)
            }
            handleFavicon(oldValue: oldValue)
            if navigationDelegate.currentNavigation == nil {
                updateCanGoBackForward(withCurrentNavigation: nil)
            }
            error = nil
        }
    }

    @discardableResult
    func setContent(_ newContent: TabContent) -> ExpectedNavigation? {
        guard contentChangeEnabled else { return nil }

        let oldContent = self.content
        let newContent: TabContent = {
            if case .settings(pane: .some) = oldContent,
               case .settings(pane: nil) = newContent {
                // prevent clearing currently selected pane (for state persistence purposes)
                return oldContent
            }
            return newContent
        }()

        // reload if content differs or user-entered
        guard newContent != self.content || newContent.isUserEnteredUrl else { return nil }
        self.content = newContent

        dismissPresentedAlert()

        if let title = content.title {
            self.title = title
        }

        return reloadIfNeeded(shouldLoadInBackground: true)
    }

    @discardableResult
    func setUrl(_ url: URL?, source: TabContent.URLSource) -> ExpectedNavigation? {
        return self.setContent(.contentFromURL(url, source: source))
    }

    private func handleUrlDidChange() {
        if let url = webView.url {
            let content = TabContent.contentFromURL(url, source: .webViewUpdated)

            if self.content.isUrl, self.content.url == url {
                // ignore content updates when tab.content has userEntered or credential set but equal url as it comes from the WebView url updated event
            } else if content != self.content {
                self.content = content
            }
        } else if self.content.isUrl {
            self.content = .none
        }
        self.updateTitle() // The title might not change if webView doesn't think anything is different so update title here as well
    }

    var lastSelectedAt: Date?

    @Published var title: String?

    private func updateTitle() {
        if let error {
            if error.code != .webContentProcessTerminated {
                self.title = nil
            }
            return
        }

        self.title = webView.title?.trimmingWhitespace()

        if let wkBackForwardListItem = webView.backForwardList.currentItem,
           content.urlForWebView == wkBackForwardListItem.url,
           !webView.isLoading,
           title?.isEmpty == false {
            wkBackForwardListItem.tabTitle = title
        }
    }

    @PublishedAfter var error: WKError? {
        didSet {
            updateTitle()
        }
    }
    let permissions: PermissionModel

    @Published private(set) var lastWebError: Error?
    @Published private(set) var lastHttpStatusCode: Int?

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
        case loadCachedFromTabContent(Data)
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

    @MainActor
    var backHistoryItems: [BackForwardListItem] {
        [BackForwardListItem](webView.backForwardList.backList)
        + (canBeClosedWithBack ? [BackForwardListItem(kind: .goBackToClose(parentTab?.url), title: parentTab?.title, identity: nil)] : [])
    }
    @MainActor
    var currentHistoryItem: BackForwardListItem? {
        webView.backForwardList.currentItem.map(BackForwardListItem.init)
        ?? (content.url ?? navigationDelegate.currentNavigation?.url).map { url in
            BackForwardListItem(kind: .url(url), title: webView.title ?? title, identity: nil)
        }
    }
    @MainActor
    var forwardHistoryItems: [BackForwardListItem] {
        [BackForwardListItem](webView.backForwardList.forwardList)
    }

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

        let canGoBack = webView.canGoBack
        let canGoForward = webView.canGoForward
        let canReload = self.content.userEditableUrl != nil

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

        userInteractionDialog = nil
        let navigation = webView.navigator()?.goBack(withExpectedNavigationType: .backForward(distance: -1))
        // update TabContent source to .historyEntry on navigation
        navigation?.appendResponder(willStart: { [weak self] navigation in
            guard let self,
                  case .url(let url, credential: let credential, .webViewUpdated) = self.content,
                  url == navigation.url else { return }
            self.content = .url(url, credential: credential, source: .historyEntry)
        })
        return navigation
    }

    @MainActor
    @discardableResult
    func goForward() -> ExpectedNavigation? {
        guard canGoForward else { return nil }

        userInteractionDialog = nil
        let navigation = webView.navigator()?.goForward(withExpectedNavigationType: .backForward(distance: 1))
        // update TabContent source to .historyEntry on navigation
        navigation?.appendResponder(willStart: { [weak self] navigation in
            guard let self,
                  case .url(let url, credential: let credential, _) = self.content,
                  url == navigation.url else { return }
            self.content = .url(url, credential: credential, source: .historyEntry)
        })
        return navigation
    }

    @MainActor
    @discardableResult
    func go(to item: BackForwardListItem) -> ExpectedNavigation? {
        userInteractionDialog = nil

        switch item.kind {
        case .goBackToClose:
            delegate?.closeTab(self)
            return nil

        case .url: break
        }

        var backForwardNavigation: (distance: Int, item: WKBackForwardListItem)? {
            guard let identity = item.identity else { return nil }

            let backForwardList = webView.backForwardList
            if let backItem = backForwardList.backItem, backItem.identity == identity {
                return (-1, backItem)
            } else if let forwardItem = backForwardList.forwardItem, forwardItem.identity == identity {
                return (1, forwardItem)
            } else if backForwardList.currentItem?.identity == identity {
                return nil
            }

            let forwardList = backForwardList.forwardList
            if let forwardIndex = forwardList.firstIndex(where: { $0.identity == identity }) {
                return (forwardIndex + 1, forwardList[forwardIndex]) // going forward, adding 1 to zero based index
            }

            let backList = backForwardList.backList
            if let backIndex = backList.lastIndex(where: { $0.identity == identity }) {
                return (-(backList.count - backIndex), backList[backIndex]) // item is in _reversed_ backList
            }

            return nil

        }

        guard let backForwardNavigation else {
            os_log(.error, "item `\(item.title ?? "") – \(item.url?.absoluteString ?? "")` is not in the backForwardList")
            return nil
        }

        let navigation = webView.navigator()?.go(to: backForwardNavigation.item,
                                                 withExpectedNavigationType: .backForward(distance: backForwardNavigation.distance))
        // update TabContent source to .historyEntry on navigation
        navigation?.appendResponder(willStart: { [weak self] navigation in
            guard let self,
                  case .url(let url, credential: let credential, _) = self.content,
                  url == navigation.url else { return }
            self.content = .url(url, credential: credential, source: .historyEntry)
        })
        return navigation
    }

    func openHomePage() {
        userInteractionDialog = nil

        if startupPreferences.launchToCustomHomePage,
           let customURL = URL(string: startupPreferences.formattedCustomHomePageURL) {
            setContent(.url(customURL, credential: nil, source: .ui))
        } else {
            setContent(.newtab)
        }
    }

    func startOnboarding() {
        userInteractionDialog = nil

        setContent(.onboarding)
    }

    @MainActor(unsafe)
    @discardableResult
    func reload() -> ExpectedNavigation? {
        userInteractionDialog = nil

        // In the case of an error only reload web URLs to prevent uxss attacks via redirecting to javascript://
        if let error = error,
           let failingUrl = error.failingUrl ?? content.urlForWebView,
           failingUrl.isHttp || failingUrl.isHttps,
           // navigate in-place to preserve back-forward history
           // launch navigation using javascript: URL navigation to prevent WebView from
           // interpreting the action as user-initiated link navigation causing a new tab opening when Cmd is pressed
           let redirectUrl = URL(string: "javascript:location.replace('\(failingUrl.absoluteString.escapedJavaScriptString())')") {

            self.content = .url(failingUrl, credential: nil, source: .reload)
            webView.load(URLRequest(url: redirectUrl))
            return nil
        }

        self.content = content.forceReload()
        if webView.url == nil, content.isUrl {
            // load from cache or interactionStateData when called by lazy loader
            return reloadIfNeeded(shouldLoadInBackground: true)
        } else {
            return webView.navigator(distributedNavigationDelegate: navigationDelegate).reload(withExpectedNavigationType: .reload)
        }
    }

    @Published private(set) var audioState: WKWebView.AudioState = .notSupported

    func muteUnmuteTab() {
        webView.muteOrUnmute()

        audioState = webView.audioState()
    }

    private func tabContentReloadInfo(for content: TabContent, shouldLoadInBackground: Bool) -> (url: URL, source: TabContent.URLSource, forceReload: Bool)? {
        switch content {
        case .url(let url, _, source: let source):
            let forceReload = url.absoluteString == source.userEnteredValue ? shouldLoadInBackground : (source == .reload)
            return (url, source, forceReload: forceReload)

        case .subscription(let url):
            return (url, .ui, forceReload: false)

        case .newtab, .bookmarks, .onboarding, .dataBrokerProtection, .settings:
            guard let contentUrl = content.urlForWebView, webView.url != contentUrl else { return nil }

            return (contentUrl, .ui, forceReload: true) // always navigate built-in ui (duck://) urls

        case .none:
            return nil
        }
    }

    @MainActor(unsafe)
    @discardableResult
    private func reloadIfNeeded(shouldLoadInBackground: Bool = false) -> ExpectedNavigation? {
        guard let (url, source, forceReload) = tabContentReloadInfo(for: content, shouldLoadInBackground: shouldLoadInBackground),
              forceReload || shouldReload(url, shouldLoadInBackground: shouldLoadInBackground) else { return nil }

        if case .settings = content, case .settings = webView.url.flatMap({ TabContent.contentFromURL($0, source: .ui) }) {
            // replace WebView URL without adding a new history item if switching settings panes
            webView.evaluateJavaScript("location.replace('\(url.absoluteString.escapedJavaScriptString())')", in: nil, in: .defaultClient)
            return nil
        }

        if webView.url == url, webView.backForwardList.currentItem?.url == url, !webView.isLoading, !content.isUserRequestedPageDownload {
            return reload()
        }
        if restoreInteractionStateIfNeeded() { return nil /* session restored */ }
        invalidateInteractionStateData()

        if url.isFileURL {
            return webView.navigator(distributedNavigationDelegate: navigationDelegate)
                .loadFileURL(url, allowingReadAccessTo: URL(fileURLWithPath: "/"), withExpectedNavigationType: source.navigationType)
        }

        var request = URLRequest(url: url, cachePolicy: source.cachePolicy)
        if #available(macOS 12.0, *), content.isUserEnteredUrl {
            request.attribution = .user
        }

        return webView.navigator(distributedNavigationDelegate: navigationDelegate)
            .load(request, withExpectedNavigationType: source.navigationType)
    }

    @MainActor
    private func shouldReload(_ url: URL, shouldLoadInBackground: Bool) -> Bool {
        // don‘t reload in background unless shouldLoadInBackground
        guard url.isValid,
              webView.superview != nil || shouldLoadInBackground,
              // don‘t reload when already loaded
              webView.url != url || error != nil else { return false }

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
    private func restoreInteractionStateIfNeeded() -> Bool {
        // only restore session from interactionStateData passed to Tab.init
        guard case .loadCachedFromTabContent(let interactionStateData) = self.interactionState else { return false }

        if let url = content.urlForWebView, url.isFileURL {
            // request file system access before restoration
            webView.navigator(distributedNavigationDelegate: navigationDelegate)
                .loadFileURL(url, allowingReadAccessTo: url)?
                .overrideResponders(navigationDidFinish: { [weak self] _ in
                    self?.restoreInteractionState(with: interactionStateData)
                }, navigationDidFail: { [weak self] _, _ in
                    self?.restoreInteractionState(with: interactionStateData)
                })
        } else {
            restoreInteractionState(with: interactionStateData)
        }

        invalidateInteractionStateData()

        return true
    }

    private func restoreInteractionState(with interactionStateData: Data) {
        guard #available(macOS 12.0, *) else {
            try? webView.restoreSessionState(from: interactionStateData)
            return
        }
        webView.interactionState = interactionStateData
    }

    private func addHomePageToWebViewIfNeeded() {
        guard NSApp.runType.requiresEnvironment else { return }
        if content == .newtab && webView.url == nil {
            webView.load(URLRequest(url: .newtab))
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
    private var emailDidSignOutCancellable: AnyCancellable?

#if NETWORK_PROTECTION
    private var netPOnboardStatusCancellabel: AnyCancellable?
#endif

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
                self?.reloadIfNeeded()
            }
        }.store(in: &webViewCancellables)

        webView.publisher(for: \.url)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
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
        DispatchQueue.main.async {
            self.reloadIfNeeded(shouldLoadInBackground: shouldLoadInBackground)
            if !shouldLoadInBackground {
                self.addHomePageToWebViewIfNeeded()
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

    @MainActor(unsafe)
    private func handleFavicon(oldValue: TabContent? = nil) {
        guard content.isUrl, let url = content.urlForWebView, error == nil else {
            favicon = nil
            return
        }

        if url.isDuckPlayer {
            favicon = .duckPlayer
            return
        }

        guard faviconManagement.areFaviconsLoaded else { return }

        if let cachedFavicon = faviconManagement.getCachedFavicon(for: url, sizeCategory: .small)?.image {
            if cachedFavicon != favicon {
                favicon = cachedFavicon
            }
        } else if oldValue?.url?.host != url.host {
            // If the domain matches the previous value, just keep the same favicon
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

    @MainActor(unsafe)
    func faviconUserScript(_ faviconUserScript: FaviconUserScript,
                           didFindFaviconLinks faviconLinks: [FaviconUserScript.FaviconLink],
                           for documentUrl: URL) {
        guard documentUrl != .error else { return }
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
        if case .url(let url, credential: .some(let credential), source: let source) = content,
           url.matches(challenge.protectionSpace),
           challenge.previousFailureCount == 0 {

            self.content = .url(url, source: source)
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

    func didReceiveRedirect(_ navigationAction: NavigationAction, for navigation: Navigation) {
        webViewDidReceiveRedirectPublisher.send()
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
                self.content = .url(navigationAction.url.removingBasicAuthCredential(), credential: credential, source: .webViewUpdated)
                // reload URL without credentialss
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
        if lastWebError != nil { lastWebError = nil }

        delegate?.tabWillStartNavigation(self, isUserInitiated: navigation.navigationAction.isUserInitiated)
    }

    @MainActor
    func decidePolicy(for navigationResponse: NavigationResponse) async -> NavigationResponsePolicy? {
        internalUserDecider?.markUserAsInternalIfNeeded(forUrl: webView.url,
                                                        response: navigationResponse.response as? HTTPURLResponse)

        lastHttpStatusCode = navigationResponse.httpStatusCode

        return .next
    }

    @MainActor
    func didStart(_ navigation: Navigation) {
        webViewDidStartNavigationPublisher.send()
        delegate?.tabDidStartNavigation(self)
        permissions.tabDidStartNavigation()
        userInteractionDialog = nil

        // Unnecessary assignment triggers publishing
        if lastWebError != nil { lastWebError = nil }
        if error != nil,
           navigation.navigationAction.navigationType != .alternateHtmlLoad { // error page navigation
            error = nil
        }

        invalidateInteractionStateData()
    }

    @MainActor
    func navigationDidFinish(_ navigation: Navigation) {
        invalidateInteractionStateData()
        webViewDidFinishNavigationPublisher.send()
        statisticsLoader?.refreshRetentionAtb(isSearch: navigation.url.isDuckDuckGoSearch)

#if NETWORK_PROTECTION
        if navigation.url.isDuckDuckGoSearch, tunnelController?.isConnected == true {
            DailyPixel.fire(pixel: .networkProtectionEnabledOnSearch, frequency: .dailyAndCount, includeAppVersionParameter: true)
        }
#endif
    }

    @MainActor
    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        invalidateInteractionStateData()

        let url = error.failingUrl ?? navigation.url
        if navigation.isCurrent,
           !error.isFrameLoadInterrupted, !error.isNavigationCancelled,
           // don‘t show an error page if the error was already handled
           // (by SearchNonexistentDomainNavigationResponder) or another navigation was triggered by `setContent`
           self.content.urlForWebView == url {

            self.error = error
            // when already displaying the error page and reload navigation fails again: don‘t navigate, just update page HTML
            let shouldPerformAlternateNavigation = navigation.url != webView.url || navigation.navigationAction.targetFrame?.url != .error
            loadErrorHTML(error, header: UserText.errorPageHeader, forUnreachableURL: url, alternate: shouldPerformAlternateNavigation)
        }
    }

    @MainActor
    func didFailProvisionalLoad(with request: URLRequest, in frame: WKFrameInfo, with error: Error) {
        lastWebError = error
    }

    @MainActor
    func webContentProcessDidTerminate(with reason: WKProcessTerminationReason?) {
        let error = WKError(.webContentProcessTerminated, userInfo: [
            WKProcessTerminationReason.userInfoKey: reason?.rawValue ?? -1,
            NSLocalizedDescriptionKey: UserText.webProcessCrashPageMessage,
        ])

        if case.url(let url, _, _) = content {
            self.error = error

            loadErrorHTML(error, header: UserText.webProcessCrashPageHeader, forUnreachableURL: url, alternate: true)
        }

        Pixel.fire(.debug(event: .webKitDidTerminate, error: error))
    }

    @MainActor
    private func loadErrorHTML(_ error: WKError, header: String, forUnreachableURL url: URL, alternate: Bool) {
        let html = ErrorPageHTMLTemplate(error: error, header: header).makeHTMLFromTemplate()
        if alternate {
            webView.loadAlternateHTML(html, baseURL: .error, forUnreachableURL: url)
        } else {
            // this should be updated using an error page update script call when (if) we have a dynamic error page content implemented
            webView.setDocumentHtml(html)
        }
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
    func prepareForDataClearing(caller: TabCleanupPreparer) {
        webViewCancellables.removeAll()

        self.stopAllMediaAndLoading()
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

// swiftlint:enable file_length
