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

import Cocoa
import os.log
import BrowserServicesKit
import NetworkProtection

// Actions are sent to objects of responder chain

// MARK: - Main Menu Actions

extension AppDelegate {

    // MARK: - DuckDuckGo

    @IBAction func checkForUpdates(_ sender: Any?) {
#if !APPSTORE
        updateController.checkForUpdates(sender)
#endif
    }

    // MARK: - File

    @IBAction func newWindow(_ sender: Any?) {
        WindowsManager.openNewWindow()
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

    @objc func clearAllHistory(_ sender: NSMenuItem) {
        guard let window = WindowsManager.openNewWindow(with: Tab(content: .homePage, shouldLoadInBackground: false)),
              let windowController = window.windowController as? MainWindowController else {
            assertionFailure("No reference to main window controller")
            return
        }

        windowController.mainViewController.clearAllHistory(sender)
    }

    @objc func clearThisHistory(_ sender: ClearThisHistoryMenuItem) {
        guard let window = WindowsManager.openNewWindow(with: Tab(content: .homePage, shouldLoadInBackground: false)),
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

        guard let bookmark = menuItem.representedObject as? Bookmark else {
            assertionFailure("Unexpected type of menuItem.representedObject: \(type(of: menuItem.representedObject))")
            return
        }

        let tab = Tab(content: .url(bookmark.url), shouldLoadInBackground: true)
        WindowsManager.openNewWindow(with: tab)
    }

    @IBAction func showManageBookmarks(_ sender: Any?) {
        let tabCollection = TabCollection(tabs: [Tab(content: .bookmarks, shouldLoadInBackground: false)])
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        WindowsManager.openNewWindow(with: tabCollectionViewModel)
    }

    @IBAction func openPreferences(_ sender: Any?) {
        let tabCollection = TabCollection(tabs: [Tab(content: .anyPreferencePane, shouldLoadInBackground: false)])
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
            if #available(macOS 11.0, *) {
                savePanel.allowedContentTypes = [.commaSeparatedText]
            } else {
                savePanel.allowedFileTypes = ["csv"]
            }

            savePanel.beginSheetModal(for: window) { response in
                guard response == .OK, let selectedURL = savePanel.url else { return }

                let vault = try? SecureVaultFactory.default.makeVault(errorReporter: SecureVaultErrorReporter.shared)
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

        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [.html]
        } else {
            savePanel.allowedFileTypes = ["html"]
        }

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

}

extension MainViewController {

    // MARK: - Main Menu

    @IBAction func openPreferences(_ sender: Any?) {
        browserTabViewController.openNewTab(with: .anyPreferencePane, selected: true)
    }

    // MARK: - File

    @IBAction func newTab(_ sender: Any?) {
        browserTabViewController.openNewTab(with: .homePage, selected: true)
    }

    @IBAction func openLocation(_ sender: Any?) {
        guard let addressBarTextField = navigationBarViewController?.addressBarViewController?.addressBarTextField else {
            os_log("MainViewController: Cannot reference address bar text field", type: .error)
            return
        }
        addressBarTextField.makeMeFirstResponder()
    }

    @IBAction func closeTab(_ sender: Any?) {
        // when close is triggered by a keyboard shortcut,
        // instead of closing a pinned tab we select the first regular tab
        // (this is in line with Safari behavior)
        if isHandlingKeyDownEvent, tabCollectionViewModel.selectionIndex?.isPinnedTab == true {
            if tabCollectionViewModel.tabCollection.tabs.isEmpty {
                tabCollectionViewModel.append(tab: Tab(content: .homePage, shouldLoadInBackground: false), selected: true)
            } else {
                tabCollectionViewModel.select(at: .unpinned(0))
            }
        } else {
            tabCollectionViewModel.removeSelected()
        }
    }

    // MARK: - View

    @IBAction func reloadPage(_ sender: Any) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.reload()
    }

    @IBAction func stopLoadingPage(_ sender: Any) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.tab.stopLoading()
    }

    @IBAction func zoomIn(_ sender: Any) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.tab.webView.zoomIn()
    }

    @IBAction func zoomOut(_ sender: Any) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.tab.webView.zoomOut()
    }

    @IBAction func actualSize(_ sender: Any) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.tab.webView.resetZoomLevel()
    }

    @IBAction func toggleDownloads(_ sender: Any) {
        var navigationBarViewController = self.navigationBarViewController
        if view.window?.isPopUpWindow == true {
            if let vc = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.navigationBarViewController {
                navigationBarViewController = vc
            } else {
                WindowsManager.openNewWindow(with: Tab(content: .homePage, shouldLoadInBackground: false))
                guard let wc = WindowControllersManager.shared.mainWindowControllers.first(where: { $0.window?.isPopUpWindow == false }) else {
                    return
                }
                navigationBarViewController = wc.mainViewController.navigationBarViewController
            }
            navigationBarViewController?.view.window?.makeKeyAndOrderFront(nil)
        }
        navigationBarViewController?.toggleDownloadsPopover(keepButtonVisible: false)
    }

    @IBAction func toggleBookmarksBar(_ sender: Any) {
        PersistentAppInterfaceSettings.shared.showBookmarksBar.toggle()
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
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.tab.goBack()
    }

    @IBAction func forward(_ sender: Any?) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.tab.goForward()
    }

    @IBAction func home(_ sender: Any?) {
        guard view.window?.isPopUpWindow == false else {
            browserTabViewController.openNewTab(with: .homePage, selected: true)
            return
        }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.tab.openHomePage()
    }

    @objc func openVisit(_ sender: NSMenuItem) {
        guard let visit = sender.representedObject as? Visit,
              let url = visit.historyEntry?.url else {
            assertionFailure("Wrong represented object")
            return
        }

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.tab.setContent(.contentFromURL(url))
        adjustFirstResponder()
    }

    @objc func clearAllHistory(_ sender: NSMenuItem) {
        guard let window = view.window else {
            assertionFailure("No window")
            return
        }

        let alert = NSAlert.clearAllHistoryAndDataAlert()
        alert.beginSheetModal(for: window, completionHandler: { [weak self] response in
            guard case .alertFirstButtonReturn = response, let self = self else {
                return
            }
            FireCoordinator.fireViewModel.fire.burnAll(tabCollectionViewModel: self.tabCollectionViewModel)
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
        navigationBarViewController?
            .addressBarViewController?
            .addressBarButtonsViewController?
            .openBookmarkPopover(setFavorite: false, accessPoint: .init(sender: sender, default: .moreMenu))
    }

    @IBAction func favoriteThisPage(_ sender: Any) {
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

        guard let bookmark = menuItem.representedObject as? Bookmark else {
            return
        }

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

        let tabs = models.compactMap { $0.entity as? Bookmark }.map { Tab(content: .url($0.url), shouldLoadInBackground: true) }
        tabCollectionViewModel.append(tabs: tabs)
    }

    @IBAction func showManageBookmarks(_ sender: Any?) {
        browserTabViewController.openNewTab(with: .bookmarks, selected: true)
    }

    // MARK: - Window

    @IBAction func showPreviousTab(_ sender: Any?) {
        tabCollectionViewModel.selectPrevious()
    }

    @IBAction func showNextTab(_ sender: Any?) {
        tabCollectionViewModel.selectNext()
    }

    @IBAction func showTab(_ sender: Any?) {
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
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        let tab = selectedTabViewModel.tab
        tabCollectionViewModel.removeSelected()
        WindowsManager.openNewWindow(with: tab)
    }

    @IBAction func pinOrUnpinTab(_ sender: Any?) {
        guard let selectedTabIndex = tabCollectionViewModel.selectionIndex else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

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
        tabCollectionViewModel.tabCollection.localHistoryOfRemovedTabs.formUnion(otherLocalHistoryOfRemovedTabs)
    }

    // MARK: - Edit

    @IBAction func findInPage(_ sender: Any?) {
        tabCollectionViewModel.selectedTabViewModel?.showFindInPage()
    }

    @IBAction func findInPageNext(_ sender: Any?) {
        self.tabCollectionViewModel.selectedTabViewModel?.findInPageNext()
    }

    @IBAction func findInPagePrevious(_ sender: Any?) {
        self.tabCollectionViewModel.selectedTabViewModel?.findInPagePrevious()
    }

    /// Declines handling findInPage action if there's no page loaded currently.
    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(findInPage(_:)) && tabCollectionViewModel.selectedTabViewModel?.tab.content.url == nil {
            return false
        }

        if aSelector == #selector(printWebView(_:)) && tabCollectionViewModel.selectedTabViewModel?.tab.webView.url == nil {
            return false
        }

        return super.responds(to: aSelector)
    }

    // MARK: - Printing

    @IBAction func printWebView(_ sender: Any?) {
        tabCollectionViewModel.selectedTabViewModel?.tab.print()
    }

    // MARK: - Saving

    @IBAction func saveAs(_ sender: Any) {
        guard let tabViewModel = self.tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        tabViewModel.tab.saveWebContentAs()
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
        let vault = try? SecureVaultFactory.default.makeVault(errorReporter: SecureVaultErrorReporter.shared)

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
    }

    @IBAction func resetBookmarks(_ sender: Any?) {
        LocalBookmarkManager.shared.resetBookmarks()
    }

    @IBAction func resetPinnedTabs(_ sender: Any?) {
        if tabCollectionViewModel.selectedTabIndex?.isPinnedTab == true, tabCollectionViewModel.tabCollection.tabs.count > 0 {
            tabCollectionViewModel.select(at: .unpinned(0))
        }
        tabCollectionViewModel.pinnedTabsManager?.tabCollection.removeAll()
    }

    @IBAction func resetPrivatePlayerOverlayInteractions(_ sender: Any?) {
        PrivatePlayerPreferences.shared.youtubeOverlayInteracted = false
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

    @IBAction func fetchConfigurationNow(_ sender: Any?) {
        ConfigurationManager.shared.lastUpdateTime = .distantPast
        ConfigurationManager.shared.refreshIfNeeded()
    }

    @IBAction func resetNetworkProtectionState(_ sender: Any?) {
        guard let window = view.window else {
            assertionFailure("No window")
            return
        }

        let alert = NSAlert.resetNetworkProtectionAlert()
        alert.beginSheetModal(for: window, completionHandler: { response in
            guard case .alertFirstButtonReturn = response else {
                return
            }

            NetworkProtectionTunnelController.resetAllState()
        })
    }

    @IBAction func networkProtectionPreferredServerChanged(_ sender: Any?) {
        guard let title = (sender as? NSMenuItem)?.title else {
            assertionFailure("\(#function): Failed to cast sender to NSMenuItem")
            return
        }

        let selectedServer: SelectedNetworkProtectionServer

        if title == "Automatic" {
            selectedServer = .automatic
        } else {
            let titleComponents = title.components(separatedBy: " ")
            selectedServer = .endpoint(titleComponents.first!)
        }

        NetworkProtectionTunnelController.setSelectedServer(selectedServer: selectedServer)
    }

    @IBAction func networkProtectionExpireRegistrationKeyNow(_ sender: Any?) {
        Task {
            try? await NetworkProtectionTunnelController.expireRegistrationKeyNow()
        }
    }

    @IBAction func networkProtectionSetRegistrationKeyValidity(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            assertionFailure("\(#function): Failed to cast sender to NSMenuItem")
            return
        }

        // nil means automatic
        let validity = menuItem.representedObject as? TimeInterval

        Task {
            do {
                try await NetworkProtectionTunnelController.setRegistrationKeyValidity(validity)
            } catch {
                assertionFailure("Could not override the key validity due to an error: \(error.localizedDescription)")
                os_log("Could not override the key validity due to an error: %{public}@", log: .networkProtection, type: .error, error.localizedDescription)
            }
        }
    }

    @IBAction func networkProtectionSimulateControllerFailure(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            assertionFailure("\(#function): Failed to cast sender to NSMenuItem")
            return
        }

        if menuItem.state == .on {
            menuItem.state = .off
        } else {
            menuItem.state = .on
        }

        NetworkProtectionTunnelController.simulationOptions.setEnabled(menuItem.state == .on, option: .controllerFailure)
    }

    @IBAction func networkProtectionSimulateTunnelFailure(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            assertionFailure("\(#function): Failed to cast sender to NSMenuItem")
            return
        }

        if menuItem.state == .on {
            menuItem.state = .off
        } else {
            menuItem.state = .on
        }

        NetworkProtectionTunnelController.simulationOptions.setEnabled(menuItem.state == .on, option: .tunnelFailure)
    }

    // MARK: - Developer Tools

    @IBAction func toggleDeveloperTools(_ sender: Any?) {
        if tabCollectionViewModel.selectedTabViewModel?.tab.webView.isInspectorShown == true {
            tabCollectionViewModel.selectedTabViewModel?.tab.webView.closeDeveloperTools()
        } else {
            tabCollectionViewModel.selectedTabViewModel?.tab.webView.openDeveloperTools()
        }
    }

    @IBAction func openJavaScriptConsole(_ sender: Any?) {
        tabCollectionViewModel.selectedTabViewModel?.tab.webView.openJavaScriptConsole()
    }

    @IBAction func showPageSource(_ sender: Any?) {
        tabCollectionViewModel.selectedTabViewModel?.tab.webView.showPageSource()
    }

    @IBAction func showPageResources(_ sender: Any?) {
        tabCollectionViewModel.selectedTabViewModel?.tab.webView.showPageSource()
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
            return tabCollectionViewModel.selectedTabViewModel?.canGoBack == true
        case #selector(MainViewController.forward(_:)):
            return tabCollectionViewModel.selectedTabViewModel?.canGoForward == true

        case #selector(MainViewController.stopLoadingPage(_:)):
            return tabCollectionViewModel.selectedTabViewModel?.isLoading == true

        case #selector(MainViewController.reloadPage(_:)):
            return tabCollectionViewModel.selectedTabViewModel?.canReload == true

        // Zoom
        case #selector(MainViewController.zoomIn(_:)):
            return tabCollectionViewModel.selectedTabViewModel?.tab.webView.canZoomIn == true
        case #selector(MainViewController.zoomOut(_:)):
            return tabCollectionViewModel.selectedTabViewModel?.tab.webView.canZoomOut == true
        case #selector(MainViewController.actualSize(_:)):
            return tabCollectionViewModel.selectedTabViewModel?.tab.webView.canZoomToActualSize == true

        // Bookmarks
        case #selector(MainViewController.bookmarkThisPage(_:)),
             #selector(MainViewController.favoriteThisPage(_:)):
            return tabCollectionViewModel.selectedTabViewModel?.canBeBookmarked == true
        case #selector(MainViewController.openBookmark(_:)),
             #selector(MainViewController.showManageBookmarks(_:)):
            return true

        // Pin Tab
        case #selector(MainViewController.pinOrUnpinTab(_:)):
            guard tabCollectionViewModel.selectedTabViewModel?.tab.isUrl == true,
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

        // Printing/saving
        case #selector(MainViewController.saveAs(_:)),
             #selector(MainViewController.printWebView(_:)):
            return tabCollectionViewModel.selectedTabViewModel?.canReload == true

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
            let isInspectorShown = tabCollectionViewModel.selectedTabViewModel?.tab.webView.isInspectorShown ?? false
            menuItem.title = isInspectorShown ? UserText.closeDeveloperTools : UserText.openDeveloperTools
            fallthrough
        case #selector(MainViewController.openJavaScriptConsole(_:)),
             #selector(MainViewController.showPageSource(_:)),
             #selector(MainViewController.showPageResources(_:)):
            return tabCollectionViewModel.selectedTabViewModel?.canReload == true

        case #selector(MainViewController.toggleDownloads(_:)):
            let isDownloadsPopoverShown = self.navigationBarViewController.isDownloadsPopoverShown
            menuItem.title = isDownloadsPopoverShown ? UserText.closeDownloads : UserText.openDownloads

            return true

        case #selector(MainViewController.networkProtectionPreferredServerChanged(_:)):
            let selectedServerName = NetworkProtectionTunnelController.selectedServerName()

            switch menuItem.title {
            case "Automatic":
                menuItem.state = selectedServerName == nil ? .on : .off
            default:
                guard let selectedServerName = selectedServerName else {
                    menuItem.state = .off
                    break
                }

                menuItem.state = (menuItem.title.hasPrefix("\(selectedServerName) ")) ? .on : .off
            }

            return true

        case #selector(MainViewController.networkProtectionExpireRegistrationKeyNow(_:)):
            return true

        case #selector(MainViewController.networkProtectionSetRegistrationKeyValidity(_:)):
            let selectedValidity = NetworkProtectionTunnelController.registrationKeyValidity()

            switch menuItem.title {
            case "Automatic":
                menuItem.state = selectedValidity == nil ? .on : .off
            default:
                guard let selectedValidity = selectedValidity,
                      let menuItemValidity = menuItem.representedObject as? TimeInterval,
                      selectedValidity == menuItemValidity else {

                    menuItem.state = .off
                    break
                }

                menuItem.state =  .on
            }

            return true
        case #selector(MainViewController.networkProtectionSimulateControllerFailure(_:)):
            menuItem.state = NetworkProtectionTunnelController.simulationOptions.isEnabled(.controllerFailure) ? .on : .off
            return true

        case #selector(MainViewController.networkProtectionSimulateTunnelFailure(_:)):
            menuItem.state = NetworkProtectionTunnelController.simulationOptions.isEnabled(.tunnelFailure) ? .on : .off
            return true

        default:
            return true
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

        default:
            return true
        }
    }
}

extension MainViewController: FindInPageDelegate {

    func findInPageNext(_ controller: FindInPageViewController) {
        self.tabCollectionViewModel.selectedTabViewModel?.findInPageNext()
    }

    func findInPagePrevious(_ controller: FindInPageViewController) {
        self.tabCollectionViewModel.selectedTabViewModel?.findInPagePrevious()
    }

    func findInPageDone(_ controller: FindInPageViewController) {
        self.tabCollectionViewModel.selectedTabViewModel?.closeFindInPage()
    }

}
