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
import os.log

class MainViewController: NSViewController {

    @IBOutlet weak var tabBarContainerView: NSView!
    @IBOutlet weak var navigationBarContainerView: NSView!
    @IBOutlet weak var webContainerView: NSView!

    var tabBarViewController: TabBarViewController?
    var navigationBarViewController: NavigationBarViewController?
    var browserTabViewController: BrowserTabViewController?

    var tabCollectionViewModel = TabCollectionViewModel()

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
    
}
