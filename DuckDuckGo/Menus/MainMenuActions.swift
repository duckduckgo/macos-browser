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

// Actions are sent to objects of responder chain

// MARK: - Main Menu Actions

extension AppDelegate {

    // MARK: - DuckDuckGo

#if OUT_OF_APPSTORE && !BETA

    @IBAction func checkForUpdates(_ sender: Any?) {
        updateController.checkForUpdates(sender)
    }

#endif

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

    // MARK: - Help

#if FEEDBACK

    @IBAction func openFeedback(_ sender: Any?) {
        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController else {
            WindowsManager.openNewWindow(with: URL.feedback)
            return
        }

        let mainViewController = windowController.mainViewController

        DefaultConfigurationStorage.shared.log()
        ConfigurationManager.shared.log()

        let tab = Tab(content: .url(.feedback))
        let tabCollectionViewModel = mainViewController.tabCollectionViewModel
        tabCollectionViewModel.append(tab: tab)
        windowController.window?.makeKeyAndOrderFront(nil)
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
        Pixel.fire(.navigation(kind: .bookmark(isFavorite: bookmark.isFavorite), source: .mainMenu))

        let tab = Tab(content: .url(bookmark.url))
        WindowsManager.openNewWindow(with: tab)
    }

    @IBAction func showManageBookmarks(_ sender: Any?) {
        let tabCollection = TabCollection(tabs: [Tab(content: .bookmarks)])
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        Pixel.fire(.manageBookmarks(source: .mainMenu))
        WindowsManager.openNewWindow(with: tabCollectionViewModel)
    }

    @IBAction func openPreferences(_ sender: Any?) {
        let tabCollection = TabCollection(tabs: [Tab(content: .preferences)])
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        WindowsManager.openNewWindow(with: tabCollectionViewModel)
    }

    @IBAction func openImportBrowserDataWindow(_ sender: Any?) {
        DataImportViewController.show()
    }

    @IBAction func openExportLogins(_ sender: Any?) {
        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController,
              let window = windowController.window else { return }

        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "DuckDuckGo \(UserText.exportLoginsFileNameSuffix)"
        savePanel.allowedFileTypes = ["csv"]

        savePanel.beginSheetModal(for: window) { response in
            guard response == .OK, let selectedURL = savePanel.url else { return }

            let vault = try? SecureVaultFactory.default.makeVault()
            let exporter = CSVLoginExporter(secureVault: vault!)
            do {
                try exporter.exportVaultLogins(to: selectedURL)
                Pixel.fire(.exportedLogins())
            } catch {
                NSAlert.exportLoginsFailed()
                    .beginSheetModal(for: window, completionHandler: nil)
            }
        }
    }

    @IBAction func openExportBookmarks(_ sender: Any?) {
        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController,
              let window = windowController.window,
              let list = LocalBookmarkManager.shared.list else { return }

        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "DuckDuckGo \(UserText.exportBookmarksFileNameSuffix)"
        savePanel.allowedFileTypes = ["html"]

        savePanel.beginSheetModal(for: window) { response in
            guard response == .OK, let selectedURL = savePanel.url else { return }

            let exporter = BookmarksExporter(list: list)
            do {
                try exporter.exportBookmarksTo(url: selectedURL)
                Pixel.fire(.exportedBookmarks())
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
        browserTabViewController.openNewTab(with: .preferences, selected: true)
    }

    // MARK: - File

    @IBAction func newTab(_ sender: Any?) {
        browserTabViewController.openNewTab(with: .homepage, selected: true)
    }

    @IBAction func openLocation(_ sender: Any?) {
        guard let addressBarTextField = navigationBarViewController?.addressBarViewController?.addressBarTextField else {
            os_log("MainViewController: Cannot reference address bar text field", type: .error)
            return
        }
        addressBarTextField.makeMeFirstResponder()
    }

    @IBAction func closeTab(_ sender: Any?) {
        tabCollectionViewModel.removeSelected()
    }

    // MARK: - View

    @IBAction func reloadPage(_ sender: Any) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        Pixel.fire(.refresh(source: .init(sender: sender, default: .mainMenu)))
        selectedTabViewModel.tab.reload()
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

        selectedTabViewModel.tab.webView.magnification = 1.0
    }

    @IBAction func toggleDownloads(_ sender: Any) {
        var navigationBarViewController = self.navigationBarViewController
        if view.window?.isPopUpWindow == true {
            if let vc = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.navigationBarViewController {
                navigationBarViewController = vc
            } else {
                WindowsManager.openNewWindow(with: Tab(content: .homepage))
                guard let wc = WindowControllersManager.shared.mainWindowControllers.first(where: { $0.window?.isPopUpWindow == false }) else {
                    return
                }
                navigationBarViewController = wc.mainViewController.navigationBarViewController
            }
            navigationBarViewController?.view.window?.makeKeyAndOrderFront(nil)
        }
        navigationBarViewController?.toggleDownloadsPopover(keepButtonVisible: false)
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
            browserTabViewController.openNewTab(with: .homepage, selected: true)
            return
        }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.tab.openHomepage()
    }

    @IBAction func reopenLastClosedTab(_ sender: Any?) {
        tabCollectionViewModel.putBackLastRemovedTab()
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

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        guard let bookmark = menuItem.representedObject as? Bookmark else {
            return
        }

        Pixel.fire(.navigation(kind: .bookmark(isFavorite: bookmark.isFavorite), source: .mainMenu))

        if NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
            WindowsManager.openNewWindow(with: bookmark.url)
        } else if NSApplication.shared.isCommandPressed || self.view.window?.isPopUpWindow == true {
            WindowControllersManager.shared.show(url: bookmark.url, newTab: true)
        } else {
            selectedTabViewModel.tab.setContent(.url(bookmark.url))
        }
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
        Pixel.fire(.manageBookmarks(source: .mainMenu))
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
        if keyEquivalent == 9,
           !tabCollectionViewModel.tabCollection.tabs.isEmpty {
            tabCollectionViewModel.select(at: tabCollectionViewModel.tabCollection.tabs.count - 1)
        } else if tabCollectionViewModel.tabCollection.tabs.indices.contains(index) {
            tabCollectionViewModel.select(at: index)
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

    @IBAction func mergeAllWindows(_ sender: Any?) {
        guard let mainWindowController = WindowControllersManager.shared.lastKeyMainWindowController else { return }
        let otherWindowControllers = WindowControllersManager.shared.mainWindowControllers.filter { $0 !== mainWindowController }
        let otherMainViewControllers = otherWindowControllers.compactMap { $0.mainViewController }
        let otherTabCollectionViewModels = otherMainViewControllers.map { $0.tabCollectionViewModel }
        let otherTabs = otherTabCollectionViewModels.flatMap { $0.tabCollection.tabs }

        WindowsManager.closeWindows(except: view.window)

        tabCollectionViewModel.append(tabs: otherTabs)
    }

    // MARK: - Edit

    @IBAction func findInPage(_ sender: Any?) {
        tabCollectionViewModel.selectedTabViewModel?.startFindInPage()
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
        guard let webView = tabCollectionViewModel.selectedTabViewModel?.tab.webView,
              let window = webView.window,
              let printOperation = webView.printOperation()
              else { return }
        
        if printOperation.view?.frame.isEmpty == true {
            printOperation.view?.frame = webView.bounds
        }
        printOperation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
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
        let vault = try? SecureVaultFactory.default.makeVault()
        let accounts = (try? vault?.accounts()) ?? []
        let accountIDs = accounts.compactMap(\.id)

        for accountID in accountIDs {
            do {
                try vault?.deleteWebsiteCredentialsFor(accountId: accountID)
            } catch {
                os_log("Failed to remove credential with account ID %d", type: .error, accountID)
            }
        }
    }
    
    @IBAction func resetMacWaitlistUnlockState(_ sender: Any?) {
        OnboardingViewModel().restart()
        let store = MacWaitlistEncryptedFileStorage()
        store.deleteExistingMetadata()
    }
    
    // Used to test the lock screen upgrade process. Users with the legacy ATB format need to be unlocked.
    @IBAction func setFakeUserDefaultsATBValues(_ sender: Any?) {
        var legacyStore = LocalStatisticsStore.LegacyStatisticsStore()
        legacyStore.atb = "fake-atb-value"
        legacyStore.installDate = Date()
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

        // Reopen Last Removed Tab
        case #selector(MainViewController.reopenLastClosedTab(_:)):
            return tabCollectionViewModel.canInsertLastRemovedTab == true

        // Printing/saving
        case #selector(MainViewController.saveAs(_:)),
             #selector(MainViewController.printWebView(_:)):
            return tabCollectionViewModel.selectedTabViewModel?.canReload == true

        // Marge all windows
        case #selector(MainViewController.mergeAllWindows(_:)):
            return WindowControllersManager.shared.mainWindowControllers.count > 1

        // Move Tab to New Window, Select Next/Prev Tab
        case #selector(MainViewController.moveTabToNewWindow(_:)),
             #selector(MainViewController.showNextTab(_:)),
             #selector(MainViewController.showPreviousTab(_:)):
            return tabCollectionViewModel.tabCollection.tabs.count > 1

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
