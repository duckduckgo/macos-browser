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

    let bookmarksMenuItem = NSMenuItem(title: UserText.bookmarks, action: nil, keyEquivalent: "")

    override func update() {
        updateBookmarks()

        super.update()
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
                                              action: #selector(AppDelegate.openFeedback(_:)),
                                         keyEquivalent: "")
        openFeedbackMenuItem.target = AppDelegate.shared
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
    
        addItem(NSMenuItem.separator())
        
        bookmarksMenuItem.image = NSImage(named: "Bookmark")
        addItem(bookmarksMenuItem)

        if let url = tabCollectionViewModel.selectedTabViewModel?.tab.url, url.canFireproof, let host = url.host {
             if FireproofDomains.shared.isAllowed(fireproofDomain: host) {

                let removeFireproofingItem = NSMenuItem(title: UserText.removeFireproofing,
                                                 action: #selector(toggleFireproofing(_:)),
                                                 keyEquivalent: "")
                removeFireproofingItem.target = self
                removeFireproofingItem.image = NSImage(named: "BurnProof")
                addItem(removeFireproofingItem)

             } else {

                let fireproofSiteItem = NSMenuItem(title: UserText.fireproofSite,
                                                 action: #selector(toggleFireproofing(_:)),
                                                 keyEquivalent: "")
                fireproofSiteItem.target = self
                fireproofSiteItem.image = NSImage(named: "BurnProof")
                addItem(fireproofSiteItem)

             }

             addItem(NSMenuItem.separator())
         }
    }
    
    private func updateEmailMenuItem() {
        if emailManager.isSignedIn {
            emailMenuItem?.title = "Turn off Email Protection"
            emailMenuItem?.image = NSImage(named: "OptionsButtonMenuEmailDisabled")
            emailMenuItem?.action = #selector(turnOffEmailAction(_:))
        } else {
            emailMenuItem?.title = "Turn on Email Protection"
            emailMenuItem?.image = NSImage(named: "OptionsButtonMenuEmail")
            emailMenuItem?.action = #selector(turnOnEmailAction(_:))
        }
    }
    
    private func updateBookmarks() {
        // The bookmarks section is the same with the main menu
        bookmarksMenuItem.submenu = NSApplication.shared.mainMenuTyped?.bookmarksMenuItem?.submenu?.copy() as? NSMenu
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
