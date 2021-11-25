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

    private func setupMenuItems() {

#if FEEDBACK

        addItem(withTitle: "Send Feedback", action: #selector(AppDelegate.openFeedback(_:)), keyEquivalent: "")
            .withImage(NSImage(named: "BetaLabel"))
            .firingPixel(.feedback)

        addItem(NSMenuItem.separator())

#endif

        addWindowItems()

        zoomMenuItem.submenu = ZoomSubMenu(tabCollectionViewModel: tabCollectionViewModel)
        addItem(zoomMenuItem)
        addItem(NSMenuItem.separator())

        addUtilityItems()

        addItem(withTitle: UserText.emailOptionsMenuItem, action: nil, keyEquivalent: "")
            .withImage(NSImage(named: "OptionsButtonMenuEmail"))
            .withSubmenu(EmailOptionsButtonSubMenu(tabCollectionViewModel: tabCollectionViewModel, emailManager: emailManager))

        addItem(NSMenuItem.separator())

        addPageItems()

        let preferencesItem = NSMenuItem(title: UserText.preferences, action: #selector(openPreferences(_:)), keyEquivalent: "")
            .targetting(self)
            .withImage(NSImage(named: "Preferences"))
            .firingPixel(Pixel.Event.MoreResult.preferences)
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

    override func performActionForItem(at index: Int) {
        defer {
            super.performActionForItem(at: index)
        }

        guard let item = self.item(at: index) else {
            assertionFailure("MainViewController: No Menu Item at index \(index)")
            return
        }

        // For now assume there must be a pixel.  This might change later as we reign this in.
        guard let pixel = item.representedObject as? Pixel.Event.MoreResult else {
            assertionFailure("MainViewController: No pixel for menu at \(index)")
            return
        }
        Pixel.fire(.moreMenu(result: pixel))
    }

    private func addWindowItems() {

        // New Tab
        addItem(withTitle: UserText.plusButtonNewTabMenuItem, action: #selector(newTab(_:)), keyEquivalent: "t")
            .targetting(self)
            .withImage(NSImage(named: "Add"))
            .firingPixel(Pixel.Event.MoreResult.newTab)

        // New Window
        addItem(withTitle: UserText.newWindowMenuItem, action: #selector(newWindow(_:)), keyEquivalent: "n")
            .targetting(self)
            .withImage(NSImage(named: "NewWindow"))
            .firingPixel(Pixel.Event.MoreResult.newWindow)

        addItem(NSMenuItem.separator())

    }

    private func addUtilityItems() {
        addItem(withTitle: UserText.bookmarks, action: #selector(openBookmarks), keyEquivalent: "")
            .targetting(self)
            .withImage(NSImage(named: "Bookmarks"))
            .firingPixel(Pixel.Event.MoreResult.bookmarksList)

        addItem(withTitle: UserText.downloads, action: #selector(openDownloads), keyEquivalent: "j")
            .targetting(self)
            .withImage(NSImage(named: "Downloads"))
            .firingPixel(Pixel.Event.MoreResult.downloads)

        addItem(withTitle: UserText.passwordManagement, action: #selector(openLogins), keyEquivalent: "")
            .targetting(self)
            .withImage(NSImage(named: "PasswordManagement"))
            .firingPixel(Pixel.Event.MoreResult.logins)

        addItem(NSMenuItem.separator())
    }

    private func addPageItems() {
        guard let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url else { return }

        if url.canFireproof, let host = url.host {

            let title = FireproofDomains.shared.isFireproof(fireproofDomain: host) ? UserText.removeFireproofing : UserText.fireproofSite

            addItem(withTitle: title, action: #selector(toggleFireproofing(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(NSImage(named: "BurnProof"))
                .firingPixel(Pixel.Event.MoreResult.fireproof)

        }

        addItem(withTitle: UserText.findInPageMenuItem, action: #selector(findInPage(_:)), keyEquivalent: "f")
            .targetting(self)
            .withImage(NSImage(named: "Find-Search"))
            .representedObject = Pixel.Event.MoreResult.findInPage

        addItem(withTitle: UserText.shareMenuItem, action: nil, keyEquivalent: "")
            .targetting(self)
            .withImage(NSImage(named: "Share"))
            .withSubmenu(SharingMenu())

        addItem(withTitle: UserText.printMenuItem, action: #selector(doPrint(_:)), keyEquivalent: "")
            .targetting(self)
            .withImage(NSImage(named: "Print"))
            .firingPixel(Pixel.Event.MoreResult.print)

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
            addItem(withTitle: UserText.emailOptionsMenuCreateAddressSubItem, action: #selector(createAddressAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(NSImage(named: "OptionsButtonMenuEmailGenerateAddress"))

            addItem(withTitle: UserText.emailOptionsMenuTurnOffSubItem, action: #selector(turnOffEmailAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(NSImage(named: "OptionsButtonMenuEmailDisabled"))

        } else {
            addItem(withTitle: UserText.emailOptionsMenuTurnOnSubItem, action: #selector(turnOnEmailAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(NSImage(named: "OptionsButtonMenuEmail"))

        }
    }
    
    @objc func createAddressAction(_ sender: NSMenuItem) {
        guard let url = emailManager.generateTokenPageURL else {
            assertionFailure("Could not get token page URL, token not available")
            return
        }
        let tab = Tab(content: .url(url))
        tabCollectionViewModel.append(tab: tab)
        Pixel.fire(.moreMenu(result: .emailProtectionCreateAddress))
    }
    
    @objc func turnOffEmailAction(_ sender: NSMenuItem) {
        emailManager.signOut()
        Pixel.fire(.moreMenu(result: .emailProtectionOff))
    }
    
    @objc func turnOnEmailAction(_ sender: NSMenuItem) {
        let tab = Tab(content: .url(EmailUrls().emailLandingPage))
        tabCollectionViewModel.append(tab: tab)
        Pixel.fire(.moreMenu(result: .emailProtection))
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

extension NSMenuItem {

    @discardableResult
    func firingPixel(_ pixel: Pixel.Event.MoreResult) -> NSMenuItem {
        representedObject = pixel
        return self
    }

    @discardableResult
    func withImage(_ image: NSImage?) -> NSMenuItem {
        self.image = image
        return self
    }

    @discardableResult
    func targetting(_ target: AnyObject) -> NSMenuItem {
        self.target = target
        return self
    }

    @discardableResult
    func withSubmenu(_ submenu: NSMenu) -> NSMenuItem {
        self.submenu = submenu
        return self
    }

}
