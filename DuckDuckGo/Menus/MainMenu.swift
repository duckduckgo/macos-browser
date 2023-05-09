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

import Cocoa
import Combine
import OSLog // swiftlint:disable:this enforce_os_log_wrapper
import WebKit
import BrowserServicesKit
import NetworkProtection

final class MainMenu: NSMenu {

    enum Constants {
        static let maxTitleLength = 55
    }

    // MARK: - DuckDuckGo
    @IBOutlet weak var checkForUpdatesMenuItem: NSMenuItem?
    @IBOutlet weak var checkForUpdatesSeparatorItem: NSMenuItem?
    @IBOutlet weak var preferencesMenuItem: NSMenuItem!

    // MARK: - File
    @IBOutlet weak var newWindowMenuItem: NSMenuItem!
    @IBOutlet weak var newBurnerWindowMenuItem: NSMenuItem!
    @IBOutlet weak var newTabMenuItem: NSMenuItem!
    @IBOutlet weak var openLocationMenuItem: NSMenuItem!
    @IBOutlet weak var closeWindowMenuItem: NSMenuItem!
    @IBOutlet weak var closeAllWindowsMenuItem: NSMenuItem!
    @IBOutlet weak var closeTabMenuItem: NSMenuItem!
    @IBOutlet weak var printSeparatorItem: NSMenuItem?
    @IBOutlet weak var printMenuItem: NSMenuItem?
    @IBOutlet weak var shareMenuItem: NSMenuItem!
    @IBOutlet weak var importBrowserDataMenuItem: NSMenuItem!

    // MARK: - Edit
    @IBOutlet weak var checkSpellingWhileTypingMenuItem: NSMenuItem?
    @IBOutlet weak var checkGrammarWithSpellingMenuItem: NSMenuItem?

    // MARK: - View
    @IBOutlet weak var backMenuItem: NSMenuItem?
    @IBOutlet weak var forwardMenuItem: NSMenuItem?
    @IBOutlet weak var reloadMenuItem: NSMenuItem?
    @IBOutlet weak var stopMenuItem: NSMenuItem?
    @IBOutlet weak var homeMenuItem: NSMenuItem?
    @IBOutlet weak var toggleFullscreenMenuItem: NSMenuItem?
    @IBOutlet weak var zoomInMenuItem: NSMenuItem?
    @IBOutlet weak var zoomOutMenuItem: NSMenuItem?
    @IBOutlet weak var actualSizeMenuItem: NSMenuItem?

    // MARK: - Bookmarks
    @IBOutlet weak var manageBookmarksMenuItem: NSMenuItem!
    @IBOutlet weak var bookmarksMenuToggleBookmarksBarMenuItem: NSMenuItem?
    @IBOutlet weak var importBookmarksMenuItem: NSMenuItem!
    @IBOutlet weak var bookmarksMenuItem: NSMenuItem?
    @IBOutlet weak var bookmarkThisPageMenuItem: NSMenuItem?
    @IBOutlet weak var favoritesMenuItem: NSMenuItem?
    @IBOutlet weak var favoriteThisPageMenuItem: NSMenuItem?

    @IBOutlet weak var toggleBookmarksBarMenuItem: NSMenuItem?
    @IBOutlet weak var toggleAutofillShortcutMenuItem: NSMenuItem?
    @IBOutlet weak var toggleBookmarksShortcutMenuItem: NSMenuItem?
    @IBOutlet weak var toggleDownloadsShortcutMenuItem: NSMenuItem?
    @IBOutlet weak var toggleNetworkProtectionShortcutMenuItem: NSMenuItem?

    // MARK: - Debug

    @IBOutlet weak var debugMenuItem: NSMenuItem?

    private func setupDebugMenuItem(with featureFlagger: FeatureFlagger) {
        guard let debugMenuItem else {
            assertionFailure("debugMenuItem missing")
            return
        }

#if !DEBUG && !REVIEW
        guard featureFlagger.isFeatureOn(.debugMenu) else {
            removeItem(debugMenuItem)
            self.debugMenuItem = nil
            return
        }
#endif

        if debugMenuItem.submenu?.items.contains(loggingMenuItem) == false {
            debugMenuItem.submenu!.addItem(loggingMenuItem)
        }
    }

    @IBOutlet weak var networkProtectionPreferredServerLocationItem: NSMenuItem?
    @IBOutlet weak var networkProtectionRegistrationKeyValidityMenuSeparatorItem: NSMenuItem?
    @IBOutlet weak var networkProtectionRegistrationKeyValidityMenuItem: NSMenuItem?

    // MARK: - Help
    @IBOutlet weak var helpMenuItem: NSMenuItem?
    @IBOutlet weak var helpSeparatorMenuItem: NSMenuItem?
    @IBOutlet weak var sendFeedbackMenuItem: NSMenuItem?

    private func setupHelpMenuItem() {
#if !FEEDBACK
        guard let sendFeedbackMenuItem else { return }

        sendFeedbackMenuItem.isHidden = true
#endif
    }

    let sharingMenu = SharingMenu()

    // MARK: - Lifecycle

    @MainActor
    override func update() {
        super.update()

        // Make sure Spotlight search is part of Help menu
        if NSApplication.shared.helpMenu != helpMenuItem?.submenu {
            NSApplication.shared.helpMenu = helpMenuItem?.submenu
        }

        if !WKWebView.canPrint {
            printMenuItem?.removeFromParent()
            printSeparatorItem?.removeFromParent()
        }

#if APPSTORE
        checkForUpdatesMenuItem?.removeFromParent()
        checkForUpdatesSeparatorItem?.removeFromParent()
#endif

        sharingMenu.title = shareMenuItem.title
        shareMenuItem.submenu = sharingMenu

        updateBookmarksBarMenuItem()
        updateShortcutMenuItems()

        updateNetworkProtectionServerListMenuItems()
        updateNetworkProtectionRegistrationKeyValidityMenuItems()

        updateLoggingMenuItems()
        updateBurnerWindowMenuItem()
    }

    @MainActor
    func setup(with featureFlagger: FeatureFlagger) {
        self.delegate = self

#if APPSTORE
        checkForUpdatesMenuItem?.removeFromParent()
        checkForUpdatesSeparatorItem?.removeFromParent()
#endif

        setupHelpMenuItem()
        setupDebugMenuItem(with: featureFlagger)
        subscribeToBookmarkList()
        subscribeToFavicons()
        updateBurnerWindowMenuItem()
    }

    // MARK: - Bookmarks

    var faviconsCancellable: AnyCancellable?
    private func subscribeToFavicons() {
        faviconsCancellable = FaviconManager.shared.$faviconsLoaded
            .receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] loaded in
                if loaded {
                    self?.updateFavicons(self?.bookmarksMenuItem)
                    self?.updateFavicons(self?.favoritesMenuItem)
                }
        })
    }

    private func updateFavicons(_ menuItem: NSMenuItem?) {
        if let bookmark = menuItem?.representedObject as? Bookmark {
            menuItem?.image = BookmarkViewModel(entity: bookmark).menuFavicon
        }
        menuItem?.submenu?.items.forEach { menuItem in
            updateFavicons(menuItem)
        }
    }

    var bookmarkListCancellable: AnyCancellable?
    private func subscribeToBookmarkList() {
        bookmarkListCancellable = LocalBookmarkManager.shared.$list
            .compactMap({
                let favorites = $0?.favoriteBookmarks.compactMap(BookmarkViewModel.init(entity:)) ?? []
                let topLevelEntities = $0?.topLevelEntities.compactMap(BookmarkViewModel.init(entity:)) ?? []

                return (favorites, topLevelEntities)
            })
            .receive(on: DispatchQueue.main).sink { [weak self] favorites, topLevel in
                self?.updateBookmarksMenu(favoriteViewModels: favorites, topLevelBookmarkViewModels: topLevel)
            }
    }

    // Nested recursing functions cause body length
    // swiftlint:disable function_body_length
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

        guard let bookmarksMenu = bookmarksMenuItem?.submenu,
              let favoritesSeparatorIndex = bookmarksMenu.items.lastIndex(where: { $0.isSeparatorItem }),
              let favoritesMenuItem = favoritesMenuItem,
              let favoritesMenu = favoritesMenuItem.submenu,
              let favoriteThisPageSeparatorIndex = favoritesMenu.items.lastIndex(where: { $0.isSeparatorItem }) else {
            os_log("MainMenuManager: Failed to reference bookmarks menu items", type: .error)
            return
        }

        let cleanedBookmarkItems = bookmarksMenu.items.dropLast(bookmarksMenu.items.count - (favoritesSeparatorIndex + 1))
        let bookmarkItems = bookmarkMenuItems(from: topLevelBookmarkViewModels)
        bookmarksMenu.items = Array(cleanedBookmarkItems) + bookmarkItems

        let cleanedFavoriteItems = favoritesMenu.items.dropLast(favoritesMenu.items.count - (favoriteThisPageSeparatorIndex + 1))
        let favoriteItems = favoriteMenuItems(from: favoriteViewModels)
        favoritesMenu.items = Array(cleanedFavoriteItems) + favoriteItems
    }
    // swiftlint:enable function_body_length

    private func updateBookmarksBarMenuItem() {
        let title = PersistentAppInterfaceSettings.shared.showBookmarksBar ? UserText.hideBookmarksBar : UserText.showBookmarksBar
        toggleBookmarksBarMenuItem?.title = title
        bookmarksMenuToggleBookmarksBarMenuItem?.title = title
    }

    private func updateShortcutMenuItems() {
        toggleAutofillShortcutMenuItem?.title = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .autofill)
        toggleBookmarksShortcutMenuItem?.title = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .bookmarks)
        toggleDownloadsShortcutMenuItem?.title = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .downloads)
        toggleNetworkProtectionShortcutMenuItem?.title = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .networkProtection)
    }

    private func updateNetworkProtectionServerListMenuItems() {
        guard let submenu = networkProtectionPreferredServerLocationItem?.submenu, let automaticItem = submenu.items.first else {
            assertionFailure("\(#function): Failed to get submenu")
            return
        }

        let networkProtectionServerStore = NetworkProtectionServerListFileSystemStore(errorEvents: nil)
        let servers = (try? networkProtectionServerStore.storedNetworkProtectionServerList()) ?? []

        if servers.isEmpty {
            submenu.items = [automaticItem]
        } else {
            submenu.items = [automaticItem, NSMenuItem.separator()] + servers.map({ server in
                let title: String

                if server.isRegistered {
                    title = "\(server.serverInfo.name) (\(server.serverInfo.serverLocation) – Public Key Registered)"
                } else {
                    title = "\(server.serverInfo.name) (\(server.serverInfo.serverLocation))"
                }

                return NSMenuItem(title: title, action: automaticItem.action, keyEquivalent: "")
            })
        }
    }

    private struct NetworkProtectionKeyValidityOption {
        let title: String
        let validity: TimeInterval
    }

    private static let networkProtectionRegistrationKeyValidityOptions: [NetworkProtectionKeyValidityOption] = [
        .init(title: "15 seconds", validity: .seconds(15)),
        .init(title: "30 seconds", validity: .seconds(30)),
        .init(title: "1 minute", validity: .minutes(1)),
        .init(title: "5 minutes", validity: .minutes(5)),
        .init(title: "30 minutes", validity: .minutes(30)),
        .init(title: "1 hour", validity: .hours(1))
    ]

    private func updateNetworkProtectionRegistrationKeyValidityMenuItems() {
        #if DEBUG
        guard let submenu = networkProtectionRegistrationKeyValidityMenuItem?.submenu,
              let automaticItem = submenu.items.first else {

            assertionFailure("\(#function): Failed to get submenu")
            return
        }

        if Self.networkProtectionRegistrationKeyValidityOptions.isEmpty {
            // Not likely to happen as it's hard-coded, but still...
            submenu.items = [automaticItem]
        } else {
            submenu.items = [automaticItem, NSMenuItem.separator()] + Self.networkProtectionRegistrationKeyValidityOptions.map { option in
                let menuItem = NSMenuItem(title: option.title, action: automaticItem.action, keyEquivalent: "")
                menuItem.representedObject = option.validity
                return menuItem
            }
        }
        #else
        guard let separator = networkProtectionRegistrationKeyValidityMenuSeparatorItem,
              let validityMenu = networkProtectionRegistrationKeyValidityMenuItem else {
            assertionFailure("\(#function): Failed to get submenu")
            return
        }

        separator.isHidden = true
        validityMenu.isHidden = true
        #endif
    }

    @MainActor
    private func updateBurnerWindowMenuItem() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
           !appDelegate.internalUserDecider.isInternalUser {
            newBurnerWindowMenuItem.isHidden = true
        }
    }

    // MARK: - Logging

    private lazy var loggingMenuItem: NSMenuItem = {
        let menuItem = NSMenuItem(title: "Logging")
        menuItem.submenu = loggingMenu
        return menuItem
    }()

    private lazy var loggingMenu: NSMenu = {
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

        return menu
    }()

    private func updateLoggingMenuItems() {
        guard debugMenuItem != nil else { return }

        let enabledCategories = OSLog.loggingCategories
        for item in loggingMenu.items {
            guard let category = item.identifier.map(\.rawValue) else { continue }

            item.state = enabledCategories.contains(category) ? .on : .off
        }
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

extension MainMenu: NSMenuDelegate {

    func menuHasKeyEquivalent(_ menu: NSMenu,
                              for event: NSEvent,
                              target: AutoreleasingUnsafeMutablePointer<AnyObject?>,
                              action: UnsafeMutablePointer<Selector?>) -> Bool {
#if DEBUG
        if NSApp.isRunningUnitTests { return false }
#endif
        sharingMenu.update()
        shareMenuItem.submenu = sharingMenu
        return false
    }

}
