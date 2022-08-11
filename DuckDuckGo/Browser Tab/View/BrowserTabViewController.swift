//
//  BrowserTabViewController.swift
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
import os.log
import Combine
import SwiftUI
import BrowserServicesKit

protocol BrowserTabViewControllerClickDelegate: AnyObject {
    func browserTabViewController(_ browserTabViewController: BrowserTabViewController, didClickAtPoint: CGPoint)
}

// swiftlint:disable file_length
final class BrowserTabViewController: NSViewController {
    
    @IBOutlet weak var errorView: NSView!
    @IBOutlet weak var homePageView: NSView!
    @IBOutlet weak var errorMessageLabel: NSTextField!
    @IBOutlet weak var hoverLabel: NSTextField!
    @IBOutlet weak var hoverLabelContainer: NSView!
    private weak var webView: WebView?
    private weak var webViewContainer: NSView?
    private weak var webViewSnapshot: NSView?

    var tabViewModel: TabViewModel?
    var clickPoint: NSPoint?

    private let tabCollectionViewModel: TabCollectionViewModel
    private var tabContentCancellable: AnyCancellable?
    private var errorViewStateCancellable: AnyCancellable?
    private var pinnedTabsDelegatesCancellable: AnyCancellable?
    private var keyWindowSelectedTabCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    private var contextMenuExpected = false
    private var contextMenuTitle: String?
    private var contextMenuLink: URL?
    private var contextMenuImage: URL?
    private var contextMenuSelectedText: String?

    private var hoverLabelWorkItem: DispatchWorkItem?

    private var transientTabContentViewController: NSViewController?

    private var mouseDownMonitor: Any?
    
    private var cookieConsentPopoverManager = CookieConsentPopoverManager()

    required init?(coder: NSCoder) {
        fatalError("BrowserTabViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    @IBSegueAction func createHomePageViewController(_ coder: NSCoder) -> NSViewController? {
        guard let controller = HomePageViewController(coder: coder,
                                                      tabCollectionViewModel: tabCollectionViewModel,
                                                      bookmarkManager: LocalBookmarkManager.shared) else {
            fatalError("BrowserTabViewController: Failed to init HomePageViewController")
        }
        return controller
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        hoverLabelContainer.alphaValue = 0
        subscribeToTabs()
        subscribeToSelectedTabViewModel()
        subscribeToErrorViewState()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        addMouseMonitors()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        removeMouseMonitors()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowWillClose(_:)),
                                               name: NSWindow.willCloseNotification,
                                               object: self.view.window)
    }

    @objc
    private func windowWillClose(_ notification: NSNotification) {
        self.removeWebViewFromHierarchy()
    }

    private func subscribeToSelectedTabViewModel() {
        tabCollectionViewModel.$selectedTabViewModel
            .sink { [weak self] selectedTabViewModel in
                
                guard let self = self else { return }
                self.tabViewModel = selectedTabViewModel
                self.showTabContent(of: selectedTabViewModel)
                self.subscribeToErrorViewState()
                self.subscribeToTabContent(of: selectedTabViewModel)
                self.showCookieConsentPopoverIfNecessary(selectedTabViewModel)
            }
            .store(in: &cancellables)
    }
    
    private func showCookieConsentPopoverIfNecessary(_ selectedTabViewModel: TabViewModel?) {
        if selectedTabViewModel?.tab == cookieConsentPopoverManager.currentTab {
            cookieConsentPopoverManager.popOver.show(on: view, animated: false)
        } else {
            cookieConsentPopoverManager.popOver.close(animated: false)
        }
    }

    private func subscribeToTabs() {
        tabCollectionViewModel.tabCollection.$tabs
            .sink { [weak self] tabs in
                for tab in tabs where tab.delegate !== self {
                    tab.delegate = self
                }
            }
            .store(in: &cancellables)
    }

    private func subscribeToPinnedTabs() {
        pinnedTabsDelegatesCancellable = tabCollectionViewModel.pinnedTabsCollection?.$tabs
            .sink { [weak self] tabs in
                for tab in tabs where tab.delegate !== self {
                    tab.delegate = self
                }
            }
    }

    private func removeWebViewFromHierarchy(webView: WebView? = nil,
                                            container: NSView? = nil) {
        guard let webView = webView ?? self.webView,
              let container = container ?? self.webViewContainer
        else { return }

        if self.webView === webView {
            self.webView = nil
        }

        if webView.window === view.window {
            container.removeFromSuperview()
        }
        if self.webViewContainer === container {
            self.webViewContainer = nil
        }
    }

    private func addWebViewToViewHierarchy(_ webView: WebView) {
        let container = WebViewContainerView(webView: webView, frame: view.bounds)
        self.webViewContainer = container
        view.addSubview(container)

        // Make sure link preview (tooltip shown in the bottom-left) is on top
        view.addSubview(hoverLabelContainer)
    }

    private func changeWebView(tabViewModel: TabViewModel?) {

        func cleanUpRemoteWebViewIfNeeded(_ webView: WebView) {
            if webView.containerView !== webViewContainer {
                webView.containerView?.removeFromSuperview()
            }
        }

        func displayWebView(of tabViewModel: TabViewModel) {
            let newWebView = tabViewModel.tab.webView
            cleanUpRemoteWebViewIfNeeded(newWebView)
            newWebView.uiDelegate = self
            webView = newWebView

            addWebViewToViewHierarchy(newWebView)
        }

        guard let tabViewModel = tabViewModel else {
            removeWebViewFromHierarchy()
            return
        }

        let oldWebView = webView
        let webViewContainer = webViewContainer

        displayWebView(of: tabViewModel)
        tabViewModel.updateAddressBarStrings()
        if let oldWebView = oldWebView, let webViewContainer = webViewContainer, oldWebView !== webView {
            removeWebViewFromHierarchy(webView: oldWebView, container: webViewContainer)
        }

        if setFirstResponderAfterAdding {
            setFirstResponderAfterAdding = false
            makeWebViewFirstResponder()
        }
    }

    func subscribeToTabContent(of tabViewModel: TabViewModel?) {
        tabContentCancellable?.cancel()

        guard let tabViewModel = tabViewModel else {
            return
        }

        let tabContentPublisher = tabViewModel.tab.$content
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)

        tabContentCancellable = tabContentPublisher
            .map { [weak tabViewModel] tabContent -> AnyPublisher<Void, Never> in
                guard let tabViewModel = tabViewModel, tabContent.isUrl else {
                    return Just(()).eraseToAnyPublisher()
                }

                return Publishers.Merge3(
                    tabViewModel.tab.webViewDidCommitNavigationPublisher,
                    tabViewModel.tab.webViewDidFailNavigationPublisher,
                    tabViewModel.tab.webViewDidReceiveChallengePublisher
                )
                .prefix(1)
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [weak self, weak tabViewModel] in
                guard let tabViewModel = tabViewModel else {
                    return
                }
                self?.showTabContent(of: tabViewModel)
            }
    }

    private func subscribeToErrorViewState() {
        errorViewStateCancellable = tabViewModel?.$errorViewState.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.displayErrorView(
                self?.tabViewModel?.errorViewState.isVisible ?? false,
                message: self?.tabViewModel?.errorViewState.message ?? UserText.unknownErrorMessage
            )
        }
    }

    func makeWebViewFirstResponder() {
        if let webView = self.webView {
            webView.makeMeFirstResponder()
        } else {
            setFirstResponderAfterAdding = true
            view.window?.makeFirstResponder(nil)
        }
    }

    private var setFirstResponderAfterAdding = false

    private func setFirstResponderIfNeeded() {
        guard webView?.url != nil else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.makeWebViewFirstResponder()
        }
    }

    private func displayErrorView(_ shown: Bool, message: String) {
        errorMessageLabel.stringValue = message
        errorView.isHidden = !shown
        webView?.isHidden = shown
        homePageView.isHidden = shown
    }

    func openNewTab(with content: Tab.TabContent, parentTab: Tab? = nil, selected: Bool = false, canBeClosedWithBack: Bool = false) {
        // shouldn't open New Tabs in PopUp window
        guard view.window?.isPopUpWindow == false else {
            // Prefer Tab's Parent
            if let parentTab = tabCollectionViewModel.selectedTabViewModel?.tab.parentTab, parentTab.delegate !== self {
                parentTab.delegate?.tab(parentTab, requestedNewTabWith: content, selected: true)
                parentTab.webView.window?.makeKeyAndOrderFront(nil)
                // Act as default URL Handler if no Parent
            } else {
                WindowControllersManager.shared.showTab(with: content)
            }
            return
        }

        guard tabCollectionViewModel.selectDisplayableTabIfPresent(content) == false else {
            return
        }

        let tab = Tab(content: content,
                      parentTab: parentTab,
                      shouldLoadInBackground: true,
                      canBeClosedWithBack: canBeClosedWithBack)

        if parentTab != nil {
            tabCollectionViewModel.insertChild(tab: tab, selected: selected)
        } else {
            tabCollectionViewModel.append(tab: tab, selected: selected)
        }
    }

    // MARK: - Browser Tabs

    private func show(displayableTabAtIndex index: Int) {
        // The tab switcher only displays displayable tab types.
        tabCollectionViewModel.selectedTabViewModel?.tab.setContent(Tab.TabContent.displayableTabTypes[index])
        showTabContent(of: tabCollectionViewModel.selectedTabViewModel)
    }

    private func removeAllTabContent(includingWebView: Bool = true) {
        self.homePageView.removeFromSuperview()
        transientTabContentViewController?.removeCompletely()
        preferencesViewController.removeCompletely()
        bookmarksViewController.removeCompletely()
        if includingWebView {
            self.removeWebViewFromHierarchy()
        }
    }

    private func showTabContentController(_ vc: NSViewController) {
        self.addChild(vc)
        view.addAndLayout(vc.view)
    }

    private func showTransientTabContentController(_ vc: NSViewController) {
        transientTabContentViewController?.removeCompletely()
        showTabContentController(vc)
        transientTabContentViewController = vc
    }

    private func requestDisableUI() {
        (view.window?.windowController as? MainWindowController)?.userInteraction(prevented: true)
    }

    private func showTabContent(of tabViewModel: TabViewModel?) {
        guard tabCollectionViewModel.allTabsCount > 0 else {
            view.window?.close()
            return
        }
        scheduleHoverLabelUpdatesForUrl(nil)

        switch tabViewModel?.tab.content {
        case .bookmarks:
            removeAllTabContent()
            showTabContentController(bookmarksViewController)

        case let .preferences(pane):
            removeAllTabContent()
            if let pane = pane, preferencesViewController.model.selectedPane != pane {
                preferencesViewController.model.selectPane(pane)
            }
            showTabContentController(preferencesViewController)

        case .onboarding:
            removeAllTabContent()
            if !OnboardingViewModel().onboardingFinished {
                requestDisableUI()
            }
            showTransientTabContentController(OnboardingViewController.create(withDelegate: self))

        case .url:
            if shouldReplaceWebView(for: tabViewModel) {
                removeAllTabContent(includingWebView: true)
                changeWebView(tabViewModel: tabViewModel)
            }

        case .homePage:
            removeAllTabContent()
            view.addAndLayout(homePageView)

        default:
            break
        }
    }

    private func shouldReplaceWebView(for tabViewModel: TabViewModel?) -> Bool {
        guard let tabViewModel = tabViewModel else {
            return false
        }

        let isPinnedTab = tabCollectionViewModel.pinnedTabsCollection?.tabs.contains(tabViewModel.tab) == true
        let isKeyWindow = view.window?.isKeyWindow == true

        let tabIsNotOnScreen = tabViewModel.tab.webView.tabContentView.superview == nil
        let isDifferentTabDisplayed = webView != tabViewModel.tab.webView

        return isDifferentTabDisplayed || tabIsNotOnScreen || (isPinnedTab && isKeyWindow)
    }

    // MARK: - Preferences

    private(set) lazy var preferencesViewController: PreferencesViewController = {
        let viewController = PreferencesViewController()
        viewController.delegate = self

        return viewController
    }()

    // MARK: - Bookmarks

    private(set) lazy var bookmarksViewController: BookmarkManagementSplitViewController = {
        let viewController = BookmarkManagementSplitViewController.create()
        viewController.delegate = self

        return viewController
    }()

    private var _contentOverlayPopover: ContentOverlayPopover?
    public var contentOverlayPopover: ContentOverlayPopover {
        guard let overlay = _contentOverlayPopover else {
            let overlayPopover = ContentOverlayPopover(currentTabView: view)
            WindowControllersManager.shared.stateChanged
                .sink { [weak self] _ in
                    self?._contentOverlayPopover?.websiteAutofillUserScriptCloseOverlay(nil)
                }.store(in: &cancellables)
            _contentOverlayPopover = overlayPopover
            return overlayPopover
        }
        return overlay
    }

    @objc(_webView:printFrame:)
    func webView(_ webView: WKWebView, printFrame handle: Any) {
        webView.tab?.print(frame: handle)
    }

    @available(macOS 12, *)
    @objc(_webView:printFrame:pdfFirstPageSize:completionHandler:)
    func webView(_ webView: WKWebView, printFrame handle: Any, pdfFirstPageSize size: CGSize, completionHandler: () -> Void) {
        self.webView(webView, printFrame: handle)
        completionHandler()
    }

}

extension BrowserTabViewController: ContentOverlayUserScriptDelegate {
    public func websiteAutofillUserScriptCloseOverlay(_ websiteAutofillUserScript: WebsiteAutofillUserScript?) {
        contentOverlayPopover.websiteAutofillUserScriptCloseOverlay(websiteAutofillUserScript)
    }
    public func websiteAutofillUserScript(_ websiteAutofillUserScript: WebsiteAutofillUserScript,
                                          willDisplayOverlayAtClick: NSPoint?,
                                          serializedInputContext: String,
                                          inputPosition: CGRect) {
        contentOverlayPopover.websiteAutofillUserScript(websiteAutofillUserScript,
                                                        willDisplayOverlayAtClick: willDisplayOverlayAtClick,
                                                        serializedInputContext: serializedInputContext,
                                                        inputPosition: inputPosition)
    }
}

extension BrowserTabViewController: TabDelegate {

    func tab(_ tab: Tab, promptUserForCookieConsent result: @escaping (Bool) -> Void) {
       cookieConsentPopoverManager.show(on: view, animated: true, result: result)
       cookieConsentPopoverManager.currentTab = tabViewModel?.tab
    }
    
    func tabWillStartNavigation(_ tab: Tab, isUserInitiated: Bool) {
        if isUserInitiated,
           let window = self.view.window,
           window.isPopUpWindow == true,
           window.isKeyWindow == false {
            
            window.makeKeyAndOrderFront(nil)
        }
    }

    func tab(_ tab: Tab, requestedOpenExternalURL url: URL, forUserEnteredURL userEntered: Bool) {

        let searchForExternalUrl = { [weak tab] in
            // Redirect after handing WebView.url update after cancelling the request
            DispatchQueue.main.async {
                tab?.update(url: URL.makeSearchUrl(from: url.absoluteString), userEntered: false)
            }
        }

        // Another way of detecting whether an app is installed to handle a protocol is described in Asana:
        // https://app.asana.com/0/1201037661562251/1202055908401751/f
        guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil else {
            if userEntered {
                searchForExternalUrl()
            }
            return
        }
        self.view.makeMeFirstResponder()

        let permissionType = PermissionType.externalScheme(scheme: url.scheme ?? "")

        tab.permissions.permissions([permissionType],
                                    requestedForDomain: webView?.url?.host,
                                    url: url) { [weak self, weak tab] granted in
            guard granted, let tab = tab else {
                if userEntered {
                    searchForExternalUrl()
                }
                return
            }

            self?.tab(tab, openExternalURL: url, touchingPermissionType: permissionType)
        }
    }

    private func tab(_ tab: Tab, openExternalURL url: URL, touchingPermissionType permissionType: PermissionType) {
        NSWorkspace.shared.open(url)
        tab.permissions.permissions[permissionType].externalSchemeOpened()
    }

    func tabPageDOMLoaded(_ tab: Tab) {
        if tabViewModel?.tab == tab {
            tabViewModel?.isLoading = false
        }
    }

    func tabDidStartNavigation(_ tab: Tab) {
        setFirstResponderIfNeeded()
        guard let tabViewModel = tabViewModel else { return }

        tabViewModel.closeFindInPage()
        tab.permissions.tabDidStartNavigation()
        if !tabViewModel.isLoading,
           tabViewModel.tab.webView.isLoading {
            tabViewModel.isLoading = true
        }
    }

    func tab(_ tab: Tab, requestedNewTabWith content: Tab.TabContent, selected: Bool) {
        openNewTab(with: content, parentTab: tab, selected: selected, canBeClosedWithBack: selected == true)
    }

    func closeTab(_ tab: Tab) {
        guard let index = tabCollectionViewModel.tabCollection.tabs.firstIndex(of: tab) else {
            return
        }
        tabCollectionViewModel.remove(at: .unpinned(index))
    }

    // swiftlint:disable:next function_parameter_count
    func tab(_ tab: Tab,
             willShowContextMenuAt position: NSPoint,
             image: URL?,
             title: String?,
             link: URL?,
             selectedText: String?) {
        contextMenuImage = image
        contextMenuTitle = title
        contextMenuLink = link
        contextMenuExpected = true
        contextMenuSelectedText = selectedText
    }

    func tab(_ tab: Tab,
             requestedBasicAuthenticationChallengeWith protectionSpace: URLProtectionSpace,
             completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let window = view.window else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let alert = AuthenticationAlert(host: protectionSpace.host, isEncrypted: protectionSpace.receivesCredentialSecurely)
        alert.beginSheetModal(for: window) { response in
            guard case .OK = response,
                  !alert.usernameTextField.stringValue.isEmpty,
                  !alert.passwordTextField.stringValue.isEmpty
            else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            completionHandler(.useCredential, URLCredential(user: alert.usernameTextField.stringValue,
                                                            password: alert.passwordTextField.stringValue,
                                                            persistence: .none))

        }
    }

    func tab(_ tab: Tab, didChangeHoverLink url: URL?) {
        scheduleHoverLabelUpdatesForUrl(url)
    }

    func windowDidBecomeKey() {
        keyWindowSelectedTabCancellable = nil
        subscribeToPinnedTabs()
        hideWebViewSnapshotIfNeeded()
    }

    func windowDidResignKey() {
        pinnedTabsDelegatesCancellable = nil
        scheduleHoverLabelUpdatesForUrl(nil)
        subscribeToTabSelectedInCurrentKeyWindow()
    }

    private func scheduleHoverLabelUpdatesForUrl(_ url: URL?) {
        // cancel previous animation, if any
        hoverLabelWorkItem?.cancel()

        // schedule an animation if needed
        var animationItem: DispatchWorkItem?
        var delay: Double = 0
        if url == nil && hoverLabelContainer.alphaValue > 0 {
            // schedule a fade out
            delay = 0.1
            animationItem = DispatchWorkItem { [weak self] in
                self?.hoverLabelContainer.animator().alphaValue = 0
            }
        } else if url != nil && hoverLabelContainer.alphaValue < 1 {
            // schedule a fade in
            delay = 0.5
            animationItem = DispatchWorkItem { [weak self] in
                self?.hoverLabel.stringValue = url?.absoluteString ?? ""
                self?.hoverLabelContainer.animator().alphaValue = 1
            }
        } else {
            hoverLabel.stringValue = url?.absoluteString ?? ""
        }

        if let item = animationItem {
            hoverLabelWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }
}

extension BrowserTabViewController: FileDownloadManagerDelegate {

    func chooseDestination(suggestedFilename: String?, directoryURL: URL?, fileTypes: [UTType], callback: @escaping (URL?, UTType?) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))

        var fileTypes = fileTypes
        if fileTypes.isEmpty || (fileTypes.count == 1 && (fileTypes[0].fileExtension?.isEmpty ?? true)),
           let fileExt = (suggestedFilename as NSString?)?.pathExtension,
           let utType = UTType(fileExtension: fileExt) {
            // When no file extension is set by default generate fileType from file extension
            fileTypes.insert(utType, at: 0)
        }
        // allow user set any file extension
        if fileTypes.count == 1 && !fileTypes.contains(where: { $0.fileExtension?.isEmpty ?? true }) {
            fileTypes.append(.data)
        }

        let savePanel = NSSavePanel.withFileTypeChooser(fileTypes: fileTypes, suggestedFilename: suggestedFilename, directoryURL: directoryURL)

        func completionHandler(_ result: NSApplication.ModalResponse) {
            guard case .OK = result else {
                callback(nil, nil)
                return
            }
            callback(savePanel.url, savePanel.selectedFileType)
        }

        if let window = self.view.window {
            savePanel.beginSheetModal(for: window, completionHandler: completionHandler)
        } else {
            completionHandler(savePanel.runModal())
        }
    }

    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect? {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let window = self.view.window,
              let dockScreen = NSScreen.dockScreen
        else { return nil }

        // fly 64x64 icon from the center of Address Bar
        let size = view.bounds.size
        let rect = NSRect(x: size.width / 2 - 32, y: size.height / 2 - 32, width: 64, height: 64)
        let windowRect = view.convert(rect, to: nil)
        let globalRect = window.convertToScreen(windowRect)
        // to the Downloads folder in Dock (in DockScreen coordinates)
        let dockScreenRect = dockScreen.convert(globalRect)

        return dockScreenRect
    }

    func tab(_ tab: Tab, requestedSaveAutofillData autofillData: AutofillData) {
        tabViewModel?.autofillDataToSave = autofillData
    }

}

extension BrowserTabViewController: NSMenuDelegate {

    func menuWillOpen(_ menu: NSMenu) {
        guard contextMenuExpected else {
            os_log("%s: Unexpected menuWillOpen", type: .error, className)
            contextMenuLink = nil
            contextMenuImage = nil
            return
        }
        contextMenuExpected = false
    }

}

extension BrowserTabViewController: LinkMenuItemSelectors {

    func openLinkInNewTab(_ sender: NSMenuItem) {
        guard let url = contextMenuLink else { return }
        openNewTab(with: .url(url), parentTab: tabViewModel?.tab)
    }

    func openLinkInNewWindow(_ sender: NSMenuItem) {
        guard let url = contextMenuLink else { return }
        WindowsManager.openNewWindow(with: url)
    }

    func downloadLinkedFileAs(_ sender: NSMenuItem) {
        guard let tab = tabCollectionViewModel.selectedTabViewModel?.tab,
              let url = contextMenuLink else { return }

        tab.download(from: url)
    }
    
    func addLinkToBookmarks(_ sender: NSMenuItem) {
        guard let url = contextMenuLink else { return }
        LocalBookmarkManager.shared.makeBookmark(for: url, title: contextMenuTitle ?? url.absoluteString, isFavorite: false)
    }
    
    func bookmarkPage(_ sender: NSMenuItem) {
        guard let tab = tabCollectionViewModel.selectedTabViewModel?.tab, let tabURL = tab.url else { return }
        LocalBookmarkManager.shared.makeBookmark(for: tabURL, title: tab.title ?? tabURL.absoluteString, isFavorite: false)
    }

    func copyLink(_ sender: NSMenuItem) {
        guard let url = contextMenuLink as NSURL? else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.URL], owner: nil)
        url.write(to: pasteboard)
        pasteboard.setString(url.absoluteString ?? "", forType: .string)
    }

}

extension BrowserTabViewController: ImageMenuItemSelectors {

    func openImageInNewTab(_ sender: NSMenuItem) {
        guard let url = contextMenuImage else { return }
        openNewTab(with: .url(url), parentTab: tabViewModel?.tab)
    }

    func openImageInNewWindow(_ sender: NSMenuItem) {
        guard let url = contextMenuImage else { return }
        WindowsManager.openNewWindow(with: url)
    }

    func saveImageAs(_ sender: NSMenuItem) {
        guard let tab = tabCollectionViewModel.selectedTabViewModel?.tab,
              let url = contextMenuImage else { return }

        tab.download(from: url)
    }

    func copyImageAddress(_ sender: NSMenuItem) {
        guard let url = contextMenuImage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        NSPasteboard.general.setString(url.absoluteString, forType: .URL)
    }

}

extension BrowserTabViewController: MenuItemSelectors {

    func search(_ sender: NSMenuItem) {
        let selectedText = contextMenuSelectedText ?? ""
        guard let url = URL.makeSearchUrl(from: selectedText) else { return }
        openNewTab(with: .url(url), parentTab: tabViewModel?.tab, selected: true)
    }

}

extension BrowserTabViewController: WKUIDelegate {

    @objc(_webView:saveDataToFile:suggestedFilename:mimeType:originatingURL:)
    func webView(_ webView: WKWebView, saveDataToFile data: Data, suggestedFilename: String, mimeType: String, originatingURL: URL) {
        func write(to url: URL) throws {
            let progress = Progress(totalUnitCount: 1,
                                    fileOperationKind: .downloading,
                                    kind: .file,
                                    isPausable: false,
                                    isCancellable: false,
                                    fileURL: url)
            progress.publish()
            defer {
                progress.unpublish()
            }

            try data.write(to: url)
            progress.completedUnitCount = progress.totalUnitCount
        }

        let prefs = DownloadsPreferences()
        if !prefs.alwaysRequestDownloadLocation,
           let location = prefs.effectiveDownloadLocation {
            let url = location.appendingPathComponent(suggestedFilename)
            try? write(to: url)

            return
        }

        chooseDestination(suggestedFilename: suggestedFilename,
                          directoryURL: prefs.effectiveDownloadLocation,
                          fileTypes: UTType(mimeType: mimeType).map { [$0] } ?? []) { url, _ in
            guard let url = url else { return }
            try? write(to: url)
        }
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {

        func makeTab(parentTab: Tab, content: Tab.TabContent) -> Tab {
            // Returned web view must be created with the specified configuration.
            return Tab(content: content,
                       webViewConfiguration: configuration,
                       parentTab: parentTab,
                       canBeClosedWithBack: true)
        }
        guard let parentTab = webView.tab else { return nil }
        func nextQuery(parentTab: Tab) -> PermissionAuthorizationQuery? {
            parentTab.permissions.authorizationQueries.first(where: { $0.permissions.contains(.popups) })
        }

        let contentSize = NSSize(width: windowFeatures.width?.intValue ?? 1024, height: windowFeatures.height?.intValue ?? 752)
        var shouldOpenPopUp = navigationAction.isUserInitiated
        if !shouldOpenPopUp {
            let url = navigationAction.request.url
            parentTab.permissions.permissions(.popups, requestedForDomain: webView.url?.host, url: url) { [weak parentTab] granted in

                guard let parentTab = parentTab else { return }

                switch (granted, shouldOpenPopUp) {
                case (true, false):
                    // callback called synchronously - will return webView for the request
                    shouldOpenPopUp = true
                case (true, true):
                    // called asynchronously
                    guard let url = navigationAction.request.url else { return }
                    let tab = makeTab(parentTab: parentTab, content: .url(url))
                    WindowsManager.openPopUpWindow(with: tab, contentSize: contentSize)

                    parentTab.permissions.permissions.popups.popupOpened(nextQuery: nextQuery(parentTab: parentTab))

                case (false, _):
                    return
                }
            }
        }
        guard shouldOpenPopUp else {
            shouldOpenPopUp = true // if granted asynchronously
            return nil
        }

        let tab = makeTab(parentTab: parentTab, content: .none)
        if windowFeatures.toolbarsVisibility?.boolValue == true {
            tabCollectionViewModel.insertChild(tab: tab, selected: !NSApp.isCommandPressed)
        } else {
            WindowsManager.openPopUpWindow(with: tab, contentSize: contentSize)
        }
        parentTab.permissions.permissions.popups.popupOpened(nextQuery: nextQuery(parentTab: parentTab))

        // WebKit loads the request in the returned web view.
        return tab.webView
    }

    @objc(_webView:checkUserMediaPermissionForURL:mainFrameURL:frameIdentifier:decisionHandler:)
    func webView(_ webView: WKWebView,
                 checkUserMediaPermissionFor url: URL,
                 mainFrameURL: URL,
                 frameIdentifier frame: UInt,
                 decisionHandler: @escaping (String, Bool) -> Void) {
        webView.tab?.permissions.checkUserMediaPermission(for: url, mainFrameURL: mainFrameURL, decisionHandler: decisionHandler)
            ?? /* Tab deallocated: */ {
                decisionHandler("", false)
            }()
    }

    // https://github.com/WebKit/WebKit/blob/995f6b1595611c934e742a4f3a9af2e678bc6b8d/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegate.h#L147
    @objc(webView:requestMediaCapturePermissionForOrigin:initiatedByFrame:type:decisionHandler:)
    @available(macOS 12, *)
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        guard let permissions = [PermissionType](devices: type) else {
            assertionFailure("Could not decode PermissionType")
            decisionHandler(.deny)
            return
        }

        webView.tab?.permissions.permissions(permissions, requestedForDomain: origin.host) { granted in
            decisionHandler(granted ? .grant : .deny)
        } ?? /* Tab deallocated: */ {
            decisionHandler(.deny)
        }()
    }

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L126
    @objc(_webView:requestUserMediaAuthorizationForDevices:url:mainFrameURL:decisionHandler:)
    func webView(_ webView: WKWebView,
                 requestUserMediaAuthorizationFor devices: _WKCaptureDevices,
                 url: URL,
                 mainFrameURL: URL,
                 decisionHandler: @escaping (Bool) -> Void) {
        guard let permissions = [PermissionType](devices: devices) else {
            decisionHandler(false)
            return
        }

        webView.tab?.permissions.permissions(permissions, requestedForDomain: url.host, decisionHandler: decisionHandler)
            ?? /* Tab deallocated: */ {
                decisionHandler(false)
            }()
    }

    @objc(_webView:mediaCaptureStateDidChange:)
    func webView(_ webView: WKWebView, mediaCaptureStateDidChange state: _WKMediaCaptureStateDeprecated) {
        webView.tab?.permissions.mediaCaptureStateDidChange()
    }

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L131
    @objc(_webView:requestGeolocationPermissionForFrame:decisionHandler:)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor frame: WKFrameInfo, decisionHandler: @escaping (Bool) -> Void) {
        webView.tab?.permissions.permissions(.geolocation, requestedForDomain: frame.request.url?.host, decisionHandler: decisionHandler)
            ?? /* Tab deallocated: */ {
                decisionHandler(false)
            }()
    }

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L132
    @objc(_webView:requestGeolocationPermissionForOrigin:initiatedByFrame:decisionHandler:)
    @available(macOS 12, *)
    func webView(_ webView: WKWebView,
                 requestGeolocationPermissionFor origin: WKSecurityOrigin,
                 initiatedBy frame: WKFrameInfo,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        webView.tab?.permissions.permissions(.geolocation, requestedForDomain: frame.request.url?.host) { granted in
            decisionHandler(granted ? .grant : .deny)
        } ?? /* Tab deallocated: */ {
            decisionHandler(.deny)
        }()
    }

    func webView(_ webView: WKWebView,
                 runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {

        guard let window = view.window else {
            os_log("%s: Window is nil", type: .error, className)
            completionHandler(nil)
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection

        openPanel.beginSheetModal(for: window) { response in
            if response == NSApplication.ModalResponse.OK {
                completionHandler(openPanel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {

        guard webView === self.webView, let window = view.window else {
            os_log("%s: Could not display JS alert panel", type: .error, className)
            completionHandler()
            return
        }

        let alert = NSAlert.javascriptAlert(with: message)
        alert.beginSheetModal(for: window) { _ in
            completionHandler()
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {

        guard webView === self.webView, let window = view.window else {
            os_log("%s: Could not display JS confirmation panel", type: .error, className)
            completionHandler(false)
            return
        }

        let alert = NSAlert.javascriptConfirmation(with: message)
        alert.beginSheetModal(for: window) { response in
            completionHandler(response == .alertFirstButtonReturn)
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {

        guard webView === self.webView, let window = view.window else {
            os_log("%s: Could not display JS text input panel", type: .error, className)
            completionHandler(nil)
            return
        }

        let alert = NSAlert.javascriptTextInput(prompt: prompt, defaultText: defaultText)
        alert.beginSheetModal(for: window) { response in
            guard let textField = alert.accessoryView as? NSTextField else {
                os_log("BrowserTabViewController: Textfield not found in alert", type: .error)
                completionHandler(nil)
                return
            }
            let answer = response == .alertFirstButtonReturn ? textField.stringValue : nil
            completionHandler(answer)
        }
    }

    func webViewDidClose(_ webView: WKWebView) {
        guard let webView = webView as? WebView else {
            os_log("BrowserTabViewController: Unknown instance of WKWebView", type: .error)
            return
        }

        tabCollectionViewModel.remove(ownerOf: webView)
    }

}

extension BrowserTabViewController: BrowserTabSelectionDelegate {

    func selectedTab(at index: Int) {
        show(displayableTabAtIndex: index)
    }

    func selectedPreferencePane(_ identifier: PreferencePaneIdentifier) {
        guard let selectedTab = tabCollectionViewModel.selectedTabViewModel?.tab else {
            return
        }

        if case .preferences = selectedTab.content {
            selectedTab.setContent(.preferences(pane: identifier))
        }
    }

}

private extension WKWebView {

    var tab: Tab? {
        guard let navigationDelegate = self.navigationDelegate else { return nil }
        guard let tab = navigationDelegate as? Tab else {
            assertionFailure("webView.navigationDelegate is not a Tab")
            return nil
        }
        return tab
    }

}

extension BrowserTabViewController: OnboardingDelegate {

    func onboardingDidRequestImportData(completion: @escaping () -> Void) {
        DataImportViewController.show(completion: completion)
    }

    func onboardingDidRequestSetDefault(completion: @escaping () -> Void) {
        let defaultBrowserPreferences = DefaultBrowserPreferences()
        if defaultBrowserPreferences.isDefault {
            completion()
            return
        }

        defaultBrowserPreferences.becomeDefault { _ in
            _ = defaultBrowserPreferences
            withAnimation {
                completion()
            }
        }
    }

    func onboardingHasFinished() {
        (view.window?.windowController as? MainWindowController)?.userInteraction(prevented: false)
    }

}

extension BrowserTabViewController {

    func addMouseMonitors() {
        guard mouseDownMonitor == nil else { return }

        self.mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.mouseDown(with: event)
        }
    }

    func removeMouseMonitors() {
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
        self.mouseDownMonitor = nil
    }

    func mouseDown(with event: NSEvent) -> NSEvent? {
        self.clickPoint = event.locationInWindow
        guard event.window === self.view.window, let clickPoint = self.clickPoint else { return event }
        tabViewModel?.tab.browserTabViewController(self, didClickAtPoint: clickPoint)
        return event
    }
}

// MARK: - Web View snapshot for Pinned Tab selected in more than 1 window

extension BrowserTabViewController {

    private func subscribeToTabSelectedInCurrentKeyWindow() {
        let lastKeyWindowOtherThanOurs = WindowControllersManager.shared.didChangeKeyWindowController
            .map { WindowControllersManager.shared.lastKeyMainWindowController }
            .prepend(WindowControllersManager.shared.lastKeyMainWindowController)
            .compactMap { $0 }
            .filter { [weak self] in $0.window !== self?.view.window }

        keyWindowSelectedTabCancellable = lastKeyWindowOtherThanOurs
            .flatMap(\.mainViewController.tabCollectionViewModel.$selectionIndex)
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self] index in
                self?.handleTabSelectedInKeyWindow(index)
            }
    }

    private func handleTabSelectedInKeyWindow(_ tabIndex: TabIndex) {
        if tabIndex.isPinnedTab, tabIndex == tabCollectionViewModel.selectionIndex, webViewSnapshot == nil {
            makeWebViewSnapshot()
        } else {
            hideWebViewSnapshotIfNeeded()
        }
    }

    private func makeWebViewSnapshot() {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let webView = webView else {
            os_log("BrowserTabViewController: failed to create a snapshot of webView", type: .error)
            return
        }

        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = false

        webView.takeSnapshot(with: config) { [weak self] image, _ in
            guard let image = image else {
                os_log("BrowserTabViewController: failed to create a snapshot of webView", type: .error)
                return
            }
            self?.showWebViewSnapshot(with: image)
        }
    }

    private func showWebViewSnapshot(with image: NSImage) {
        let snapshotView = WebViewSnapshotView(image: image, frame: view.bounds)
        snapshotView.autoresizingMask = [.width, .height]
        snapshotView.translatesAutoresizingMaskIntoConstraints = true

        view.addSubview(snapshotView)
        webViewSnapshot?.removeFromSuperview()
        webViewSnapshot = snapshotView
    }

    private func hideWebViewSnapshotIfNeeded() {
        if webViewSnapshot != nil {
            DispatchQueue.main.async {
                self.showTabContent(of: self.tabCollectionViewModel.selectedTabViewModel)
                self.webViewSnapshot?.removeFromSuperview()
            }
        }
    }
}
// swiftlint:enable file_length
