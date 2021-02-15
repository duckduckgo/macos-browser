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
import os.log

class MainViewController: NSViewController {

    @IBOutlet weak var tabBarContainerView: NSView!
    @IBOutlet weak var navigationBarContainerView: NSView!
    @IBOutlet weak var webContainerView: NSView!
    @IBOutlet weak var findInPageContainerView: NSView!

    private(set) weak var tabBarViewController: TabBarViewController?
    private(set) weak var navigationBarViewController: NavigationBarViewController?
    private(set) weak var browserTabViewController: BrowserTabViewController?
    private(set) weak var findInPageViewController: FindInPageViewController?

    let tabCollectionViewModel: TabCollectionViewModel

    private var selectedTabViewModelCancellable: AnyCancellable?
    private var canGoForwardCancellable: AnyCancellable?
    private var canGoBackCancellable: AnyCancellable?
    private var canBookmarkCancellable: AnyCancellable?
    private var canInsertLastRemovedTabCancellable: AnyCancellable?
    private var findInPageCancellable: AnyCancellable?
    private var keyDownMonitor: Any?

    required init?(coder: NSCoder) {
        self.tabCollectionViewModel = TabCollectionViewModel()
        super.init(coder: coder)
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        listenToKeyDownEvents()
        subscribeToSelectedTabViewModel()
        subscribeToCanInsertLastRemovedTab()
        findInPageContainerView.applyDropShadow()
    }
    
    override func viewDidLayout() {
        findInPageContainerView.applyDropShadow()
    }

    override func encodeRestorableState(with coder: NSCoder) {
        fatalError("Default AppKit State Restoration should not be used")
    }

    func windowDidBecomeMain() {
        NSApplication.shared.mainMenuTyped?.setWindowRelatedMenuItems(enabled: true)

        updateBackMenuItem()
        updateForwardMenuItem()
        updateReopenLastClosedTabMenuItem()
    }

    func windowDidResignMain() {
        NSApplication.shared.mainMenuTyped?.setWindowRelatedMenuItems(enabled: false)
    }

    func windowWillClose() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }

        tabBarViewController?.hideTooltip()
    }

    @IBSegueAction
    func createTabBarViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> TabBarViewController? {
        guard let tabBarViewController = TabBarViewController(coder: coder, tabCollectionViewModel: tabCollectionViewModel) else {
            os_log("MainViewController: Failed to init TabBarViewController", type: .error)
            return nil
        }

        self.tabBarViewController = tabBarViewController
        return tabBarViewController
    }

    @IBSegueAction
    func createNavigationBarViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> NavigationBarViewController? {
        guard let navigationBarViewController = NavigationBarViewController(coder: coder, tabCollectionViewModel: tabCollectionViewModel) else {
            os_log("MainViewController: Failed to init NavigationBarViewController", type: .error)
            return nil
        }

        self.navigationBarViewController = navigationBarViewController
        return navigationBarViewController
    }

    @IBSegueAction
    func createWebViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> BrowserTabViewController? {
        guard let browserTabViewController = BrowserTabViewController(coder: coder,
                                                                      tabCollectionViewModel: tabCollectionViewModel) else {
            os_log("MainViewController: Failed to init BrowserTabViewController", type: .error)
            return nil
        }

        self.browserTabViewController = browserTabViewController
        return browserTabViewController
    }

    @IBSegueAction
    func createFindInPageViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> FindInPageViewController? {
        let findInPageViewController = FindInPageViewController(coder: coder)
        findInPageViewController?.delegate = self
        self.findInPageViewController = findInPageViewController
        return findInPageViewController
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.subscribeToCanGoBackForward()
            self?.subscribeToFindInPage()
            self?.subscribeToCanBookmark()
        }
    }

    private func subscribeToFindInPage() {
        findInPageCancellable?.cancel()
        let model = tabCollectionViewModel.selectedTabViewModel?.findInPage
        findInPageCancellable = model?.$visible.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateFindInPage()
        }
    }

    private func subscribeToCanGoBackForward() {
        canGoBackCancellable?.cancel()
        canGoBackCancellable = tabCollectionViewModel.selectedTabViewModel?.$canGoBack.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateBackMenuItem()
        }
        canGoForwardCancellable?.cancel()
        canGoForwardCancellable = tabCollectionViewModel.selectedTabViewModel?.$canGoForward.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateForwardMenuItem()
        }
    }

    private func subscribeToCanBookmark() {
        canBookmarkCancellable?.cancel()
        canBookmarkCancellable = tabCollectionViewModel.selectedTabViewModel?.$canBeBookmarked.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateBookmarksMenu()
        }
    }

    private func subscribeToCanInsertLastRemovedTab() {
        canInsertLastRemovedTabCancellable?.cancel()
        canInsertLastRemovedTabCancellable = tabCollectionViewModel.$canInsertLastRemovedTab.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateReopenLastClosedTabMenuItem()
        }
    }

    private func updateFindInPage() {

        guard let model = tabCollectionViewModel.selectedTabViewModel?.findInPage else {
            findInPageViewController?.makeMeFirstResponder()
            os_log("MainViewController: Failed to get find in page model", type: .error)
            return
        }

        findInPageContainerView.isHidden = !model.visible
        findInPageViewController?.model = model
        if model.visible {
            findInPageViewController?.makeMeFirstResponder()
        } else if !(tabCollectionViewModel.selectedTabViewModel?.addressBarString.isEmpty ?? false) {
            // If there's an address bar string, this isn't a new tab, so make the webview the first responder
            tabCollectionViewModel.selectedTabViewModel?.tab.webView.makeMeFirstResponder()
        }
        
    }

    private func updateBackMenuItem() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }
        guard let backMenuItem = NSApplication.shared.mainMenuTyped?.backMenuItem else {
            os_log("MainViewController: Failed to get reference to back menu item", type: .error)
            return
        }

        backMenuItem.isEnabled = selectedTabViewModel.canGoBack
    }

    func updateForwardMenuItem() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }
        guard let forwardMenuItem = NSApplication.shared.mainMenuTyped?.forwardMenuItem else {
            os_log("MainViewController: Failed to get reference to back menu item", type: .error)
            return
        }

        forwardMenuItem.isEnabled = selectedTabViewModel.canGoForward
    }

    private func updateBookmarksMenu() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }
        guard let mainMenu = NSApplication.shared.mainMenuTyped,
              let bookmarkThisPageMenuItem = mainMenu.bookmarkThisPageMenuItem,
              let favoriteThisPageMenuItem = mainMenu.favoriteThisPageMenuItem else {
            os_log("MainViewController: Failed to get reference to bookmarks menu items", type: .error)
            return
        }

        bookmarkThisPageMenuItem.isEnabled = selectedTabViewModel.canBeBookmarked
        favoriteThisPageMenuItem.isEnabled = selectedTabViewModel.canBeBookmarked
    }

    func updateReopenLastClosedTabMenuItem() {
        guard let reopenLastClosedTabMenuItem = NSApplication.shared.mainMenuTyped?.reopenLastClosedTabMenuItem else {
            os_log("MainViewController: Failed to get reference to back menu item", type: .error)
            return
        }

        reopenLastClosedTabMenuItem.isEnabled = tabCollectionViewModel.canInsertLastRemovedTab
    }

}

// MARK: - Escape key

// This needs to be handled here or else there will be a "beep" even if handled in a different view controller. This now
//  matches Safari behaviour.
extension MainViewController {

    func listenToKeyDownEvents() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }

        self.keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return nil }
            return self.customKeyDown(with: event) ? nil : event
        }
    }

    func customKeyDown(with event: NSEvent) -> Bool {
       guard let locWindow = self.view.window,
          NSApplication.shared.keyWindow === locWindow else { return false }

        if Int(event.keyCode) == kVK_Escape {
            findInPageViewController?.findInPageDone(self)
            checkForEndAddressBarEditing()
            return true
        }

        return false
    }

    private func checkForEndAddressBarEditing() {
        let addressBarTextField = navigationBarViewController?.addressBarViewController?.addressBarTextField
        guard view.window?.firstResponder == addressBarTextField?.currentEditor() else { return }

        // If the webview doesn't have content it doesn't handle becoming the first responder properly
        if tabCollectionViewModel.selectedTabViewModel?.tab.webView.url != nil {
            tabCollectionViewModel.selectedTabViewModel?.tab.webView.makeMeFirstResponder()
        } else {
            navigationBarContainerView.makeMeFirstResponder()
        }

    }

}
