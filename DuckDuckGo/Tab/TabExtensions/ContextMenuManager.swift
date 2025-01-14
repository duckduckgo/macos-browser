//
//  ContextMenuManager.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import AppKit
import Combine
import Foundation
import WebKitExtensions

enum NavigationDecision {
    case allow(NewWindowPolicy)
    case cancel

    /**
     * Replaces `.tab` with `.window` when user prefers windows over tabs.
     */
    func preferringTabsToWindows(_ prefersTabsToWindows: Bool) -> NavigationDecision {
        guard case .allow(let targetKind) = self, !prefersTabsToWindows else {
            return self
        }
        return .allow(targetKind.preferringTabsToWindows(prefersTabsToWindows))
    }
}

@MainActor
final class ContextMenuManager: NSObject {
    private var userScriptCancellable: AnyCancellable?

    private var onNewWindow: ((WKNavigationAction?) -> NavigationDecision)?
    private var originalItems: [WKMenuItemIdentifier: NSMenuItem]?
    private var selectedText: String?
    private var linkURL: String?

    private var tabsPreferences: TabsPreferences

    private var isEmailAddress: Bool {
        guard let linkURL, let url = URL(string: linkURL) else {
            return false
        }
        return url.navigationalScheme == .mailto
    }

    private var isWebViewSupportedScheme: Bool {
        guard let linkURL, let scheme = URL(string: linkURL)?.scheme else {
            return false
        }
        return WKWebView.handlesURLScheme(scheme)
    }

    fileprivate weak var webView: WKWebView?

    @MainActor
    init(contextMenuScriptPublisher: some Publisher<ContextMenuUserScript?, Never>,
         tabsPreferences: TabsPreferences = TabsPreferences.shared) {
        self.tabsPreferences = tabsPreferences
        super.init()

        userScriptCancellable = contextMenuScriptPublisher.sink { [weak self] contextMenuScript in
            contextMenuScript?.delegate = self
        }
    }

}

extension ContextMenuManager: NewWindowPolicyDecisionMaker {

    func decideNewWindowPolicy(for navigationAction: WKNavigationAction) -> NavigationDecision? {
        defer {
            onNewWindow = nil
        }
        return onNewWindow?(navigationAction)
    }

}

// MARK: Context Menu Modification
extension ContextMenuManager {

    /// Defines which functions will handle matching WebKit Menu Items
    private static let menuItemHandlers: [WKMenuItemIdentifier: ((ContextMenuManager) -> @MainActor (NSMenuItem, Int, NSMenu) -> Void)] = [
        .openLink: handleOpenLinkItem,
        .openLinkInNewWindow: handleOpenLinkInNewWindowItem,
        .downloadLinkedFile: handleDownloadLinkedFileItem,
        .downloadMedia: handleDownloadLinkedFileItem,
        .copyLink: handleCopyLinkItem,
        .copyImage: handleCopyImageItem,
        .openImageInNewWindow: handleOpenImageInNewWindowItem,
        .downloadImage: handleDownloadImageItem,
        .searchWeb: handleSearchWebItem,
        .reload: handleReloadItem,
        .openFrameInNewWindow: handleOpenFrameInNewWindowItem
    ]

    private var isCurrentWindowBurner: Bool {
        (webView?.window?.windowController as? MainWindowController)?.mainViewController.isBurner ?? false
    }

    private func handleOpenLinkItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        guard let openLinkInNewWindowItem = originalItems?[.openLinkInNewWindow] else {
            assertionFailure("WKMenuItemIdentifierOpenLinkInNewWindow item not found")
            return
        }

        if isEmailAddress {
            menu.removeItem(at: index)
        } else if isWebViewSupportedScheme {
            menu.replaceItem(at: index, with: self.openLinkInNewTabMenuItem(from: openLinkInNewWindowItem,
                                                                            makeBurner: isCurrentWindowBurner))
        }
    }

    private func handleOpenLinkInNewWindowItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        if isCurrentWindowBurner || !isWebViewSupportedScheme {
            menu.removeItem(at: index)
        } else {
            menu.replaceItem(at: index, with: self.openLinkInNewWindowMenuItem(from: item))
        }
    }

    private func handleOpenFrameInNewWindowItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        if isCurrentWindowBurner || !isWebViewSupportedScheme {
            menu.removeItem(at: index)
        } else {
            menu.replaceItem(at: index, with: self.openFrameInNewWindowMenuItem(from: item))
        }
    }

    private func handleDownloadLinkedFileItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        if isWebViewSupportedScheme {
            menu.replaceItem(at: index, with: self.downloadMenuItem(from: item))
        } else {
            menu.removeItem(at: index)
        }
    }

    private func handleCopyLinkItem(_ copyLinkItem: NSMenuItem, at index: Int, in menu: NSMenu) {
        guard let openLinkInNewWindowItem = originalItems?[.openLinkInNewWindow] else {
            assertionFailure("WKMenuItemIdentifierOpenLinkInNewWindow item not found")
            return
        }

        var currentIndex = index

        if isWebViewSupportedScheme {
            // insert Add Link to Bookmarks
            menu.insertItem(self.addLinkToBookmarksMenuItem(from: openLinkInNewWindowItem), at: currentIndex)
            menu.replaceItem(at: currentIndex + 1, with: self.copyLinkOrEmailAddressMenuItem(withTitle: copyLinkItem.title, from: openLinkInNewWindowItem))
            currentIndex += 2
        } else if isEmailAddress {
            let emailAddresses = linkURL.flatMap(URL.init(string:))?.emailAddresses ?? []
            let title = emailAddresses.count > 1 ? UserText.copyEmailAddresses : UserText.copyEmailAddress
            menu.replaceItem(at: currentIndex, with: self.copyLinkOrEmailAddressMenuItem(withTitle: title, from: openLinkInNewWindowItem))
            currentIndex += 1
        }

        // insert Separator and Copy (selection) items
        if selectedText?.isEmpty == false {
            menu.insertItem(.separator(), at: currentIndex)
            menu.insertItem(self.copySelectionMenuItem(), at: currentIndex + 1)
        }
    }

    private func handleCopyImageItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.insertItem(.separator(), at: index)

        guard let openImageInNewWindowItem = originalItems?[.openImageInNewWindow]  else {
            assertionFailure("WKMenuItemIdentifierOpenImageInNewWindow item not found")
            return
        }
        menu.insertItem(self.copyImageAddressMenuItem(from: openImageInNewWindowItem), at: index + 1)
    }

    private func handleOpenImageInNewWindowItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.insertItem(self.openImageInNewTabMenuItem(from: item, makeBurner: isCurrentWindowBurner), at: index)
        if isCurrentWindowBurner {
            menu.removeItem(at: index + 1)
        } else {
            menu.replaceItem(at: index + 1, with: self.openImageInNewWindowMenuItem(from: item))
        }
    }

    private func handleDownloadImageItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.replaceItem(at: index, with: self.downloadImageMenuItem(from: item))
    }

    private func handleSearchWebItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.replaceItem(at: index, with: self.searchMenuItem(makeBurner: isCurrentWindowBurner))
    }

    private func handleReloadItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.insertItem(self.bookmarkPageMenuItem(), at: index + 1)
    }
}

// MARK: - NSMenuDelegate
extension ContextMenuManager: WebViewContextMenuDelegate {

    func webView(_ webView: WebView, willOpenContextMenu menu: NSMenu, with event: NSEvent) {

        originalItems = menu.items.reduce(into: [WKMenuItemIdentifier: NSMenuItem]()) { partialResult, item in
            if let identifier = item.identifier.flatMap(WKMenuItemIdentifier.init) {
                partialResult[identifier] = item
            }
        }

        self.webView = webView

        for (index, item) in menu.items.enumerated().reversed() {
            guard let identifier = item.identifier.flatMap(WKMenuItemIdentifier.init) else { continue }
            Self.menuItemHandlers[identifier]?(self)(item, index, menu)
        }
    }

    func webView(_ webView: WebView, didCloseContextMenu menu: NSMenu, with event: NSEvent?) {
        DispatchQueue.main.async { [weak self] in
            self?.selectedText = nil
            self?.linkURL = nil
            self?.originalItems = nil
        }
    }
}

// MARK: - Make Context Menu Items
private extension ContextMenuManager {

    func openLinkInNewTabMenuItem(from item: NSMenuItem, makeBurner: Bool) -> NSMenuItem {
        let title = makeBurner ? UserText.openLinkInNewBurnerTab : UserText.openLinkInNewTab
        let action = makeBurner ? #selector(openLinkInNewBurnerTab) : #selector(openLinkInNewTab)
        return makeMenuItem(withTitle: title, action: action, from: item, with: .openLinkInNewWindow)
    }

    func addLinkToBookmarksMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: UserText.addLinkToBookmarks, action: #selector(addLinkToBookmarks), from: item, with: .openLinkInNewWindow, keyEquivalent: "")
    }

    func bookmarkPageMenuItem() -> NSMenuItem {
        NSMenuItem(title: UserText.bookmarkPage, action: #selector(MainViewController.bookmarkThisPage), target: nil, keyEquivalent: "").withAccessibilityIdentifier("ContextMenuManager.bookmarkPageMenuItem")
    }

    func openLinkInNewWindowMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: item.title, action: #selector(openLinkInNewWindow), from: item, with: .openLinkInNewWindow)
    }

    func openFrameInNewWindowMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: item.title, action: #selector(openFrameInNewWindow), from: item, with: .openFrameInNewWindow)
    }

    private func downloadMenuItemTitle(for item: NSMenuItem) -> String {
        switch item.identifier.flatMap(WKMenuItemIdentifier.init) {
        case .downloadLinkedFile:
            return UserText.downloadLinkedFileAs
        default:
            return item.title
        }
    }
    func downloadMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: downloadMenuItemTitle(for: item),
                     action: #selector(downloadLinkedFileAs),
                     from: item,
                     withIdentifierIn: [.downloadLinkedFile, .downloadMedia])
    }

    func copyLinkOrEmailAddressMenuItem(withTitle title: String, from openLinkItem: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: title, action: #selector(copyLinkOrEmailAddress), from: openLinkItem, with: .openLinkInNewWindow)
    }

    func copySelectionMenuItem() -> NSMenuItem {
        NSMenuItem(title: UserText.copySelection, action: #selector(copySelection), target: self)
    }

    func copyImageAddressMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: UserText.copyImageAddress, action: #selector(copyImageAddress), from: item, with: .openImageInNewWindow, keyEquivalent: "")
    }

    func openImageInNewTabMenuItem(from item: NSMenuItem, makeBurner: Bool) -> NSMenuItem {
        let title = makeBurner ? UserText.openImageInNewBurnerTab : UserText.openImageInNewTab
        let action = makeBurner ? #selector(openImageInNewBurnerTab) : #selector(openImageInNewTab)
        return makeMenuItem(withTitle: title, action: action, from: item, with: .openImageInNewWindow, keyEquivalent: "")
    }

    func openImageInNewWindowMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: item.title, action: #selector(openImageInNewWindow), from: item, with: .openImageInNewWindow)
    }

    func downloadImageMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: UserText.saveImageAs, action: #selector(saveImageAs), from: item, with: .downloadImage)
    }

    func searchMenuItem(makeBurner: Bool) -> NSMenuItem {
        let action = makeBurner ? #selector(searchInBurner) : #selector(search)
        return NSMenuItem(title: UserText.searchWithDuckDuckGo, action: action, target: self)
    }

    private func makeMenuItem(withTitle title: String, action: Selector, from item: NSMenuItem, with identifier: WKMenuItemIdentifier, keyEquivalent: String? = nil) -> NSMenuItem {
        return makeMenuItem(withTitle: title, action: action, from: item, withIdentifierIn: [identifier], keyEquivalent: keyEquivalent)
    }

    /// Creates a new NSMenuItem and sets the Reference Menu Item as its representedObject
    /// Provided WKMenuItemIdentifier-s are here just to validate correctness of the Reference Item and avoid copy-pasting mistakes
    /// Reference Item‘s keyEquivalent is used if nil is provided, providing non-nil values may be useful for new items (not replacing the original item)
    private func makeMenuItem(withTitle title: String, action: Selector, from item: NSMenuItem, withIdentifierIn validIdentifiers: [WKMenuItemIdentifier], keyEquivalent: String? = nil) -> NSMenuItem {
        let identifier = item.identifier.flatMap(WKMenuItemIdentifier.init)
        assert(identifier != nil && validIdentifiers.contains(identifier!))

        return NSMenuItem(title: title, action: action, target: self, keyEquivalent: [.charCode(keyEquivalent ?? item.keyEquivalent)], representedObject: item)
    }

}

// MARK: - Handle Context Menu Items
@objc extension ContextMenuManager {

    func search(_ sender: NSMenuItem) {
        searchCommon(sender, burner: false)
    }

    func searchInBurner(_ sender: NSMenuItem) {
        searchCommon(sender, burner: true)
    }

    private func searchCommon(_ sender: NSMenuItem, burner: Bool) {
        guard let selectedText,
              let url = URL.makeSearchUrl(from: selectedText),
              let webView
        else {
            assertionFailure("Failed to get search term")
            return
        }

        self.onNewWindow = { _ in
            .allow(.tab(selected: true, burner: burner))
        }
        webView.loadInNewWindow(url)
    }

    func copySelection(_ sender: NSMenuItem) {
        guard let selectedText else {
            assertionFailure("Failed to get selected text")
            return
        }

        NSPasteboard.general.copy(selectedText)
    }

    func openLinkInNewTab(_ sender: NSMenuItem) {
        openLinkInNewTabCommon(sender, burner: false)
    }

    func openLinkInNewBurnerTab(_ sender: NSMenuItem) {
        openLinkInNewTabCommon(sender, burner: true)
    }

    private func openLinkInNewTabCommon(_ sender: NSMenuItem, burner: Bool) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openLinkInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { [weak self] _ in
            .allow(.tab(selected: self?.tabsPreferences.switchToNewTabWhenOpened ?? false, burner: burner, contextMenuInitiated: true))
        }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func openLinkInNewWindow(_ sender: NSMenuItem) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openLinkInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { _ in
            .allow(.window(active: true, burner: false))
        }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func openFrameInNewWindow(_ sender: NSMenuItem) {
        openFrameInNewWindowCommon(sender, burner: false)
    }

    func openFrameInNewBurnerWindow(_ sender: NSMenuItem) {
        openFrameInNewWindowCommon(sender, burner: true)
    }

    private func openFrameInNewWindowCommon(_ sender: NSMenuItem, burner: Bool) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openFrameInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { _ in .allow(.window(active: true, burner: burner)) }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func downloadLinkedFileAs(_ sender: NSMenuItem) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              [.downloadLinkedFile, .downloadMedia].contains(identifier),
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func addLinkToBookmarks(_ sender: NSMenuItem) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openLinkInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { [selectedText] navigationAction in
            guard let url = navigationAction?.request.url else { return .cancel }

            let title = selectedText ?? url.absoluteString
            LocalBookmarkManager.shared.makeBookmark(for: url, title: title, isFavorite: false)

            return .cancel
        }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func copyLinkOrEmailAddress(_ sender: NSMenuItem) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openLinkInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        let isEmailAddress = self.isEmailAddress

        onNewWindow = { navigationAction in
            guard let url = navigationAction?.request.url else { return .cancel }

            if isEmailAddress {
                let emailAddresses = url.emailAddresses
                if !emailAddresses.isEmpty {
                    NSPasteboard.general.copy(emailAddresses.joined(separator: ", "))
                }
            } else {
                NSPasteboard.general.copy(url)
            }

            return .cancel
        }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func openImageInNewTab(_ sender: NSMenuItem) {
        openImageInNewTabCommon(sender, burner: false)
    }

    func openImageInNewBurnerTab(_ sender: NSMenuItem) {
        openImageInNewTabCommon(sender, burner: true)
    }

    func openImageInNewTabCommon(_ sender: NSMenuItem, burner: Bool) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openImageInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { _ in
            .allow(.tab(selected: true, burner: burner))
        }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func openImageInNewWindow(_ sender: NSMenuItem) {
        openImageInNewWindowCommon(sender, burner: false)
    }

    func openImageInNewBurnerWindow(_ sender: NSMenuItem) {
        openImageInNewWindowCommon(sender, burner: true)
    }

    func openImageInNewWindowCommon(_ sender: NSMenuItem, burner: Bool) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openImageInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { _ in
            .allow(.window(active: true, burner: burner))
        }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func saveImageAs(_ sender: NSMenuItem) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .downloadImage,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func copyImageAddress(_ sender: NSMenuItem) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openImageInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { navigationAction in
            guard let url = navigationAction?.request.url else { return .cancel }

            NSPasteboard.general.copy(url)

            return .cancel
        }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

}

// MARK: - ContextMenuUserScriptDelegate
extension ContextMenuManager: ContextMenuUserScriptDelegate {
    func willShowContextMenu(withSelectedText selectedText: String?, linkURL: String?) {
        self.selectedText = selectedText
        self.linkURL = linkURL
    }
}

// MARK: - TabExtensions

protocol ContextMenuManagerProtocol: NewWindowPolicyDecisionMaker, WebViewContextMenuDelegate {
    func decideNewWindowPolicy(for navigationAction: WKNavigationAction) -> NavigationDecision?
}

extension ContextMenuManager: TabExtension, ContextMenuManagerProtocol {
    func getPublicProtocol() -> ContextMenuManagerProtocol { self }
}

extension TabExtensions {
    var contextMenuManager: ContextMenuManagerProtocol? {
        resolve(ContextMenuManager.self)
    }
}
