//
//  MainViewController.swift
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
import Cocoa
import Carbon.HIToolbox
import Combine
import Common
import NetworkProtection
import NetworkProtectionIPC
import os.log
import BrokenSitePrompt

final class MainViewController: NSViewController {
    private(set) lazy var mainView = MainView(frame: NSRect(x: 0, y: 0, width: 600, height: 660))

    let tabBarViewController: TabBarViewController
    let navigationBarViewController: NavigationBarViewController
    let browserTabViewController: BrowserTabViewController
    let findInPageViewController: FindInPageViewController
    let fireViewController: FireViewController
    let bookmarksBarViewController: BookmarksBarViewController
    let featureFlagger: FeatureFlagger
    private let bookmarksBarVisibilityManager: BookmarksBarVisibilityManager

    let tabCollectionViewModel: TabCollectionViewModel
    let isBurner: Bool

    private var addressBarBookmarkIconVisibilityCancellable: AnyCancellable?
    private var selectedTabViewModelCancellable: AnyCancellable?
    private var tabViewModelCancellables = Set<AnyCancellable>()
    private var bookmarksBarVisibilityChangedCancellable: AnyCancellable?
    private var eventMonitorCancellables = Set<AnyCancellable>()
    private let aiChatMenuConfig: AIChatMenuVisibilityConfigurable

    private var bookmarksBarIsVisible: Bool {
        return bookmarksBarViewController.parent != nil
    }

    private var isInPopUpWindow: Bool {
        view.window?.isPopUpWindow == true
    }

    required init?(coder: NSCoder) {
        fatalError("MainViewController: Bad initializer")
    }

    init(tabCollectionViewModel: TabCollectionViewModel? = nil,
         bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
         autofillPopoverPresenter: AutofillPopoverPresenter,
         vpnXPCClient: VPNControllerXPCClient = .shared,
         aiChatMenuConfig: AIChatMenuVisibilityConfigurable = AIChatMenuConfiguration(),
         brokenSitePromptLimiter: BrokenSitePromptLimiter = .shared,
         featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger
    ) {

        self.aiChatMenuConfig = aiChatMenuConfig
        let tabCollectionViewModel = tabCollectionViewModel ?? TabCollectionViewModel()
        self.tabCollectionViewModel = tabCollectionViewModel
        self.isBurner = tabCollectionViewModel.isBurner
        self.featureFlagger = featureFlagger

        tabBarViewController = TabBarViewController.create(tabCollectionViewModel: tabCollectionViewModel, activeRemoteMessageModel: NSApp.delegateTyped.activeRemoteMessageModel)
        bookmarksBarVisibilityManager = BookmarksBarVisibilityManager(selectedTabPublisher: tabCollectionViewModel.$selectedTabViewModel.eraseToAnyPublisher())

        let networkProtectionPopoverManager: NetPPopoverManager = { @MainActor in
#if DEBUG
            guard case .normal = NSApp.runType else {
                return NetPPopoverManagerMock()
            }
#endif

            vpnXPCClient.register { error in
                NetworkProtectionKnownFailureStore().lastKnownFailure = KnownFailure(error)
            }

            let vpnUninstaller = VPNUninstaller(ipcClient: vpnXPCClient)

            return NetworkProtectionNavBarPopoverManager(
                ipcClient: vpnXPCClient,
                vpnUninstaller: vpnUninstaller,
                vpnUIPresenting: WindowControllersManager.shared)
        }()
        let networkProtectionStatusReporter: NetworkProtectionStatusReporter = {
            var connectivityIssuesObserver: ConnectivityIssueObserver!
            var controllerErrorMessageObserver: ControllerErrorMesssageObserver!
#if DEBUG
            if ![.normal, .integrationTests].contains(NSApp.runType) {
                connectivityIssuesObserver = ConnectivityIssueObserverMock()
                controllerErrorMessageObserver = ControllerErrorMesssageObserverMock()
            }
#endif
            connectivityIssuesObserver = connectivityIssuesObserver ?? DisabledConnectivityIssueObserver()
            controllerErrorMessageObserver = controllerErrorMessageObserver ?? ControllerErrorMesssageObserverThroughDistributedNotifications()

            return DefaultNetworkProtectionStatusReporter(
                statusObserver: vpnXPCClient.ipcStatusObserver,
                serverInfoObserver: vpnXPCClient.ipcServerInfoObserver,
                connectionErrorObserver: vpnXPCClient.ipcConnectionErrorObserver,
                connectivityIssuesObserver: connectivityIssuesObserver,
                controllerErrorMessageObserver: controllerErrorMessageObserver,
                dataVolumeObserver: vpnXPCClient.ipcDataVolumeObserver,
                knownFailureObserver: KnownFailureObserverThroughDistributedNotifications()
            )
        }()

        navigationBarViewController = NavigationBarViewController.create(tabCollectionViewModel: tabCollectionViewModel,
                                                                         networkProtectionPopoverManager: networkProtectionPopoverManager,
                                                                         networkProtectionStatusReporter: networkProtectionStatusReporter,
                                                                         autofillPopoverPresenter: autofillPopoverPresenter,
                                                                         aiChatMenuConfig: aiChatMenuConfig,
                                                                         brokenSitePromptLimiter: brokenSitePromptLimiter)

        browserTabViewController = BrowserTabViewController(tabCollectionViewModel: tabCollectionViewModel, bookmarkManager: bookmarkManager)
        findInPageViewController = FindInPageViewController.create()
        fireViewController = FireViewController.create(tabCollectionViewModel: tabCollectionViewModel)
        bookmarksBarViewController = BookmarksBarViewController.create(tabCollectionViewModel: tabCollectionViewModel, bookmarkManager: bookmarkManager)

        super.init(nibName: nil, bundle: nil)
        browserTabViewController.delegate = self
        findInPageViewController.delegate = self
    }

    override func loadView() {
        view = mainView

        addAndLayoutChild(tabBarViewController, into: mainView.tabBarContainerView)
        addAndLayoutChild(bookmarksBarViewController, into: mainView.bookmarksBarContainerView)
        addAndLayoutChild(navigationBarViewController, into: mainView.navigationBarContainerView)
        addAndLayoutChild(browserTabViewController, into: mainView.webContainerView)
        addAndLayoutChild(findInPageViewController, into: mainView.findInPageContainerView)
        addAndLayoutChild(fireViewController, into: mainView.fireContainerView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        listenToKeyDownEvents()
        subscribeToMouseTrackingArea()
        subscribeToSelectedTabViewModel()
        subscribeToBookmarkBarVisibility()
        subscribeToFirstResponder()
        mainView.findInPageContainerView.applyDropShadow()

        view.registerForDraggedTypes([.URL, .fileURL])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        mainView.setMouseAboveWebViewTrackingAreaEnabled(true)
        registerForBookmarkBarPromptNotifications()
        adjustFirstResponder(force: true)
    }

    var bookmarkBarPromptObserver: Any?
    func registerForBookmarkBarPromptNotifications() {
        guard !bookmarksBarViewController.bookmarksBarPromptShown else { return }
        bookmarkBarPromptObserver = NotificationCenter.default.addObserver(
            forName: .bookmarkPromptShouldShow,
            object: nil,
            queue: .main) { [weak self] _ in
                self?.showBookmarkPromptIfNeeded()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        mainView.setMouseAboveWebViewTrackingAreaEnabled(false)
        if let bookmarkBarPromptObserver {
            NotificationCenter.default.removeObserver(bookmarkBarPromptObserver)
        }
    }

    override func viewWillAppear() {
        if isInPopUpWindow {
            tabBarViewController.view.isHidden = true
            mainView.tabBarContainerView.isHidden = true
            mainView.navigationBarTopConstraint.constant = 0.0
            resizeNavigationBar(isHomePage: false, animated: false)

            updateBookmarksBarViewVisibility(visible: false)
        } else {
            mainView.navigationBarContainerView.wantsLayer = true
            mainView.navigationBarContainerView.layer?.masksToBounds = false

            if tabCollectionViewModel.selectedTabViewModel?.tab.content == .newtab,
               browserTabViewController.homePageViewController?.addressBarModel.shouldShowAddressBar == false {
                resizeNavigationBar(isHomePage: true, animated: lastTabContent != .newtab)
            } else {
                resizeNavigationBar(isHomePage: false, animated: false)
            }
        }

        updateDividerColor(isShowingHomePage: tabCollectionViewModel.selectedTabViewModel?.tab.content == .newtab)
    }

    override func viewDidLayout() {
        mainView.findInPageContainerView.applyDropShadow()
    }

    func windowDidBecomeMain() {
        updateBackMenuItem()
        updateForwardMenuItem()
        updateReloadMenuItem()
        updateStopMenuItem()
        browserTabViewController.windowDidBecomeKey()
    }

    func windowDidResignKey() {
        browserTabViewController.windowDidResignKey()
        tabBarViewController.hideTabPreview()
    }

    func showBookmarkPromptIfNeeded() {
        guard !bookmarksBarViewController.bookmarksBarPromptShown, OnboardingActionsManager.isOnboardingFinished else { return }
        if bookmarksBarIsVisible {
            // Don't show this to users who obviously know about the bookmarks bar already
            bookmarksBarViewController.bookmarksBarPromptShown = true
            return
        }

        updateBookmarksBarViewVisibility(visible: true)
        // This won't work until the bookmarks bar is actually visible which it isn't until the next ui cycle
        DispatchQueue.main.async {
            self.bookmarksBarViewController.showBookmarksBarPrompt()
        }
    }

    override func encodeRestorableState(with coder: NSCoder) {
        fatalError("Default AppKit State Restoration should not be used")
    }

    func windowWillClose() {
        eventMonitorCancellables.removeAll()
        tabBarViewController.hideTabPreview()
    }

    func windowWillMiniaturize() {
        tabBarViewController.hideTabPreview()
    }

    func windowWillEnterFullScreen() {
        tabBarViewController.hideTabPreview()
    }

    func disableTabPreviews() {
        tabBarViewController.shouldDisplayTabPreviews = false
    }

    func enableTabPreviews() {
        tabBarViewController.shouldDisplayTabPreviews = true
    }

    func toggleBookmarksBarVisibility() {
        updateBookmarksBarViewVisibility(visible: !(mainView.bookmarksBarHeightConstraint.constant > 0))
    }

    // Can be updated via keyboard shortcut so needs to be internal visibility
    private func updateBookmarksBarViewVisibility(visible: Bool) {
        let showBookmarksBar = isInPopUpWindow ? false : visible

        if showBookmarksBar {
            if bookmarksBarViewController.parent == nil {
                addChild(bookmarksBarViewController)

                bookmarksBarViewController.view.frame = mainView.bookmarksBarContainerView.bounds
                mainView.bookmarksBarContainerView.addSubview(bookmarksBarViewController.view)
            }
        } else {
            bookmarksBarViewController.removeFromParent()
            bookmarksBarViewController.view.removeFromSuperview()
        }

        mainView.bookmarksBarHeightConstraint?.constant = showBookmarksBar ? 34 : 0
        mainView.layoutSubtreeIfNeeded()
        mainView.updateTrackingAreas()

        updateDividerColor(isShowingHomePage: tabCollectionViewModel.selectedTabViewModel?.tab.content == .newtab)
    }

    private func updateDividerColor(isShowingHomePage isHomePage: Bool) {
        NSAppearance.withAppAppearance {
            let backgroundColor: NSColor = (bookmarksBarIsVisible || isHomePage) ? .bookmarkBarBackground : .addressBarSolidSeparator
            mainView.divider.backgroundColor = backgroundColor
        }
    }

    private func subscribeToMouseTrackingArea() {
        addressBarBookmarkIconVisibilityCancellable = mainView.$isMouseAboveWebView
            .sink { [weak self] isMouseAboveWebView in
                self?.navigationBarViewController.addressBarViewController?
                    .addressBarButtonsViewController?.isMouseOverNavigationBar = isMouseAboveWebView
            }
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.sink { [weak self] tabViewModel in
            guard let self, let tabViewModel else { return }

            tabViewModelCancellables.removeAll(keepingCapacity: true)
            subscribeToCanGoBackForward(of: tabViewModel)
            subscribeToFindInPage(of: tabViewModel)
            subscribeToTitleChange(of: tabViewModel)
            subscribeToTabContent(of: tabViewModel)
        }
    }

    private func subscribeToTitleChange(of selectedTabViewModel: TabViewModel?) {
        guard let selectedTabViewModel else { return }

        // Only subscribe once the view is added to the window.
        let windowPublisher = view.publisher(for: \.window).filter({ $0 != nil }).prefix(1).asVoid()

        windowPublisher
            .combineLatest(selectedTabViewModel.$title) { $1 }
            .map {
                $0.truncated(length: MainMenu.Constants.maxTitleLength)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] title in
                guard let self else { return }
                guard !isBurner else {
                    // Fire Window: don‘t display active Tab title as the Window title
                    view.window?.title = UserText.burnerWindowHeader
                    return
                }

                view.window?.title = title
            }
            .store(in: &tabViewModelCancellables)
    }

    private func subscribeToBookmarkBarVisibility() {
        bookmarksBarVisibilityChangedCancellable = bookmarksBarVisibilityManager
            .$isBookmarksBarVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isBookmarksBarVisible in
                self?.updateBookmarksBarViewVisibility(visible: isBookmarksBarVisible)
            }
    }

    private func resizeNavigationBar(isHomePage homePage: Bool, animated: Bool) {
        updateDividerColor(isShowingHomePage: homePage)
        navigationBarViewController.resizeAddressBar(for: homePage ? .homePage : (isInPopUpWindow ? .popUpWindow : .default), animated: animated)
    }

    private var lastTabContent = Tab.TabContent.none
    private func subscribeToTabContent(of selectedTabViewModel: TabViewModel?) {
        selectedTabViewModel?.tab.$content
            .sink { [weak self, weak selectedTabViewModel] content in
                guard let self, let selectedTabViewModel else { return }
                defer { lastTabContent = content }

                if content == .newtab {
                    if browserTabViewController.homePageViewController?.addressBarModel.shouldShowAddressBar == true {
                        subscribeToNTPAddressBarVisibility(of: selectedTabViewModel)
                    } else {
                        ntpAddressBarVisibilityCancellable?.cancel()
                        resizeNavigationBar(isHomePage: true, animated: lastTabContent != .newtab)
                    }
                } else {
                    ntpAddressBarVisibilityCancellable?.cancel()
                    resizeNavigationBar(isHomePage: false, animated: false)
                }
                adjustFirstResponder(selectedTabViewModel: selectedTabViewModel, tabContent: content)
            }
            .store(in: &self.tabViewModelCancellables)
    }

    private var ntpAddressBarVisibilityCancellable: AnyCancellable?

    private func subscribeToNTPAddressBarVisibility(of selectedTabViewModel: TabViewModel) {
        ntpAddressBarVisibilityCancellable = browserTabViewController.homePageViewController?.appearancePreferences.$isSearchBarVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAddressBarVisible in
                guard let self else { return }
                resizeNavigationBar(isHomePage: !isAddressBarVisible, animated: true)
                adjustFirstResponder(selectedTabViewModel: selectedTabViewModel, tabContent: .newtab)
            }
    }

    private func subscribeToFirstResponder() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(firstReponderDidChange(_:)),
                                               name: .firstResponder,
                                               object: nil)

    }
    @objc private func firstReponderDidChange(_ notification: Notification) {
        // when window first responder is reset (to the window): activate Tab Content View
        if view.window?.firstResponder === view.window {
            browserTabViewController.adjustFirstResponder()
        }
    }

    private func subscribeToFindInPage(of selectedTabViewModel: TabViewModel?) {
        selectedTabViewModel?.findInPage?
            .$isVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFindInPage()
            }
            .store(in: &self.tabViewModelCancellables)
    }

    private func subscribeToCanGoBackForward(of selectedTabViewModel: TabViewModel) {
        selectedTabViewModel.$canGoBack.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateBackMenuItem()
        }.store(in: &self.tabViewModelCancellables)
        selectedTabViewModel.$canGoForward.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateForwardMenuItem()
        }.store(in: &self.tabViewModelCancellables)
        selectedTabViewModel.$canReload.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateReloadMenuItem()
        }.store(in: &self.tabViewModelCancellables)
        selectedTabViewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateStopMenuItem()
        }.store(in: &self.tabViewModelCancellables)
    }

    private func updateFindInPage() {
        guard let model = tabCollectionViewModel.selectedTabViewModel?.findInPage else {
            findInPageViewController.makeMeFirstResponder()
            Logger.general.error("MainViewController: Failed to get find in page model")
            return
        }

        mainView.findInPageContainerView.isHidden = !model.isVisible
        findInPageViewController.model = model
        if model.isVisible {
            findInPageViewController.makeMeFirstResponder()
        }
    }

    private func updateBackMenuItem() {
        guard self.view.window?.isMainWindow == true else { return }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            Logger.general.error("MainViewController: No tab view model selected")
            return
        }
        NSApp.mainMenuTyped.backMenuItem.isEnabled = selectedTabViewModel.canGoBack
    }

    private func updateForwardMenuItem() {
        guard self.view.window?.isMainWindow == true else { return }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            Logger.general.error("MainViewController: No tab view model selected")
            return
        }
        NSApp.mainMenuTyped.forwardMenuItem.isEnabled = selectedTabViewModel.canGoForward
    }

    private func updateReloadMenuItem() {
        guard self.view.window?.isMainWindow == true else { return }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            Logger.general.error("MainViewController: No tab view model selected")
            return
        }
        NSApp.mainMenuTyped.reloadMenuItem.isEnabled = selectedTabViewModel.canReload
    }

    private func updateStopMenuItem() {
        guard self.view.window?.isMainWindow == true else { return }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            Logger.general.error("MainViewController: No tab view model selected")
            return
        }
        NSApp.mainMenuTyped.stopMenuItem.isEnabled = selectedTabViewModel.isLoading
    }

    // MARK: - First responder

    func adjustFirstResponder(selectedTabViewModel: TabViewModel? = nil, tabContent: Tab.TabContent? = nil, force: Bool = false) {
        guard let selectedTabViewModel = selectedTabViewModel ?? tabCollectionViewModel.selectedTabViewModel else {
            return
        }
        let tabContent = tabContent ?? selectedTabViewModel.tab.content

        if case .newtab = tabContent {
            navigationBarViewController.addressBarViewController?.addressBarTextField.makeMeFirstResponder()
        } else {
            // ignore published tab switch: BrowserTabViewController
            // adjusts first responder itself
            guard selectedTabViewModel === tabCollectionViewModel.selectedTabViewModel || force else { return }
            browserTabViewController.adjustFirstResponder(force: force, tabContent: tabContent)
        }
    }

}
extension MainViewController: NSDraggingDestination {

    func draggingEntered(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    func draggingUpdated(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        guard draggingInfo.draggingPasteboard.url != nil else { return .none }

        return .copy
    }

    func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        guard let url = draggingInfo.draggingPasteboard.url else { return false }

        browserTabViewController.openNewTab(with: .url(url, source: .appOpenUrl))
        return true
    }

}

// MARK: - Mouse & Keyboard Events

// This needs to be handled here or else there will be a "beep" even if handled in a different view controller. This now
//  matches Safari behaviour.
extension MainViewController {

    func listenToKeyDownEvents() {
        NSEvent.addLocalCancellableMonitor(forEventsMatching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.customKeyDown(with: event) ? nil : event
        }.store(in: &eventMonitorCancellables)
        NSEvent.addLocalCancellableMonitor(forEventsMatching: .otherMouseUp) { [weak self] event in
            guard let self else { return event }
            return self.otherMouseUp(with: event)
        }.store(in: &eventMonitorCancellables)
    }

    func customKeyDown(with event: NSEvent) -> Bool {
        guard let locWindow = self.view.window,
              NSApplication.shared.keyWindow === locWindow else { return false }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting(.capsLock)

        switch Int(event.keyCode) {
        case kVK_Return  where navigationBarViewController.addressBarViewController?
                .addressBarTextField.isFirstResponder == true:

            navigationBarViewController.addressBarViewController?.addressBarTextField.addressBarEnterPressed()

            return true

        case kVK_Escape:
            var isHandled = false
            if !mainView.findInPageContainerView.isHidden {
                findInPageViewController.findInPageDone(self)
                isHandled = true
            }
            if let addressBarVC = navigationBarViewController.addressBarViewController {
                isHandled = isHandled || addressBarVC.escapeKeyDown()
            }
            if let homePageAddressBarModel = browserTabViewController.homePageViewController?.addressBarModel {
                isHandled = isHandled || homePageAddressBarModel.escapeKeyDown()
            }
            return isHandled

        // Handle critical Main Menu actions before WebView
        case kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6,
             kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
             kVK_ANSI_Keypad1, kVK_ANSI_Keypad2, kVK_ANSI_Keypad3, kVK_ANSI_Keypad4,
             kVK_ANSI_Keypad5, kVK_ANSI_Keypad6, kVK_ANSI_Keypad7, kVK_ANSI_Keypad8,
             kVK_ANSI_Keypad9:
            guard flags == .command else { return false }
            fallthrough
        case kVK_Tab where [[.control], [.control, .shift]].contains(flags),
             kVK_ANSI_N where flags == .command,
             kVK_ANSI_W where flags.contains(.command),
             kVK_ANSI_T where [[.command], [.command, .shift]].contains(flags),
             kVK_ANSI_Q where flags == .command,
             kVK_ANSI_R where flags == .command:
            guard view.window?.firstResponder is WebView else { return false }
            NSApp.menu?.performKeyEquivalent(with: event)
            return true

        case kVK_ANSI_Y where flags == .command:
            if NSApp.delegateTyped.featureFlagger.isFeatureOn(.historyView) {
                return false
            }
            (NSApp.mainMenuTyped.historyMenu.accessibilityParent() as? NSMenuItem)?.accessibilityPerformPress()
            return true

        default:
            return false
        }
    }

    func otherMouseUp(with event: NSEvent) -> NSEvent? {
        guard event.window === self.view.window,
              mainView.webContainerView.isMouseLocationInsideBounds(event.locationInWindow)
        else { return event }

        if event.buttonNumber == 3,
           tabCollectionViewModel.selectedTabViewModel?.canGoBack == true {
            tabCollectionViewModel.selectedTabViewModel?.tab.goBack()
            return nil
        } else if event.buttonNumber == 4,
                  tabCollectionViewModel.selectedTabViewModel?.canGoForward == true {
            tabCollectionViewModel.selectedTabViewModel?.tab.goForward()
            return nil
        }

        return event

    }
}

// MARK: - BrowserTabViewControllerDelegate

extension MainViewController: BrowserTabViewControllerDelegate {

    func highlightFireButton() {
        tabBarViewController.startFireButtonPulseAnimation()
    }

    func dismissViewHighlight() {
        tabBarViewController.stopFireButtonPulseAnimation()
        navigationBarViewController.addressBarViewController?.addressBarButtonsViewController?.stopHighlightingPrivacyShield()
    }

    func highlightPrivacyShield() {
        navigationBarViewController.addressBarViewController?.addressBarButtonsViewController?.highlightPrivacyShield()
    }

}

#if DEBUG
@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 700, height: 660)) {

    let bkman = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [
        BookmarkFolder(id: "1", title: "Folder", children: [
            Bookmark(id: "2", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true)
        ]),
        Bookmark(id: "3", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "1")
    ]))
    bkman.loadBookmarks()

    let vc = MainViewController(bookmarkManager: bkman, autofillPopoverPresenter: DefaultAutofillPopoverPresenter())
    var c: AnyCancellable!
    c = vc.publisher(for: \.view.window).sink { window in
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        withExtendedLifetime(c) {}
    }

    return vc
}
#endif
