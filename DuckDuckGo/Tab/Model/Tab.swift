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
import Foundation
import History
import MaliciousSiteProtection
import Navigation
import Onboarding
import os.log
import PageRefreshMonitor
import PixelKit
import SpecialErrorPages
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

@dynamicMemberLookup final class Tab: NSObject, Identifiable, ObservableObject {

    private struct ExtensionDependencies: TabExtensionDependencies {
        let privacyFeatures: PrivacyFeaturesProtocol
        let historyCoordinating: HistoryCoordinating
        var workspace: Workspace
        var cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?
        let duckPlayer: DuckPlayer
        var downloadManager: FileDownloadManagerProtocol
        var certificateTrustEvaluator: CertificateTrustEvaluating
        var tunnelController: NetworkProtectionIPCTunnelController?
        var maliciousSiteDetector: MaliciousSiteDetecting
    }

    fileprivate weak var delegate: TabDelegate?
    func setDelegate(_ delegate: TabDelegate) { self.delegate = delegate }

    private let navigationDelegate = DistributedNavigationDelegate()
    private var newWindowPolicyDecisionMakers: [NewWindowPolicyDecisionMaker]?
    private var onNewWindow: ((WKNavigationAction?) -> NavigationDecision)?

    private let statisticsLoader: StatisticsLoader?
    private let onboardingPixelReporter: OnboardingAddressBarReporting
    private let internalUserDecider: InternalUserDecider?
    private let pageRefreshMonitor: PageRefreshMonitoring
    private let featureFlagger: FeatureFlagger
    let pinnedTabsManager: PinnedTabsManager

    private let webViewConfiguration: WKWebViewConfiguration

    let startupPreferences: StartupPreferences
    let tabsPreferences: TabsPreferences
    let reloadPublisher = PassthroughSubject<Void, Never>()
    let navigationDidEndPublisher = PassthroughSubject<Tab, Never>()

    private var extensions: TabExtensions
    // accesing TabExtensions‘ Public Protocols projecting tab.extensions.extensionName to tab.extensionName
    // allows extending Tab functionality while maintaining encapsulation
    subscript<Extension>(dynamicMember keyPath: KeyPath<TabExtensions, Extension?>) -> Extension? {
        self.extensions[keyPath: keyPath]
    }

    private(set) var userContentController: UserContentController?
    private(set) var specialPagesUserScript: SpecialPagesUserScript?

    @MainActor
    convenience init(content: TabContent,
                     faviconManagement: FaviconManagement? = nil,
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
                     featureFlagger: FeatureFlagger? = nil,
                     title: String? = nil,
                     favicon: NSImage? = nil,
                     interactionStateData: Data? = nil,
                     parentTab: Tab? = nil,
                     securityOrigin: SecurityOrigin? = nil,
                     shouldLoadInBackground: Bool = false,
                     burnerMode: BurnerMode = .regular,
                     canBeClosedWithBack: Bool = false,
                     lastSelectedAt: Date? = nil,
                     webViewSize: CGSize = CGSize(width: 1024, height: 768),
                     startupPreferences: StartupPreferences = StartupPreferences.shared,
                     certificateTrustEvaluator: CertificateTrustEvaluating = CertificateTrustEvaluator(),
                     tunnelController: NetworkProtectionIPCTunnelController? = TunnelControllerProvider.shared.tunnelController,
                     maliciousSiteDetector: MaliciousSiteDetecting = MaliciousSiteProtectionManager.shared,
                     tabsPreferences: TabsPreferences = TabsPreferences.shared,
                     onboardingPixelReporter: OnboardingAddressBarReporting = OnboardingPixelReporter(),
                     pageRefreshMonitor: PageRefreshMonitoring = PageRefreshMonitor(onDidDetectRefreshPattern: PageRefreshMonitor.onDidDetectRefreshPattern)
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
                  faviconManagement: faviconManager ?? FaviconManager.shared,
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
                  featureFlagger: featureFlagger ?? NSApp.delegateTyped.featureFlagger,
                  cbaTimeReporter: cbaTimeReporter,
                  statisticsLoader: statisticsLoader,
                  internalUserDecider: internalUserDecider,
                  title: title,
                  favicon: favicon,
                  interactionStateData: interactionStateData,
                  parentTab: parentTab,
                  securityOrigin: securityOrigin,
                  shouldLoadInBackground: shouldLoadInBackground,
                  burnerMode: burnerMode,
                  canBeClosedWithBack: canBeClosedWithBack,
                  lastSelectedAt: lastSelectedAt,
                  webViewSize: webViewSize,
                  startupPreferences: startupPreferences,
                  certificateTrustEvaluator: certificateTrustEvaluator,
                  tunnelController: tunnelController,
                  maliciousSiteDetector: maliciousSiteDetector,
                  tabsPreferences: tabsPreferences,
                  onboardingPixelReporter: onboardingPixelReporter,
                  pageRefreshMonitor: pageRefreshMonitor)
    }

    @MainActor
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
         featureFlagger: FeatureFlagger,
         cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?,
         statisticsLoader: StatisticsLoader?,
         internalUserDecider: InternalUserDecider?,
         title: String?,
         favicon: NSImage?,
         interactionStateData: Data?,
         parentTab: Tab?,
         securityOrigin: SecurityOrigin? = nil,
         shouldLoadInBackground: Bool,
         burnerMode: BurnerMode,
         canBeClosedWithBack: Bool,
         lastSelectedAt: Date?,
         webViewSize: CGSize,
         startupPreferences: StartupPreferences,
         certificateTrustEvaluator: CertificateTrustEvaluating,
         tunnelController: NetworkProtectionIPCTunnelController?,
         maliciousSiteDetector: MaliciousSiteDetecting,
         tabsPreferences: TabsPreferences,
         onboardingPixelReporter: OnboardingAddressBarReporting,
         pageRefreshMonitor: PageRefreshMonitoring
    ) {

        self.content = content
        self.faviconManagement = faviconManagement
        self.pinnedTabsManager = pinnedTabsManager
        self.featureFlagger = featureFlagger
        self.statisticsLoader = statisticsLoader
        self.internalUserDecider = internalUserDecider
        self.title = title
        self.favicon = favicon
        self.parentTab = parentTab
        self.securityOrigin = securityOrigin ?? .empty
        self.burnerMode = burnerMode
        self._canBeClosedWithBack = canBeClosedWithBack
        self.interactionState = interactionStateData.map(InteractionState.loadCachedFromTabContent) ?? .none
        self.lastSelectedAt = lastSelectedAt
        self.startupPreferences = startupPreferences
        self.tabsPreferences = tabsPreferences

        self.specialPagesUserScript = SpecialPagesUserScript()
        specialPagesUserScript?
            .withAllSubfeatures()
        let configuration = webViewConfiguration ?? WKWebViewConfiguration()
        configuration.applyStandardConfiguration(contentBlocking: privacyFeatures.contentBlocking,
                                                 burnerMode: burnerMode,
                                                 earlyAccessHandlers: specialPagesUserScript.map { [$0] } ?? [])
        self.webViewConfiguration = configuration
        let userContentController = configuration.userContentController as? UserContentController
        assert(userContentController != nil)
        self.userContentController = userContentController
        self.onboardingPixelReporter = onboardingPixelReporter
        self.pageRefreshMonitor = pageRefreshMonitor

        webView = WebView(frame: CGRect(origin: .zero, size: webViewSize), configuration: configuration)
        webView.allowsLinkPreview = false
        webView.addsVisitedLinks = true

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
                          closeTab: {
                guard let tab = tabGetter() else { return }
                tab.delegate?.closeTab(tab)
            },
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
                                                       downloadManager: downloadManager,
                                                       certificateTrustEvaluator: certificateTrustEvaluator,
                                                       tunnelController: tunnelController,
                                                       maliciousSiteDetector: maliciousSiteDetector))

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
        DispatchQueue.main.asyncOrNow { [webView, userContentController] in
            // WebKit objects must be deallocated on the main thread
            webView.stopAllMedia(shouldStopLoading: true)

            userContentController?.cleanUpBeforeClosing()
#if DEBUG
            if case .normal = NSApp.runType {
                webView.assertObjectDeallocated(after: 4.0)
            }
#endif
        }
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

    /// Publishes currently active main frame Navigation state
    var navigationStatePublisher: some Publisher<NavigationState?, Never> {
        navigationDelegate.$currentNavigation.map { currentNavigation -> AnyPublisher<NavigationState?, Never> in
            MainActor.assumeIsolated {
                currentNavigation?.$state.map { $0 }.eraseToAnyPublisher() ?? Just(nil).eraseToAnyPublisher()
            }
        }.switchToLatest()
    }

    var webViewDidStartNavigationPublisher: some Publisher<Void, Never> {
        navigationStatePublisher
            .compactMap { $0 }
            .filter { $0 == .started }
            .asVoid()
    }

    var webViewDidFinishNavigationPublisher: some Publisher<Void, Never> {
        navigationStatePublisher
            .combineLatest(navigationDelegate.$currentNavigation)
            .filter { navigationState, currentNavigation in
                guard let navigationState = navigationState, navigationState.isFinished else {
                    return false
                }
                guard let currentNavigation = currentNavigation else {
                    return false
                }
                return MainActor.assumeIsolated {
                    let isSameDocumentNavigation = (currentNavigation.redirectHistory.first ?? currentNavigation.navigationAction).navigationType.isSameDocumentNavigation
                    return !isSameDocumentNavigation
                }
            }
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    // MARK: - Properties

    let webView: WebView

    var audioState: WebView.AudioState {
        webView.audioState
    }

    @Published private(set) var audioStateTest: WebView.AudioState = .unmuted(isPlayingAudio: false)

    var audioStatePublisher: AnyPublisher<WebView.AudioState, Never> {
        webView.audioStatePublisher
    }

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
#if !APPSTORE
            if #available(macOS 14.4, *) {
                WebExtensionManager.shared.eventsListener.didChangeTabProperties([.URL], for: self)
            }
#endif
        }
    }

    /// Currently committed page security origin (protocol, host, port).
    ///
    /// Set to the opener location security origin for popup Tabs.
    /// Used to safely update the Address Bar displayed URL to protect from spoofing attacks
    ///
    /// see https://github.com/mozilla-mobile/firefox-ios/wiki/WKWebView-navigation-and-security-considerations
    @Published private(set) var securityOrigin: SecurityOrigin = .empty

    /// Set to true when the Tab‘s first navigation is committed
    @Published var hasCommittedContent = false

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

        if error != nil { error = nil }

        return reloadIfNeeded(source: .contentUpdated)
    }

    @discardableResult
    func setUrl(_ url: URL?, source: TabContent.URLSource) -> ExpectedNavigation? {
        return self.setContent(.contentFromURL(url, source: source))
    }

    private func handleUrlDidChange() {
        if let url = webView.url {
            let content = TabContent.contentFromURL(url, source: .webViewUpdated)

            if self.content.isUrl, self.content.urlForWebView == url {
                // ignore content updates when tab.content has userEntered or credential set but equal url as it comes from the WebView url updated event
            } else if content != self.content {
                self.content = content
            }
        } else if self.content.isUrl,
                  // DuckURLSchemeHandler redirects duck:// address to a simulated request
                  // ignore webView.url temporarily switching to `nil`
                  self.content.urlForWebView?.isDuckPlayer != true {
            // when e.g. opening a download in new tab - web view restores `nil` after the navigation is interrupted
            // maybe it worths adding another content type like .interruptedLoad(URL) to display a URL in the address bar
            self.content = .none
        }
        self.updateTitle() // The title might not change if webView doesn't think anything is different so update title here as well
    }

    var lastSelectedAt: Date?

    @Published var title: String? {
        didSet {
#if !APPSTORE
            if #available(macOS 14.4, *) {
                WebExtensionManager.shared.eventsListener.didChangeTabProperties([.title], for: self)
            }
#endif
        }
    }

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

    @Published private(set) var isLoading: Bool = false {
        didSet {
#if !APPSTORE
            if #available(macOS 14.4, *) {
                WebExtensionManager.shared.eventsListener.didChangeTabProperties([.loading], for: self)
            }
#endif
        }
    }
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
        ?? (content.urlForWebView ?? navigationDelegate.currentNavigation?.url).map { url in
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
        let canReload = {
            switch content {
            case .url(let url, _, _):
                return !(url.isDuckPlayer || url.isDuckURLScheme)
            case .history:
                return true
            default:
                return false
            }
        }()

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
        guard canGoBack, let backItem = webView.backForwardList.backItem else {
            if canBeClosedWithBack {
                delegate?.closeTab(self)
            }
            return nil
        }

        userInteractionDialog = nil
        let navigation = webView.navigator()?.go(to: backItem, withExpectedNavigationType: .backForward(distance: -1))
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
        guard canGoForward, let forwardItem = webView.backForwardList.forwardItem else { return nil }

        userInteractionDialog = nil
        let navigation = webView.navigator()?.go(to: forwardItem, withExpectedNavigationType: .backForward(distance: 1))
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
            Logger.navigation.error("item `\(item.title ?? "") – \(item.url?.absoluteString ?? "")` is not in the backForwardList")
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
            setContent(.contentFromURL(customURL, source: .ui))
        } else {
            setContent(.newtab)
        }
    }

    @MainActor
    func startOnboarding() {
        userInteractionDialog = nil

#if DEBUG || REVIEW
        if Application.runType == .uiTestsOnboarding {
            setContent(.onboarding)
            return
        }
#endif
        if PixelExperiment.cohort == .newOnboarding {
            Application.appDelegate.onboardingStateMachine.state = .notStarted
            setContent(.onboarding)
        } else {
            setContent(.onboardingDeprecated)
        }
    }

    @MainActor(unsafe)
    @discardableResult
    func reload() -> ExpectedNavigation? {
        userInteractionDialog = nil

        self.brokenSiteInfo?.tabReloadRequested()
        reloadPublisher.send()
        if let url = webView.url {
            pageRefreshMonitor.register(for: url)
        }

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
            return reloadIfNeeded(source: .lazyLoad)
        } else {
            return webView.navigator(distributedNavigationDelegate: navigationDelegate).reload(withExpectedNavigationType: .reload)
        }
    }

    func muteUnmuteTab() {
        webView.audioState.toggle()
        objectWillChange.send()

#if !APPSTORE
        if #available(macOS 14.4, *) {
            WebExtensionManager.shared.eventsListener.didChangeTabProperties([.muted], for: self)
        }
#endif
    }

    private enum ReloadIfNeededSource {
        case contentUpdated
        case webViewDisplayed
        case loadInBackgroundIfNeeded(shouldLoadInBackground: Bool)
        case lazyLoad
    }
    @MainActor(unsafe)
    @discardableResult
    private func reloadIfNeeded(source reloadIfNeededSource: ReloadIfNeededSource) -> ExpectedNavigation? {
        guard let url = content.urlForWebView,
              shouldReload(url, source: reloadIfNeededSource) else { return nil }

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

        let source = content.source
        if url.isFileURL {
            // WebKit won‘t load local page‘s external resouces even with `allowingReadAccessTo` provided
            // this could be fixed using a custom scheme handler loading local resources in future.
            let readAccessScopeURL = url
            return webView.navigator(distributedNavigationDelegate: navigationDelegate)
                .loadFileURL(url, allowingReadAccessTo: readAccessScopeURL, withExpectedNavigationType: source.navigationType)
        }

        var request = URLRequest(url: url, cachePolicy: source.cachePolicy)
        if #available(macOS 12.0, *), content.isUserEnteredUrl {
            request.attribution = .user
        }

        return webView.navigator(distributedNavigationDelegate: navigationDelegate)
            .load(request, withExpectedNavigationType: source.navigationType)
    }

    @MainActor
    private func shouldReload(_ url: URL, source: ReloadIfNeededSource) -> Bool {
        guard url.isValid else { return false }

        switch source {
        // should load when Web View is displayed?
        case .webViewDisplayed:
            // yes if not loaded yet
            if webView.url == nil {
                return true
            }

            switch error {
            case .some(URLError.notConnectedToInternet),
                 .some(URLError.networkConnectionLost):
                // reload when showing error due to connection failure
                return true
            default:
                // don‘t autoreload on other kinds of errors
                return false
            }

        // should load on Web View instantiation?
        case .loadInBackgroundIfNeeded(shouldLoadInBackground: let shouldLoadInBackground):
            switch content {
            case .newtab, .bookmarks, .settings:
                return webView.url == nil // navigate to empty pages loaded for duck:// urls
            default:
                return shouldLoadInBackground
            }

        // lazy loading triggered
        case .lazyLoad:
            return webView.url == nil

        // `.setContent()` called - always load
        case .contentUpdated:
            return true
        }
    }

    @MainActor
    private func restoreInteractionStateIfNeeded() -> Bool {
        // only restore session from interactionStateData passed to Tab.init
        guard case .loadCachedFromTabContent(let interactionStateData) = self.interactionState else { return false }

        switch content.urlForWebView {
        case .some(let url) where url.isFileURL:
#if APPSTORE
            guard url.isWritableLocation() else { fallthrough }
#endif

            // request file system access before restoration
            webView.navigator(distributedNavigationDelegate: navigationDelegate)
                .loadFileURL(url, allowingReadAccessTo: url)?
                .overrideResponders(navigationDidFinish: { [weak self] _ in
                    self?.restoreInteractionState(with: interactionStateData)
                }, navigationDidFail: { [weak self] _, _ in
                    self?.restoreInteractionState(with: interactionStateData)
                })

        default:
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

    func stopLoading() {
        webView.stopLoading()
    }

    func requestFireproofToggle() {
        guard case .url(let url, _, _) = content,
              url.navigationalScheme?.isHypertextScheme == true,
              !url.isDuckPlayer,
              let host = url.host else { return }

        _ = FireproofDomains.shared.toggle(domain: host)
    }

    private var webViewCancellables = Set<AnyCancellable>()
    private var emailDidSignOutCancellable: AnyCancellable?

    private func setupWebView(shouldLoadInBackground: Bool) {
        webView.navigationDelegate = navigationDelegate
        webView.uiDelegate = self
        webView.inspectorDelegate = self
        webView.contextMenuDelegate = self.contextMenuManager
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

        permissions.webView = webView

        webViewCancellables.removeAll()

        webView.observe(\.superview, options: .old) { [weak self] _, change in
            // if the webView is being added to superview - reload if needed
            guard case .some(.none) = change.oldValue else { return }

            self?.reloadIfNeeded(source: .webViewDisplayed)
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

        navigationDelegate.$currentNavigation.sink { [weak self] navigation in
            self?.updateCanGoBackForward(withCurrentNavigation: navigation)
        }.store(in: &webViewCancellables)

        audioStatePublisher
            .assign(to: \.audioStateTest, onWeaklyHeld: self)
            .store(in: &webViewCancellables)

        // background tab loading should start immediately
        DispatchQueue.main.async {
            self.reloadIfNeeded(source: .loadInBackgroundIfNeeded(shouldLoadInBackground: shouldLoadInBackground))
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
        } else if oldValue?.urlForWebView?.host != url.host {
            // If the domain matches the previous value, just keep the same favicon
            favicon = nil
        }
    }

}

extension Tab: UserContentControllerDelegate {

    @MainActor
    func userContentController(_ userContentController: UserContentController, didInstallContentRuleLists contentRuleLists: [String: WKContentRuleList], userScripts: UserScriptsProvider, updateEvent: ContentBlockerRulesManager.UpdateEvent) {
        Logger.contentBlocking.info("didInstallContentRuleLists")
        guard let userScripts = userScripts as? UserScripts else { fatalError("Unexpected UserScripts") }

        userScripts.debugScript.instrumentation = instrumentation
        userScripts.faviconScript.delegate = self
        userScripts.pageObserverScript.delegate = self
        userScripts.printingUserScript.delegate = self
        specialPagesUserScript = nil
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
            guard documentUrl == self.content.urlForWebView, let favicon = favicon else {
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

    @MainActor
    func didCommit(_ navigation: Navigation) {
        let securityOrigin = if !navigation.url.securityOrigin.isEmpty {
            navigation.url.securityOrigin
        } else {
            navigation.navigationAction.sourceFrame.securityOrigin
        }
        if !securityOrigin.isEmpty || self.hasCommittedContent {
            // don‘t reset the initially passed parent tab SecurityOrigin to an empty one for "about:blank" page
            self.securityOrigin = securityOrigin
        }

        hasCommittedContent = true
    }

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        // allow local file navigations
        if navigationAction.url.isFileURL || navigationAction.url == .blankPage { return .allow }

        // when navigating to a URL with basic auth username/password, cache it and redirect to a trimmed URL
        if let mainFrame = navigationAction.mainFrameTarget,
           let credential = navigationAction.url.basicAuthCredential {

            return .redirect(mainFrame) { navigator in
                var request = navigationAction.request
                // credential is removed from the URL and set to TabContent to be used on next Challenge
                self.content = .url(navigationAction.url.removingBasicAuthCredential(), credential: credential, source: .webViewUpdated)
                // reload URL without credentialss
                request.url = self.content.urlForWebView!
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

        /*
         From a certain point, WebKit no longer supports loading any URL with the "about:" scheme, except for "about:blank".
         Although "about:" requests are approved without waiting for the `decidePolicyForNavigationAction:` decision, we will only receive the `willBegin` delegate call.
         If we receive an "about:" request pointing to an internal page like "about:preferences" or others, we should redirect to a "duck://" address by directly setting the Tab Content.
         Other "about:" URLs will fail to load and display an error page.
         */
        if navigation.url.navigationalScheme == .about, navigation.url != .blankPage {
            let tabContent = TabContent.contentFromURL(navigation.url, source: .webViewUpdated)
            guard case .url = tabContent else {
                setContent(tabContent)
                return
            }
        }

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
        permissions.tabDidStartNavigation()
        userInteractionDialog = nil

        // Unnecessary assignment triggers publishing
        if error != nil,
           navigation.navigationAction.navigationType != .alternateHtmlLoad { // error page navigation
            error = nil
        }

        invalidateInteractionStateData()
    }

    @MainActor
    func navigationDidFinish(_ navigation: Navigation) {
        invalidateInteractionStateData()
        statisticsLoader?.refreshRetentionAtb(isSearch: navigation.url.isDuckDuckGoSearch)
        if !navigation.url.isDuckDuckGoSearch {
            onboardingPixelReporter.trackSiteVisited()
        }
        navigationDidEndPublisher.send(self)
    }

    @MainActor
    func navigation(_ navigation: Navigation, didSameDocumentNavigationOf navigationType: WKSameDocumentNavigationType) {
        guard navigation.isCurrent else { return }

        invalidateInteractionStateData()
    }

    @MainActor
    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        let url = error.failingUrl ?? navigation.url
        guard navigation.isCurrent else { return }
        invalidateInteractionStateData()

        guard !error.isNavigationCancelled, /* user stopped loading */
              !error.isFrameLoadInterrupted /* navigation cancelled by a Navigation Responder */ else { return }

        // don‘t show an error page if the error was already handled
        // (by SearchNonexistentDomainNavigationResponder) or another navigation was triggered by `setContent`
        guard self.content.urlForWebView == url
                || self.content == .none /* when navigation fails instantly we may have no content set yet */
                // navigation failure with MaliciousSiteError is achieved by redirecting to a special token-protected
                // duck://error?.. URL performed in SpecialErrorPageTabExtension.swift
                || error as NSError is MaliciousSiteError else { return }

        self.error = error

        // when already displaying the error page and reload navigation fails again: don‘t navigate, just update page HTML
        let shouldPerformAlternateNavigation = navigation.url != webView.url || navigation.navigationAction.targetFrame?.url != .error
        loadErrorHTML(error, header: UserText.errorPageHeader, forUnreachableURL: url, alternate: shouldPerformAlternateNavigation)
    }

    @MainActor
    func webContentProcessDidTerminate(with reason: WKProcessTerminationReason?) {
        guard (error?.code.rawValue ?? WKError.Code.unknown.rawValue) != WKError.Code.webContentProcessTerminated.rawValue else { return }

        let terminationReason = reason?.rawValue ?? -1

        let error = WKError(.webContentProcessTerminated, userInfo: [
            WKProcessTerminationReason.userInfoKey: terminationReason,
            NSLocalizedDescriptionKey: UserText.webProcessCrashPageMessage,
            NSUnderlyingErrorKey: NSError(domain: WKErrorDomain, code: terminationReason)
        ])

        let isInternalUser = internalUserDecider?.isInternalUser == true

        if isInternalUser {
            self.webView.reload()
        } else {
            if case.url(let url, _, _) = content {
                self.error = error

                loadErrorHTML(error, header: UserText.webProcessCrashPageHeader, forUnreachableURL: url, alternate: true)
            }
        }

        Task {
#if APPSTORE
            let additionalParameters = [String: String]()
#else
            let additionalParameters = await SystemInfo.pixelParameters()
#endif

            PixelKit.fire(DebugEvent(GeneralPixel.webKitDidTerminate, error: error), frequency: .dailyAndStandard, withAdditionalParameters: additionalParameters)
        }
    }

    @MainActor
    private func loadErrorHTML(_ error: WKError, header: String, forUnreachableURL url: URL, alternate: Bool) {
        let html = ErrorPageHTMLFactory.html(for: error, featureFlagger: featureFlagger, header: header)
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
