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
import BrowserServicesKit

class OptionsButtonMenu: NSMenu {

    private let tabCollectionViewModel: TabCollectionViewModel
    private let emailManager: EmailManager
    
    private var emailMenuItem: NSMenuItem?

    required init(coder: NSCoder) {
        fatalError("OptionsButtonMenu: Bad initializer")
    }

    init(tabCollectionViewModel: TabCollectionViewModel, emailManager: EmailManager = EmailManager()) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        super.init(title: "")

        setupMenuItems()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(emailDidSignInNotification(_:)),
                                               name: .emailDidSignIn,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(emailDidSignOutNotification(_:)),
                                               name: .emailDidSignOut,
                                               object: nil)
    }

    private func setupMenuItems() {
        let moveTabMenuItem = NSMenuItem(title: UserText.moveTabToNewWindow,
                                         action: #selector(moveTabToNewWindowAction(_:)),
                                         keyEquivalent: "")
        moveTabMenuItem.target = self
        moveTabMenuItem.image = NSImage(named: "MoveTabToNewWindow")
        addItem(moveTabMenuItem)

#if FEEDBACK

        let openFeedbackMenuItem = NSMenuItem(title: "Send Feedback",
                                         action: #selector(openFeedbackAction(_:)),
                                         keyEquivalent: "")
        openFeedbackMenuItem.target = self
        openFeedbackMenuItem.image = NSImage(named: "Feedback")
        addItem(openFeedbackMenuItem)

#endif
        
        let emailItem = NSMenuItem(title: "",
                                   action: nil,
                                   keyEquivalent: "")
        emailItem.target = self
        emailItem.image = NSImage(named: "Feedback")
        addItem(emailItem)
        emailMenuItem = emailItem
        updateEmailMenuItem()
    }
    
    private func updateEmailMenuItem() {
        if emailManager.isSignedIn {
            emailMenuItem?.title = "Turn off Email Protection"
            emailMenuItem?.action = #selector(turnOffEmailAction(_:))
        } else {
            emailMenuItem?.title = "Turn on Email Protection"
            emailMenuItem?.action = #selector(turnOnEmailAction(_:))
        }
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

#if FEEDBACK

    @objc func openFeedbackAction(_ sender: NSMenuItem) {
        let tab = Tab()
        tab.url = URL.feedback
        tabCollectionViewModel.append(tab: tab)
    }

#endif
    
    @objc func turnOffEmailAction(_ sender: NSMenuItem) {
        emailManager.signOut()
    }
    
    @objc func turnOnEmailAction(_ sender: NSMenuItem) {
        let tab = Tab()
        tab.url = EmailUrls().emailLandingPage
        tabCollectionViewModel.append(tab: tab)
    }

    @objc func emailDidSignInNotification(_ notification: Notification) {
        updateEmailMenuItem()
    }
    
    @objc func emailDidSignOutNotification(_ notification: Notification) {
        updateEmailMenuItem()
    }
    
}
