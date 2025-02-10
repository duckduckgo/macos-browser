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
import FeatureFlags
import OSLog
import SwiftUI
import WebKit
import Configuration
import NetworkProtection
import Subscription
import SubscriptionUI

final class MainMenu: NSMenu {

    enum Constants {
        static let maxTitleLength = 55
    }

    // MARK: DuckDuckGo
    let servicesMenu = NSMenu(title: UserText.mainMenuAppServices)
    let preferencesMenuItem = NSMenuItem(title: UserText.mainMenuAppPreferences, action: #selector(AppDelegate.openPreferences), keyEquivalent: ",").withAccessibilityIdentifier("MainMenu.preferencesMenuItem")

    // MARK: File
    let newWindowMenuItem = NSMenuItem(title: UserText.newWindowMenuItem, action: #selector(AppDelegate.newWindow), keyEquivalent: "n")
    let newTabMenuItem = NSMenuItem(title: UserText.mainMenuFileNewTab, action: #selector(AppDelegate.newTab), keyEquivalent: "t")
    let openLocationMenuItem = NSMenuItem(title: UserText.mainMenuFileOpenLocation, action: #selector(AppDelegate.openLocation), keyEquivalent: "l")
    let closeWindowMenuItem = NSMenuItem(title: UserText.mainMenuFileCloseWindow, action: #selector(NSWindow.performClose), keyEquivalent: "W")
    let closeAllWindowsMenuItem = NSMenuItem(title: UserText.mainMenuFileCloseAllWindows, action: #selector(AppDelegate.closeAllWindows), keyEquivalent: [.option, .command, "W"])
    let closeTabMenuItem = NSMenuItem(title: UserText.closeTab, action: #selector(MainViewController.closeTab), keyEquivalent: "w")
    let importBrowserDataMenuItem = NSMenuItem(title: UserText.mainMenuFileImportBookmarksandPasswords, action: #selector(AppDelegate.openImportBrowserDataWindow))

    @MainActor
    let sharingMenu = SharingMenu(title: UserText.shareMenuItem)

    // MARK: View
    let stopMenuItem = NSMenuItem(title: UserText.mainMenuViewStop, action: #selector(MainViewController.stopLoadingPage), keyEquivalent: ".")
    let reloadMenuItem = NSMenuItem(title: UserText.mainMenuViewReloadPage, action: #selector(MainViewController.reloadPage), keyEquivalent: "r")

    let toggleFullscreenMenuItem = NSMenuItem(title: UserText.mainMenuViewEnterFullScreen, action: #selector(NSWindow.toggleFullScreen), keyEquivalent: [.control, .command, "f"])
    let actualSizeMenuItem = NSMenuItem(title: UserText.mainMenuViewActualSize, action: #selector(MainViewController.actualSize), keyEquivalent: "0")
    let zoomInMenuItem = NSMenuItem(title: UserText.mainMenuViewZoomIn, action: #selector(MainViewController.zoomIn), keyEquivalent: "+")
    let zoomOutMenuItem = NSMenuItem(title: UserText.mainMenuViewZoomOut, action: #selector(MainViewController.zoomOut), keyEquivalent: "-")

    // MARK: History
    @MainActor
    let historyMenu = HistoryMenu()

    @MainActor
    var backMenuItem: NSMenuItem { historyMenu.backMenuItem }
    @MainActor
    var forwardMenuItem: NSMenuItem { historyMenu.forwardMenuItem }

    // MARK: Bookmarks
    let manageBookmarksMenuItem = NSMenuItem(title: UserText.mainMenuHistoryManageBookmarks, action: #selector(MainViewController.showManageBookmarks), keyEquivalent: [.command, .option, "b"])
        .withAccessibilityIdentifier("MainMenu.manageBookmarksMenuItem")
    var bookmarksMenuToggleBookmarksBarMenuItem = NSMenuItem(title: "BookmarksBarMenuPlaceholder", action: #selector(MainViewController.toggleBookmarksBarFromMenu), keyEquivalent: "B")
    let importBookmarksMenuItem = NSMenuItem(title: UserText.importBookmarks, action: #selector(AppDelegate.openImportBrowserDataWindow))
    let bookmarksMenu = NSMenu(title: UserText.bookmarks)
    let favoritesMenu = NSMenu(title: UserText.favorites)

    private var toggleBookmarksBarMenuItem = NSMenuItem(title: "BookmarksBarMenuPlaceholder", action: #selector(MainViewController.toggleBookmarksBarFromMenu), keyEquivalent: "B")

    var homeButtonMenuItem = NSMenuItem(title: "HomeButtonPlaceholder")
    var showTabsAndBookmarksBarOnFullScreenMenuItem = NSMenuItem(title: "ShowTabsAndBookmarksBarOnFullScreenMenuItem")
    let toggleAutofillShortcutMenuItem = NSMenuItem(title: UserText.mainMenuViewShowAutofillShortcut, action: #selector(MainViewController.toggleAutofillShortcut), keyEquivalent: "A")
    let toggleBookmarksShortcutMenuItem = NSMenuItem(title: UserText.mainMenuViewShowBookmarksShortcut, action: #selector(MainViewController.toggleBookmarksShortcut), keyEquivalent: "K")
    let toggleDownloadsShortcutMenuItem = NSMenuItem(title: UserText.mainMenuViewShowDownloadsShortcut, action: #selector(MainViewController.toggleDownloadsShortcut), keyEquivalent: "J")
    var aiChatMenu = NSMenuItem(title: UserText.newAIChatMenuItem, action: #selector(AppDelegate.newAIChat), keyEquivalent: [.option, .command, "n"])
    let toggleNetworkProtectionShortcutMenuItem = NSMenuItem(title: UserText.showNetworkProtectionShortcut, action: #selector(MainViewController.toggleNetworkProtectionShortcut), keyEquivalent: "N")

    let toggleAIChatShortcutMenuItem = NSMenuItem(title: UserText.showAIChatShortcut, action: #selector(MainViewController.toggleAIChatShortcut), keyEquivalent: "L")

    // MARK: Window
    let windowsMenu = NSMenu(title: UserText.mainMenuWindow)

    // MARK: Debug

    private var loggingMenu: NSMenu?
    let newTabPagePrivacyStatsModeMenuItem = NSMenuItem(title: "Privacy Stats", action: #selector(MainMenu.updateNewTabPageMode), representedObject: NewTabPageMode.privacyStats)
    let newTabPageRecentActivityModeMenuItem = NSMenuItem(title: "Recent Activity", action: #selector(MainMenu.updateNewTabPageMode), representedObject: NewTabPageMode.recentActivity)
    let customConfigurationUrlMenuItem = NSMenuItem(title: "Last Update Time", action: nil)
    let configurationDateAndTimeMenuItem = NSMenuItem(title: "Configuration URL", action: nil)
    let autofillDebugScriptMenuItem = NSMenuItem(title: "Autofill Debug Script", action: #selector(MainMenu.toggleAutofillScriptDebugSettingsAction))

    // MARK: Help

    let helpMenu = NSMenu(title: UserText.mainMenuHelp)
    let aboutMenuItem = NSMenuItem(title: UserText.about, action: #selector(AppDelegate.showAbout))
    let addToDockMenuItem = NSMenuItem(title: UserText.addDuckDuckGoToDock, action: #selector(AppDelegate.addToDock))
    let setAsDefaultMenuItem = NSMenuItem(title: UserText.setAsDefaultBrowser + "…", action: #selector(AppDelegate.setAsDefault))
    let releaseNotesMenuItem = NSMenuItem(title: UserText.releaseNotesMenuItem, action: #selector(AppDelegate.showReleaseNotes))
    let whatIsNewMenuItem = NSMenuItem(title: UserText.whatsNewMenuItem, action: #selector(AppDelegate.showWhatIsNew))
    let sendFeedbackMenuItem = NSMenuItem(title: UserText.sendFeedback, action: #selector(AppDelegate.openFeedback))

    private let dockCustomizer: DockCustomization
    private let defaultBrowserPreferences: DefaultBrowserPreferences
    private let aiChatMenuConfig: AIChatMenuVisibilityConfigurable

    // MARK: - Initialization

    @MainActor
    init(featureFlagger: FeatureFlagger,
         bookmarkManager: BookmarkManager,
         faviconManager: FaviconManagement,
         dockCustomizer: DockCustomization = DockCustomizer(),
         defaultBrowserPreferences: DefaultBrowserPreferences = .shared,
         aiChatMenuConfig: AIChatMenuVisibilityConfigurable) {

        self.dockCustomizer = dockCustomizer
        self.defaultBrowserPreferences = defaultBrowserPreferences
        self.aiChatMenuConfig = aiChatMenuConfig
        super.init(title: UserText.duckDuckGo)

        buildItems {
            buildDuckDuckGoMenu()
            buildFileMenu()
            buildEditMenu()
            buildViewMenu()
            buildHistoryMenu()
            buildBookmarksMenu()
            buildWindowMenu()
            buildDebugMenu(featureFlagger: featureFlagger)
            buildHelpMenu()
        }

        subscribeToBookmarkList(bookmarkManager: bookmarkManager)
        subscribeToFavicons(faviconManager: faviconManager)

        setupAIChatMenu()
        subscribeToAIChatPreferences(aiChatMenuConfig: aiChatMenuConfig)
    }

    func buildDuckDuckGoMenu() -> NSMenuItem {
        NSMenuItem(title: UserText.duckDuckGo) {
            NSMenuItem(title: UserText.aboutDuckDuckGo, action: #selector(AppDelegate.openAbout))
            NSMenuItem.separator()

            preferencesMenuItem
            addToDockMenuItem
            setAsDefaultMenuItem

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
    }

    @MainActor
    func buildFileMenu() -> NSMenuItem {
        NSMenuItem(title: UserText.mainMenuFile) {
            newTabMenuItem

            newWindowMenuItem
            NSMenuItem(title: UserText.newBurnerWindowMenuItem, action: #selector(AppDelegate.newBurnerWindow), keyEquivalent: "N")

            aiChatMenu

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
    }

    func buildEditMenu() -> NSMenuItem {
        NSMenuItem(title: UserText.mainMenuEdit) {
            NSMenuItem(title: UserText.mainMenuEditUndo, action: Selector(("undo:")), keyEquivalent: "z")
            NSMenuItem(title: UserText.mainMenuEditRedo, action: Selector(("redo:")), keyEquivalent: "Z")
            NSMenuItem.separator()

            NSMenuItem(title: UserText.mainMenuEditCut, action: #selector(NSText.cut(_:)), keyEquivalent: "x")
            NSMenuItem(title: UserText.mainMenuEditCopy, action: #selector(NSText.copy(_:)), keyEquivalent: "c")
            NSMenuItem(title: UserText.mainMenuEditPaste, action: #selector(NSText.paste), keyEquivalent: "v")
            NSMenuItem(title: UserText.mainMenuEditPasteAndMatchStyle, action: #selector(NSTextView.pasteAsPlainText), keyEquivalent: [.option, .command, .shift, "v"])
            NSMenuItem(title: UserText.mainMenuEditPasteAndMatchStyle, action: #selector(NSTextView.pasteAsPlainText), keyEquivalent: [.command, .shift, "v"])
                .alternate()

            NSMenuItem(title: UserText.mainMenuEditDelete, action: #selector(NSText.delete))
            NSMenuItem(title: UserText.mainMenuEditSelectAll, action: #selector(NSText.selectAll), keyEquivalent: "a")
            NSMenuItem.separator()

            NSMenuItem(title: UserText.mainMenuEditFind) {
                NSMenuItem(title: UserText.findInPageMenuItem, action: #selector(MainViewController.findInPage), keyEquivalent: "f").withAccessibilityIdentifier("MainMenu.findInPage")
                NSMenuItem(title: UserText.mainMenuEditFindFindNext, action: #selector(MainViewController.findInPageNext), keyEquivalent: "g").withAccessibilityIdentifier("MainMenu.findNext")
                NSMenuItem(title: UserText.mainMenuEditFindFindPrevious, action: #selector(MainViewController.findInPagePrevious), keyEquivalent: "G").withAccessibilityIdentifier("MainMenu.findPrevious")
                NSMenuItem.separator()

                NSMenuItem(title: UserText.mainMenuEditFindHideFind, action: #selector(MainViewController.findInPageDone), keyEquivalent: "F").withAccessibilityIdentifier("MainMenu.findInPageDone")
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
    }

    func buildViewMenu() -> NSMenuItem {
        NSMenuItem(title: UserText.mainMenuView) {
            stopMenuItem
            reloadMenuItem
            NSMenuItem.separator()

            NSMenuItem(title: UserText.mainMenuViewHome, action: #selector(MainViewController.home), keyEquivalent: "H")
            NSMenuItem.separator()

            showTabsAndBookmarksBarOnFullScreenMenuItem

            toggleBookmarksBarMenuItem

            NSMenuItem(title: UserText.openDownloads, action: #selector(MainViewController.toggleDownloads), keyEquivalent: "j")
            NSMenuItem.separator()

            homeButtonMenuItem
            toggleAutofillShortcutMenuItem
            toggleBookmarksShortcutMenuItem
            toggleDownloadsShortcutMenuItem

            toggleNetworkProtectionShortcutMenuItem

            toggleAIChatShortcutMenuItem

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
    }

    @MainActor
    func buildHistoryMenu() -> NSMenuItem {
        NSMenuItem(title: UserText.mainMenuHistory)
            .submenu(historyMenu)
    }

    func buildBookmarksMenu() -> NSMenuItem {
        NSMenuItem(title: UserText.bookmarks)
            .withAccessibilityIdentifier("MainMenu.bookmarks")
            .submenu(bookmarksMenu.buildItems {
                NSMenuItem(title: UserText.bookmarkThisPage, action: #selector(MainViewController.bookmarkThisPage), keyEquivalent: "d")
                NSMenuItem(title: UserText.bookmarkAllTabs, action: #selector(MainViewController.bookmarkAllOpenTabs), keyEquivalent: [.command, .shift, "d"])
                manageBookmarksMenuItem
                bookmarksMenuToggleBookmarksBarMenuItem
                NSMenuItem.separator()

                importBookmarksMenuItem
                NSMenuItem(title: UserText.exportBookmarks, action: #selector(AppDelegate.openExportBookmarks))
                NSMenuItem.separator()

                NSMenuItem(title: UserText.favorites)
                    .submenu(favoritesMenu.buildItems {
                        NSMenuItem(title: UserText.mainMenuHistoryFavoriteThisPage, action: #selector(MainViewController.favoriteThisPage))
                            .withImage(.favorite)
                            .withAccessibilityIdentifier("MainMenu.favoriteThisPage")
                        NSMenuItem.separator()
                    })
                    .withImage(.favorite)

                NSMenuItem.separator()
            })
    }

    func buildWindowMenu() -> NSMenuItem {
        NSMenuItem(title: UserText.mainMenuWindow)
            .submenu(windowsMenu.buildItems {
                NSMenuItem(title: UserText.mainMenuWindowMinimize, action: #selector(NSWindow.performMiniaturize), keyEquivalent: "m")
                NSMenuItem(title: UserText.zoom, action: #selector(NSWindow.performZoom))
                NSMenuItem.separator()

                NSMenuItem(title: UserText.duplicateTab, action: #selector(MainViewController.duplicateTab))
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
    }

    @MainActor
    func buildDebugMenu(featureFlagger: FeatureFlagger) -> NSMenuItem? {
#if DEBUG || REVIEW
        NSMenuItem(title: "Debug")
            .submenu(setupDebugMenu())
#else
        if featureFlagger.isFeatureOn(.debugMenu) {
            NSMenuItem(title: "Debug")
                .submenu(setupDebugMenu())
        } else {
            nil
        }
#endif
    }

    func buildHelpMenu() -> NSMenuItem {
        NSMenuItem(title: UserText.mainMenuHelp)
            .submenu(helpMenu.buildItems {
                NSMenuItem(title: UserText.mainMenuHelpDuckDuckGoHelp, action: #selector(NSApplication.showHelp), keyEquivalent: "?")
                    .hidden()

                NSMenuItem.separator()

                aboutMenuItem
#if SPARKLE
                releaseNotesMenuItem
                whatIsNewMenuItem
#endif

#if FEEDBACK
                sendFeedbackMenuItem
#endif
            })
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    @MainActor
    override func update() {
        super.update()

#if SPARKLE
        addToDockMenuItem.isHidden = dockCustomizer.isAddedToDock
#else
        addToDockMenuItem.isHidden = true
#endif
        setAsDefaultMenuItem.isHidden = defaultBrowserPreferences.isDefault

        // To be safe, hide the NetP shortcut menu item by default.
        toggleNetworkProtectionShortcutMenuItem.isHidden = true
        toggleAIChatShortcutMenuItem.isHidden = true

        updateHomeButtonMenuItem()
        updateBookmarksBarMenuItem()
        updateShortcutMenuItems()
        updateNewTabPageModeMenuItem()
        updateInternalUserItem()
        updateRemoteConfigurationInfo()
        updateAutofillDebugScriptMenuItem()
        updateShowToolbarsOnFullScreenMenuItem()
    }

    // MARK: - Bookmarks

    var faviconsCancellable: AnyCancellable?
    @MainActor
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

    var aiChatCancellable: AnyCancellable?
    private func subscribeToAIChatPreferences(aiChatMenuConfig: AIChatMenuVisibilityConfigurable) {
        aiChatCancellable = aiChatMenuConfig.valuesChangedPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] in
                self?.setupAIChatMenu()
            })
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

    private func updateHomeButtonMenuItem() {
        guard let homeButtonMenuItem = HomeButtonMenuFactory.replace(homeButtonMenuItem) else {
            assertionFailure("Could not replace HomeButtonMenuItem")
            return
        }
        self.homeButtonMenuItem = homeButtonMenuItem
    }

    private func updateShowToolbarsOnFullScreenMenuItem() {
        guard let showTabsAndBookmarksBarOnFullScreenMenuItem = ShowToolbarsOnFullScreenMenuCoordinator.replace(showTabsAndBookmarksBarOnFullScreenMenuItem) else {
            assertionFailure("Could not replace ShowTabsAndBookmarksBarOnFullScreenMenuItem")
            return
        }
        self.showTabsAndBookmarksBarOnFullScreenMenuItem = showTabsAndBookmarksBarOnFullScreenMenuItem
    }

    @MainActor
    @objc
    private func toggleBookmarksBarFromMenu(_ sender: Any) {
        guard let mainVC = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController else { return }
        mainVC.toggleBookmarksBarFromMenu(sender)
    }

    private func updateShortcutMenuItems() {
        Task { @MainActor in
            toggleAutofillShortcutMenuItem.title = LocalPinningManager.shared.shortcutTitle(for: .autofill)
            toggleBookmarksShortcutMenuItem.title = LocalPinningManager.shared.shortcutTitle(for: .bookmarks)
            toggleDownloadsShortcutMenuItem.title = LocalPinningManager.shared.shortcutTitle(for: .downloads)

            if AIChatRemoteSettings().isApplicationMenuShortcutEnabled {
                toggleAIChatShortcutMenuItem.title = LocalPinningManager.shared.shortcutTitle(for: .aiChat)
                toggleAIChatShortcutMenuItem.isHidden = false
            } else {
                toggleAIChatShortcutMenuItem.isHidden = true
            }

            if DefaultVPNFeatureGatekeeper(subscriptionManager: Application.appDelegate.subscriptionManager).isVPNVisible() {
                toggleNetworkProtectionShortcutMenuItem.isHidden = false
                toggleNetworkProtectionShortcutMenuItem.title = LocalPinningManager.shared.shortcutTitle(for: .networkProtection)
            } else {
                toggleNetworkProtectionShortcutMenuItem.isHidden = true
            }
        }
    }

    // MARK: - Debug

    let internalUserItem = NSMenuItem(title: "Set Internal User State", action: #selector(MainViewController.internalUserState))

    @MainActor
    private func setupDebugMenu() -> NSMenu {
        let debugMenu = NSMenu(title: "Debug") {
            NSMenuItem(title: "Feature Flag Overrides")
                .submenu(FeatureFlagOverridesMenu(featureFlagOverrides: NSApp.delegateTyped.featureFlagger))
            NSMenuItem.separator()
            NSMenuItem(title: "Open Vanilla Browser", action: #selector(MainViewController.openVanillaBrowser)).withAccessibilityIdentifier("MainMenu.openVanillaBrowser")
            NSMenuItem.separator()
            NSMenuItem(title: "Skip Onboarding", action: #selector(MainViewController.skipOnboarding))
            NSMenuItem(title: "New Tab Page") {
                NSMenuItem(title: "Mode") {
                    newTabPagePrivacyStatsModeMenuItem.targetting(self)
                    newTabPageRecentActivityModeMenuItem.targetting(self)
                }
                NSMenuItem(title: "Reset Continue Setup", action: #selector(MainViewController.debugResetContinueSetup))
                NSMenuItem(title: "Shift New Tab daily impression", action: #selector(MainViewController.debugShiftNewTabOpeningDate))
                NSMenuItem(title: "Shift \(AppearancePreferences.Constants.dismissNextStepsCardsAfterDays) days", action: #selector(MainViewController.debugShiftNewTabOpeningDateNtimes))
            }
            NSMenuItem(title: "History")
                .submenu(HistoryDebugMenu())
            NSMenuItem(title: "Reset Data") {
                NSMenuItem(title: "Reset Default Browser Prompt", action: #selector(MainViewController.resetDefaultBrowserPrompt))
                NSMenuItem(title: "Reset Default Grammar Checks", action: #selector(MainViewController.resetDefaultGrammarChecks))
                NSMenuItem(title: "Reset Autofill Data", action: #selector(MainViewController.resetSecureVaultData)).withAccessibilityIdentifier("MainMenu.resetSecureVaultData")
                NSMenuItem(title: "Reset Bookmarks", action: #selector(MainViewController.resetBookmarks)).withAccessibilityIdentifier("MainMenu.resetBookmarks")
                NSMenuItem(title: "Reset Pinned Tabs", action: #selector(MainViewController.resetPinnedTabs))
                NSMenuItem(title: "Reset New Tab Page Customizations", action: #selector(AppDelegate.resetNewTabPageCustomization))
                NSMenuItem(title: "Reset YouTube Overlay Interactions", action: #selector(MainViewController.resetDuckPlayerOverlayInteractions))
                NSMenuItem(title: "Reset MakeDuckDuckYours user settings", action: #selector(MainViewController.resetMakeDuckDuckGoYoursUserSettings))
                NSMenuItem(title: "Experiment Install Date more than 5 days ago", action: #selector(MainViewController.changePixelExperimentInstalledDateToLessMoreThan5DayAgo(_:)))
                NSMenuItem(title: "Change Activation Date") {
                    NSMenuItem(title: "Today", action: #selector(MainViewController.changeInstallDateToToday), keyEquivalent: "N")
                    NSMenuItem(title: "Less Than a 5 days Ago", action: #selector(MainViewController.changeInstallDateToLessThan5DayAgo(_:)))
                    NSMenuItem(title: "More Than 5 Days Ago", action: #selector(MainViewController.changeInstallDateToMoreThan5DayAgoButLessThan9(_:)))
                    NSMenuItem(title: "More Than 9 Days Ago", action: #selector(MainViewController.changeInstallDateToMoreThan9DaysAgo(_:)))
                }
                NSMenuItem(title: "Reset Email Protection InContext Signup Prompt", action: #selector(MainViewController.resetEmailProtectionInContextPrompt))
                NSMenuItem(title: "Reset Pixels Storage", action: #selector(MainViewController.resetDailyPixels))
                NSMenuItem(title: "Reset Remote Messages", action: #selector(AppDelegate.resetRemoteMessages))
                NSMenuItem(title: "Reset Duck Player Preferences", action: #selector(MainViewController.resetDuckPlayerPreferences))
                NSMenuItem(title: "Reset Onboarding", action: #selector(MainViewController.resetOnboarding(_:)))
                NSMenuItem(title: "Reset Home Page Settings Onboarding", action: #selector(MainViewController.resetHomePageSettingsOnboarding(_:)))
                NSMenuItem(title: "Reset Contextual Onboarding", action: #selector(MainViewController.resetContextualOnboarding(_:)))
                NSMenuItem(title: "Reset Sync Promo prompts", action: #selector(MainViewController.resetSyncPromoPrompts))
                NSMenuItem(title: "Reset Add To Dock more options menu notification", action: #selector(MainViewController.resetAddToDockFeatureNotification))
                NSMenuItem(title: "Reset Launch Date To Today", action: #selector(MainViewController.resetLaunchDateToToday))
                NSMenuItem(title: "Set Launch Date A Week In the Past", action: #selector(MainViewController.setLaunchDayAWeekInThePast))

            }.withAccessibilityIdentifier("MainMenu.resetData")
            NSMenuItem(title: "UI Triggers") {
                NSMenuItem(title: "Append Tabs") {
                    NSMenuItem(title: "10 Tabs", action: #selector(MainViewController.addDebugTabs(_:)), representedObject: 10)
                    NSMenuItem(title: "50 Tabs", action: #selector(MainViewController.addDebugTabs(_:)), representedObject: 50)
                    NSMenuItem(title: "100 Tabs", action: #selector(MainViewController.addDebugTabs(_:)), representedObject: 100)
                    NSMenuItem(title: "150 Tabs", action: #selector(MainViewController.addDebugTabs(_:)), representedObject: 150)
                }
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
            NSMenuItem(title: "Remote Messaging Framework")
                .submenu(RemoteMessagingDebugMenu())
            NSMenuItem(title: "User Scripts") {
                NSMenuItem(title: "Remove user scripts from selected tab", action: #selector(MainViewController.removeUserScripts))
            }
            NSMenuItem(title: "Sync & Backup")
                .submenu(SyncDebugMenu())
                .withAccessibilityIdentifier("MainMenu.syncAndBackup")

            NSMenuItem(title: "Personal Information Removal")
                .submenu(DataBrokerProtectionDebugMenu())

            FreemiumDebugMenu()

            if case .normal = NSApp.runType {
                NSMenuItem(title: "VPN")
                    .submenu(NetworkProtectionDebugMenu())
            }

            if #available(macOS 13.5, *) {
                NSMenuItem(title: "Autofill") {
                    NSMenuItem(title: "View all Credentials", action: #selector(MainViewController.showAllCredentials)).withAccessibilityIdentifier("MainMenu.showAllCredentials")
                }
            }

            NSMenuItem(title: "Simulate crash") {
                NSMenuItem(title: "fatalError", action: #selector(MainViewController.triggerFatalError))
                NSMenuItem(title: "NSException", action: #selector(MainViewController.crashOnException))
                NSMenuItem(title: "C++ exception", action: #selector(MainViewController.crashOnCxxException))
            }

            let subscriptionAppGroup = Bundle.main.appGroup(bundle: .subs)
            let subscriptionUserDefaults = UserDefaults(suiteName: subscriptionAppGroup)!

            var currentEnvironment = DefaultSubscriptionManager.getSavedOrDefaultEnvironment(userDefaults: subscriptionUserDefaults)
            let updateServiceEnvironment: (SubscriptionEnvironment.ServiceEnvironment) -> Void = { env in
                currentEnvironment.serviceEnvironment = env
                DefaultSubscriptionManager.save(subscriptionEnvironment: currentEnvironment, userDefaults: subscriptionUserDefaults)
            }
            let updatePurchasingPlatform: (SubscriptionEnvironment.PurchasePlatform) -> Void = { platform in
                currentEnvironment.purchasePlatform = platform
                DefaultSubscriptionManager.save(subscriptionEnvironment: currentEnvironment, userDefaults: subscriptionUserDefaults)
            }

            SubscriptionDebugMenu(currentEnvironment: currentEnvironment,
                                  updateServiceEnvironment: updateServiceEnvironment,
                                  updatePurchasingPlatform: updatePurchasingPlatform,
                                  currentViewController: { WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController },
                                  openSubscriptionTab: { WindowControllersManager.shared.showTab(with: .subscription($0)) },
                                  subscriptionManager: Application.appDelegate.subscriptionManager,
                                  subscriptionUserDefaults: subscriptionUserDefaults)

            NSMenuItem(title: "TipKit") {
                NSMenuItem(title: "Reset", action: #selector(MainViewController.resetTipKit))
                NSMenuItem(title: "⚠️ App restart required.", action: nil, target: nil)
            }

            NSMenuItem(title: "Logging").submenu(setupLoggingMenu())
            NSMenuItem(title: "AI Chat").submenu(AIChatDebugMenu())

#if !APPSTORE
            if #available(macOS 14.4, *) {
                NSMenuItem.separator()
                NSMenuItem(title: "Web Extensions").submenu(WebExtensionsDebugMenu())
                NSMenuItem.separator()
            }
#endif
        }

        debugMenu.addItem(internalUserItem)
        debugMenu.autoenablesItems = false
        return debugMenu
    }

    private func setupLoggingMenu() -> NSMenu {
        let menu = NSMenu(title: "")

        menu.addItem(autofillDebugScriptMenuItem
            .targetting(self))

        menu.addItem(.separator())

        if #available(macOS 12.0, *) {
            let exportLogsMenuItem = NSMenuItem(title: "Save Logs…", action: #selector(exportLogs), target: self)
            menu.addItem(exportLogsMenuItem)
        }

        self.loggingMenu = menu
        return menu
    }

    private func setupAIChatMenu() {
        aiChatMenu.isHidden = !aiChatMenuConfig.shouldDisplayApplicationMenuShortcut
    }

    private func updateNewTabPageModeMenuItem() {
        let mode = NewTabPageModeDecider().effectiveMode
        newTabPagePrivacyStatsModeMenuItem.state = mode == .privacyStats ? .on : .off
        newTabPageRecentActivityModeMenuItem.state = mode == .recentActivity ? .on : .off
    }

    @objc private func updateNewTabPageMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? NewTabPageMode else {
            return
        }
        NewTabPageModeDecider().modeOverride = mode
    }

    private func updateInternalUserItem() {
        internalUserItem.title = NSApp.delegateTyped.internalUserDecider.isInternalUser ? "Remove Internal User State" : "Set Internal User State"
    }

    private func updateAutofillDebugScriptMenuItem() {
        autofillDebugScriptMenuItem.state = AutofillPreferences().debugScriptEnabled ? .on : .off
    }

    private func updateRemoteConfigurationInfo() {
        var dateString: String
        if let date = Application.appDelegate.configurationManager.lastConfigurationInstallDate {
            dateString = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .medium)
            configurationDateAndTimeMenuItem.title = "Last Update Time: \(dateString)"
        } else {
            dateString = "Last Update Time: -"
        }
        configurationDateAndTimeMenuItem.title = dateString
        customConfigurationUrlMenuItem.title = "Configuration URL:  \(AppConfigurationURLProvider().url(for: .privacyConfiguration).absoluteString)"
    }

    @objc private func toggleAutofillScriptDebugSettingsAction(_ sender: NSMenuItem) {
        AutofillPreferences().debugScriptEnabled = !AutofillPreferences().debugScriptEnabled
        NotificationCenter.default.post(name: .autofillScriptDebugSettingsDidChange, object: nil)
        updateAutofillDebugScriptMenuItem()
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
                    guard let entry = $0 as? OSLogEntryLog else { return nil }
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
