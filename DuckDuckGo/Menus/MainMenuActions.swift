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

// Actions are sent to objects of responder chain

// MARK: - Main Menu Actions

extension AppDelegate {

    // MARK: - DuckDuckGo

#if OUT_OF_APPSTORE

    @IBAction func checkForUpdates(_ sender: Any?) {
        updateController.checkForUpdates(sender)
    }

#endif

    // MARK: - File

    @IBAction func newWindow(_ sender: Any?) {
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
        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController,
              windowController.window?.isKeyWindow == true else {
            WindowsManager.openNewWindow(with: URL.feedback)
            return
        }

        let mainViewController = windowController.mainViewController

        DefaultConfigurationStorage.shared.log()
        ConfigurationManager.shared.log()

        let tab = Tab()
        tab.url = URL.feedback

        let tabCollectionViewModel = mainViewController.tabCollectionViewModel
        tabCollectionViewModel.append(tab: tab)
    }

#endif

    @IBAction func navigateToBookmark(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            os_log("AppDelegate: Casting to menu item failed", type: .error)
            return
        }

        let tab = Tab()
        guard let bookmark = menuItem.representedObject as? Bookmark else {
            assertionFailure("Unexpected type of menuItem.representedObject: \(type(of: menuItem.representedObject))")
            return
        }
        Pixel.fire(.navigation(kind: .bookmark(isFavorite: bookmark.isFavorite), source: .mainMenu))

        tab.url = bookmark.url
        WindowsManager.openNewWindow(with: tab)
    }

    @IBAction func showManageBookmarks(_ sender: Any?) {
        let tabCollection = TabCollection(tabs: [Tab(tabType: .bookmarks)])
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        Pixel.fire(.manageBookmarks(source: .mainMenu))
        WindowsManager.openNewWindow(with: tabCollectionViewModel)
    }

    @IBAction func openPreferences(_ sender: Any?) {
        let tabCollection = TabCollection(tabs: [Tab(tabType: .preferences)])
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        WindowsManager.openNewWindow(with: tabCollectionViewModel)
    }

}

extension MainViewController {

    // MARK: - Main Menu

    @IBAction func openPreferences(_ sender: Any?) {
        tabCollectionViewModel.appendNewTab(type: .preferences)
    }

    // MARK: - File

    @IBAction func newTab(_ sender: Any?) {
        tabCollectionViewModel.appendNewTab()
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
    
    @IBAction func navigateToBookmark(_ sender: Any?) {
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

        selectedTabViewModel.tab.url = bookmark.url
    }

    @IBAction func showManageBookmarks(_ sender: Any?) {
        tabCollectionViewModel.appendNewTab(type: .bookmarks)
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
        if index >= 0 && index < tabCollectionViewModel.tabCollection.tabs.count {
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
        let otherWindowControllers = WindowControllersManager.shared.mainWindowControllers.filter { $0.window != view.window }
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

    /// Declines handling findInPage action if there's no page loaded currently.
    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(findInPage(_:)) && tabCollectionViewModel.selectedTabViewModel?.tab.url == nil {
            return false
        }

        if aSelector == #selector(printWebView(_:)) && tabCollectionViewModel.selectedTabViewModel?.tab.webView.url == nil {
            return false
        }

        return super.responds(to: aSelector)
    }

    // MARK: - Printing

    @IBAction func printWebView(_ sender: Any?) {
        guard let webView = tabCollectionViewModel.selectedTabViewModel?.tab.webView else { return }
        if #available(macOS 11.0, *) {
            // This might crash when running from Xcode, hit resume and it should be fine.
            // Release builds work fine.
            webView.printOperation(with: NSPrintInfo.shared).run()
        }
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

}

extension MainViewController: NSMenuItemValidation {
    
    // swiftlint:disable cyclomatic_complexity
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
        case #selector(MainViewController.navigateToBookmark(_:)),
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

        default:
            return true
        }
    }
    // swiftlint:enable cyclomatic_complexity

}

extension AppDelegate: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        // Close all windows
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
