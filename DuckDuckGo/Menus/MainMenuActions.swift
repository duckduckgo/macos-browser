//
//  MainMenuActions.swift
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
import Common
import WebKit

#if NETWORK_PROTECTION
import NetworkProtection
#endif

// Actions are sent to objects of responder chain

// MARK: - Main Menu Actions

extension AppDelegate {

    // MARK: - DuckDuckGo

    @IBAction func checkForUpdates(_ sender: Any?) {
#if !APPSTORE && !DBP
        updateController.checkForUpdates(sender)
#endif
    }

    // MARK: - File

    @IBAction func newWindow(_ sender: Any?) {
        WindowsManager.openNewWindow()
    }

    @IBAction func newBurnerWindow(_ sender: Any?) {
        WindowsManager.openNewWindow(burnerMode: BurnerMode(isBurner: true))
    }

    @IBAction func newTab(_ sender: Any?) {
        WindowsManager.openNewWindow()
    }

    @IBAction func openLocation(_ sender: Any?) {
        WindowsManager.openNewWindow()
    }

    @IBAction func closeAllWindows(_ sender: Any?) {
        WindowsManager.closeWindows()
    }

    // MARK: - History

    @IBAction func reopenLastClosedTab(_ sender: Any?) {
        RecentlyClosedCoordinator.shared.reopenItem()
    }

    @IBAction func recentlyClosedAction(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let cacheItem = menuItem.representedObject as? RecentlyClosedCacheItem else {
                  assertionFailure("Wrong represented object for recentlyClosedAction()")
                  return
              }

        RecentlyClosedCoordinator.shared.reopenItem(cacheItem)
    }

    @objc func openVisit(_ sender: NSMenuItem) {
        guard let visit = sender.representedObject as? Visit,
              let url = visit.historyEntry?.url else {
            assertionFailure("Wrong represented object")
            return
        }

        WindowsManager.openNewWindow(with: Tab(content: .contentFromURL(url), shouldLoadInBackground: true))
    }

    @IBAction func clearAllHistory(_ sender: NSMenuItem) {
        guard let window = WindowsManager.openNewWindow(with: Tab(content: .homePage)),
              let windowController = window.windowController as? MainWindowController else {
            assertionFailure("No reference to main window controller")
            return
        }

        windowController.mainViewController.clearAllHistory(sender)
    }

    @objc func clearThisHistory(_ sender: ClearThisHistoryMenuItem) {
        guard let window = WindowsManager.openNewWindow(with: Tab(content: .homePage)),
              let windowController = window.windowController as? MainWindowController else {
            assertionFailure("No reference to main window controller")
            return
        }

        windowController.mainViewController.clearThisHistory(sender)
    }

    // MARK: - Window

    @IBAction func reopenAllWindowsFromLastSession(_ sender: Any?) {
        stateRestorationManager.restoreLastSessionState(interactive: true)
    }

    // MARK: - Help

    #if FEEDBACK

    @IBAction func openFeedback(_ sender: Any?) {
        FeedbackPresenter.presentFeedbackForm()
    }

    #endif

    @IBAction func navigateToBookmark(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            os_log("AppDelegate: Casting to menu item failed", type: .error)
            return
        }

        guard let bookmark = menuItem.representedObject as? Bookmark,
        let url = bookmark.urlObject else {
            assertionFailure("Unexpected type of menuItem.representedObject: \(type(of: menuItem.representedObject))")
            return
        }

        let tab = Tab(content: .url(url), shouldLoadInBackground: true)
        WindowsManager.openNewWindow(with: tab)
    }

    @IBAction func showManageBookmarks(_ sender: Any?) {
        let tabCollection = TabCollection(tabs: [Tab(content: .bookmarks)])
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)

        WindowsManager.openNewWindow(with: tabCollectionViewModel)
    }

    @IBAction func openPreferences(_ sender: Any?) {
        let tabCollection = TabCollection(tabs: [Tab(content: .anyPreferencePane)])
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        WindowsManager.openNewWindow(with: tabCollectionViewModel)
    }

    @IBAction func openAbout(_ sender: Any?) {
#if APPSTORE
        let options = [NSApplication.AboutPanelOptionKey.applicationName: UserText.duckDuckGoForMacAppStore]
#else
        let options: [NSApplication.AboutPanelOptionKey: Any] = [:]
#endif
        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    @IBAction func openImportBrowserDataWindow(_ sender: Any?) {
        DataImportViewController.show()
    }

    @IBAction func openExportLogins(_ sender: Any?) {
        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController,
              let window = windowController.window else { return }

        DeviceAuthenticator.shared.authenticateUser(reason: .exportLogins) { authenticationResult in
            guard authenticationResult.authenticated else {
                return
            }

            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = "DuckDuckGo \(UserText.exportLoginsFileNameSuffix)"

            let accessory = NSTextField.label(titled: UserText.exportLoginsWarning)
            accessory.textColor = .red
            accessory.alignment = .center
            accessory.sizeToFit()

            let accessoryContainer = accessory.wrappedInContainer(padding: 10)
            accessoryContainer.frame.size = accessoryContainer.fittingSize

            savePanel.accessoryView = accessoryContainer
            savePanel.allowedContentTypes = [.commaSeparatedText]

            savePanel.beginSheetModal(for: window) { response in
                guard response == .OK, let selectedURL = savePanel.url else { return }

                let vault = try? AutofillSecureVaultFactory.makeVault(errorReporter: SecureVaultErrorReporter.shared)
                let exporter = CSVLoginExporter(secureVault: vault!)
                do {
                    try exporter.exportVaultLogins(to: selectedURL)
                } catch {
                    NSAlert.exportLoginsFailed()
                        .beginSheetModal(for: window, completionHandler: nil)
                }
            }
        }
    }

    @IBAction func openExportBookmarks(_ sender: Any?) {
        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController,
              let window = windowController.window,
              let list = LocalBookmarkManager.shared.list else { return }

        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "DuckDuckGo \(UserText.exportBookmarksFileNameSuffix)"
        savePanel.allowedContentTypes = [.html]

        savePanel.beginSheetModal(for: window) { response in
            guard response == .OK, let selectedURL = savePanel.url else { return }

            let exporter = BookmarksExporter(list: list)
            do {
                try exporter.exportBookmarksTo(url: selectedURL)
            } catch {
                NSAlert.exportBookmarksFailed()
                    .beginSheetModal(for: window, completionHandler: nil)
            }
        }
    }

    @IBAction func fireButtonAction(_ sender: NSButton) {
        FireCoordinator.fireButtonAction()
    }

    @IBAction func navigateToPrivateEmail(_ sender: Any?) {
        guard let window = NSApplication.shared.keyWindow,
              let windowController = window.windowController as? MainWindowController else {
            assertionFailure("No reference to main window controller")
            return
        }
        windowController.mainViewController.browserTabViewController.openNewTab(with: .url(URL.duckDuckGoEmailLogin))
    }

}

extension MainViewController {

    /// Finds currently active Tab even if it‘s playing a Full Screen video
    private func getActiveTabAndIndex() -> (tab: Tab, index: TabIndex)? {
        guard let tab = NSApp.keyWindow?.windowController?.activeTab else {
            assertionFailure("Could not get currently active Tab")
            return nil
        }
        guard let index = tabCollectionViewModel.indexInAllTabs(of: tab) else {
            assertionFailure("Could not get Tab index")
            return nil
        }
        return (tab, index)
    }

    var activeTabViewModel: TabViewModel? {
        getActiveTabAndIndex().flatMap { tabCollectionViewModel.tabViewModel(at: $0.index) }
    }

    func makeKeyIfNeeded() {
        if view.window?.isKeyWindow != true {
            view.window?.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Main Menu

    @IBAction func openPreferences(_ sender: Any?) {
        makeKeyIfNeeded()
        browserTabViewController.openNewTab(with: .anyPreferencePane)
    }

    // MARK: - File

    @IBAction func newTab(_ sender: Any?) {
        makeKeyIfNeeded()
        browserTabViewController.openNewTab(with: .homePage)
    }

    @IBAction func openLocation(_ sender: Any?) {
        makeKeyIfNeeded()
        guard let addressBarTextField = navigationBarViewController?.addressBarViewController?.addressBarTextField else {
            os_log("MainViewController: Cannot reference address bar text field", type: .error)
            return
        }
        addressBarTextField.makeMeFirstResponder()
    }

    @IBAction func closeTab(_ sender: Any?) {
        guard let (tab, index) = getActiveTabAndIndex() else { return }
        makeKeyIfNeeded()

        // when close is triggered by a keyboard shortcut,
        // instead of closing a pinned tab we select the first regular tab
        // (this is in line with Safari behavior)
        // If there are no regular tabs, we close the window.
        var isHandlingKeyDownEvent: Bool {
            guard sender is NSMenuItem,
                  let currentEvent = NSApp.currentEvent,
                  case .keyDown = currentEvent.type,
                  currentEvent.modifierFlags.contains(.command) else { return false }
             return true
        }
        if isHandlingKeyDownEvent, tab.isPinned {
            if tabCollectionViewModel.tabCollection.tabs.isEmpty {
                view.window?.performClose(sender)
            } else {
                tab.stopAllMediaAndLoading()
                tabCollectionViewModel.select(at: .unpinned(0))
            }
            return
        }

        tabCollectionViewModel.remove(at: index)
    }

    // MARK: - View

    @IBAction func reloadPage(_ sender: Any) {
        makeKeyIfNeeded()
        activeTabViewModel?.reload()
    }

    @IBAction func stopLoadingPage(_ sender: Any) {
        getActiveTabAndIndex()?.tab.stopLoading()
    }

    @IBAction func zoomIn(_ sender: Any) {
        getActiveTabAndIndex()?.tab.webView.zoomIn()
    }

    @IBAction func zoomOut(_ sender: Any) {
        getActiveTabAndIndex()?.tab.webView.zoomOut()
    }

    @IBAction func actualSize(_ sender: Any) {
        getActiveTabAndIndex()?.tab.webView.resetZoomLevel()
    }

    @IBAction func toggleDownloads(_ sender: Any) {
        var navigationBarViewController = self.navigationBarViewController
        if view.window?.isPopUpWindow == true {
            if let vc = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.navigationBarViewController {
                navigationBarViewController = vc
            } else {
                WindowsManager.openNewWindow(with: Tab(content: .homePage))
                guard let wc = WindowControllersManager.shared.mainWindowControllers.first(where: { $0.window?.isPopUpWindow == false }) else {
                    return
                }
                navigationBarViewController = wc.mainViewController.navigationBarViewController
            }
            navigationBarViewController?.view.window?.makeKeyAndOrderFront(nil)
        }
        navigationBarViewController?.toggleDownloadsPopover(keepButtonVisible: false)
    }

    @IBAction func toggleBookmarksBarFromMenu(_ sender: Any) {
        // Leaving this keyboard shortcut in place.  When toggled on it will use the previously set appearence which defaults to "always".
        //  If the user sets it to "new tabs only" somewhere (e.g. preferences), then it'll be that.
        guard let mainVC = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController else { return }

        let prefs = AppearancePreferences.shared
        if prefs.showBookmarksBar && prefs.bookmarksBarAppearance == .newTabOnly {
            // show bookmarks bar but don't change the setting
            mainVC.toggleBookmarksBarVisibility()
        } else {
            prefs.showBookmarksBar.toggle()
        }
    }

    @IBAction func toggleAutofillShortcut(_ sender: Any) {
        LocalPinningManager.shared.togglePinning(for: .autofill)
    }

    @IBAction func toggleBookmarksShortcut(_ sender: Any) {
        LocalPinningManager.shared.togglePinning(for: .bookmarks)
    }

    @IBAction func toggleDownloadsShortcut(_ sender: Any) {
        LocalPinningManager.shared.togglePinning(for: .downloads)
    }

    @IBAction func toggleNetworkProtectionShortcut(_ sender: Any) {
        LocalPinningManager.shared.togglePinning(for: .networkProtection)
    }

    // MARK: - History

    @IBAction func back(_ sender: Any?) {
        makeKeyIfNeeded()
        getActiveTabAndIndex()?.tab.goBack()
    }

    @IBAction func forward(_ sender: Any?) {
        makeKeyIfNeeded()
        getActiveTabAndIndex()?.tab.goForward()
    }

    @IBAction func home(_ sender: Any?) {
        guard view.window?.isPopUpWindow == false,
            let (tab, _) = getActiveTabAndIndex(), tab === tabCollectionViewModel.selectedTab else {

            browserTabViewController.openNewTab(with: .homePage)
            return
        }
        makeKeyIfNeeded()
        tab.openHomePage()
    }

    @objc func openVisit(_ sender: NSMenuItem) {
        guard let visit = sender.representedObject as? Visit,
              let url = visit.historyEntry?.url else {
            assertionFailure("Wrong represented object")
            return
        }

        makeKeyIfNeeded()
        getActiveTabAndIndex()?.tab.setContent(.contentFromURL(url))
        adjustFirstResponder()
    }

    @IBAction func clearAllHistory(_ sender: NSMenuItem) {
        guard let window = view.window else {
            assertionFailure("No window")
            return
        }

        let alert = NSAlert.clearAllHistoryAndDataAlert()
        alert.beginSheetModal(for: window, completionHandler: { response in
            guard case .alertFirstButtonReturn = response else {
                return
            }
            FireCoordinator.fireViewModel.fire.burnAll()
        })
    }

    @objc func clearThisHistory(_ sender: ClearThisHistoryMenuItem) {
        guard let window = view.window else {
            assertionFailure("No window")
            return
        }

        let dateString = sender.dateString
        let visits = sender.getVisits()
        let alert = NSAlert.clearHistoryAndDataAlert(dateString: dateString)
        alert.beginSheetModal(for: window, completionHandler: { response in
            guard case .alertFirstButtonReturn = response else {
                return
            }
            FireCoordinator.fireViewModel.fire.burnVisits(of: visits, except: FireproofDomains.shared)
        })
    }

    // MARK: - Bookmarks

    @IBAction func bookmarkThisPage(_ sender: Any) {
        guard let tabIndex = getActiveTabAndIndex()?.index else { return }
        if tabCollectionViewModel.selectedTabIndex != tabIndex {
            tabCollectionViewModel.select(at: tabIndex)
        }
        makeKeyIfNeeded()

        navigationBarViewController?
            .addressBarViewController?
            .addressBarButtonsViewController?
            .openBookmarkPopover(setFavorite: false, accessPoint: .init(sender: sender, default: .moreMenu))
    }

    @IBAction func favoriteThisPage(_ sender: Any) {
        guard let tabIndex = getActiveTabAndIndex()?.index else { return }
        if tabCollectionViewModel.selectedTabIndex != tabIndex {
            tabCollectionViewModel.select(at: tabIndex)
        }
        makeKeyIfNeeded()

        navigationBarViewController?
            .addressBarViewController?
            .addressBarButtonsViewController?
            .openBookmarkPopover(setFavorite: true, accessPoint: .init(sender: sender, default: .moreMenu))
    }

    @IBAction func openBookmark(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            os_log("MainViewController: Casting to menu item failed", type: .error)
            return
        }

        guard let bookmark = menuItem.representedObject as? Bookmark else { return }
        makeKeyIfNeeded()

        WindowControllersManager.shared.open(bookmark: bookmark)
    }

    @IBAction func openAllInTabs(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            os_log("MainViewController: Casting to menu item failed", type: .error)
            return
        }

        guard let models = menuItem.representedObject as? [BookmarkViewModel] else {
            return
        }

        let tabs = models.compactMap { ($0.entity as? Bookmark)?.urlObject }.map {
            Tab(content: .url($0),
                shouldLoadInBackground: true,
                burnerMode: tabCollectionViewModel.burnerMode)
        }
        tabCollectionViewModel.append(tabs: tabs)
    }

    @IBAction func showManageBookmarks(_ sender: Any?) {
        makeKeyIfNeeded()
        browserTabViewController.openNewTab(with: .bookmarks)
    }

    // MARK: - Window

    @IBAction func showPreviousTab(_ sender: Any?) {
        makeKeyIfNeeded()
        guard let (tab, index) = getActiveTabAndIndex() else { return }
        if tabCollectionViewModel.selectedTab !== tab {
            tabCollectionViewModel.select(at: index)
        }
        tabCollectionViewModel.selectPrevious()
    }

    @IBAction func showNextTab(_ sender: Any?) {
        guard let (tab, index) = getActiveTabAndIndex() else { return }
        makeKeyIfNeeded()

        if tabCollectionViewModel.selectedTab !== tab {
            tabCollectionViewModel.select(at: index)
        }
        tabCollectionViewModel.selectNext()
    }

    @IBAction func showTab(_ sender: Any?) {
        makeKeyIfNeeded()
        guard let sender = sender as? NSMenuItem else {
            os_log("MainViewController: Casting to NSMenuItem failed", type: .error)
            return
        }
        guard let keyEquivalent = Int(sender.keyEquivalent), keyEquivalent >= 0 && keyEquivalent <= 9 else {
            os_log("MainViewController: Key equivalent is not correct for tab selection", type: .error)
            return
        }
        let index = keyEquivalent - 1
        if keyEquivalent == 9 {
            tabCollectionViewModel.select(at: .last(in: tabCollectionViewModel))
        } else if index < tabCollectionViewModel.allTabsCount {
            tabCollectionViewModel.select(at: .at(index, in: tabCollectionViewModel))
        }
    }

    @IBAction func moveTabToNewWindow(_ sender: Any?) {
        guard let (tab, index) = getActiveTabAndIndex() else { return }

        tabCollectionViewModel.remove(at: index)
        WindowsManager.openNewWindow(with: tab)
    }

    @IBAction func pinOrUnpinTab(_ sender: Any?) {
        guard let (_, selectedTabIndex) = getActiveTabAndIndex() else { return }

        switch selectedTabIndex {
        case .pinned(let index):
            tabCollectionViewModel.unpinTab(at: index)
        case .unpinned(let index):
            tabCollectionViewModel.pinTab(at: index)
        }
    }

    @IBAction func mergeAllWindows(_ sender: Any?) {
        guard let mainWindowController = WindowControllersManager.shared.lastKeyMainWindowController else { return }
        let otherWindowControllers = WindowControllersManager.shared.mainWindowControllers.filter { $0 !== mainWindowController }
        let otherMainViewControllers = otherWindowControllers.compactMap { $0.mainViewController }
        let otherTabCollectionViewModels = otherMainViewControllers.map { $0.tabCollectionViewModel }
        let otherTabs = otherTabCollectionViewModels.flatMap { $0.tabCollection.tabs }
        let otherLocalHistoryOfRemovedTabs = Set(otherTabCollectionViewModels.flatMap { $0.tabCollection.localHistoryOfRemovedTabs })

        WindowsManager.closeWindows(except: view.window)

        tabCollectionViewModel.append(tabs: otherTabs)
        tabCollectionViewModel.tabCollection.localHistoryOfRemovedTabs += otherLocalHistoryOfRemovedTabs
    }

    // MARK: - Printing

    @IBAction func printWebView(_ sender: Any?) {
        getActiveTabAndIndex()?.tab.print()
    }

    // MARK: - Saving

    @IBAction func saveAs(_ sender: Any) {
        getActiveTabAndIndex()?.tab.saveWebContentAs()
    }

    // MARK: - Debug

    @IBAction func resetDefaultBrowserPrompt(_ sender: Any?) {
        UserDefaultsWrapper<Bool>.clear(.defaultBrowserDismissed)
    }

    @IBAction func resetDefaultGrammarChecks(_ sender: Any?) {
        UserDefaultsWrapper<Bool>.clear(.spellingCheckEnabledOnce)
        UserDefaultsWrapper<Bool>.clear(.grammarCheckEnabledOnce)
    }

    @IBAction func triggerFatalError(_ sender: Any?) {
        fatalError("Fatal error triggered from the Debug menu")
    }

    @IBAction func resetSecureVaultData(_ sender: Any?) {
        let vault = try? AutofillSecureVaultFactory.makeVault(errorReporter: SecureVaultErrorReporter.shared)

        let accounts = (try? vault?.accounts()) ?? []
        for accountID in accounts.compactMap(\.id) {
            if let accountID = Int64(accountID) {
                try? vault?.deleteWebsiteCredentialsFor(accountId: accountID)
            }
        }

        let cards = (try? vault?.creditCards()) ?? []
        for cardID in cards.compactMap(\.id) {
            try? vault?.deleteCreditCardFor(cardId: cardID)
        }

        let identities = (try? vault?.identities()) ?? []
        for identityID in identities.compactMap(\.id) {
            try? vault?.deleteIdentityFor(identityId: identityID)
        }

        let notes = (try? vault?.notes()) ?? []
        for noteID in notes.compactMap(\.id) {
            try? vault?.deleteNoteFor(noteId: noteID)
        }
        UserDefaults.standard.set(false, forKey: UserDefaultsWrapper<Bool>.Key.homePageContinueSetUpImport.rawValue)
    }

    @IBAction func resetBookmarks(_ sender: Any?) {
        LocalBookmarkManager.shared.resetBookmarks()
        UserDefaults.standard.set(false, forKey: UserDefaultsWrapper<Bool>.Key.homePageContinueSetUpImport.rawValue)
    }

    @IBAction func resetPinnedTabs(_ sender: Any?) {
        if tabCollectionViewModel.selectedTabIndex?.isPinnedTab == true, tabCollectionViewModel.tabCollection.tabs.count > 0 {
            tabCollectionViewModel.select(at: .unpinned(0))
        }
        tabCollectionViewModel.pinnedTabsManager?.tabCollection.removeAll()
    }

    @IBAction func resetDuckPlayerOverlayInteractions(_ sender: Any?) {
        DuckPlayerPreferences.shared.youtubeOverlayAnyButtonPressed = false
        DuckPlayerPreferences.shared.youtubeOverlayInteracted = false
    }

    @IBAction func resetMakeDuckDuckGoYoursUserSettings(_ sender: Any?) {
        UserDefaults.standard.set(true, forKey: UserDefaultsWrapper<Bool>.Key.homePageShowAllFeatures.rawValue)
        UserDefaults.standard.set(true, forKey: UserDefaultsWrapper<Bool>.Key.homePageShowMakeDefault.rawValue)
        UserDefaults.standard.set(true, forKey: UserDefaultsWrapper<Bool>.Key.homePageShowImport.rawValue)
        UserDefaults.standard.set(true, forKey: UserDefaultsWrapper<Bool>.Key.homePageShowDuckPlayer.rawValue)
        UserDefaults.standard.set(true, forKey: UserDefaultsWrapper<Bool>.Key.homePageShowEmailProtection.rawValue)
        UserDefaults.standard.set(true, forKey: UserDefaultsWrapper<Bool>.Key.homePageShowCookie.rawValue)
        UserDefaults.standard.set(true, forKey: UserDefaultsWrapper<Bool>.Key.homePageShowSurveyDay0.rawValue)
        UserDefaults.standard.set(true, forKey: UserDefaultsWrapper<Bool>.Key.homePageShowSurveyDay7.rawValue)
        UserDefaults.standard.set(false, forKey: UserDefaultsWrapper<Bool>.Key.homePageUserInteractedWithSurveyDay0.rawValue)
    }

    @IBAction func changeInstallDateToToday(_ sender: Any?) {
        UserDefaults.standard.set(Date(), forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
    }

    @IBAction func changeInstallDateToLessThanAWeekAgo(_ sender: Any?) {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        UserDefaults.standard.set(yesterday, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
    }

    @IBAction func changeInstallDateToMoreThanAWeekAgo(_ sender: Any?) {
        let aWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())
        UserDefaults.standard.set(aWeekAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
    }

    @IBAction func showSaveCredentialsPopover(_ sender: Any?) {
        #if DEBUG || REVIEW
        NotificationCenter.default.post(name: .ShowSaveCredentialsPopover, object: nil)
        #endif
    }

    @IBAction func showCredentialsSavedPopover(_ sender: Any?) {
        #if DEBUG || REVIEW
        NotificationCenter.default.post(name: .ShowCredentialsSavedPopover, object: nil)
        #endif
    }

    @IBAction func showPopUpWindow(_ sender: Any?) {
        let tabURL = Tab.TabContent.url(URL(string: "https://duckduckgo.com")!)
        let tab = Tab(content: tabURL,
                      webViewConfiguration: WKWebViewConfiguration(),
                      parentTab: nil,
                      canBeClosedWithBack: false,
                      webViewSize: .zero)

        WindowsManager.openPopUpWindow(with: tab, origin: nil, contentSize: nil)
    }

    @IBAction func resetEmailProtectionInContextPrompt(_ sender: Any?) {
        EmailManager().resetEmailProtectionInContextPrompt()
    }

    @IBAction func fetchConfigurationNow(_ sender: Any?) {
        ConfigurationManager.shared.forceRefresh()
    }

    @IBAction func resetNetworkProtectionWaitlistState(_ sender: Any?) {
#if NETWORK_PROTECTION
        NetworkProtectionWaitlist().waitlistStorage.deleteWaitlistState()
        UserDefaults().removeObject(forKey: UserDefaultsWrapper<Bool>.Key.networkProtectionTermsAndConditionsAccepted.rawValue)
        NotificationCenter.default.post(name: .networkProtectionWaitlistAccessChanged, object: nil)
#endif
    }

    @IBAction func resetNetworkProtectionTermsAndConditionsAcceptance(_ sender: Any?) {
#if NETWORK_PROTECTION
        UserDefaults().removeObject(forKey: UserDefaultsWrapper<Bool>.Key.networkProtectionTermsAndConditionsAccepted.rawValue)
        NotificationCenter.default.post(name: .networkProtectionWaitlistAccessChanged, object: nil)
#endif
    }

    @IBAction func showNetworkProtectionInviteCodePrompt(_ sender: Any?) {
#if NETWORK_PROTECTION
        let code = getInviteCode()

        Task {
            do {
                let redeemer = NetworkProtectionCodeRedemptionCoordinator()
                try await redeemer.redeem(code)
                NetworkProtectionWaitlist().waitlistStorage.store(inviteCode: code)
                NotificationCenter.default.post(name: .networkProtectionWaitlistAccessChanged, object: nil)
            } catch {
                // Do nothing here, this is just a debug menu
            }
        }
#endif
    }

    @IBAction func sendNetworkProtectionWaitlistAvailableNotification(_ sender: Any?) {
#if NETWORK_PROTECTION
        NetworkProtectionWaitlist().sendInviteCodeAvailableNotification()
#endif
    }

    // MARK: - Developer Tools

    @IBAction func toggleDeveloperTools(_ sender: Any?) {
        guard let webView = getActiveTabAndIndex()?.tab.webView else { return }

        if webView.isInspectorShown == true {
            webView.closeDeveloperTools()
        } else {
            webView.openDeveloperTools()
        }
    }

    @IBAction func openJavaScriptConsole(_ sender: Any?) {
        getActiveTabAndIndex()?.tab.webView.openJavaScriptConsole()
    }

    @IBAction func showPageSource(_ sender: Any?) {
        getActiveTabAndIndex()?.tab.webView.showPageSource()
    }

    @IBAction func showPageResources(_ sender: Any?) {
        getActiveTabAndIndex()?.tab.webView.showPageSource()
    }
}

extension MainViewController: NSMenuItemValidation {

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Enable "Move to another Display" menu item (is there a better way?)
        for item in menuItem.menu!.items where item.action == Selector(("_moveToDisplay:")) {
            item.isEnabled = true
        }

        switch menuItem.action {
        // Back/Forward
        case #selector(MainViewController.back(_:)):
            return activeTabViewModel?.canGoBack == true
        case #selector(MainViewController.forward(_:)):
            return activeTabViewModel?.canGoForward == true

        case #selector(MainViewController.stopLoadingPage(_:)):
            return activeTabViewModel?.isLoading == true

        case #selector(MainViewController.reloadPage(_:)):
            return activeTabViewModel?.canReload == true

        // Find In Page
        case #selector(findInPage),
             #selector(findInPageNext),
             #selector(findInPagePrevious):
            return activeTabViewModel?.canReload == true // must have content loaded
                && view.window?.isKeyWindow == true // disable in full screen

        case #selector(findInPageDone):
            return getActiveTabAndIndex()?.tab.findInPage?.isActive == true

        // Zoom
        case #selector(MainViewController.zoomIn(_:)):
            return getActiveTabAndIndex()?.tab.webView.canZoomIn == true
        case #selector(MainViewController.zoomOut(_:)):
            return getActiveTabAndIndex()?.tab.webView.canZoomOut == true
        case #selector(MainViewController.actualSize(_:)):
            return getActiveTabAndIndex()?.tab.webView.canZoomToActualSize == true

        // Bookmarks
        case #selector(MainViewController.bookmarkThisPage(_:)),
             #selector(MainViewController.favoriteThisPage(_:)):
            return activeTabViewModel?.canBeBookmarked == true
        case #selector(MainViewController.openBookmark(_:)),
             #selector(MainViewController.showManageBookmarks(_:)):
            return true

        // Pin Tab
        case #selector(MainViewController.pinOrUnpinTab(_:)):
            guard getActiveTabAndIndex()?.tab.isUrl == true,
                  tabCollectionViewModel.pinnedTabsManager != nil
            else {
                return false
            }
            if tabCollectionViewModel.selectionIndex?.isUnpinnedTab == true {
                menuItem.title = UserText.pinTab
                return true
            }
            if tabCollectionViewModel.selectionIndex?.isPinnedTab == true {
                menuItem.title = UserText.unpinTab
                return true
            }
            return false

        // Save Content
        case #selector(MainViewController.saveAs(_:)):
            return activeTabViewModel?.canSaveContent == true

        // Printing
        case #selector(MainViewController.printWebView(_:)):
            return activeTabViewModel?.canPrint == true

        // Merge all windows
        case #selector(MainViewController.mergeAllWindows(_:)):
            return WindowControllersManager.shared.mainWindowControllers.count > 1

        // Move Tab to New Window, Select Next/Prev Tab
        case #selector(MainViewController.moveTabToNewWindow(_:)):
            return tabCollectionViewModel.tabCollection.tabs.count > 1 && tabCollectionViewModel.selectionIndex?.isUnpinnedTab == true

        case #selector(MainViewController.showNextTab(_:)),
             #selector(MainViewController.showPreviousTab(_:)):
            return tabCollectionViewModel.allTabsCount > 1

        // Developer Tools
        case #selector(MainViewController.toggleDeveloperTools(_:)):
            let isInspectorShown = getActiveTabAndIndex()?.tab.webView.isInspectorShown ?? false
            menuItem.title = isInspectorShown ? UserText.closeDeveloperTools : UserText.openDeveloperTools
            fallthrough
        case #selector(MainViewController.openJavaScriptConsole(_:)),
             #selector(MainViewController.showPageSource(_:)),
             #selector(MainViewController.showPageResources(_:)):
            return activeTabViewModel?.canReload == true

        case #selector(MainViewController.toggleDownloads(_:)):
            let isDownloadsPopoverShown = self.navigationBarViewController.isDownloadsPopoverShown
            menuItem.title = isDownloadsPopoverShown ? UserText.closeDownloads : UserText.openDownloads

            return true

        // Network Protection Debugging
        case #selector(MainViewController.showNetworkProtectionInviteCodePrompt(_:)):
            // Only allow testers to enter a custom code if they're on the waitlist, to simulate the correct path through the flow
#if NETWORK_PROTECTION
            let waitlist = NetworkProtectionWaitlist()
            return waitlist.waitlistStorage.isOnWaitlist || waitlist.waitlistStorage.isInvited
#else
            return false
#endif
        default:
            return true
        }
    }

    func getInviteCode() -> String {
        let alert = NSAlert()
        alert.addButton(withTitle: "Use Invite Code")
        alert.addButton(withTitle: "Cancel")
        alert.messageText = "Enter Invite Code"
        alert.informativeText = "Please grab a Network Protection invite code from Asana and enter it here."

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = textField

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            return textField.stringValue
        } else {
            return ""
        }
    }

    // swiftlint:enable function_body_length
    // swiftlint:enable cyclomatic_complexity
}

extension AppDelegate: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(AppDelegate.closeAllWindows(_:)):
            return !WindowControllersManager.shared.mainWindowControllers.isEmpty

        // Reopen Last Removed Tab
        case #selector(AppDelegate.reopenLastClosedTab(_:)):
            return RecentlyClosedCoordinator.shared.canReopenRecentlyClosedTab == true

        // Reopen All Windows from Last Session
        case #selector(AppDelegate.reopenAllWindowsFromLastSession(_:)):
            return stateRestorationManager.canRestoreLastSessionState

        // Enables and disables export bookmarks items
        case #selector(AppDelegate.openExportBookmarks(_:)):
            return bookmarksManager.list?.totalBookmarks != 0

        // Enables and disables export passwords items
        case #selector(AppDelegate.openExportLogins(_:)):
            return areTherePasswords

        default:
            return true
        }
    }

    private var areTherePasswords: Bool {
        let vault = try? AutofillSecureVaultFactory.makeVault(errorReporter: SecureVaultErrorReporter.shared)
        guard let vault else {
            return false
        }
        let accounts = (try? vault.accounts()) ?? []
        if !accounts.isEmpty {
            return true
        }
        let cards = (try? vault.creditCards()) ?? []
        if !cards.isEmpty {
            return true
        }
        let notes = (try? vault.notes()) ?? []
        if !notes.isEmpty {
            return true
        }
        let identities = (try? vault.identities()) ?? []
        if !identities.isEmpty {
            return true
        }
        return false
    }

}

extension MainViewController: FindInPageDelegate {

    @IBAction func findInPage(_ sender: Any) {
        activeTabViewModel?.showFindInPage()
    }

    @IBAction func findInPageNext(_ sender: Any) {
        activeTabViewModel?.findInPageNext()
    }

    @IBAction func findInPagePrevious(_ sender: Any) {
        activeTabViewModel?.findInPagePrevious()
    }

    @IBAction func findInPageDone(_ sender: Any) {
        activeTabViewModel?.closeFindInPage()
    }

}
