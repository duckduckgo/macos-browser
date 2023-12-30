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

import Cocoa
import Carbon.HIToolbox
import Combine
import Common

#if NETWORK_PROTECTION
import NetworkProtection
#endif

final class MainViewController: NSViewController {

    private let tabBarContainerView = NSView()
    private let navigationBarContainerView = NSView()
    private let webContainerView = NSView()
    private let findInPageContainerView = NSView().hidden()
    private let bookmarksBarContainerView = NSView()
    private let fireContainerView = NSView()
    private var navigationBarTopConstraint: NSLayoutConstraint!
    private var addressBarHeightConstraint: NSLayoutConstraint!
    private var bookmarksBarHeightConstraint: NSLayoutConstraint!

    private let divider = ColorView(frame: .zero, backgroundColor: .separatorColor)

    let tabBarViewController: TabBarViewController
    let navigationBarViewController: NavigationBarViewController
    let browserTabViewController: BrowserTabViewController
    let findInPageViewController: FindInPageViewController
    let fireViewController: FireViewController
    let bookmarksBarViewController: BookmarksBarViewController

    let tabCollectionViewModel: TabCollectionViewModel
    let isBurner: Bool

    private var selectedTabViewModelCancellable: AnyCancellable?
    private var bookmarksBarVisibilityChangedCancellable: AnyCancellable?
    private var navigationalCancellables = Set<AnyCancellable>()
    private var windowTitleCancellable: AnyCancellable?
    private var eventMonitorCancellables = Set<AnyCancellable>()

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
         bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        let tabCollectionViewModel = tabCollectionViewModel ?? TabCollectionViewModel()
        self.tabCollectionViewModel = tabCollectionViewModel
        self.isBurner = tabCollectionViewModel.isBurner

        tabBarViewController = TabBarViewController.create(tabCollectionViewModel: tabCollectionViewModel)
        navigationBarViewController = NavigationBarViewController.create(tabCollectionViewModel: tabCollectionViewModel, isBurner: isBurner)
        browserTabViewController = BrowserTabViewController.create(tabCollectionViewModel: tabCollectionViewModel)
        findInPageViewController = FindInPageViewController.create()
        fireViewController = FireViewController.create(tabCollectionViewModel: tabCollectionViewModel)
        bookmarksBarViewController = BookmarksBarViewController.create(tabCollectionViewModel: tabCollectionViewModel, bookmarkManager: bookmarkManager)

        super.init(nibName: nil, bundle: nil)

        findInPageViewController.delegate = self
    }

    override func loadView() {
        view = MainView(frame: NSRect(x: 0, y: 0, width: 600, height: 660))

        for subview in [
            tabBarContainerView,
            divider,
            bookmarksBarContainerView,
            navigationBarContainerView,
            webContainerView,
            findInPageContainerView,
            fireContainerView,
        ] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        addConstraints()

        addAndLayoutChild(tabBarViewController, into: tabBarContainerView)
        addAndLayoutChild(bookmarksBarViewController, into: bookmarksBarContainerView)
        addAndLayoutChild(navigationBarViewController, into: navigationBarContainerView)
        addAndLayoutChild(browserTabViewController, into: webContainerView)
        addAndLayoutChild(findInPageViewController, into: findInPageContainerView)
        addAndLayoutChild(fireViewController, into: fireContainerView)
    }

    private func addConstraints() {
        bookmarksBarHeightConstraint = bookmarksBarContainerView.heightAnchor.constraint(equalToConstant: 34)

        navigationBarTopConstraint = navigationBarContainerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 38)
        addressBarHeightConstraint = navigationBarContainerView.heightAnchor.constraint(equalToConstant: 42)

        NSLayoutConstraint.activate([
            tabBarContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            tabBarContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBarContainerView.heightAnchor.constraint(equalToConstant: 38),

            divider.topAnchor.constraint(equalTo: navigationBarContainerView.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            bookmarksBarContainerView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            bookmarksBarContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bookmarksBarContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bookmarksBarHeightConstraint,

            navigationBarTopConstraint,
            navigationBarContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBarContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            addressBarHeightConstraint,

            webContainerView.topAnchor.constraint(equalTo: bookmarksBarContainerView.bottomAnchor),
            webContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webContainerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 512),
            webContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 178),

            findInPageContainerView.topAnchor.constraint(equalTo: bookmarksBarContainerView.bottomAnchor, constant: -4),
            findInPageContainerView.topAnchor.constraint(equalTo: navigationBarContainerView.bottomAnchor, constant: -4).priority(900),
            findInPageContainerView.centerXAnchor.constraint(equalTo: navigationBarContainerView.centerXAnchor),
            findInPageContainerView.widthAnchor.constraint(equalToConstant: 400),
            findInPageContainerView.heightAnchor.constraint(equalToConstant: 40),

            fireContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            fireContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            fireContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fireContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        listenToKeyDownEvents()
        subscribeToSelectedTabViewModel()
        subscribeToAppSettingsNotifications()
        findInPageContainerView.applyDropShadow()

        view.registerForDraggedTypes([.URL, .fileURL])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        registerForBookmarkBarPromptNotifications()
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
        if let bookmarkBarPromptObserver {
            NotificationCenter.default.removeObserver(bookmarkBarPromptObserver)
        }
    }

    override func viewWillAppear() {
        if isInPopUpWindow {
            tabBarViewController.view.isHidden = true
            tabBarContainerView.isHidden = true
            navigationBarTopConstraint.constant = 0.0
            addressBarHeightConstraint.constant = tabBarContainerView.frame.height
            updateBookmarksBarViewVisibility(visible: false)
        } else {
            navigationBarContainerView.wantsLayer = true
            navigationBarContainerView.layer?.masksToBounds = false

            resizeNavigationBarForHomePage(tabCollectionViewModel.selectedTabViewModel?.tab.content == .homePage, animated: false)

            let bookmarksBarVisible = AppearancePreferences.shared.showBookmarksBar
            updateBookmarksBarViewVisibility(visible: bookmarksBarVisible)
        }

        updateDividerColor()
    }

    override func viewDidLayout() {
        findInPageContainerView.applyDropShadow()
    }

    func windowDidBecomeMain() {
        updateBackMenuItem()
        updateForwardMenuItem()
        updateReloadMenuItem()
        updateStopMenuItem()
        browserTabViewController.windowDidBecomeKey()

#if NETWORK_PROTECTION
        sendActiveNetworkProtectionWaitlistUserPixel()
        refreshNetworkProtectionMessages()
#endif

#if DBP
        DataBrokerProtectionAppEvents().windowDidBecomeMain()
#endif
    }

    func windowDidResignKey() {
        browserTabViewController.windowDidResignKey()
    }

    func showBookmarkPromptIfNeeded() {
        guard !bookmarksBarViewController.bookmarksBarPromptShown else { return }
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

#if NETWORK_PROTECTION
    private let networkProtectionMessaging = DefaultNetworkProtectionRemoteMessaging()

    func refreshNetworkProtectionMessages() {
        networkProtectionMessaging.fetchRemoteMessages()
    }
#endif

    override func encodeRestorableState(with coder: NSCoder) {
        fatalError("Default AppKit State Restoration should not be used")
    }

    func windowWillClose() {
        eventMonitorCancellables.removeAll()
        tabBarViewController.hideTabPreview()
    }

    func toggleBookmarksBarVisibility() {
        updateBookmarksBarViewVisibility(visible: !(bookmarksBarHeightConstraint.constant > 0))
    }

    // Can be updated via keyboard shortcut so needs to be internal visibility
    private func updateBookmarksBarViewVisibility(visible: Bool) {
        let showBookmarksBar = isInPopUpWindow ? false : visible

        if showBookmarksBar {
            if bookmarksBarViewController.parent == nil {
                addChild(bookmarksBarViewController)

                bookmarksBarViewController.view.frame = bookmarksBarContainerView.bounds
                bookmarksBarContainerView.addSubview(bookmarksBarViewController.view)
            }
        } else {
            bookmarksBarViewController.removeFromParent()
            bookmarksBarViewController.view.removeFromSuperview()
        }

        bookmarksBarHeightConstraint?.constant = showBookmarksBar ? 34 : 0

        updateDividerColor()
    }

    private func updateDividerColor() {
        NSAppearance.withAppAppearance {
            let isHomePage = tabCollectionViewModel.selectedTabViewModel?.tab.content == .homePage
            let backgroundColor: NSColor = (bookmarksBarIsVisible || isHomePage) ? .addressBarFocusedBackgroundColor : .addressBarSolidSeparatorColor
            divider.backgroundColor = backgroundColor
        }
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.navigationalCancellables = []
            self?.subscribeToCanGoBackForward()
            self?.subscribeToFindInPage()
            self?.subscribeToTabContent()
            self?.adjustFirstResponder()
            self?.subscribeToTitleChange()
        }
    }

    private func subscribeToTitleChange() {
        guard let window = self.view.window else { return }
        windowTitleCancellable = tabCollectionViewModel.$selectedTabViewModel
            .compactMap { tabViewModel in
                tabViewModel?.$title
            }
            .switchToLatest()
            .map {
                $0.truncated(length: MainMenu.Constants.maxTitleLength)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.title, onWeaklyHeld: window)
    }

    private func subscribeToAppSettingsNotifications() {
        bookmarksBarVisibilityChangedCancellable = NotificationCenter.default
            .publisher(for: AppearancePreferences.Notifications.showBookmarksBarSettingChanged)
            .sink { [weak self] _ in
                self?.updateBookmarksBarViewVisibility(visible: AppearancePreferences.shared.showBookmarksBar)
            }
    }

    private func resizeNavigationBarForHomePage(_ homePage: Bool, animated: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1

            let nonHomePageHeight: CGFloat = isInPopUpWindow ? 42 : 48

            let height = animated ? addressBarHeightConstraint.animator() : addressBarHeightConstraint
            height?.constant = homePage ? 52 : nonHomePageHeight

            updateDividerColor()
            navigationBarViewController.resizeAddressBarForHomePage(homePage, animated: animated)
        }
    }

    var lastTabContent: Tab.TabContent?
    private func subscribeToTabContent() {
        tabCollectionViewModel.selectedTabViewModel?.tab.$content.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] content in
            guard let self = self else { return }
            self.resizeNavigationBarForHomePage(content == .homePage, animated: content == .homePage && self.lastTabContent != .homePage)
            self.updateBookmarksBar(content)
            self.lastTabContent = content
            self.adjustFirstResponderOnContentChange(content: content)
        }).store(in: &self.navigationalCancellables)
    }

    private func updateBookmarksBar(_ content: Tab.TabContent, _ prefs: AppearancePreferences = AppearancePreferences.shared) {
        if content.isUrl && prefs.bookmarksBarAppearance == .newTabOnly {
            updateBookmarksBarViewVisibility(visible: false)
        } else if prefs.showBookmarksBar {
            updateBookmarksBarViewVisibility(visible: true)
        }
    }

    private func subscribeToFindInPage() {
        tabCollectionViewModel.selectedTabViewModel?.findInPage?
            .$isVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFindInPage()
            }
            .store(in: &self.navigationalCancellables)
    }

    private func subscribeToCanGoBackForward() {
        tabCollectionViewModel.selectedTabViewModel?.$canGoBack.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateBackMenuItem()
        }.store(in: &self.navigationalCancellables)
        tabCollectionViewModel.selectedTabViewModel?.$canGoForward.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateForwardMenuItem()
        }.store(in: &self.navigationalCancellables)
        tabCollectionViewModel.selectedTabViewModel?.$canReload.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateReloadMenuItem()
        }.store(in: &self.navigationalCancellables)
        tabCollectionViewModel.selectedTabViewModel?.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateStopMenuItem()
        }.store(in: &self.navigationalCancellables)
    }

    private func updateFindInPage() {
        guard let model = tabCollectionViewModel.selectedTabViewModel?.findInPage else {
            findInPageViewController.makeMeFirstResponder()
            os_log("MainViewController: Failed to get find in page model", type: .error)
            return
        }

        findInPageContainerView.isHidden = !model.isVisible
        findInPageViewController.model = model
        if model.isVisible {
            findInPageViewController.makeMeFirstResponder()
        }
    }

    private func updateBackMenuItem() {
        guard self.view.window?.isMainWindow == true else { return }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }
        NSApp.mainMenuTyped.backMenuItem.isEnabled = selectedTabViewModel.canGoBack
    }

    private func updateForwardMenuItem() {
        guard self.view.window?.isMainWindow == true else { return }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }
        NSApp.mainMenuTyped.forwardMenuItem.isEnabled = selectedTabViewModel.canGoForward
    }

    private func updateReloadMenuItem() {
        guard self.view.window?.isMainWindow == true else { return }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }
        NSApp.mainMenuTyped.reloadMenuItem.isEnabled = selectedTabViewModel.canReload
    }

    private func updateStopMenuItem() {
        guard self.view.window?.isMainWindow == true else { return }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }
        NSApp.mainMenuTyped.stopMenuItem.isEnabled = selectedTabViewModel.isLoading
    }

#if NETWORK_PROTECTION
    private func sendActiveNetworkProtectionWaitlistUserPixel() {
        if DefaultNetworkProtectionVisibility().waitlistIsOngoing {
            DailyPixel.fire(pixel: .networkProtectionWaitlistUserActive, frequency: .dailyOnly, includeAppVersionParameter: true)
        }
    }
#endif

    // MARK: - First responder

    func adjustFirstResponder() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        switch selectedTabViewModel.tab.content {
        case .homePage:
            navigationBarViewController.addressBarViewController?.addressBarTextField.makeMeFirstResponder()
        case .onboarding:
            self.view.makeMeFirstResponder()
        case .url:
            browserTabViewController.makeWebViewFirstResponder()
        case .preferences:
            browserTabViewController.preferencesViewController?.view.makeMeFirstResponder()
        case .bookmarks:
            browserTabViewController.bookmarksViewController?.view.makeMeFirstResponder()
        case .none:
            shouldAdjustFirstResponderOnContentChange = true
        case .dataBrokerProtection:
            browserTabViewController.preferencesViewController?.view.makeMeFirstResponder()
        }
    }

    var shouldAdjustFirstResponderOnContentChange = false

    func adjustFirstResponderOnContentChange(content: Tab.TabContent) {
        guard shouldAdjustFirstResponderOnContentChange, content != .none else {
            return
        }

        shouldAdjustFirstResponderOnContentChange = false
        adjustFirstResponder()
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
        case kVK_Escape:
            var isHandled = false
            if !findInPageContainerView.isHidden {
                findInPageViewController.findInPageDone(self)
                isHandled = true
            }
            if let addressBarVC = navigationBarViewController.addressBarViewController {
                isHandled = isHandled || addressBarVC.escapeKeyDown()
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

        default:
            return false
        }
    }

    func otherMouseUp(with event: NSEvent) -> NSEvent? {
        guard event.window === self.view.window,
              self.webContainerView.isMouseLocationInsideBounds(event.locationInWindow)
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

    let vc = MainViewController(bookmarkManager: bkman)
    var c: AnyCancellable!
    c = vc.publisher(for: \.view.window).sink { window in
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        withExtendedLifetime(c) {}
    }

    return vc
}
#endif
