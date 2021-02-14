//
//  OptionsButtonMenuDelegate.swift
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
import WebKit

class OptionsButtonMenu: NSMenu {

    private let tabCollectionViewModel: TabCollectionViewModel

    required init(coder: NSCoder) {
        fatalError("OptionsButtonMenu: Bad initializer")
    }

    init(tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        super.init(title: "")

        setupMenuItems()
    }

    private func addMenuItem(title: String, action: Selector, imageName: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(named: imageName)
        addItem(item)
    }

    private func setupMenuItems() {
        addMenuItem(title: UserText.moveTabToNewWindow,
                    action: #selector(moveTabToNewWindowAction(_:)),
                    imageName: "MoveTabToNewWindow")

        addItem(NSMenuItem.separator())

        if let host = tabCollectionViewModel.selectedTabViewModel?.tab.url?.baseHost {
            if PreserveLogins.shared.isAllowed(fireproofDomain: host) {
                addMenuItem(title: UserText.removeFireproofing, action: #selector(toggleFireproofing(_:)), imageName: "BurnProof")
            } else {
                addMenuItem(title: UserText.fireproofSite, action: #selector(toggleFireproofing(_:)), imageName: "BurnProof")
            }

            addItem(NSMenuItem.separator())
        }

#if FEEDBACK

        addMenuItem(title: "Send Feedback",
                    action: #selector(openFeedbackAction(_:)),
                    imageName: "Feedback")

#endif

    }

    @objc func moveTabToNewWindowAction(_ sender: NSMenuItem) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        let tab = selectedTabViewModel.tab
        tabCollectionViewModel.removeSelected()
        WindowsManager.openNewWindow(with: tab)
    }

    @objc func toggleFireproofing(_ sender: NSMenuItem) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.tab.requestFireproofToggle()
    }

    #if FEEDBACK

    @objc func openFeedbackAction(_ sender: NSMenuItem) {
        let tab = Tab()
        tab.url = URL.feedback
        tabCollectionViewModel.append(tab: tab)
    }

    #endif

}
