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

    private var tabBarViewController: TabBarViewController!
    private(set) var navigationBarViewController: NavigationBarViewController!
    private var browserTabViewController: BrowserTabViewController!
    private var findInPageViewController: FindInPageViewController!

    var tabCollectionViewModel = TabCollectionViewModel()

    private var selectedTabViewModelCancellable: AnyCancellable?
    private var canGoForwardCancellable: AnyCancellable?
    private var canGoBackCancellable: AnyCancellable?
    private var canInsertLastRemovedTabCancellable: AnyCancellable?
    private var findInPageCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        listenToKeyDownEvents()
        subscribeToSelectedTabViewModel()
        subscribeToCanInsertLastRemovedTab()
        findInPageContainerView.applyDropShadow()
    }

    func windowDidBecomeMain() {
        updateBackMenuItem()
        updateForwardMenuItem()
        updateReopenLastClosedTabMenuItem()
    }

    func windowWillClose() {
        tabCollectionViewModel.removeAllTabs()
    }

    @IBSegueAction
    func createTabBarViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> TabBarViewController {
        self.tabBarViewController = TabBarViewController(coder: coder, tabCollectionViewModel: tabCollectionViewModel)!
        return tabBarViewController
    }

    @IBSegueAction
    func createNavigationBarViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> NavigationBarViewController {
        self.navigationBarViewController = NavigationBarViewController(coder: coder, tabCollectionViewModel: tabCollectionViewModel)!
        return navigationBarViewController
    }

    @IBSegueAction
    func createWebViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> BrowserTabViewController {
        self.browserTabViewController = BrowserTabViewController(coder: coder, tabCollectionViewModel: tabCollectionViewModel)!
        return browserTabViewController
    }

    @IBSegueAction
    func createFindInPageViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> FindInPageViewController? {
        self.findInPageViewController = FindInPageViewController(coder: coder)
        findInPageViewController?.delegate = self
        return findInPageViewController
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.subscribeToCanGoBackForward()
            self?.subscribeToFindInPage()
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
        guard let mainMenu = NSApplication.shared.mainMenu, let backMenuItem = mainMenu.backMenuItem else {
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
        guard let mainMenu = NSApplication.shared.mainMenu, let forwardMenuItem = mainMenu.forwardMenuItem else {
            os_log("MainViewController: Failed to get reference to back menu item", type: .error)
            return
        }

        forwardMenuItem.isEnabled = selectedTabViewModel.canGoForward
    }

    func updateReopenLastClosedTabMenuItem() {
        guard let mainMenu = NSApplication.shared.mainMenu, let reopenLastClosedTabMenuItem = mainMenu.reopenLastClosedTabMenuItem else {
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
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
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
