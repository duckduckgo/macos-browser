//
//  WindowControllersManager.swift
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
import Combine
import Common
import os.log
import BrowserServicesKit

@MainActor
protocol WindowControllersManagerProtocol {

    var mainWindowControllers: [MainWindowController] { get }
    var selectedTab: Tab? { get }
    var allTabCollectionViewModels: [TabCollectionViewModel] { get }

    var lastKeyMainWindowController: MainWindowController? { get }
    var pinnedTabsManager: PinnedTabsManager { get }

    var didRegisterWindowController: PassthroughSubject<(MainWindowController), Never> { get }
    var didUnregisterWindowController: PassthroughSubject<(MainWindowController), Never> { get }

    func register(_ windowController: MainWindowController)
    func unregister(_ windowController: MainWindowController)

    func show(url: URL?, source: Tab.TabContent.URLSource, newTab: Bool)
    func showBookmarksTab()

    @discardableResult
    func openNewWindow(with tabCollectionViewModel: TabCollectionViewModel?,
                       burnerMode: BurnerMode,
                       droppingPoint: NSPoint?,
                       contentSize: NSSize?,
                       showWindow: Bool,
                       popUp: Bool,
                       lazyLoadTabs: Bool,
                       isMiniaturized: Bool,
                       isMaximized: Bool,
                       isFullscreen: Bool) -> MainWindow?
    func showTab(with content: Tab.TabContent)
}
extension WindowControllersManagerProtocol {
    @discardableResult
    func openNewWindow(with tabCollectionViewModel: TabCollectionViewModel? = nil,
                       burnerMode: BurnerMode = .regular,
                       droppingPoint: NSPoint? = nil,
                       contentSize: NSSize? = nil,
                       showWindow: Bool = true,
                       popUp: Bool = false,
                       lazyLoadTabs: Bool = false) -> MainWindow? {
        openNewWindow(with: tabCollectionViewModel, burnerMode: burnerMode, droppingPoint: droppingPoint, contentSize: contentSize, showWindow: showWindow, popUp: popUp, lazyLoadTabs: lazyLoadTabs, isMiniaturized: false, isMaximized: false, isFullscreen: false)
    }
}

@MainActor
final class WindowControllersManager: WindowControllersManagerProtocol {

    static let shared = WindowControllersManager(pinnedTabsManager: Application.appDelegate.pinnedTabsManager,
                                                 subscriptionFeatureAvailability: DefaultSubscriptionFeatureAvailability()
    )

    var activeViewController: MainViewController? {
        lastKeyMainWindowController?.mainViewController
    }

    init(pinnedTabsManager: PinnedTabsManager,
         subscriptionFeatureAvailability: SubscriptionFeatureAvailability) {
        self.pinnedTabsManager = pinnedTabsManager
        self.subscriptionFeatureAvailability = subscriptionFeatureAvailability
    }

    /**
     * _Initial_ meaning a single window with a single home page tab.
     */
    @Published private(set) var isInInitialState: Bool = true
    @Published private(set) var mainWindowControllers = [MainWindowController]()
    private(set) var pinnedTabsManager: PinnedTabsManager
    private let subscriptionFeatureAvailability: SubscriptionFeatureAvailability

    weak var lastKeyMainWindowController: MainWindowController? {
        didSet {
            if lastKeyMainWindowController != oldValue {
                didChangeKeyWindowController.send(lastKeyMainWindowController)
            }
        }
    }

    let didChangeKeyWindowController = PassthroughSubject<MainWindowController?, Never>()
    let didRegisterWindowController = PassthroughSubject<(MainWindowController), Never>()
    let didUnregisterWindowController = PassthroughSubject<(MainWindowController), Never>()

    func register(_ windowController: MainWindowController) {
        guard !mainWindowControllers.contains(windowController) else {
            assertionFailure("Window controller already registered")
            return
        }

        mainWindowControllers.append(windowController)
        didRegisterWindowController.send(windowController)
    }

    func unregister(_ windowController: MainWindowController) {
        guard let idx = mainWindowControllers.firstIndex(of: windowController) else {
            Logger.general.error("WindowControllersManager: Window Controller not registered")
            return
        }
        mainWindowControllers.remove(at: idx)
        didUnregisterWindowController.send(windowController)
    }

    func updateIsInInitialState() {
        if isInInitialState {

            isInInitialState = mainWindowControllers.isEmpty ||
            (
                mainWindowControllers.count == 1 &&
                mainWindowControllers.first?.mainViewController.tabCollectionViewModel.tabs.count == 1 &&
                mainWindowControllers.first?.mainViewController.tabCollectionViewModel.tabs.first?.content == .newtab &&
                pinnedTabsManager.tabCollection.tabs.isEmpty
            )
        }
    }

}

// MARK: - Opening a url from the external event

extension WindowControllersManager {

    func showDataBrokerProtectionTab() {
        showTab(with: .dataBrokerProtection)
    }

    func showBookmarksTab() {
        showTab(with: .bookmarks)
    }

    func showPreferencesTab(withSelectedPane pane: PreferencePaneIdentifier? = nil) {
        showTab(with: .settings(pane: pane))
    }

    /// Opens a bookmark in a tab, respecting the current modifier keys when deciding where to open the bookmark's URL.
    func open(bookmark: Bookmark) {
        guard let url = bookmark.urlObject else { return }

        if NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
            WindowsManager.openNewWindow(with: url, source: .bookmark, isBurner: false)
        } else if mainWindowController?.mainViewController.view.window?.isPopUpWindow ?? false {
            show(url: url, source: .bookmark, newTab: true)
        } else if NSApplication.shared.isCommandPressed && !NSApplication.shared.isOptionPressed {
            mainWindowController?.mainViewController.tabCollectionViewModel.appendNewTab(with: .url(url, source: .bookmark), selected: false)
        } else if selectedTab?.isPinned ?? false { // When selecting a bookmark with a pinned tab active, always open the URL in a new tab
            show(url: url, source: .bookmark, newTab: true)
        } else {
            show(url: url, source: .bookmark)
        }
        PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
    }

    func show(url: URL?, source: Tab.TabContent.URLSource, newTab: Bool = false) {
        let nonPopupMainWindowControllers = mainWindowControllers.filter { $0.window?.isPopUpWindow == false }
        if source == .bookmark {
            PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
        }
        // If there is a main window, open the URL in it
        if let windowController = nonPopupMainWindowControllers.first(where: { $0.window?.isMainWindow == true })
            // If a last key window is available, open the URL in it
            ?? lastKeyMainWindowController
            // If there is any open window on the current screen, open the URL in it
            ?? nonPopupMainWindowControllers.first(where: { $0.window?.screen == NSScreen.main })
            // If there is any non-popup window available, open the URL in it
            ?? nonPopupMainWindowControllers.first {

            let tabCollectionViewModel = windowController.mainViewController.tabCollectionViewModel
            let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel
            let selectionIndex = tabCollectionViewModel.selectionIndex

            // Switch to already open tab if present
            if [.appOpenUrl, .switchToOpenTab].contains(source),
               let url, switchToOpenTab(with: url, preferring: windowController) == true {

                if let selectedTabViewModel, let selectionIndex,
                   case .newtab = selectedTabViewModel.tab.content {
                    // close tab with "new tab" page open
                    tabCollectionViewModel.remove(at: selectionIndex)

                    // close the window if no more non-pinned tabs are open
                    if tabCollectionViewModel.tabs.isEmpty, let window = windowController.window, window.isVisible,
                       mainWindowController?.mainViewController.tabCollectionViewModel.selectedTabIndex?.isPinnedTab != true {
                        window.performClose(nil)
                    }
                }
                return
            }

            show(url: url, in: windowController, source: source, newTab: newTab)
            return
        }

        // Open a new window
        if let url = url {
            WindowsManager.openNewWindow(with: url, source: source, isBurner: false)
        } else {
            WindowsManager.openNewWindow(burnerMode: .regular)
        }
    }

    private func switchToOpenTab(with url: URL, preferring mainWindowController: MainWindowController) -> Bool {
        for (windowIdx, windowController) in ([mainWindowController] + mainWindowControllers).enumerated() {
            // prefer current main window
            guard windowIdx == 0 || windowController !== mainWindowController else { continue }
            let tabCollectionViewModel = windowController.mainViewController.tabCollectionViewModel
            guard let index = tabCollectionViewModel.indexInAllTabs(where: {
                $0.content.urlForWebView == url || (url.isSettingsURL && $0.content.urlForWebView?.isSettingsURL == true)
            }) else { continue }

            windowController.window?.makeKeyAndOrderFront(self)
            tabCollectionViewModel.select(at: index)
            if let tab = tabCollectionViewModel.tabViewModel(at: index)?.tab,
               tab.content.urlForWebView != url {
                // navigate to another settings pane
                tab.setContent(.contentFromURL(url, source: .switchToOpenTab))
            }

            return true
        }
        return false
    }

    private func show(url: URL?, in windowController: MainWindowController, source: Tab.TabContent.URLSource, newTab: Bool) {
        let viewController = windowController.mainViewController
        windowController.window?.makeKeyAndOrderFront(self)

        let tabCollectionViewModel = viewController.tabCollectionViewModel
        let tabCollection = tabCollectionViewModel.tabCollection

        if tabCollection.tabs.count == 1,
           let firstTab = tabCollection.tabs.first,
           case .newtab = firstTab.content,
           !newTab {
            firstTab.setContent(url.map { .contentFromURL($0, source: source) } ?? .newtab)
        } else if let tab = tabCollectionViewModel.selectedTabViewModel?.tab, !newTab {
            tab.setContent(url.map { .contentFromURL($0, source: source) } ?? .newtab)
        } else {
            let newTab = Tab(content: url.map { .url($0, source: source) } ?? .newtab, shouldLoadInBackground: true, burnerMode: tabCollectionViewModel.burnerMode)
            newTab.setContent(url.map { .contentFromURL($0, source: source) } ?? .newtab)
            tabCollectionViewModel.insertOrAppend(tab: newTab, selected: true)
        }
    }

    func showTab(with content: Tab.TabContent) {
        guard let windowController = self.mainWindowController else {
            let tabCollection = TabCollection(tabs: [Tab(content: content)])
            let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
            WindowsManager.openNewWindow(with: tabCollectionViewModel)
            return
        }

        let viewController = windowController.mainViewController
        let tabCollectionViewModel = viewController.tabCollectionViewModel
        tabCollectionViewModel.insertOrAppendNewTab(content)
        windowController.window?.orderFront(nil)
    }

    // MARK: - VPN

    @MainActor
    func showNetworkProtectionStatus(retry: Bool = false) async {
        guard let windowController = mainWindowControllers.first else {
            guard !retry else {
                return
            }

            WindowsManager.openNewWindow()

            // Not proud of this ugly hack... ideally openNewWindow() should let us know when the window is ready
            try? await Task.sleep(interval: 0.5)
            await showNetworkProtectionStatus(retry: true)
            return
        }

        windowController.mainViewController.navigationBarViewController.showNetworkProtectionStatus()
    }

    func showShareFeedbackModal(source: UnifiedFeedbackSource = .default) {
        let feedbackFormViewController: NSViewController = {
            if subscriptionFeatureAvailability.usesUnifiedFeedbackForm {
                return UnifiedFeedbackFormViewController(source: source)
            } else {
                return VPNFeedbackFormViewController()
            }
        }()
        let feedbackFormWindowController = feedbackFormViewController.wrappedInWindowController()

        guard let feedbackFormWindow = feedbackFormWindowController.window else {
            assertionFailure("Couldn't get window for feedback form")
            return
        }

        if let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController {
            parentWindowController.window?.beginSheet(feedbackFormWindow)
        } else {
            let tabCollection = TabCollection(tabs: [])
            let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
            let window = WindowsManager.openNewWindow(with: tabCollectionViewModel)
            window?.beginSheet(feedbackFormWindow)
        }
    }

    func showMainWindow() {
        guard WindowControllersManager.shared.lastKeyMainWindowController == nil else { return }
        let tabCollection = TabCollection(tabs: [])
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        _ = WindowsManager.openNewWindow(with: tabCollectionViewModel)
    }

    func showLocationPickerSheet() {
        let locationsViewController = VPNLocationsHostingViewController()
        let locationsWindowController = locationsViewController.wrappedInWindowController()

        guard let locationsFormWindow = locationsWindowController.window,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController else {
            assertionFailure("Failed to present native VPN feedback form")
            return
        }

        parentWindowController.window?.beginSheet(locationsFormWindow)
    }

    @discardableResult
    func openNewWindow(with tabCollectionViewModel: TabCollectionViewModel? = nil,
                       burnerMode: BurnerMode = .regular,
                       droppingPoint: NSPoint? = nil,
                       contentSize: NSSize? = nil,
                       showWindow: Bool = true,
                       popUp: Bool = false,
                       lazyLoadTabs: Bool = false,
                       isMiniaturized: Bool = false,
                       isMaximized: Bool = false,
                       isFullscreen: Bool = false) -> MainWindow? {
        return WindowsManager.openNewWindow(with: tabCollectionViewModel, burnerMode: burnerMode, droppingPoint: droppingPoint, contentSize: contentSize, showWindow: showWindow, popUp: popUp, lazyLoadTabs: lazyLoadTabs, isMiniaturized: isMiniaturized, isMaximized: isMaximized, isFullscreen: isFullscreen)
    }

}

extension Tab {
    var isPinned: Bool {
        return self.pinnedTabsManager.isTabPinned(self)
    }
}

// MARK: - Accessing all TabCollectionViewModels
extension WindowControllersManagerProtocol {

    var mainWindowController: MainWindowController? {
        return mainWindowControllers.first(where: {
            let isMain = $0.window?.isMainWindow ?? false
            let hasMainChildWindow = $0.window?.childWindows?.contains { $0.isMainWindow } ?? false
            return $0.window?.isPopUpWindow == false && (isMain || hasMainChildWindow)
        })
    }

    var selectedTab: Tab? {
        return mainWindowController?.mainViewController.tabCollectionViewModel.selectedTab
    }

    var allTabCollectionViewModels: [TabCollectionViewModel] {
        return mainWindowControllers.map {
            $0.mainViewController.tabCollectionViewModel
        }
    }

    var allTabViewModels: [TabViewModel] {
        return allTabCollectionViewModels.flatMap {
            $0.tabViewModels.values
        }
    }

    func allTabViewModels(for burnerMode: BurnerMode, includingPinnedTabs: Bool = false) -> [TabViewModel] {
        var result = allTabCollectionViewModels
            .filter { tabCollectionViewModel in
                tabCollectionViewModel.burnerMode == burnerMode
            }
            .flatMap {
                $0.tabViewModels.values
            }
        if includingPinnedTabs {
            result += pinnedTabsManager.tabViewModels.values
        }
        return result
    }

    func windowController(for tabCollectionViewModel: TabCollectionViewModel) -> MainWindowController? {
        return mainWindowControllers.first(where: {
            tabCollectionViewModel === $0.mainViewController.tabCollectionViewModel
        })
    }

    func windowController(for tab: Tab) -> MainWindowController? {
        return mainWindowControllers.first(where: {
            $0.mainViewController.tabCollectionViewModel.tabCollection.tabs.contains(tab)
        })
    }

}

extension WindowControllersManager: OnboardingNavigating {
    @MainActor
    func updatePreventUserInteraction(prevent: Bool) {
        mainWindowController?.userInteraction(prevented: prevent)
    }

    @MainActor
    func showImportDataView() {
        DataImportView(title: UserText.importDataTitleOnboarding).show()
    }

    @MainActor
    func replaceTabWith(_ tab: Tab) {
        guard let tabToRemove = selectedTab else { return }
        guard let mainWindowController else { return }
        guard let index = mainWindowController.mainViewController.tabCollectionViewModel.indexInAllTabs(of: tabToRemove) else { return }
        var tabToAppend = tab
        if mainWindowController.mainViewController.isBurner {
            let burnerMode = mainWindowController.mainViewController.tabCollectionViewModel.burnerMode
            tabToAppend = Tab(content: tab.content, burnerMode: burnerMode)
        }
        mainWindowController.mainViewController.tabCollectionViewModel.append(tab: tabToAppend)
        mainWindowController.mainViewController.tabCollectionViewModel.remove(at: index)
    }

    @MainActor
    func focusOnAddressBar() {
        guard let mainVC = lastKeyMainWindowController?.mainViewController else { return }
        mainVC.navigationBarViewController.addressBarViewController?.addressBarTextField.stringValue = ""
        mainVC.navigationBarViewController.addressBarViewController?.addressBarTextField.makeMeFirstResponder()
    }
}
