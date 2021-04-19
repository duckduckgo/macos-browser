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

final class OptionsButtonMenu: NSMenu {

    private let tabCollectionViewModel: TabCollectionViewModel
    private let emailManager: EmailManager

    enum Result {
        case moveTabToNewWindow
        case feedback
        case fireproof

        case emailProtection
        case emailProtectionOff
        case emailProtectionCreateAddress
        case emailProtectionDashboard

        case bookmarkThisPage
        case favoriteThisPage
        case navigateToBookmark

        case preferences
    }
    fileprivate(set) var result: Result?

    required init(coder: NSCoder) {
        fatalError("OptionsButtonMenu: Bad initializer")
    }

    init(tabCollectionViewModel: TabCollectionViewModel, emailManager: EmailManager = EmailManager()) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        super.init(title: "")

        setupMenuItems()
    }

    let bookmarksMenuItem = NSMenuItem(title: UserText.bookmarks, action: nil, keyEquivalent: "")

    override func update() {
        self.result = nil
        updateBookmarks()

        super.update()
    }

    // swiftlint:disable function_body_length
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
        openFeedbackMenuItem.image = NSImage(named: "Feedback")
        addItem(openFeedbackMenuItem)

#endif
        
        let emailItem = NSMenuItem(title: UserText.emailOptionsMenuItem,
                                   action: nil,
                                   keyEquivalent: "")
        emailItem.image = NSImage(named: "OptionsButtonMenuEmail")
        emailItem.submenu = EmailOptionsButtonSubMenu(tabCollectionViewModel: tabCollectionViewModel, emailManager: emailManager)
        addItem(emailItem)
    
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

        let preferencesItem = NSMenuItem(title: UserText.preferences, action: #selector(openPreferences(_:)), keyEquivalent: "")
        preferencesItem.target = self
        preferencesItem.image = NSImage(named: "Preferences")
        addItem(preferencesItem)
    }
    // swiftlint:enable function_body_length
    
    private func updateBookmarks() {
        // The bookmarks section is the same with the main menu
        bookmarksMenuItem.submenu = BookmarksSubMenu()
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

    @objc func openPreferences(_ sender: NSMenuItem) {
        WindowControllersManager.shared.showPreferencesTab()
    }

    override func performActionForItem(at index: Int) {
        defer {
            super.performActionForItem(at: index)
        }

        guard let item = self.item(at: index) else {
            assertionFailure("MainViewController: No Menu Item at index \(index)")
            return
        }

        switch item.action {
        case #selector(moveTabToNewWindowAction(_:)):
            self.result = .moveTabToNewWindow
        case #selector(AppDelegate.openFeedback(_:)):
            self.result = .feedback
        case #selector(toggleFireproofing(_:)):
            self.result = .fireproof
        case #selector(openPreferences(_:)):
            self.result = .preferences
        case .none:
            break
        default:
            assertionFailure("MainViewController: no case for selector \(item.action!)")
        }
    }

}

final class BookmarksSubMenu: NSMenu {

    init(menu: NSMenu?) {
        super.init(title: menu?.title ?? "")

        for item in menu?.items ?? [] {
            let item = (item.copy() as? NSMenuItem)!
            self.addItem(item)
            if let submenu = item.submenu {
                item.submenu = BookmarksSubMenu(menu: submenu)
            }
        }
    }

    convenience init() {
        let bookmarksMenu = NSApplication.shared.mainMenuTyped.bookmarksMenuItem?.submenu

        self.init(menu: bookmarksMenu)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func performActionForItem(at index: Int) {
        defer {
            super.performActionForItem(at: index)
        }
        guard let item = self.item(at: index) else {
            assertionFailure("MainViewController: No Menu Item at index \(index)")
            return
        }
        guard let supermenu = item.topMenu as? OptionsButtonMenu else {
            assertionFailure("Unexpected supermenu kind: \(type(of: item.topMenu))")
            return
        }

        switch item.action {
        case #selector(MainViewController.bookmarkThisPage(_:)):
            supermenu.result = .bookmarkThisPage
        case #selector(MainViewController.favoriteThisPage(_:)):
            supermenu.result = .favoriteThisPage
        case #selector(MainViewController.navigateToBookmark(_:)):
            supermenu.result = .navigateToBookmark
        case .none:
            break
        default:
            assertionFailure("MainViewController: no case for selector \(item.action!)")
        }
    }

}

final class EmailOptionsButtonSubMenu: NSMenu {
    
    private let tabCollectionViewModel: TabCollectionViewModel
    private let emailManager: EmailManager
        
    init(tabCollectionViewModel: TabCollectionViewModel, emailManager: EmailManager) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        super.init(title: UserText.emailOptionsMenuItem)

        updateMenuItems()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(emailDidSignInNotification(_:)),
                                               name: .emailDidSignIn,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(emailDidSignOutNotification(_:)),
                                               name: .emailDidSignOut,
                                               object: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateMenuItems() {
        removeAllItems()
        if emailManager.isSignedIn {
            let createAddressItem = NSMenuItem(title: UserText.emailOptionsMenuCreateAddressSubItem,
                                           action: #selector(createAddressAction(_:)),
                                           keyEquivalent: "")
            createAddressItem.target = self
            createAddressItem.image = NSImage(named: "OptionsButtonMenuEmailGenerateAddress")
            addItem(createAddressItem)
            
            let viewDashboardItem = NSMenuItem(title: UserText.emailOptionsMenuViewDashboardSubItem,
                                           action: #selector(viewDashboardAction(_:)),
                                           keyEquivalent: "")
            viewDashboardItem.target = self
            viewDashboardItem.image = NSImage(named: "OptionsButtonMenuEmailDashboard")
            addItem(viewDashboardItem)
            
            let turnOnOffItem = NSMenuItem(title: UserText.emailOptionsMenuTurnOffSubItem,
                                           action: #selector(turnOffEmailAction(_:)),
                                           keyEquivalent: "")
            turnOnOffItem.target = self
            turnOnOffItem.image = NSImage(named: "OptionsButtonMenuEmailDisabled")
            addItem(turnOnOffItem)
        } else {
            let turnOnOffItem = NSMenuItem(title: UserText.emailOptionsMenuTurnOnSubItem,
                                           action: #selector(turnOnEmailAction(_:)),
                                           keyEquivalent: "")
            turnOnOffItem.target = self
            turnOnOffItem.image = NSImage(named: "OptionsButtonMenuEmail")
            addItem(turnOnOffItem)
        }
    }
    
    @objc func createAddressAction(_ sender: NSMenuItem) {
        guard let url = emailManager.generateTokenPageURL else {
            assertionFailure("Could not get token page URL, token not available")
            return
        }
        let tab = Tab()
        tab.url = url
        tabCollectionViewModel.append(tab: tab)

        (supermenu as? OptionsButtonMenu)?.result = .emailProtectionCreateAddress
    }
    
    @objc func viewDashboardAction(_ sender: NSMenuItem) {
        let tab = Tab()
        tab.url = EmailUrls().emailDashboardPage
        tabCollectionViewModel.append(tab: tab)

        (supermenu as? OptionsButtonMenu)?.result = .emailProtectionDashboard
    }
    
    @objc func turnOffEmailAction(_ sender: NSMenuItem) {
        emailManager.signOut()

        (supermenu as? OptionsButtonMenu)?.result = .emailProtectionOff
    }
    
    @objc func turnOnEmailAction(_ sender: NSMenuItem) {
        let tab = Tab()
        tab.url = EmailUrls().emailLandingPage
        tabCollectionViewModel.append(tab: tab)

        (supermenu as? OptionsButtonMenu)?.result = .emailProtection
    }

    @objc func emailDidSignInNotification(_ notification: Notification) {
        updateMenuItems()
    }
    
    @objc func emailDidSignOutNotification(_ notification: Notification) {
        updateMenuItems()
    }
}
