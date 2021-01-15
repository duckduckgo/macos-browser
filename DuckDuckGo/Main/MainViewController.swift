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
import Combine
import Carbon.HIToolbox
import os.log

class MainViewController: NSViewController {

    @IBOutlet weak var tabBarContainerView: NSView!
    @IBOutlet weak var navigationBarContainerView: NSView!
    @IBOutlet weak var webContainerView: NSView!
    @IBOutlet weak var findInPageContainerView: NSView!

    private(set) var tabBarViewController: TabBarViewController?
    private(set) var navigationBarViewController: NavigationBarViewController?
    private(set) var browserTabViewController: BrowserTabViewController?
    private(set) var findInPageViewController: FindInPageViewController?

    var tabCollectionViewModel = TabCollectionViewModel()

    private var selectedTabViewModelCancellable: AnyCancellable?
    private var canGoForwardCancellable: AnyCancellable?
    private var canGoBackCancellable: AnyCancellable?
    private var canInsertLastRemovedTabCancellable: AnyCancellable?
    private var findInPageCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

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
        self.findInPageViewController = FindInPageViewController(coder: coder)
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
        findInPageCancellable = tabCollectionViewModel.selectedTabViewModel?.$findInPage.receive(on: DispatchQueue.main).sink { [weak self] model in
            self?.updateFindInPage(model)
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

    private func updateFindInPage(_ model: FindInPageModel?) {
        findInPageContainerView.isHidden = model == nil
        findInPageViewController?.model = model
        if model == nil {
            self.view.makeMeFirstResponder()
        } else {
            findInPageViewController?.makeMeFirstResponder()
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
