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
    // TODO: UIDelegate
    // - UI linking through WebView
    // -- Popup Window/New Tab
    // -- JS Alerts
    // -- Autoconsent
    // -- Tab closing
    // - permissions

    // navigational published
    func tabWillStartNavigation(_ tab: Tab, isUserInitiated: Bool)
    func tabDidStartNavigation(_ tab: Tab)
    func tabPageDOMLoaded(_ tab: Tab)

    // published
    func tab(_ tab: Tab, requestedSaveAutofillData autofillData: AutofillData)
    func tab(_ tab: Tab, didChangeHoverLink url: URL?)

    // js
    func tab(_ tab: Tab, requestedNewTabWith content: Tab.TabContent, selected: Bool)
    func closeTab(_ tab: Tab)


    // do thru js alert (ui) delegate?
    func tab(_ tab: Tab,
             requestedBasicAuthenticationChallengeWith protectionSpace: URLProtectionSpace,
             completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)


    // published like permissions.. or make it permission?
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
    var navigationPolicyMakersProvider: NavigationPolicyHandlersProvider { TabNavigationPolicyHandlers() }

}

protocol NavigationPolicyHandlersProvider {
    func policyHandlers(for tab: Tab) -> [PartialNavigationPolicyHandler]
}

struct TabNavigationPolicyHandlers: NavigationPolicyHandlersProvider {

    func policyHandlers(for tab: Tab) -> [PartialNavigationPolicyHandler] {
        [
            tab.extensions.adClickAttribution
        ]
    }

}

@dynamicMemberLookup
struct DynamicTabExtensions {
    private var storage = [AnyKeyPath: TabExtension]()

    subscript<T: TabExtension>(dynamicMember keyPath: KeyPath<TabExtensions, T.Type>) -> T {
        (storage[\T.self] as? T)!
    }

    mutating func register<T: TabExtension>(_ tabExtension: T) {
        assert(storage[\T.self] == nil, "Trying to register \(T.self) twice!")
        storage[\T.self] = tabExtension
    }

}

protocol ExtensionsBuilder {
    func buildExtensions(into result: inout DynamicTabExtensions, for tab: Tab)
}

struct TabExtensionsBuilder: ExtensionsBuilder {

    func buildExtensions(into result: inout DynamicTabExtensions, for tab: Tab) {

        for child in Mirror(reflecting: TabExtensions()).children {
            guard let extensionType = child.value as? TabExtension.Type else {
                assertionFailure("\(child.label!) should be TabExtension.Type")
                continue
            }
            result.register(extensionType.init(tab: tab))
        }
    }

}

protocol TabExtension {
    init(tab: Tab)
}

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

    weak var delegate: TabDelegate?

    private let instrumentation = TabInstrumentation()
    private(set) var extensions = DynamicTabExtensions()
    private let navigationDelegate = NavigationDelegate()

    private var youtubePlayerCancellables: Set<AnyCancellable> = []
    var findInPageCancellable: AnyCancellable?
    // make it a callback in WebView UI?
    private var superviewObserver: NSKeyValueObservation?

    init(content: TabContent,
         // TODO: merge it with "should load in background"; shouldn‘t delay loading of pre-configured webviews
         webViewConfiguration: WKWebViewConfiguration? = nil,
         localHistory: Set<String> = Set<String>(),
         title: String? = nil,
         favicon: NSImage? = nil,
         sessionStateData: Data? = nil,
         interactionStateData: Data? = nil,
         parentTab: Tab? = nil,
         shouldLoadInBackground: Bool = false,
         canBeClosedWithBack: Bool = false,
         lastSelectedAt: Date? = nil,
         currentDownload: URL? = nil,
         webViewFrame: CGRect = .zero) {

        self.content = content
        self.localHistory = localHistory
        self.title = title
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

    func createChildTab(with content: TabContent,
                        configuration: WKWebViewConfiguration? = nil,
                        canBeClosedWithBack: Bool = true,
                        webViewFrame: CGRect = .zero) -> Tab {
        return Tab(content: content,
                   webViewConfiguration: configuration,
                   parentTab: self,
                   canBeClosedWithBack: canBeClosedWithBack,
                   webViewFrame: webViewFrame)
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
        userContentController.removeAllUserScripts()

        // TODO: Move to TabInstrumentation
        dependencyProvider.cbaTimeReporter?.tabWillClose(self.instrumentation.currentTabIdentifier)
    }

    var userContentController: UserContentController {
        (webView.configuration.userContentController as? UserContentController)!
    }
    var userScripts: UserScripts? {
        userContentController.contentBlockingAssets?.userScripts
    }
    var userScriptsPublisher: AnyPublisher<UserScripts?, Never> {
        userContentController.$contentBlockingAssets.map(\.?.userScripts).eraseToAnyPublisher()
    }

    // MARK: - Event Publishers

    let webViewDidReceiveChallengePublisher = PassthroughSubject<Void, Never>()
    let webViewDidCommitNavigationPublisher = PassthroughSubject<Void, Never>()
    let webViewDidFinishNavigationPublisher = PassthroughSubject<Void, Never>()
    let webViewDidFailNavigationPublisher = PassthroughSubject<Void, Never>()

    // MARK: - Properties

    let webView: WebView

    private var lastUpgradedURL: URL?

    private var userEnteredUrl = false

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

    var isPinned: Bool {
        return dependencyProvider.pinnedTabsManager.isTabPinned(self)
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
//                isAMPProtectionExtracting = true
            }, onFinishExtracting: { [weak self] in
//                self?.isAMPProtectionExtracting = false
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
                    // TODO: also call loadFileURL
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

    private func setupWebView(shouldLoadInBackground: Bool) {
        navigationDelegate.navigationPolicyHandlers = dependencyProvider.navigationPolicyMakersProvider.policyHandlers(for: self)
        navigationDelegate.tab = self

        webView.navigationDelegate = navigationDelegate
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        userContentController.delegate = self

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

    func requestOpenExternalURL(_ url: URL, forUserEnteredURL userEntered: Bool) {

        let searchForExternalUrl = { [weak self] in
            // Redirect after handing WebView.url update after cancelling the request
            DispatchQueue.main.async {
                self?.update(url: URL.makeSearchUrl(from: url.absoluteString), userEntered: false)
            }
        }

        // Another way of detecting whether an app is installed to handle a protocol is described in Asana:
        // https://app.asana.com/0/1201037661562251/1202055908401751/f
        guard dependencyProvider.workspace.urlForApplication(toOpen: url) != nil else {
            if userEntered {
                searchForExternalUrl()
            }
            return
        }
        self.webView.window?.contentView?.makeMeFirstResponder()

        let permissionType = PermissionType.externalScheme(scheme: url.scheme ?? "")

        self.permissions.permissions([permissionType],
                                    requestedForDomain: webView.url?.host,
                                    url: url) { [weak self] granted in
            guard granted else {
                if userEntered {
                    searchForExternalUrl()
                }
                return
            }

            self?.openExternalURL(url, touchingPermissionType: permissionType)
        }
    }

    private func openExternalURL(_ url: URL, touchingPermissionType permissionType: PermissionType) {
        dependencyProvider.workspace.open(url)
        self.permissions.permissions[permissionType].externalSchemeOpened()
    }

    // MARK: - Favicon

    @Published var favicon: NSImage?

    private func handleFavicon() {
        if content.isPrivatePlayer {
            favicon = .privatePlayer
            return
        }

        let faviconManagement = dependencyProvider.faviconManagement
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

}

extension Tab: UserContentControllerDelegate {

    func userContentController(_ userContentController: UserContentController, didInstallUserScripts userScripts: UserScripts) {
        userScripts.debugScript.instrumentation = instrumentation
        userScripts.faviconScript.delegate = self
//        userScripts.contextMenuScript.delegate = self
        userScripts.surrogatesScript.delegate = self
        userScripts.contentBlockerRulesScript.delegate = self
        userScripts.clickToLoadScript.delegate = self
        userScripts.autofillScript.currentOverlayTab = self.delegate
        userScripts.autofillScript.emailDelegate = emailManager
        userScripts.autofillScript.vaultDelegate = vaultManager
        userScripts.pageObserverScript.delegate = self
        userScripts.hoverUserScript.delegate = self
        if #available(macOS 11, *) {
            userScripts.autoconsentUserScript?.delegate = self
        }
        youtubeOverlayScript?.delegate = self
        setUpYoutubeScriptsIfNeeded()

//        attachFindInPage()
    }

}

// MARK: - Youtube Player
extension Tab {

    private var youtubeOverlayScript: YoutubeOverlayUserScript? {
        userScripts?.youtubeOverlayScript
    }
    private var youtubePlayerScript: YoutubePlayerUserScript? {
        userScripts?.youtubePlayerUserScript
    }
    private var privatePlayer: PrivatePlayer {
        dependencyProvider.privatePlayer
    }

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

// MARK: - Autofill

extension Tab: BrowserTabViewControllerClickDelegate {

    func browserTabViewController(_ browserTabViewController: BrowserTabViewController, didClickAtPoint: NSPoint) {
        userScripts?.autofillScript.clickPoint = didClickAtPoint
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


// MARK: - Find In Page
extension Tab {

    private var findInPageScript: FindInPageUserScript? {
        userScripts?.findInPageScript
    }

    func attachFindInPage(_ findInPage: FindInPageModel) {
        findInPageScript?.model = findInPage
        findInPageCancellable = findInPage.$text.receive(on: DispatchQueue.main).sink { [weak self] text in
            self?.find(text: text)
        }
    }

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
        userContentController.removeAllUserScripts()

        webView.navigationDelegate = caller
        webView.load(URL(string: "about:blank")!)
    }
}
