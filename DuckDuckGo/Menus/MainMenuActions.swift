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

}

extension MainViewController {

    // MARK: - File

    @IBAction func newTab(_ sender: Any?) {
        tabCollectionViewModel.appendNewTab()
    }

    @IBAction func openLocation(_ sender: Any?) {
        guard let addressBarTextField = navigationBarViewController?.addressBarViewController?.addressBarTextField else {
            os_log("MainViewController: Cannot reference address bar text field", type: .error)
            return
        }
        view.window?.makeFirstResponder(addressBarTextField)
    }

    @IBAction func closeTab(_ sender: Any?) {
        tabCollectionViewModel.removeSelected()
    }

    // MARK: - View

    @IBAction func reloadPage(_ sender: Any?) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.tab.reload()
    }

    @IBAction func stopLoading(_ sender: Any?) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.tab.stopLoading()
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

    // MARK: - Help

#if FEEDBACK

    @IBAction func openFeedback(_ sender: Any?) {
        let tab = Tab()
        tab.url = URL.feedback
        tabCollectionViewModel.append(tab: tab)
    }

#endif

}
