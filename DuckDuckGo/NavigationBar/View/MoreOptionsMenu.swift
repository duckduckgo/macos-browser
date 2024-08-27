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
import Combine
import Common
import BrowserServicesKit
import PixelKit
import NetworkProtection
import Subscription
import os.log

protocol OptionsButtonMenuDelegate: AnyObject {

    func optionsButtonMenuRequestedBookmarkThisPage(_ sender: NSMenuItem)
    func optionsButtonMenuRequestedBookmarkAllOpenTabs(_ sender: NSMenuItem)
    func optionsButtonMenuRequestedBookmarkPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedBookmarkManagementInterface(_ menu: NSMenu)
    func optionsButtonMenuRequestedBookmarkImportInterface(_ menu: NSMenu)
    func optionsButtonMenuRequestedBookmarkExportInterface(_ menu: NSMenu)
    func optionsButtonMenuRequestedLoginsPopover(_ menu: NSMenu, selectedCategory: SecureVaultSorting.Category)
    func optionsButtonMenuRequestedOpenExternalPasswordManager(_ menu: NSMenu)
    func optionsButtonMenuRequestedNetworkProtectionPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedDownloadsPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedPrint(_ menu: NSMenu)
    func optionsButtonMenuRequestedPreferences(_ menu: NSMenu)
    func optionsButtonMenuRequestedAppearancePreferences(_ menu: NSMenu)
    func optionsButtonMenuRequestedAccessibilityPreferences(_ menu: NSMenu)
    func optionsButtonMenuRequestedDataBrokerProtection(_ menu: NSMenu)
    func optionsButtonMenuRequestedSubscriptionPurchasePage(_ menu: NSMenu)
    func optionsButtonMenuRequestedSubscriptionPreferences(_ menu: NSMenu)
    func optionsButtonMenuRequestedIdentityTheftRestoration(_ menu: NSMenu)
}

@MainActor
final class MoreOptionsMenu: NSMenu {

    weak var actionDelegate: OptionsButtonMenuDelegate?

    private let tabCollectionViewModel: TabCollectionViewModel
    private let emailManager: EmailManager
    private let passwordManagerCoordinator: PasswordManagerCoordinating
    private let internalUserDecider: InternalUserDecider
    private lazy var sharingMenu: NSMenu = SharingMenu(title: UserText.shareMenuItem)
    private var accountManager: AccountManager { subscriptionManager.accountManager }
    private let subscriptionManager: SubscriptionManager

    private let vpnFeatureGatekeeper: VPNFeatureGatekeeper
    private let subscriptionFeatureAvailability: SubscriptionFeatureAvailability

    required init(coder: NSCoder) {
        fatalError("MoreOptionsMenu: Bad initializer")
    }

    init(tabCollectionViewModel: TabCollectionViewModel,
         emailManager: EmailManager = EmailManager(),
         passwordManagerCoordinator: PasswordManagerCoordinator,
         vpnFeatureGatekeeper: VPNFeatureGatekeeper,
         subscriptionFeatureAvailability: SubscriptionFeatureAvailability = DefaultSubscriptionFeatureAvailability(),
         sharingMenu: NSMenu? = nil,
         internalUserDecider: InternalUserDecider,
         subscriptionManager: SubscriptionManager) {

        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        self.passwordManagerCoordinator = passwordManagerCoordinator
        self.vpnFeatureGatekeeper = vpnFeatureGatekeeper
        self.subscriptionFeatureAvailability = subscriptionFeatureAvailability
        self.internalUserDecider = internalUserDecider
        self.subscriptionManager = subscriptionManager

        super.init(title: "")

        if let sharingMenu {
            self.sharingMenu = sharingMenu
        }
        self.emailManager.requestDelegate = self

        setupMenuItems()
    }

    let zoomMenuItem = NSMenuItem(title: UserText.zoom, action: nil, keyEquivalent: "").withImage(.optionsButtonMenuZoom)

    private func setupMenuItems() {
        addUpdateItem()

#if FEEDBACK
        let feedbackString: String = {
            guard internalUserDecider.isInternalUser else {
                return UserText.sendFeedback
            }
            return "\(UserText.sendFeedback) (version: \(AppVersion.shared.versionNumber).\(AppVersion.shared.buildNumber))"
        }()
        let feedbackMenuItem = NSMenuItem(title: feedbackString, action: nil, keyEquivalent: "")
            .withImage(.sendFeedback)

        feedbackMenuItem.submenu = FeedbackSubMenu(targetting: self, tabCollectionViewModel: tabCollectionViewModel)
        addItem(feedbackMenuItem)

        addItem(NSMenuItem.separator())

#endif // FEEDBACK

        addWindowItems()

        zoomMenuItem.submenu = ZoomSubMenu(targetting: self, tabCollectionViewModel: tabCollectionViewModel)
        addItem(zoomMenuItem)

        addItem(NSMenuItem.separator())

        addUtilityItems()

        addItem(withTitle: UserText.emailOptionsMenuItem, action: nil, keyEquivalent: "")
            .withImage(.optionsButtonMenuEmail)
            .withSubmenu(EmailOptionsButtonSubMenu(tabCollectionViewModel: tabCollectionViewModel, emailManager: emailManager))

        addItem(NSMenuItem.separator())

        addSubscriptionItems()

        addPageItems()

        let helpItem = NSMenuItem(title: UserText.mainMenuHelp, action: nil, keyEquivalent: "").withImage(.helpMenuItemIcon)
        helpItem.submenu = HelpSubMenu(targetting: self)
        addItem(helpItem)

        let preferencesItem = NSMenuItem(title: UserText.settings, action: #selector(openPreferences(_:)), keyEquivalent: "")
            .targetting(self)
            .withImage(.preferences)
        addItem(preferencesItem)
    }

    @objc func openDataBrokerProtection(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedDataBrokerProtection(self)
    }

    @objc func showNetworkProtectionStatus(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedNetworkProtectionPopover(self)
    }

    @objc func newTab(_ sender: NSMenuItem) {
        tabCollectionViewModel.appendNewTab()
    }

    @objc func newWindow(_ sender: NSMenuItem) {
        WindowsManager.openNewWindow()
    }

    @objc func newBurnerWindow(_ sender: NSMenuItem) {
        WindowsManager.openNewWindow(burnerMode: BurnerMode(isBurner: true))
    }

    @objc func toggleFireproofing(_ sender: NSMenuItem) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            Logger.general.error("MainViewController: No tab view model selected")
            return
        }

        selectedTabViewModel.tab.requestFireproofToggle()
    }

    @objc func bookmarkPage(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkThisPage(sender)
    }

    @objc func bookmarkAllOpenTabs(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkAllOpenTabs(sender)
    }

    @objc func openBookmarks(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkPopover(self)
    }

    @objc func openBookmarksManagementInterface(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkManagementInterface(self)
    }

    @objc func openBookmarkImportInterface(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkImportInterface(self)
    }

    @objc func openBookmarkExportInterface(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkExportInterface(self)
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
        actionDelegate?.optionsButtonMenuRequestedPreferences(self)
    }

    @objc func openAppearancePreferences(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedAppearancePreferences(self)
    }

    @objc func openAccessibilityPreferences(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedAccessibilityPreferences(self)
    }

    @objc func openSubscriptionPurchasePage(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedSubscriptionPurchasePage(self)
    }

    @objc func openSubscriptionSettings(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedSubscriptionPreferences(self)
    }

    @objc func openIdentityTheftRestoration(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedIdentityTheftRestoration(self)
    }

    @objc func findInPage(_ sender: NSMenuItem) {
        tabCollectionViewModel.selectedTabViewModel?.showFindInPage()
    }

    @objc func doPrint(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedPrint(self)
    }

    private func addUpdateItem() {
#if SPARKLE
        guard NSApp.runType != .uiTests,
            let update = Application.appDelegate.updateController.latestUpdate,
            !update.isInstalled
        else {
            return
        }
        addItem(UpdateMenuItemFactory.menuItem(for: update))
        addItem(NSMenuItem.separator())
#endif
    }

    private func addWindowItems() {
        // New Tab
        addItem(withTitle: UserText.plusButtonNewTabMenuItem, action: #selector(newTab(_:)), keyEquivalent: "t")
            .targetting(self)
            .withImage(.add)

        // New Window
        addItem(withTitle: UserText.newWindowMenuItem, action: #selector(newWindow(_:)), keyEquivalent: "n")
            .targetting(self)
            .withImage(.newWindow)

        // New Burner Window
        let burnerWindowItem = NSMenuItem(title: UserText.newBurnerWindowMenuItem,
                                          action: #selector(newBurnerWindow(_:)),
                                          target: self)
        burnerWindowItem.keyEquivalent = "n"
        burnerWindowItem.keyEquivalentModifierMask = [.command, .shift]
        burnerWindowItem.image = .newBurnerWindow
        addItem(burnerWindowItem)

        addItem(NSMenuItem.separator())
    }

    private func addUtilityItems() {
        let bookmarksSubMenu = BookmarksSubMenu(targetting: self, tabCollectionViewModel: tabCollectionViewModel)

        addItem(withTitle: UserText.bookmarks, action: #selector(openBookmarks), keyEquivalent: "")
            .targetting(self)
            .withImage(.bookmarks)
            .withSubmenu(bookmarksSubMenu)
            .withAccessibilityIdentifier("MoreOptionsMenu.openBookmarks")
        addItem(withTitle: UserText.downloads, action: #selector(openDownloads), keyEquivalent: "j")
            .targetting(self)
            .withImage(.downloads)

        let loginsSubMenu = LoginsSubMenu(targetting: self,
                                          passwordManagerCoordinator: passwordManagerCoordinator)

        addItem(withTitle: UserText.passwordManagementTitle, action: #selector(openAutofillWithAllItems), keyEquivalent: "")
            .targetting(self)
            .withImage(.passwordManagement)
            .withSubmenu(loginsSubMenu)
            .withAccessibilityIdentifier("MoreOptionsMenu.autofill")

        addItem(NSMenuItem.separator())
    }

    private func addSubscriptionItems() {
        guard subscriptionFeatureAvailability.isFeatureAvailable else { return }

        func shouldHideDueToNoProduct() -> Bool {
            let platform = subscriptionManager.currentEnvironment.purchasePlatform
            return platform == .appStore && subscriptionManager.canPurchase == false
        }

        let privacyProItem = NSMenuItem(title: UserText.subscriptionOptionsMenuItem).withImage(.subscriptionIcon)

        if !accountManager.isUserAuthenticated {
            privacyProItem.target = self
            privacyProItem.action = #selector(openSubscriptionPurchasePage(_:))

            // Do not add for App Store when purchase not available in the region
            if !shouldHideDueToNoProduct() {
                addItem(privacyProItem)
                addItem(NSMenuItem.separator())
            }
        } else {
            privacyProItem.submenu = SubscriptionSubMenu(targeting: self,
                                                         subscriptionFeatureAvailability: DefaultSubscriptionFeatureAvailability(),
                                                         accountManager: accountManager)
            addItem(privacyProItem)
            addItem(NSMenuItem.separator())
        }
    }

    private func addPageItems() {
        guard let tabViewModel = tabCollectionViewModel.selectedTabViewModel,
              let url = tabViewModel.tab.content.userEditableUrl else { return }
        let oldItemsCount = items.count

        if url.canFireproof, let host = url.host {
            let isFireproof = FireproofDomains.shared.isFireproof(fireproofDomain: host)
            let title = isFireproof ? UserText.removeFireproofing : UserText.fireproofSite
            let image: NSImage = isFireproof ? .burn : .fireproof

            addItem(withTitle: title, action: #selector(toggleFireproofing(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(image)
        }

        if tabViewModel.canFindInPage {
            addItem(withTitle: UserText.findInPageMenuItem, action: #selector(findInPage(_:)), keyEquivalent: "f")
                .targetting(self)
                .withImage(.findSearch)
                .withAccessibilityIdentifier("MoreOptionsMenu.findInPage")
        }

        if tabViewModel.canReload {
            addItem(withTitle: UserText.shareMenuItem, action: nil, keyEquivalent: "")
                .targetting(self)
                .withImage(.share)
                .withSubmenu(sharingMenu)
        }

        if tabViewModel.canPrint {
            addItem(withTitle: UserText.printMenuItem, action: #selector(doPrint(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(.print)
        }

        if items.count > oldItemsCount {
            addItem(NSMenuItem.separator())
        }
    }

    private func makeNetworkProtectionItem() -> NSMenuItem {
        let networkProtectionItem = NSMenuItem(title: "", action: #selector(showNetworkProtectionStatus(_:)), keyEquivalent: "")
            .targetting(self)
            .withImage(.image(for: .vpnIcon))

        networkProtectionItem.title = UserText.networkProtection

        return networkProtectionItem
    }

}

@MainActor
final class EmailOptionsButtonSubMenu: NSMenu {

    private let tabCollectionViewModel: TabCollectionViewModel
    private let emailManager: EmailManager
    private var emailProtectionDidChangeCancellable: AnyCancellable?

    init(tabCollectionViewModel: TabCollectionViewModel, emailManager: EmailManager) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        super.init(title: UserText.emailOptionsMenuItem)

        updateMenuItems()

        emailProtectionDidChangeCancellable = Publishers
            .Merge(
                NotificationCenter.default.publisher(for: .emailDidSignIn),
                NotificationCenter.default.publisher(for: .emailDidSignOut)
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuItems()
            }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems() {
        removeAllItems()
        if emailManager.isSignedIn {
            addItem(withTitle: UserText.emailOptionsMenuCreateAddressSubItem, action: #selector(createAddressAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(.optionsButtonMenuEmailGenerateAddress)

            addItem(withTitle: UserText.emailOptionsMenuManageAccountSubItem, action: #selector(manageAccountAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(.identity16)

            addItem(.separator())

            addItem(withTitle: UserText.emailOptionsMenuTurnOffSubItem, action: #selector(turnOffEmailAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(.emailDisabled16)

        } else {
            addItem(withTitle: UserText.emailOptionsMenuTurnOnSubItem, action: #selector(turnOnEmailAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(.optionsButtonMenuEmail)

        }
    }

    @objc func manageAccountAction(_ sender: NSMenuItem) {
        let tab = Tab(content: .url(EmailUrls().emailProtectionAccountLink, source: .ui), shouldLoadInBackground: true, burnerMode: tabCollectionViewModel.burnerMode)
        tabCollectionViewModel.append(tab: tab)
    }

    @objc func createAddressAction(_ sender: NSMenuItem) {
        assert(emailManager.requestDelegate != nil, "No requestDelegate on emailManager")

        emailManager.getAliasIfNeededAndConsume { [weak self] alias, error in
            guard let self = self, let alias = alias else {
                assertionFailure(error?.localizedDescription ?? "Unexpected email error")
                return
            }

            let address = self.emailManager.emailAddressFor(alias)
            let pixelParameters = self.emailManager.emailPixelParameters
            self.emailManager.updateLastUseDate()

            PixelKit.fire(NonStandardEvent(NonStandardPixel.emailUserCreatedAlias), withAdditionalParameters: pixelParameters)

            NSPasteboard.general.copy(address)
            NotificationCenter.default.post(name: NSNotification.Name.privateEmailCopiedToClipboard, object: nil)
        }
    }

    @objc func turnOffEmailAction(_ sender: NSMenuItem) {
        let alert = NSAlert.disableEmailProtection()
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            try? emailManager.signOut()
        }
    }

    @objc func turnOnEmailAction(_ sender: NSMenuItem) {
        let tab = Tab(content: .url(EmailUrls().emailProtectionLink, source: .ui), shouldLoadInBackground: true, burnerMode: tabCollectionViewModel.burnerMode)
        tabCollectionViewModel.append(tab: tab)
    }
}

@MainActor
final class FeedbackSubMenu: NSMenu {

    init(targetting target: AnyObject, tabCollectionViewModel: TabCollectionViewModel) {
        super.init(title: UserText.sendFeedback)
        updateMenuItems(with: tabCollectionViewModel, targetting: target)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(with tabCollectionViewModel: TabCollectionViewModel, targetting target: AnyObject) {
        removeAllItems()

        let browserFeedbackItem = NSMenuItem(title: UserText.browserFeedback,
                                             action: #selector(AppDelegate.openFeedback(_:)),
                                             keyEquivalent: "")
            .withImage(.browserFeedback)
        addItem(browserFeedbackItem)

        let reportBrokenSiteItem = NSMenuItem(title: UserText.reportBrokenSite,
                                              action: #selector(AppDelegate.openReportBrokenSite(_:)),
                                              keyEquivalent: "")
            .withImage(.siteBreakage)
        addItem(reportBrokenSiteItem)
    }
}

@MainActor
final class ZoomSubMenu: NSMenu {

    init(targetting target: AnyObject, tabCollectionViewModel: TabCollectionViewModel) {
        super.init(title: UserText.zoom)

        updateMenuItems(with: tabCollectionViewModel, targetting: target)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(with tabCollectionViewModel: TabCollectionViewModel, targetting target: AnyObject) {
        removeAllItems()

        let fullScreenItem = (NSApp.mainMenuTyped.toggleFullscreenMenuItem.copy() as? NSMenuItem)!
        addItem(fullScreenItem)

        addItem(.separator())

        let zoomInItem = (NSApp.mainMenuTyped.zoomInMenuItem.copy() as? NSMenuItem)!
        addItem(zoomInItem)

        let zoomOutItem = (NSApp.mainMenuTyped.zoomOutMenuItem.copy() as? NSMenuItem)!
        addItem(zoomOutItem)

        let actualSizeItem = (NSApp.mainMenuTyped.actualSizeMenuItem.copy() as? NSMenuItem)!
        addItem(actualSizeItem)

        addItem(.separator())

        let globalZoomSettingItem = NSMenuItem(title: UserText.defaultZoomPageMoreOptionsItem, action: #selector(MoreOptionsMenu.openAccessibilityPreferences(_:)), keyEquivalent: "")
            .targetting(target)
        addItem(globalZoomSettingItem)
    }
}

@MainActor
final class BookmarksSubMenu: NSMenu {

    init(targetting target: AnyObject, tabCollectionViewModel: TabCollectionViewModel) {
        super.init(title: UserText.passwordManagementTitle)
        self.autoenablesItems = false
        addMenuItems(with: tabCollectionViewModel, target: target)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addMenuItems(with tabCollectionViewModel: TabCollectionViewModel, target: AnyObject) {
        let bookmarkPageItem = addItem(withTitle: UserText.bookmarkThisPage, action: #selector(MoreOptionsMenu.bookmarkPage(_:)), keyEquivalent: "d")
            .withModifierMask([.command])
            .targetting(target)
            .withAccessibilityIdentifier("MoreOptionsMenu.bookmarkPage")

        bookmarkPageItem.isEnabled = tabCollectionViewModel.selectedTabViewModel?.canBeBookmarked == true

        let bookmarkAllTabsItem = addItem(withTitle: UserText.bookmarkAllTabs, action: #selector(MoreOptionsMenu.bookmarkAllOpenTabs(_:)), keyEquivalent: "d")
            .withModifierMask([.command, .shift])
            .targetting(target)

        bookmarkAllTabsItem.isEnabled = tabCollectionViewModel.canBookmarkAllOpenTabs()

        addItem(NSMenuItem.separator())

        addItem(withTitle: UserText.bookmarksShowToolbarPanel, action: #selector(MoreOptionsMenu.openBookmarks(_:)), keyEquivalent: "")
            .targetting(target)

        BookmarksBarMenuFactory.addToMenu(self)

        addItem(NSMenuItem.separator())

        if let favorites = LocalBookmarkManager.shared.list?.favoriteBookmarks {
            let favoriteViewModels = favorites.compactMap(BookmarkViewModel.init(entity:))
            let potentialItems = bookmarkMenuItems(from: favoriteViewModels)

            let favoriteMenuItems = potentialItems.isEmpty ? [NSMenuItem.empty] : potentialItems

            let favoritesItem = addItem(withTitle: UserText.favorites, action: nil, keyEquivalent: "")
            favoritesItem.submenu = NSMenu(items: favoriteMenuItems)
            favoritesItem.image = .favorite

            addItem(NSMenuItem.separator())
        }

        let bookmarkManager = LocalBookmarkManager.shared
        guard let entities = bookmarkManager.list?.topLevelEntities else {
            return
        }

        let bookmarkViewModels = entities.compactMap(BookmarkViewModel.init(entity:))
        let menuItems = bookmarkMenuItems(from: bookmarkViewModels, topLevel: true)

        self.items.append(contentsOf: menuItems)

        addItem(NSMenuItem.separator())

        addItem(withTitle: UserText.importBookmarks, action: #selector(MoreOptionsMenu.openBookmarkImportInterface(_:)), keyEquivalent: "")
            .targetting(target)

        let exportBookmarItem = NSMenuItem(title: UserText.exportBookmarks, action: #selector(MoreOptionsMenu.openBookmarkExportInterface(_:)), keyEquivalent: "").targetting(target)
        exportBookmarItem.isEnabled = bookmarkManager.list?.totalBookmarks != 0
        addItem(exportBookmarItem)

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
        super.init(title: UserText.passwordManagementTitle)
        updateMenuItems(with: target)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(with target: AnyObject) {
        addItem(withTitle: UserText.passwordManagementAllItems, action: #selector(MoreOptionsMenu.openAutofillWithAllItems), keyEquivalent: "")
            .targetting(target)
            .withAccessibilityIdentifier("LoginsSubMenu.allItems")

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
            .withImage(.loginGlyph)

        addItem(withTitle: UserText.passwordManagementIdentities, action: #selector(MoreOptionsMenu.openAutofillWithIdentities), keyEquivalent: "")
            .targetting(target)
            .withImage(.identityGlyph)

        addItem(withTitle: UserText.passwordManagementCreditCards, action: #selector(MoreOptionsMenu.openAutofillWithCreditCards), keyEquivalent: "")
            .targetting(target)
            .withImage(.creditCardGlyph)
    }

}

@MainActor
final class HelpSubMenu: NSMenu {

    init(targetting target: AnyObject) {
        super.init(title: UserText.mainMenuHelp)

        updateMenuItems(targetting: target)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(targetting target: AnyObject) {
        removeAllItems()

        let about = (NSApp.mainMenuTyped.aboutMenuItem.copy() as? NSMenuItem)!
        addItem(about)
#if SPARKLE
        let releaseNotes = (NSApp.mainMenuTyped.releaseNotesMenuItem.copy() as? NSMenuItem)!
        addItem(releaseNotes)

        let whatIsNew = (NSApp.mainMenuTyped.whatIsNewMenuItem.copy() as? NSMenuItem)!
        addItem(whatIsNew)
#endif

#if FEEDBACK
        let feedback = (NSApp.mainMenuTyped.sendFeedbackMenuItem.copy() as? NSMenuItem)!
        addItem(feedback)
#endif
    }
}

@MainActor
final class SubscriptionSubMenu: NSMenu, NSMenuDelegate {

    var subscriptionFeatureAvailability: SubscriptionFeatureAvailability
    var accountManager: AccountManager

    var networkProtectionItem: NSMenuItem!
    var dataBrokerProtectionItem: NSMenuItem!
    var identityTheftRestorationItem: NSMenuItem!
    var subscriptionSettingsItem: NSMenuItem!

    init(targeting target: AnyObject,
         subscriptionFeatureAvailability: SubscriptionFeatureAvailability,
         accountManager: AccountManager) {

        self.subscriptionFeatureAvailability = subscriptionFeatureAvailability
        self.accountManager = accountManager

        super.init(title: "")

        self.networkProtectionItem = makeNetworkProtectionItem(target: target)
        self.dataBrokerProtectionItem = makeDataBrokerProtectionItem(target: target)
        self.identityTheftRestorationItem = makeIdentityTheftRestorationItem(target: target)
        self.subscriptionSettingsItem = makeSubscriptionSettingsItem(target: target)

        delegate = self

        addMenuItems()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addMenuItems() {
        addItem(networkProtectionItem)
        addItem(dataBrokerProtectionItem)
        addItem(identityTheftRestorationItem)
        addItem(NSMenuItem.separator())
        addItem(subscriptionSettingsItem)
    }

    private func makeNetworkProtectionItem(target: AnyObject) -> NSMenuItem {
        return NSMenuItem(title: UserText.networkProtection,
                   action: #selector(MoreOptionsMenu.showNetworkProtectionStatus(_:)),
                   keyEquivalent: "")
        .targetting(target)
        .withImage(.image(for: .vpnIcon))
    }

    private func makeDataBrokerProtectionItem(target: AnyObject) -> NSMenuItem {
        return NSMenuItem(title: UserText.dataBrokerProtectionOptionsMenuItem,
                   action: #selector(MoreOptionsMenu.openDataBrokerProtection),
                   keyEquivalent: "")
        .targetting(target)
        .withImage(.dbpIcon)
    }

    private func makeIdentityTheftRestorationItem(target: AnyObject) -> NSMenuItem {
        return NSMenuItem(title: UserText.identityTheftRestorationOptionsMenuItem,
                   action: #selector(MoreOptionsMenu.openIdentityTheftRestoration),
                   keyEquivalent: "")
        .targetting(target)
        .withImage(.itrIcon)
    }

    private func makeSubscriptionSettingsItem(target: AnyObject) -> NSMenuItem {
        return NSMenuItem(title: UserText.subscriptionSettingsOptionsMenuItem,
                   action: #selector(MoreOptionsMenu.openSubscriptionSettings),
                   keyEquivalent: "")
        .targetting(target)
    }

    private func refreshAvailabilityBasedOnEntitlements() {
        guard subscriptionFeatureAvailability.isFeatureAvailable, accountManager.isUserAuthenticated else { return }

        @Sendable func hasEntitlement(for productName: Entitlement.ProductName) async -> Bool {
            switch await self.accountManager.hasEntitlement(forProductName: productName) {
            case let .success(result):
                return result
            case .failure:
                return false
            }
        }

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }

            let isNetworkProtectionItemEnabled = await hasEntitlement(for: .networkProtection)
            let isDataBrokerProtectionItemEnabled = await hasEntitlement(for: .dataBrokerProtection)
            let isIdentityTheftRestorationItemEnabled = await hasEntitlement(for: .identityTheftRestoration)

            Task { @MainActor in
                self.networkProtectionItem.isEnabled = isNetworkProtectionItemEnabled
                self.dataBrokerProtectionItem.isEnabled = isDataBrokerProtectionItemEnabled
                self.identityTheftRestorationItem.isEnabled = isIdentityTheftRestorationItemEnabled
            }
        }
    }

    public func menuWillOpen(_ menu: NSMenu) {
        refreshAvailabilityBasedOnEntitlements()
    }

}

extension MoreOptionsMenu: EmailManagerRequestDelegate {}
