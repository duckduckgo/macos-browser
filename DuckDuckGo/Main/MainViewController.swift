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
import os.log

class MainViewController: NSViewController {

    @IBOutlet weak var tabBarContainerView: NSView!
    @IBOutlet weak var navigationBarContainerView: NSView!
    @IBOutlet weak var webContainerView: NSView!

    private var tabBarViewController: TabBarViewController?
    private var navigationBarViewController: NavigationBarViewController?
    private var browserTabViewController: BrowserTabViewController?

    var tabCollectionViewModel = TabCollectionViewModel()

    private var selectedTabViewModelCancelable: AnyCancellable?
    private var canGoForwardCancelable: AnyCancellable?
    private var canGoBackCancelable: AnyCancellable?
    private var canInsertLastRemovedTabCancelable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        bindSelectedTabViewModel()
        bindCanInsertLastRemovedTab()
    }

    func windowDidBecomeMain() {
        setBackMenuItem()
        setForwardMenuItem()
        setReopenLastClosedTabMenuItem()
    }

    func windowWillClose() {
        tabCollectionViewModel.removeAllTabs()
    }

    @IBSegueAction
    func createTabBarViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> TabBarViewController? {
        guard let tabBarViewController = TabBarViewController(coder: coder, tabCollectionViewModel: tabCollectionViewModel) else {
            os_log("MainViewController: Failed to init TabBarViewController", log: OSLog.Category.general, type: .error)
            return nil
        }

        self.tabBarViewController = tabBarViewController
        return tabBarViewController
    }

    @IBSegueAction
    func createNavigationBarViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> NavigationBarViewController? {
        guard let navigationBarViewController = NavigationBarViewController(coder: coder, tabCollectionViewModel: tabCollectionViewModel) else {
            os_log("MainViewController: Failed to init NavigationBarViewController", log: OSLog.Category.general, type: .error)
            return nil
        }

        self.navigationBarViewController = navigationBarViewController
        return navigationBarViewController
    }

    @IBSegueAction
    func createWebViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> BrowserTabViewController? {
        guard let browserTabViewController = BrowserTabViewController(coder: coder,
                                                                      tabCollectionViewModel: tabCollectionViewModel,
                                                                      historyViewModel: HistoryViewModel()) else {
            os_log("MainViewController: Failed to init BrowserTabViewController", log: OSLog.Category.general, type: .error)
            return nil
        }

        self.browserTabViewController = browserTabViewController
        return browserTabViewController
    }

    private func bindSelectedTabViewModel() {
        selectedTabViewModelCancelable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.bindCanGoBackForward()
        }
    }

    private func bindCanGoBackForward() {
        canGoBackCancelable?.cancel()
        canGoBackCancelable = tabCollectionViewModel.selectedTabViewModel?.$canGoBack.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.setBackMenuItem()
        }
        canGoForwardCancelable?.cancel()
        canGoForwardCancelable = tabCollectionViewModel.selectedTabViewModel?.$canGoForward.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.setForwardMenuItem()
        }
    }

    private func bindCanInsertLastRemovedTab() {
        canInsertLastRemovedTabCancelable?.cancel()
        canInsertLastRemovedTabCancelable = tabCollectionViewModel.$canInsertLastRemovedTab.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.setReopenLastClosedTabMenuItem()
        }
    }

    private func setBackMenuItem() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", log: OSLog.Category.general, type: .error)
            return
        }
        guard let mainMenu = NSApplication.shared.mainMenu, let backMenuItem = mainMenu.backMenuItem else {
            os_log("MainViewController: Failed to get reference to back menu item", log: OSLog.Category.general, type: .error)
            return
        }

        backMenuItem.isEnabled = selectedTabViewModel.canGoBack
    }

    func setForwardMenuItem() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", log: OSLog.Category.general, type: .error)
            return
        }
        guard let mainMenu = NSApplication.shared.mainMenu, let forwardMenuItem = mainMenu.forwardMenuItem else {
            os_log("MainViewController: Failed to get reference to back menu item", log: OSLog.Category.general, type: .error)
            return
        }

        forwardMenuItem.isEnabled = selectedTabViewModel.canGoForward
    }

    func setReopenLastClosedTabMenuItem() {
        guard let mainMenu = NSApplication.shared.mainMenu, let reopenLastClosedTabMenuItem = mainMenu.reopenLastClosedTabMenuItem else {
            os_log("MainViewController: Failed to get reference to back menu item", log: OSLog.Category.general, type: .error)
            return
        }

        reopenLastClosedTabMenuItem.isEnabled = tabCollectionViewModel.canInsertLastRemovedTab
    }

}
