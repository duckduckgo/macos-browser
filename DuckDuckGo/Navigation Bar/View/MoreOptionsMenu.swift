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
    
    func optionsButtonMenuRequestedBookmarkThisPage(_ sender: NSMenuItem)
    func optionsButtonMenuRequestedBookmarkPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedToggleBookmarksBar(_ menu: NSMenu)
    func optionsButtonMenuRequestedBookmarkManagementInterface(_ menu: NSMenu)
    func optionsButtonMenuRequestedBookmarkImportInterface(_ menu: NSMenu)
    func optionsButtonMenuRequestedLoginsPopover(_ menu: NSMenu, selectedCategory: SecureVaultSorting.Category)
    func optionsButtonMenuRequestedOpenExternalPasswordManager(_ menu: NSMenu)
    func optionsButtonMenuRequestedDownloadsPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedPrint(_ menu: NSMenu)

}

final class MoreOptionsMenu: NSMenu {

    weak var actionDelegate: OptionsButtonMenuDelegate?

    private let tabCollectionViewModel: TabCollectionViewModel
    private let emailManager: EmailManager
    private let passwordManagerCoordinator: PasswordManagerCoordinating
    
    required init(coder: NSCoder) {
        fatalError("MoreOptionsMenu: Bad initializer")
    }
    
    init(tabCollectionViewModel: TabCollectionViewModel,
         emailManager: EmailManager = EmailManager(),
         passwordManagerCoordinator: PasswordManagerCoordinator) {
        
        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        self.passwordManagerCoordinator = passwordManagerCoordinator

        super.init(title: "")
        
        self.emailManager.requestDelegate = self
        
        setupMenuItems()
    }

    let zoomMenuItem = NSMenuItem(title: UserText.zoom, action: nil, keyEquivalent: "")

    private func setupMenuItems() {

        #if FEEDBACK

        addItem(withTitle: "Send Feedback", action: #selector(AppDelegate.openFeedback(_:)), keyEquivalent: "")
            .withImage(NSImage(named: "BetaLabel"))

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

        addItem(withTitle: UserText.networkProtection, action: nil, keyEquivalent: "")
            .withImage(.NetworkProtection.moreOptionsIcon)
            .withSubmenu(NetworkProtectionMenu())

        addItem(NSMenuItem.separator())

        addPageItems()

        let preferencesItem = NSMenuItem(title: UserText.settings, action: #selector(openPreferences(_:)), keyEquivalent: "")
            .targetting(self)
            .withImage(NSImage(named: "Preferences"))
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

    @objc func bookmarkPage(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkThisPage(sender)
    }
    
    @objc func openBookmarks(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkPopover(self)
    }
    
    @objc func openBookmarksManagementInterface(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkManagementInterface(self)
    }
    
    @objc func toggleBookmarksBar(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedToggleBookmarksBar(self)
    }
    
    @objc func openBookmarkImportInterface(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkImportInterface(self)
    }

    @objc func openDownloads(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedDownloadsPopover(self)
    }

    @objc func openAutofillWithAllItems(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedLoginsPopover(self, selectedCategory: .allItems)
    }

    @objc func openAutofillWithLogins(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedLoginsPopover(self, selectedCategory: .logins)
    }
    
    @objc func openExternalPasswordManager(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedOpenExternalPasswordManager(self)
    }

    @objc func openAutofillWithIdentities(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedLoginsPopover(self, selectedCategory: .identities)
    }

    @objc func openAutofillWithCreditCards(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedLoginsPopover(self, selectedCategory: .cards)
    }

    @objc func openPreferences(_ sender: NSMenuItem) {
        WindowControllersManager.shared.showPreferencesTab()
    }

    @objc func findInPage(_ sender: NSMenuItem) {
        tabCollectionViewModel.selectedTabViewModel?.showFindInPage()
    }

    @objc func doPrint(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedPrint(self)
    }

    private func addWindowItems() {

        // New Tab
        addItem(withTitle: UserText.plusButtonNewTabMenuItem, action: #selector(newTab(_:)), keyEquivalent: "t")
            .targetting(self)
            .withImage(NSImage(named: "Add"))

        // New Window
        addItem(withTitle: UserText.newWindowMenuItem, action: #selector(newWindow(_:)), keyEquivalent: "n")
            .targetting(self)
            .withImage(NSImage(named: "NewWindow"))

        addItem(NSMenuItem.separator())

    }

    private func addUtilityItems() {
        let bookmarksSubMenu = BookmarksSubMenu(targetting: self, tabCollectionViewModel: tabCollectionViewModel)
        
        addItem(withTitle: UserText.bookmarks, action: #selector(openBookmarks), keyEquivalent: "")
            .targetting(self)
            .withImage(NSImage(named: "Bookmarks"))
            .withSubmenu(bookmarksSubMenu)

        addItem(withTitle: UserText.downloads, action: #selector(openDownloads), keyEquivalent: "j")
            .targetting(self)
            .withImage(NSImage(named: "Downloads"))

        let loginsSubMenu = LoginsSubMenu(targetting: self,
                                          passwordManagerCoordinator: passwordManagerCoordinator)

        addItem(withTitle: UserText.passwordManagement, action: #selector(openAutofillWithAllItems), keyEquivalent: "")
            .targetting(self)
            .withImage(NSImage(named: "PasswordManagement"))
            .withSubmenu(loginsSubMenu)

        addItem(NSMenuItem.separator())
    }

    private func addPageItems() {
        guard let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url else { return }

        if url.canFireproof, let host = url.host {

            let isFireproof = FireproofDomains.shared.isFireproof(fireproofDomain: host)
            let title = isFireproof ? UserText.removeFireproofing : UserText.fireproofSite
            let image = isFireproof ? NSImage(named: "Burn") : NSImage(named: "Fireproof")

            addItem(withTitle: title, action: #selector(toggleFireproofing(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(image)

        }

        addItem(withTitle: UserText.findInPageMenuItem, action: #selector(findInPage(_:)), keyEquivalent: "f")
            .targetting(self)
            .withImage(NSImage(named: "Find-Search"))

        addItem(withTitle: UserText.shareMenuItem, action: nil, keyEquivalent: "")
            .targetting(self)
            .withImage(NSImage(named: "Share"))
            .withSubmenu(SharingMenu())

        addItem(withTitle: UserText.printMenuItem, action: #selector(doPrint(_:)), keyEquivalent: "")
            .targetting(self)
            .withImage(NSImage(named: "Print"))

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
        assert(emailManager.requestDelegate != nil, "No requestDelegate on emailManager")

        emailManager.getAliasIfNeededAndConsume { [weak self] alias, error in
            guard let alias = alias, let address = self?.emailManager.emailAddressFor(alias) else {
                assertionFailure(error?.localizedDescription ?? "Unexpected email error")
                return
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(address, forType: .string)
            NotificationCenter.default.post(name: NSNotification.Name.privateEmailCopiedToClipboard, object: nil)
        }
    }

    @objc func turnOffEmailAction(_ sender: NSMenuItem) {
        emailManager.signOut()
    }

    @objc func turnOnEmailAction(_ sender: NSMenuItem) {
        let tab = Tab(content: .url(EmailUrls().emailProtectionLink), shouldLoadInBackground: true)
        tabCollectionViewModel.append(tab: tab)
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

final class BookmarksSubMenu: NSMenu {
    
    init(targetting target: AnyObject, tabCollectionViewModel: TabCollectionViewModel) {
        super.init(title: UserText.passwordManagement)
        self.autoenablesItems = false
        updateMenuItems(with: tabCollectionViewModel, target: target)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(with tabCollectionViewModel: TabCollectionViewModel, target: AnyObject) {
        let bookmarkPageItem = addItem(withTitle: UserText.bookmarkThisPage, action: #selector(MoreOptionsMenu.bookmarkPage(_:)), keyEquivalent: "d")
            .withModifierMask([.command])
            .targetting(target)

        bookmarkPageItem.isEnabled = tabCollectionViewModel.selectedTabViewModel?.canBeBookmarked == true
        
        addItem(NSMenuItem.separator())
        
        addItem(withTitle: UserText.bookmarksShowToolbarPanel, action: #selector(MoreOptionsMenu.openBookmarks(_:)), keyEquivalent: "")
            .targetting(target)

        addItem(NSMenuItem.separator())
        
        if let favorites = LocalBookmarkManager.shared.list?.favoriteBookmarks {
            let favoriteViewModels = favorites.compactMap(BookmarkViewModel.init(entity:))
            let potentialItems = bookmarkMenuItems(from: favoriteViewModels)
            
            let favoriteMenuItems = potentialItems.isEmpty ? [NSMenuItem.empty] : potentialItems
            
            let favoritesItem = addItem(withTitle: UserText.favorites, action: nil, keyEquivalent: "")
            favoritesItem.submenu = NSMenu(items: favoriteMenuItems)
            favoritesItem.image = NSImage(named: "Favorite")
            
            addItem(NSMenuItem.separator())
        }
        
        guard let entities = LocalBookmarkManager.shared.list?.topLevelEntities else {
            return
        }
        
        let bookmarkViewModels = entities.compactMap(BookmarkViewModel.init(entity:))
        let menuItems = bookmarkMenuItems(from: bookmarkViewModels, topLevel: true)
        
        self.items.append(contentsOf: menuItems)
        
        addItem(NSMenuItem.separator())

        addItem(withTitle: UserText.importBrowserData, action: #selector(MoreOptionsMenu.openBookmarkImportInterface(_:)), keyEquivalent: "")
            .targetting(target)
    }
    
    private func bookmarkMenuItems(from bookmarkViewModels: [BookmarkViewModel], topLevel: Bool = true) -> [NSMenuItem] {
        var menuItems = [NSMenuItem]()

        if !topLevel {
            let showOpenInTabsItem = bookmarkViewModels.compactMap { $0.entity as? Bookmark }.count > 1
            if showOpenInTabsItem {
                menuItems.append(NSMenuItem(bookmarkViewModels: bookmarkViewModels))
                menuItems.append(.separator())
            }
        }

        for viewModel in bookmarkViewModels {
            let menuItem = NSMenuItem(bookmarkViewModel: viewModel)

            if let folder = viewModel.entity as? BookmarkFolder {
                let subMenu = NSMenu(title: folder.title)
                let childViewModels = folder.children.map(BookmarkViewModel.init)
                let childMenuItems = bookmarkMenuItems(from: childViewModels, topLevel: false)
                subMenu.items = childMenuItems

                if !subMenu.items.isEmpty {
                    menuItem.submenu = subMenu
                }
            }

            menuItems.append(menuItem)
        }

        return menuItems
    }
    
}

final class LoginsSubMenu: NSMenu {
    let passwordManagerCoordinator: PasswordManagerCoordinating

    init(targetting target: AnyObject, passwordManagerCoordinator: PasswordManagerCoordinating) {
        self.passwordManagerCoordinator = passwordManagerCoordinator
        super.init(title: UserText.passwordManagement)
        updateMenuItems(with: target)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(with target: AnyObject) {
        addItem(withTitle: UserText.passwordManagementAllItems, action: #selector(MoreOptionsMenu.openAutofillWithAllItems), keyEquivalent: "")
            .targetting(target)

        addItem(NSMenuItem.separator())

        let autofillSelector: Selector
        let autofillTitle: String
        
        if passwordManagerCoordinator.isEnabled {
            autofillSelector = #selector(MoreOptionsMenu.openExternalPasswordManager)
            autofillTitle = "\(UserText.passwordManagementLogins) (\(UserText.openIn(value: passwordManagerCoordinator.displayName)))"
        } else {
            autofillSelector = #selector(MoreOptionsMenu.openAutofillWithLogins)
            autofillTitle = UserText.passwordManagementLogins
        }
        
        addItem(withTitle: autofillTitle, action: autofillSelector, keyEquivalent: "")
            .targetting(target)
            .withImage(NSImage(named: "LoginGlyph"))

        addItem(withTitle: UserText.passwordManagementIdentities, action: #selector(MoreOptionsMenu.openAutofillWithIdentities), keyEquivalent: "")
            .targetting(target)
            .withImage(NSImage(named: "IdentityGlyph"))

        addItem(withTitle: UserText.passwordManagementCreditCards, action: #selector(MoreOptionsMenu.openAutofillWithCreditCards), keyEquivalent: "")
            .targetting(target)
            .withImage(NSImage(named: "CreditCardGlyph"))
    }

}

extension NSMenuItem {

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
    
    @discardableResult
    func withModifierMask(_ mask: NSEvent.ModifierFlags) -> NSMenuItem {
        self.keyEquivalentModifierMask = mask
        return self
    }

}

extension MoreOptionsMenu: EmailManagerRequestDelegate { }
