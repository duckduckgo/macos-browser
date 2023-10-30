//
//  MainMenu.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit
import Cocoa
import Common
import Combine
import OSLog // swiftlint:disable:this enforce_os_log_wrapper
import SwiftUI
import WebKit
import Configuration

#if NETWORK_PROTECTION
import NetworkProtection
#endif

#if SUBSCRIPTION
import Subscription
#endif

// swiftlint:disable:next type_body_length
@MainActor final class MainMenu: NSMenu {

    enum Constants {
        static let maxTitleLength = 55
    }

    // MARK: - DuckDuckGo
    let servicesMenu = NSMenu(title: UserText.mainMenuAppServices)
    let preferencesMenuItem = NSMenuItem(title: UserText.mainMenuAppPreferences, action: #selector(AppDelegate.openPreferences), keyEquivalent: ",")

    // MARK: - File
    let newWindowMenuItem = NSMenuItem(title: UserText.newWindowMenuItem, action: #selector(AppDelegate.newWindow), keyEquivalent: "n")
    let newTabMenuItem = NSMenuItem(title: UserText.mainMenuFileNewTab, action: #selector(AppDelegate.newTab), keyEquivalent: "t")
    let openLocationMenuItem = NSMenuItem(title: UserText.mainMenuFileOpenLocation, action: #selector(AppDelegate.openLocation), keyEquivalent: "l")
    let closeWindowMenuItem = NSMenuItem(title: UserText.mainMenuFileCloseWindow, action: #selector(NSWindow.performClose), keyEquivalent: "W")
    let closeAllWindowsMenuItem = NSMenuItem(title: UserText.mainMenuFileCloseAllWindows, action: #selector(AppDelegate.closeAllWindows), keyEquivalent: [.option, .command, "W"])
    let closeTabMenuItem = NSMenuItem(title: UserText.closeTab, action: #selector(MainViewController.closeTab), keyEquivalent: "w")
    let importBrowserDataMenuItem = NSMenuItem(title: UserText.mainMenuFileImportBookmarksandPasswords, action: #selector(AppDelegate.openImportBrowserDataWindow))

    let sharingMenu = SharingMenu(title: UserText.shareMenuItem)

    // MARK: - View
    let stopMenuItem = NSMenuItem(title: UserText.mainMenuViewStop, action: #selector(MainViewController.stopLoadingPage), keyEquivalent: ".")
    let reloadMenuItem = NSMenuItem(title: UserText.mainMenuViewReloadPage, action: #selector(MainViewController.reloadPage), keyEquivalent: "r")

    let toggleFullscreenMenuItem = NSMenuItem(title: UserText.mainMenuViewEnterFullScreen, action: #selector(NSWindow.toggleFullScreen), keyEquivalent: [.control, .command, "f"])
    let actualSizeMenuItem = NSMenuItem(title: UserText.mainMenuViewActualSize, action: #selector(MainViewController.actualSize), keyEquivalent: "0")
    let zoomInMenuItem = NSMenuItem(title: UserText.mainMenuViewZoomIn, action: #selector(MainViewController.zoomIn), keyEquivalent: "+")
    let zoomOutMenuItem = NSMenuItem(title: UserText.mainMenuViewZoomOut, action: #selector(MainViewController.zoomOut), keyEquivalent: "-")

    // MARK: - History
    let historyMenu = HistoryMenu()

    var backMenuItem: NSMenuItem { historyMenu.backMenuItem }
    var forwardMenuItem: NSMenuItem { historyMenu.forwardMenuItem }

    // MARK: - Bookmarks
    let manageBookmarksMenuItem = NSMenuItem(title: UserText.mainMenuHistoryManageBookmarks, action: #selector(MainViewController.showManageBookmarks))
    var bookmarksMenuToggleBookmarksBarMenuItem = NSMenuItem(title: "BookmarksBarMenuPlaceholder", action: #selector(MainViewController.toggleBookmarksBarFromMenu), keyEquivalent: "B")
    let importBookmarksMenuItem = NSMenuItem(title: UserText.importBookmarks, action: #selector(AppDelegate.openImportBrowserDataWindow))
    let bookmarksMenu = NSMenu(title: UserText.bookmarks)
    let favoritesMenu = NSMenu(title: UserText.favorites)

    private var toggleBookmarksBarMenuItem = NSMenuItem(title: "BookmarksBarMenuPlaceholder", action: #selector(MainViewController.toggleBookmarksBarFromMenu), keyEquivalent: "B")
    let toggleHomeButtonMenuItem = NSMenuItem(title: UserText.mainMenuViewShowHomeShortcut, action: #selector(MainViewController.toggleHomeButton), keyEquivalent: "Y")
    let toggleAutofillShortcutMenuItem = NSMenuItem(title: UserText.mainMenuViewShowAutofillShortcut, action: #selector(MainViewController.toggleAutofillShortcut), keyEquivalent: "A")
    let toggleBookmarksShortcutMenuItem = NSMenuItem(title: UserText.mainMenuViewShowBookmarksShortcut, action: #selector(MainViewController.toggleBookmarksShortcut), keyEquivalent: "K")
    let toggleDownloadsShortcutMenuItem = NSMenuItem(title: UserText.mainMenuViewShowDownloadsShortcut, action: #selector(MainViewController.toggleDownloadsShortcut), keyEquivalent: "J")

#if NETWORK_PROTECTION
    let toggleNetworkProtectionShortcutMenuItem = NSMenuItem(title: UserText.showNetworkProtectionShortcut, action: #selector(MainViewController.toggleNetworkProtectionShortcut), keyEquivalent: "N")
#endif

    // MARK: - Window
    let windowsMenu = NSMenu(title: UserText.mainMenuWindow)

    // MARK: - Debug

    private var loggingMenu: NSMenu?
    let customConfigurationUrlMenuItem = NSMenuItem(title: "Last Update Time", action: #selector(MainViewController.reloadConfigurationNow))
    let configurationDateAndTimeMenuItem = NSMenuItem(title: "Configuration URL", action: #selector(MainViewController.reloadConfigurationNow))

    // MARK: - Help

    let helpMenu = NSMenu(title: UserText.mainMenuHelp) {
        NSMenuItem(title: UserText.mainMenuHelpDuckDuckGoHelp, action: #selector(NSApplication.showHelp), keyEquivalent: "?")
            .hidden()

#if FEEDBACK
        NSMenuItem.separator()
        NSMenuItem(title: UserText.sendFeedback, action: #selector(AppDelegate.openFeedback))
#endif
    }

    // swiftlint:disable:next function_body_length
    init(featureFlagger: FeatureFlagger, bookmarkManager: BookmarkManager, faviconManager: FaviconManagement, copyHandler: CopyHandler) {

        super.init(title: UserText.duckDuckGo)

        buildItems {
            // MARK: DuckDuckGo
            NSMenuItem(title: UserText.duckDuckGo) {
                NSMenuItem(title: UserText.aboutDuckDuckGo, action: #selector(AppDelegate.openAbout))
                NSMenuItem.separator()

                preferencesMenuItem

                NSMenuItem.separator()

                NSMenuItem(title: UserText.mainMenuAppServices)
                    .submenu(servicesMenu)
                NSMenuItem.separator()

#if SPARKLE
                NSMenuItem(title: UserText.mainMenuAppCheckforUpdates, action: #selector(AppDelegate.checkForUpdates))
                NSMenuItem.separator()
#endif

                NSMenuItem(title: UserText.mainMenuAppHideDuckDuckGo, action: #selector(NSApplication.hide), keyEquivalent: "h")
                NSMenuItem(title: UserText.mainMenuAppHideOthers, action: #selector(NSApplication.hideOtherApplications), keyEquivalent: [.option, .command, "h"])
                NSMenuItem(title: UserText.mainMenuAppShowAll, action: #selector(NSApplication.unhideAllApplications))
                NSMenuItem.separator()

                NSMenuItem(title: UserText.mainMenuAppQuitDuckDuckGo, action: #selector(NSApplication.terminate), keyEquivalent: "q")
            }

            // MARK: File
            NSMenuItem(title: UserText.mainMenuFile) {
                newWindowMenuItem
                NSMenuItem(title: UserText.newBurnerWindowMenuItem, action: #selector(AppDelegate.newBurnerWindow), keyEquivalent: "N")
                newTabMenuItem
                openLocationMenuItem
                NSMenuItem.separator()

                closeWindowMenuItem
                closeAllWindowsMenuItem
                closeTabMenuItem
                NSMenuItem(title: UserText.mainMenuFileSaveAs, action: #selector(MainViewController.saveAs), keyEquivalent: "s")
                NSMenuItem.separator()

                importBrowserDataMenuItem
                NSMenuItem(title: UserText.mainMenuFileExport) {
                    NSMenuItem(title: UserText.mainMenuFileExportPasswords, action: #selector(AppDelegate.openExportLogins))
                    NSMenuItem(title: UserText.mainMenuFileExportBookmarks, action: #selector(AppDelegate.openExportBookmarks))
                }
                NSMenuItem.separator()

                NSMenuItem(title: UserText.shareMenuItem)
                    .submenu(sharingMenu)
                NSMenuItem.separator()

                NSMenuItem(title: UserText.printMenuItem, action: #selector(MainViewController.printWebView), keyEquivalent: "p")
            }

            // MARK: Edit
            NSMenuItem(title: UserText.mainMenuEdit) {
                NSMenuItem(title: UserText.mainMenuEditUndo, action: Selector(("undo:")), keyEquivalent: "z")
                NSMenuItem(title: UserText.mainMenuEditRedo, action: Selector(("redo:")), keyEquivalent: "Z")
                NSMenuItem.separator()

                NSMenuItem(title: UserText.mainMenuEditCut, action: #selector(NSText.cut), keyEquivalent: "x")
                NSMenuItem(title: UserText.mainMenuEditCopy, action: #selector(CopyHandler.copy(_:)), target: copyHandler, keyEquivalent: "c")
                NSMenuItem(title: UserText.mainMenuEditPaste, action: #selector(NSText.paste), keyEquivalent: "v")
                NSMenuItem(title: UserText.mainMenuEditPasteAndMatchStyle, action: #selector(NSTextView.pasteAsPlainText), keyEquivalent: [.option, .command, .shift, "v"])
                NSMenuItem(title: UserText.mainMenuEditPasteAndMatchStyle, action: #selector(NSTextView.pasteAsPlainText), keyEquivalent: [.command, .shift, "v"])
                    .alternate()

                NSMenuItem(title: UserText.mainMenuEditDelete, action: #selector(NSText.delete))
                NSMenuItem(title: UserText.mainMenuEditSelectAll, action: #selector(NSText.selectAll), keyEquivalent: "a")
                NSMenuItem.separator()

                NSMenuItem(title: UserText.mainMenuEditFind) {
                    NSMenuItem(title: UserText.findInPageMenuItem, action: #selector(MainViewController.findInPage), keyEquivalent: "f")
                    NSMenuItem(title: UserText.mainMenuEditFindFindNext, action: #selector(MainViewController.findInPageNext), keyEquivalent: "g")
                    NSMenuItem(title: UserText.mainMenuEditFindFindPrevious, action: #selector(MainViewController.findInPagePrevious), keyEquivalent: "G")
                    NSMenuItem.separator()

                    NSMenuItem(title: UserText.mainMenuEditFindHideFind, action: #selector(MainViewController.findInPageDone), keyEquivalent: "F")
                }

                NSMenuItem(title: UserText.mainMenuEditSpellingandGrammar) {
                    NSMenuItem(title: UserText.mainMenuEditSpellingandShowSpellingandGrammar, action: #selector(NSText.showGuessPanel), keyEquivalent: ":")
                    NSMenuItem(title: UserText.mainMenuEditSpellingandCheckDocumentNow, action: #selector(NSText.checkSpelling), keyEquivalent: ";")
                    NSMenuItem.separator()

                    NSMenuItem(title: UserText.mainMenuEditSpellingandCheckSpellingWhileTyping, action: #selector(NSTextView.toggleContinuousSpellChecking))
                    NSMenuItem(title: UserText.mainMenuEditSpellingandCheckGrammarWithSpelling, action: #selector(NSTextView.toggleGrammarChecking))
                    NSMenuItem(title: UserText.mainMenuEditSpellingandCorrectSpellingAutomatically, action: #selector(NSTextView.toggleAutomaticSpellingCorrection))
                        .hidden()
                }

                NSMenuItem(title: UserText.mainMenuEditSubstitutions) {
                    NSMenuItem(title: UserText.mainMenuEditSubstitutionsShowSubstitutions, action: #selector(NSTextView.orderFrontSubstitutionsPanel))
                    NSMenuItem.separator()

                    NSMenuItem(title: UserText.mainMenuEditSubstitutionsSmartCopyPaste, action: #selector(NSTextView.toggleSmartInsertDelete))
                    NSMenuItem(title: UserText.mainMenuEditSubstitutionsSmartQuotes, action: #selector(NSTextView.toggleAutomaticQuoteSubstitution))
                    NSMenuItem(title: UserText.mainMenuEditSubstitutionsSmartDashes, action: #selector(NSTextView.toggleAutomaticDashSubstitution))
                    NSMenuItem(title: UserText.mainMenuEditSubstitutionsSmartLinks, action: #selector(NSTextView.toggleAutomaticLinkDetection))
                    NSMenuItem(title: UserText.mainMenuEditSubstitutionsDataDetectors, action: #selector(NSTextView.toggleAutomaticDataDetection))
                    NSMenuItem(title: UserText.mainMenuEditSubstitutionsTextReplacement, action: #selector(NSTextView.toggleAutomaticTextReplacement))
                }

                NSMenuItem(title: UserText.mainMenuEditTransformations) {
                    NSMenuItem(title: UserText.mainMenuEditTransformationsMakeUpperCase, action: #selector(NSResponder.uppercaseWord))
                    NSMenuItem(title: UserText.mainMenuEditTransformationsMakeLowerCase, action: #selector(NSResponder.lowercaseWord))
                    NSMenuItem(title: UserText.mainMenuEditTransformationsCapitalize, action: #selector(NSResponder.capitalizeWord))
                }

                NSMenuItem(title: UserText.mainMenuEditSpeech) {
                    NSMenuItem(title: UserText.mainMenuEditSpeechStartSpeaking, action: #selector(NSTextView.startSpeaking))
                    NSMenuItem(title: UserText.mainMenuEditSpeechStopSpeaking, action: #selector(NSTextView.stopSpeaking))
                }
            }

            // MARK: View
            NSMenuItem(title: UserText.mainMenuView) {
                stopMenuItem
                reloadMenuItem
                NSMenuItem.separator()

                NSMenuItem(title: UserText.mainMenuViewHome, action: #selector(MainViewController.home), keyEquivalent: "H")
                NSMenuItem.separator()

                toggleBookmarksBarMenuItem

                NSMenuItem(title: UserText.openDownloads, action: #selector(MainViewController.toggleDownloads), keyEquivalent: "j")
                NSMenuItem.separator()

                toggleHomeButtonMenuItem
                toggleAutofillShortcutMenuItem
                toggleBookmarksShortcutMenuItem
                toggleDownloadsShortcutMenuItem

#if NETWORK_PROTECTION
                toggleNetworkProtectionShortcutMenuItem
#endif

                NSMenuItem.separator()

                toggleFullscreenMenuItem
                NSMenuItem.separator()

                actualSizeMenuItem
                zoomInMenuItem
                zoomOutMenuItem
                NSMenuItem.separator()

                NSMenuItem(title: UserText.mainMenuDeveloper) {
                    NSMenuItem(title: UserText.openDeveloperTools, action: #selector(MainViewController.toggleDeveloperTools), keyEquivalent: [.option, .command, "i"])
                    NSMenuItem(title: UserText.mainMenuViewDeveloperJavaScriptConsole, action: #selector(MainViewController.openJavaScriptConsole), keyEquivalent: [.option, .command, "c"])
                    NSMenuItem(title: UserText.mainMenuViewDeveloperShowPageSource, action: #selector(MainViewController.showPageSource), keyEquivalent: [.option, .command, "u"])
                    NSMenuItem(title: UserText.mainMenuViewDeveloperShowResources, action: #selector(MainViewController.showPageResources), keyEquivalent: [.option, .command, "a"])
                }
            }

            // MARK: History
            NSMenuItem(title: UserText.mainMenuHistory)
                .submenu(historyMenu)

            // MARK: Bookmarks
            NSMenuItem(title: UserText.bookmarks).submenu(bookmarksMenu.buildItems {
                NSMenuItem(title: UserText.bookmarkThisPage, action: #selector(MainViewController.bookmarkThisPage), keyEquivalent: "d")
                manageBookmarksMenuItem
                bookmarksMenuToggleBookmarksBarMenuItem
                NSMenuItem.separator()

                importBookmarksMenuItem
                NSMenuItem(title: UserText.exportBookmarks, action: #selector(AppDelegate.openExportBookmarks))
                NSMenuItem.separator()

                NSMenuItem(title: UserText.favorites)
                    .submenu(favoritesMenu.buildItems {
                        NSMenuItem(title: UserText.mainMenuHistoryFavoriteThisPage, action: #selector(MainViewController.favoriteThisPage))
                            .withImage(NSImage(named: "Favorite"))
                        NSMenuItem.separator()
                    })
                    .withImage(NSImage(named: "Favorite"))

                NSMenuItem.separator()
            })

            // MARK: Window
            NSMenuItem(title: UserText.mainMenuWindow)
                .submenu(windowsMenu.buildItems {
                    NSMenuItem(title: UserText.mainMenuWindowMinimize, action: #selector(NSWindow.performMiniaturize), keyEquivalent: "m")
                    NSMenuItem(title: UserText.zoom, action: #selector(NSWindow.performZoom))
                    NSMenuItem.separator()

                    NSMenuItem(title: UserText.pinTab, action: #selector(MainViewController.pinOrUnpinTab))
                    NSMenuItem(title: UserText.moveTabToNewWindow, action: #selector(MainViewController.moveTabToNewWindow))
                    NSMenuItem(title: UserText.mainMenuWindowMergeAllWindows, action: #selector(NSWindow.mergeAllWindows))
                    NSMenuItem.separator()

                    NSMenuItem(title: UserText.mainMenuWindowShowPreviousTab, action: #selector(MainViewController.showPreviousTab), keyEquivalent: [.control, .shift, .tab])
                    NSMenuItem(title: "Show Previous Tab (Hidden)", action: #selector(MainViewController.showPreviousTab), keyEquivalent: [.command, .shift, "["])
                        .hidden()
                    NSMenuItem(title: "Show Previous Tab (Hidden)", action: #selector(MainViewController.showPreviousTab), keyEquivalent: [.option, .command, .left])
                        .hidden()

                    NSMenuItem(title: UserText.mainMenuWindowShowNextTab, action: #selector(MainViewController.showNextTab), keyEquivalent: [.control, .tab])
                    NSMenuItem(title: "Show Next Tab (Hidden)", action: #selector(MainViewController.showNextTab), keyEquivalent: [.command, .shift, "]"])
                        .hidden()
                    NSMenuItem(title: "Show Next Tab (Hidden)", action: #selector(MainViewController.showNextTab), keyEquivalent: [.option, .command, .right])
                        .hidden()

                    NSMenuItem(title: "Show First Tab (Hidden)", action: #selector(MainViewController.showTab), keyEquivalent: "1")
                        .hidden()
                    NSMenuItem(title: "Show Second Tab (Hidden)", action: #selector(MainViewController.showTab), keyEquivalent: "2")
                        .hidden()
                    NSMenuItem(title: "Show Third Tab (Hidden)", action: #selector(MainViewController.showTab), keyEquivalent: "3")
                        .hidden()
                    NSMenuItem(title: "Show Fourth Tab (Hidden)", action: #selector(MainViewController.showTab), keyEquivalent: "4")
                        .hidden()
                    NSMenuItem(title: "Show Fifth Tab (Hidden)", action: #selector(MainViewController.showTab), keyEquivalent: "5")
                        .hidden()
                    NSMenuItem(title: "Show Sixth Tab (Hidden)", action: #selector(MainViewController.showTab), keyEquivalent: "6")
                        .hidden()
                    NSMenuItem(title: "Show Seventh Tab (Hidden)", action: #selector(MainViewController.showTab), keyEquivalent: "7")
                        .hidden()
                    NSMenuItem(title: "Show Eighth Tab (Hidden)", action: #selector(MainViewController.showTab), keyEquivalent: "8")
                        .hidden()
                    NSMenuItem(title: "Show Ninth Tab (Hidden)", action: #selector(MainViewController.showTab), keyEquivalent: "9")
                        .hidden()
                    NSMenuItem.separator()

                    NSMenuItem(title: UserText.mainMenuWindowBringAllToFront, action: #selector(NSApplication.arrangeInFront))
                })

            // MARK: Debug
#if DEBUG || REVIEW
            NSMenuItem(title: "Debug")
                .submenu(setupDebugMenu())
#else
            if featureFlagger.isFeatureOn(.debugMenu) {
                NSMenuItem(title: "Debug")
                    .submenu(setupDebugMenu())
            }
#endif

            // MARK: Help
            NSMenuItem(title: UserText.mainMenuHelp)
                .submenu(helpMenu)
        }

        subscribeToBookmarkList(bookmarkManager: bookmarkManager)
        subscribeToFavicons(faviconManager: faviconManager)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    @MainActor
    override func update() {
        super.update()

#if NETWORK_PROTECTION
        // To be safe, hide the NetP shortcut menu item by default.
        toggleNetworkProtectionShortcutMenuItem.isHidden = true
#endif

        updateBookmarksBarMenuItem()
        updateShortcutMenuItems()
        updateLoggingMenuItems()
        updateRemoteConfigurationInfo()
    }

    // MARK: - Bookmarks

    var faviconsCancellable: AnyCancellable?
    private func subscribeToFavicons(faviconManager: FaviconManagement) {
        faviconsCancellable = faviconManager.faviconsLoadedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loaded in
                guard let self, loaded else { return }

                self.updateFavicons(in: bookmarksMenu)
                self.updateFavicons(in: favoritesMenu)
            }
    }

    private func updateFavicons(in menu: NSMenu) {
        for menuItem in menu.items {
            if let bookmark = menuItem.representedObject as? Bookmark {
                menuItem.image = BookmarkViewModel(entity: bookmark).menuFavicon
            }
            if let submenu = menuItem.submenu {
                updateFavicons(in: submenu)
            }
        }
    }

    var bookmarkListCancellable: AnyCancellable?
    private func subscribeToBookmarkList(bookmarkManager: BookmarkManager) {
        bookmarkListCancellable = bookmarkManager.listPublisher
            .compactMap {
                let favorites = $0?.favoriteBookmarks.compactMap(BookmarkViewModel.init(entity:)) ?? []
                let topLevelEntities = $0?.topLevelEntities.compactMap(BookmarkViewModel.init(entity:)) ?? []

                return (favorites, topLevelEntities)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] favorites, topLevel in
                self?.updateBookmarksMenu(favoriteViewModels: favorites, topLevelBookmarkViewModels: topLevel)
            }
    }

    // Nested recursing functions cause body length
    func updateBookmarksMenu(favoriteViewModels: [BookmarkViewModel], topLevelBookmarkViewModels: [BookmarkViewModel]) {

        func bookmarkMenuItems(from bookmarkViewModels: [BookmarkViewModel], topLevel: Bool = true) -> [NSMenuItem] {
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

        func favoriteMenuItems(from bookmarkViewModels: [BookmarkViewModel]) -> [NSMenuItem] {
            bookmarkViewModels
                .filter { ($0.entity as? Bookmark)?.isFavorite ?? false }
                .enumerated()
                .map { index, bookmarkViewModel in
                    let item = NSMenuItem(bookmarkViewModel: bookmarkViewModel)
                    if index < 9 {
                        item.keyEquivalentModifierMask = [.option, .command]
                        item.keyEquivalent = String(index + 1)
                    }
                    return item
                }
        }

        guard let favoritesSeparatorIndex = bookmarksMenu.items.lastIndex(where: { $0.isSeparatorItem }),
              let favoriteThisPageSeparatorIndex = favoritesMenu.items.lastIndex(where: { $0.isSeparatorItem }) else {
            assertionFailure("MainMenuManager: Failed to reference bookmarks menu items")
            return
        }

        let cleanedBookmarkItems = bookmarksMenu.items.dropLast(bookmarksMenu.items.count - (favoritesSeparatorIndex + 1))
        let bookmarkItems = bookmarkMenuItems(from: topLevelBookmarkViewModels)
        bookmarksMenu.items = Array(cleanedBookmarkItems) + bookmarkItems

        let cleanedFavoriteItems = favoritesMenu.items.dropLast(favoritesMenu.items.count - (favoriteThisPageSeparatorIndex + 1))
        let favoriteItems = favoriteMenuItems(from: favoriteViewModels)
        favoritesMenu.items = Array(cleanedFavoriteItems) + favoriteItems
    }

    private func updateBookmarksBarMenuItem() {
        guard let toggleBookmarksBarMenuItem = BookmarksBarMenuFactory.replace(toggleBookmarksBarMenuItem),
              let bookmarksMenuToggleBookmarksBarMenuItem = BookmarksBarMenuFactory.replace(bookmarksMenuToggleBookmarksBarMenuItem) else {
            assertionFailure("Could not replace toggleBookmarksBarMenuItem")
            return
        }
        self.toggleBookmarksBarMenuItem = toggleBookmarksBarMenuItem
        toggleBookmarksBarMenuItem.target = self
        toggleBookmarksBarMenuItem.action = #selector(toggleBookmarksBarFromMenu(_:))

        self.bookmarksMenuToggleBookmarksBarMenuItem = bookmarksMenuToggleBookmarksBarMenuItem
    }

    @MainActor
    @objc
    private func toggleBookmarksBarFromMenu(_ sender: Any) {
        guard let mainVC = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController else { return }
        mainVC.toggleBookmarksBarFromMenu(sender)
    }

    private func updateShortcutMenuItems() {
        toggleAutofillShortcutMenuItem.title = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .autofill)
        toggleBookmarksShortcutMenuItem.title = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .bookmarks)
        toggleDownloadsShortcutMenuItem.title = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .downloads)
        toggleHomeButtonMenuItem.title = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .homeButton)

#if NETWORK_PROTECTION
        if NetworkProtectionKeychainTokenStore().isFeatureActivated {
            toggleNetworkProtectionShortcutMenuItem.isHidden = false
            toggleNetworkProtectionShortcutMenuItem.title = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .networkProtection)
        } else {
            toggleNetworkProtectionShortcutMenuItem.isHidden = true
        }
#endif
    }

    // MARK: - Debug

    private func setupDebugMenu() -> NSMenu {
        let debugMenu = NSMenu(title: "Debug") {
            NSMenuItem(title: "Reset Data") {
                NSMenuItem(title: "Reset Default Browser Prompt", action: #selector(MainViewController.resetDefaultBrowserPrompt))
                NSMenuItem(title: "Reset Default Grammar Checks", action: #selector(MainViewController.resetDefaultGrammarChecks))
                NSMenuItem(title: "Reset Autofill Data", action: #selector(MainViewController.resetSecureVaultData))
                NSMenuItem(title: "Reset Bookmarks", action: #selector(MainViewController.resetBookmarks))
                NSMenuItem(title: "Reset Pinned Tabs", action: #selector(MainViewController.resetPinnedTabs))
                NSMenuItem(title: "Reset YouTube Overlay Interactions", action: #selector(MainViewController.resetDuckPlayerOverlayInteractions))
                NSMenuItem(title: "Reset MakeDuckDuckYours user settings", action: #selector(MainViewController.resetMakeDuckDuckGoYoursUserSettings))
                NSMenuItem(title: "Change Activation Date") {
                    NSMenuItem(title: "Today", action: #selector(MainViewController.changeInstallDateToToday), keyEquivalent: "N")
                    NSMenuItem(title: "Less Than a 21 days Ago", action: #selector(MainViewController.changeInstallDateToLessThan21DaysAgo))
                    NSMenuItem(title: "More Than 21 Days Ago", action: #selector(MainViewController.changeInstallDateToMoreThan21DaysAgoButLessThan27))
                    NSMenuItem(title: "More Than 27 Days Ago", action: #selector(MainViewController.changeInstallDateToMoreThan27DaysAgo))
                }
                NSMenuItem(title: "Reset Email Protection InContext Signup Prompt", action: #selector(MainViewController.resetEmailProtectionInContextPrompt))
                NSMenuItem(title: "Reset Daily Pixels", action: #selector(MainViewController.resetDailyPixels))
            }
            NSMenuItem(title: "UI Triggers") {
                NSMenuItem(title: "Show Save Credentials Popover", action: #selector(MainViewController.showSaveCredentialsPopover))
                NSMenuItem(title: "Show Credentials Saved Popover", action: #selector(MainViewController.showCredentialsSavedPopover))
                NSMenuItem(title: "Show Pop Up Window", action: #selector(MainViewController.showPopUpWindow))
            }
            NSMenuItem(title: "Remote Configuration") {
                customConfigurationUrlMenuItem
                configurationDateAndTimeMenuItem
                NSMenuItem.separator()
                NSMenuItem(title: "Reload Configuration Now", action: #selector(MainViewController.reloadConfigurationNow))
                NSMenuItem(title: "Set custom configuration URL…", action: #selector(MainViewController.setCustomConfigurationURL))
                NSMenuItem(title: "Reset configuration to default", action: #selector(MainViewController.resetConfigurationToDefault))
            }
            NSMenuItem(title: "Sync")
                .submenu(SyncDebugMenu())

#if NETWORK_PROTECTION
            NSMenuItem(title: "Network Protection")
                .submenu(NetworkProtectionDebugMenu())
#endif

            NSMenuItem(title: "Trigger Fatal Error", action: #selector(MainViewController.triggerFatalError))

#if SUBSCRIPTION
            SubscriptionDebugMenu(currentViewController: {
                WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController
            })
#endif

            NSMenuItem(title: "Logging").submenu(setupLoggingMenu())
        }
        debugMenu.autoenablesItems = false
        return debugMenu
    }

    private func setupLoggingMenu() -> NSMenu {
        let menu = NSMenu(title: "")

        menu.addItem(NSMenuItem(title: "Enable All", action: #selector(enableAllLogsMenuItemAction), target: self))
        menu.addItem(NSMenuItem(title: "Disable All", action: #selector(disableAllLogsMenuItemAction), target: self))
        menu.addItem(.separator())

        for category in OSLog.AllCategories.allCases.sorted() {
            let menuItem = NSMenuItem(title: category, action: #selector(loggingMenuItemAction), target: self)
            menuItem.identifier = .init(category)
            menu.addItem(menuItem)
        }

        menu.addItem(.separator())
        let debugLoggingMenuItem = NSMenuItem(title: OSLog.isRunningInDebugEnvironment ? "Disable DEBUG level logging…" : "Enable DEBUG level logging…", action: #selector(debugLoggingMenuItemAction), target: self)
        menu.addItem(debugLoggingMenuItem)

        if #available(macOS 12.0, *) {
            let exportLogsMenuItem = NSMenuItem(title: "Save Logs…", action: #selector(exportLogs), target: self)
            menu.addItem(exportLogsMenuItem)
        }

        self.loggingMenu = menu
        return menu
    }

    private func updateLoggingMenuItems() {
        guard let loggingMenu else { return }

        let enabledCategories = OSLog.loggingCategories
        for item in loggingMenu.items {
            guard let category = item.identifier.map(\.rawValue) else { continue }

            item.state = enabledCategories.contains(category) ? .on : .off
        }
    }

    private func updateRemoteConfigurationInfo() {
        let dateString = DateFormatter.localizedString(from: ConfigurationManager.shared.lastUpdateTime, dateStyle: .short, timeStyle: .medium)
        configurationDateAndTimeMenuItem.title = "Last Update Time: \(dateString)"
        customConfigurationUrlMenuItem.title = "Configuration URL:  \(AppConfigurationURLProvider().url(for: .privacyConfiguration).absoluteString)"
    }

    @objc private func loggingMenuItemAction(_ sender: NSMenuItem) {
        guard let category = sender.identifier?.rawValue else { return }

        if case .on = sender.state {
            OSLog.loggingCategories.remove(category)
        } else {
            OSLog.loggingCategories.insert(category)
        }
    }

    @objc private func enableAllLogsMenuItemAction(_ sender: NSMenuItem) {
        OSLog.loggingCategories = Set(OSLog.AllCategories.allCases)
    }

    @objc private func disableAllLogsMenuItemAction(_ sender: NSMenuItem) {
        OSLog.loggingCategories = []
    }

    @objc private func debugLoggingMenuItemAction(_ sender: NSMenuItem) {
#if APPSTORE
        if !OSLog.isRunningInDebugEnvironment {
            let alert = NSAlert()
            alert.messageText = "Restart with DEBUG logging Enabled not supported for AppStore build"
            alert.informativeText = """
            Open terminal and run:
            export \(ProcessInfo.Constants.osActivityMode)=\(ProcessInfo.Constants.debug)
            "\(Bundle.main.executablePath!)"
            """
            alert.runModal()

            return
        }
#endif

        let alert = NSAlert()
        alert.messageText = "Restart with DEBUG logging \(OSLog.isRunningInDebugEnvironment ? "Disabled" : "Enabled")?"
        alert.addButton(withTitle: "Restart").tag = NSApplication.ModalResponse.OK.rawValue
        alert.addButton(withTitle: "Cancel").tag = NSApplication.ModalResponse.cancel.rawValue
        guard case .OK = alert.runModal() else { return }

        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.environment = [ProcessInfo.Constants.osActivityMode: (OSLog.isRunningInDebugEnvironment ? "" : ProcessInfo.Constants.debug)]

        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    @available(macOS 12.0, *)
    @objc private func exportLogs(_ sender: NSMenuItem) {
        let displayName = Bundle.main.displayName!.replacingOccurrences(of: " ", with: "")

        let launchDate = ISO8601DateFormatter().string(from: NSRunningApplication.current.launchDate ?? Date()).replacingOccurrences(of: ":", with: "_")
        let savePanel = NSSavePanel.savePanelWithFileTypeChooser(fileTypes: [.log, .text], suggestedFilename: "\(displayName)_\(launchDate)")
        guard case .OK = savePanel.runModal(),
              let url = savePanel.url else { return }

        do {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

            let logStore = try OSLogStore(scope: .currentProcessIdentifier)
            try logStore.getEntries()
                .compactMap {
                    guard let entry = $0 as? OSLogEntryLog,
                          entry.subsystem == OSLog.subsystem else { return nil }
                    return "\(formatter.string(from: entry.date)) [\(entry.category)] \(entry.composedMessage)"
                }
                .joined(separator: "\n")
                .utf8data
                .write(to: url)

            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

#if DEBUG
#Preview {
    return MenuPreview(menu: NSApp.mainMenu!)
}
#endif
