//
//  MoreOptionsMenu.swift
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

protocol OptionsButtonMenuDelegate: AnyObject {

    func optionsButtonMenuRequestedBookmarkPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedLoginsPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedDownloadsPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedPrint(_ menu: NSMenu)

}

final class MoreOptionsMenu: NSMenu {

    weak var actionDelegate: OptionsButtonMenuDelegate?

    private let tabCollectionViewModel: TabCollectionViewModel
    private let emailManager: EmailManager

    fileprivate(set) var pixel: Pixel.Event.MoreResult?

    required init(coder: NSCoder) {
        fatalError("MoreOptionsMenu: Bad initializer")
    }

    init(tabCollectionViewModel: TabCollectionViewModel, emailManager: EmailManager = EmailManager()) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        super.init(title: "")

        setupMenuItems()
    }

    let zoomMenuItem = NSMenuItem(title: UserText.zoom, action: nil, keyEquivalent: "")

    override func update() {
        self.pixel = nil
        super.update()
    }

    private func setupMenuItems() {

#if FEEDBACK

        let openFeedbackMenuItem = NSMenuItem(title: "Send Feedback",
                                              action: #selector(AppDelegate.openFeedback(_:)),
                                         keyEquivalent: "")
        openFeedbackMenuItem.image = NSImage(named: "Feedback")
        addItem(openFeedbackMenuItem)

        addItem(NSMenuItem.separator())

#endif

        addWindowItems()

        zoomMenuItem.submenu = ZoomSubMenu(tabCollectionViewModel: tabCollectionViewModel)
        addItem(zoomMenuItem)
        addItem(NSMenuItem.separator())

        addUtilityItems()

        addPageItems()

        let preferencesItem = NSMenuItem(title: UserText.preferences, action: #selector(openPreferences(_:)), keyEquivalent: "")
        preferencesItem.target = self
        preferencesItem.image = NSImage(named: "Preferences")
        addItem(preferencesItem)
    }

    @objc func newTab(_ sender: NSMenuItem) {
        tabCollectionViewModel.appendNewTab()
    }

    @objc func newWindow(_ sender: NSMenuItem) {
        WindowsManager.openNewWindow()
    }

    @objc func toggleFireproofing(_ sender: NSMenuItem) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }
        
        selectedTabViewModel.tab.requestFireproofToggle()
    }

    @objc func openBookmarks(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkPopover(self)
    }

    @objc func openDownloads(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedDownloadsPopover(self)
    }

    @objc func openLogins(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedLoginsPopover(self)
    }

    @objc func openPreferences(_ sender: NSMenuItem) {
        WindowControllersManager.shared.showPreferencesTab()
    }

    @objc func findInPage(_ sender: NSMenuItem) {
        tabCollectionViewModel.selectedTabViewModel?.findInPage.show()
    }

    @objc func doPrint(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedPrint(self)
    }

    // swiftlint:disable cyclomatic_complexity
    override func performActionForItem(at index: Int) {
        defer {
            super.performActionForItem(at: index)
        }

        guard let item = self.item(at: index) else {
            assertionFailure("MainViewController: No Menu Item at index \(index)")
            return
        }

        switch item.action {
        case #selector(AppDelegate.openFeedback(_:)):
            self.pixel = .feedback
        case #selector(toggleFireproofing(_:)):
            self.pixel = .fireproof
        case #selector(openBookmarks(_:)):
            self.pixel = .bookmarksList
        case #selector(openDownloads(_:)):
            self.pixel = .downloads
        case #selector(openPreferences(_:)):
            self.pixel = .preferences
        case #selector(openLogins(_:)):
            self.pixel = .logins
        case #selector(findInPage(_:)):
            self.pixel = .findInPage
        case #selector(doPrint(_:)):
            self.pixel = .print
        case #selector(newTab(_:)):
            self.pixel = .newTab
        case #selector(newWindow(_:)):
            self.pixel = .newWindow
        case .none:
            break
        default:
            assertionFailure("MainViewController: no case for selector \(item.action!)")
        }
    }
    // swiftlint:enable cyclomatic_complexity

    private func addWindowItems() {

        // New Tab
        let newTabMenuItem = NSMenuItem(title: UserText.plusButtonNewTabMenuItem,
                                         action: #selector(newTab(_:)),
                                         keyEquivalent: "t")
        newTabMenuItem.target = self
        newTabMenuItem.image = NSImage(named: "Add")
        addItem(newTabMenuItem)

        // New Window
        let newWindowItem = NSMenuItem(title: UserText.newWindowMenuItem,
                                         action: #selector(newWindow(_:)),
                                         keyEquivalent: "n")
        newWindowItem.target = self
        newWindowItem.image = NSImage(named: "NewWindow")
        addItem(newWindowItem)

        addItem(NSMenuItem.separator())

    }

    private func addUtilityItems() {
        let bookmarksMenuItem = NSMenuItem(title: UserText.bookmarks, action: #selector(openBookmarks), keyEquivalent: "")
        bookmarksMenuItem.target = self
        bookmarksMenuItem.image = NSImage(named: "Bookmarks")
        addItem(bookmarksMenuItem)

        let downloadsMenuItem = NSMenuItem(title: UserText.downloads, action: #selector(openDownloads), keyEquivalent: "j")
        downloadsMenuItem.target = self
        downloadsMenuItem.image = NSImage(named: "Downloads")
        addItem(downloadsMenuItem)

        let passwordManagementMenuItem = NSMenuItem(title: UserText.passwordManagement, action: #selector(openLogins), keyEquivalent: "")
        passwordManagementMenuItem.target = self
        passwordManagementMenuItem.image = NSImage(named: "PasswordManagement")
        addItem(passwordManagementMenuItem)

        let emailItem = NSMenuItem(title: UserText.emailOptionsMenuItem,
                                   action: nil,
                                   keyEquivalent: "")
        emailItem.image = NSImage(named: "OptionsButtonMenuEmail")
        emailItem.submenu = EmailOptionsButtonSubMenu(tabCollectionViewModel: tabCollectionViewModel, emailManager: emailManager)
        addItem(emailItem)

        addItem(NSMenuItem.separator())
    }

    private func addPageItems() {
        guard let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url else { return }

        if url.canFireproof, let host = url.host {
            if FireproofDomains.shared.isFireproof(fireproofDomain: host) {

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
        }

        let findInPageMenuItem = NSMenuItem(title: UserText.findInPageMenuItem, action: #selector(findInPage(_:)), keyEquivalent: "f")
        findInPageMenuItem.target = self
        findInPageMenuItem.image = NSImage(named: "Find-Search")
        addItem(findInPageMenuItem)

        let shareMenuItem = NSMenuItem(title: UserText.shareMenuItem, action: nil, keyEquivalent: "")
        shareMenuItem.target = self
        shareMenuItem.image = NSImage(named: "Share")
        addItem(shareMenuItem)
        shareMenuItem.submenu = SharingMenu()

        let printMenuItem = NSMenuItem(title: UserText.printMenuItem, action: #selector(doPrint(_:)), keyEquivalent: "")
        printMenuItem.target = self
        printMenuItem.image = NSImage(named: "Print")
        addItem(printMenuItem)

        addItem(NSMenuItem.separator())

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
        let tab = Tab(content: .url(url))
        tabCollectionViewModel.append(tab: tab)
        (supermenu as? MoreOptionsMenu)?.pixel = .emailProtectionCreateAddress
    }
    
    @objc func turnOffEmailAction(_ sender: NSMenuItem) {
        emailManager.signOut()

        (supermenu as? MoreOptionsMenu)?.pixel = .emailProtectionOff
    }
    
    @objc func turnOnEmailAction(_ sender: NSMenuItem) {
        let tab = Tab(content: .url(EmailUrls().emailLandingPage))
        tabCollectionViewModel.append(tab: tab)

        (supermenu as? MoreOptionsMenu)?.pixel = .emailProtection
    }

    @objc func emailDidSignInNotification(_ notification: Notification) {
        updateMenuItems()
    }
    
    @objc func emailDidSignOutNotification(_ notification: Notification) {
        updateMenuItems()
    }
}

final class ZoomSubMenu: NSMenu {

    init(tabCollectionViewModel: TabCollectionViewModel) {
        super.init(title: UserText.zoom)

        updateMenuItems(with: tabCollectionViewModel)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(with tabCollectionViewModel: TabCollectionViewModel) {
        removeAllItems()

        let fullScreenItem = (NSApplication.shared.mainMenuTyped.toggleFullscreenMenuItem?.copy() as? NSMenuItem)!
        addItem(fullScreenItem)

        addItem(.separator())

        let zoomInItem = (NSApplication.shared.mainMenuTyped.zoomInMenuItem?.copy() as? NSMenuItem)!
        addItem(zoomInItem)

        let zoomOutItem = (NSApplication.shared.mainMenuTyped.zoomOutMenuItem?.copy() as? NSMenuItem)!
        addItem(zoomOutItem)

        let actualSizeItem = (NSApplication.shared.mainMenuTyped.actualSizeMenuItem?.copy() as? NSMenuItem)!
        addItem(actualSizeItem)
    }

}
