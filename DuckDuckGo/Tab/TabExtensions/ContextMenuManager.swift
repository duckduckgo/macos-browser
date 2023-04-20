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
import WebKit

enum NavigationDecision {
    case allow(NewWindowPolicy)
    case cancel
}

@MainActor
final class ContextMenuManager: NSObject {
    private var userScriptCancellable: AnyCancellable?

    private var onNewWindow: ((WKNavigationAction?) -> NavigationDecision)?
    private var originalItems: [WKMenuItemIdentifier: NSMenuItem]?
    private var selectedText: String?
    fileprivate weak var webView: WKWebView?

    @MainActor
    init(contextMenuScriptPublisher: some Publisher<ContextMenuUserScript?, Never>) {
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

    private var isCurrentWindowDisposable: Bool {
        (webView?.window?.windowController as? MainWindowController)?.mainViewController.isDisposable ?? false
    }

    private func handleOpenLinkItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        guard let openLinkInNewWindowItem = originalItems?[.openLinkInNewWindow] else {
            assertionFailure("WKMenuItemIdentifierOpenLinkInNewWindow item not found")
            return
        }

        menu.replaceItem(at: index, with: self.openLinkInNewTabMenuItem(from: openLinkInNewWindowItem,
                                                                            makeDisposable: isCurrentWindowDisposable))
    }

    private func handleOpenLinkInNewWindowItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.replaceItem(at: index, with: self.openLinkInNewWindowMenuItem(from: item, makeDisposable: isCurrentWindowDisposable))
    }

    private func handleOpenFrameInNewWindowItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.replaceItem(at: index, with: self.openFrameInNewWindowMenuItem(from: item, makeDisposable: isCurrentWindowDisposable))
    }

    private func handleDownloadLinkedFileItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.replaceItem(at: index, with: self.downloadMenuItem(from: item))
    }

    private func handleCopyLinkItem(_ copyLinkItem: NSMenuItem, at index: Int, in menu: NSMenu) {
        guard let openLinkInNewWindowItem = originalItems?[.openLinkInNewWindow] else {
            assertionFailure("WKMenuItemIdentifierOpenLinkInNewWindow item not found")
            return
        }
        // insert Add Link to Bookmarks
        menu.insertItem(self.addLinkToBookmarksMenuItem(from: openLinkInNewWindowItem), at: index)
        menu.replaceItem(at: index + 1, with: self.copyLinkMenuItem(withTitle: copyLinkItem.title, from: openLinkInNewWindowItem))

        // insert Separator and Copy (selection) items
        if selectedText?.isEmpty == false {
            menu.insertItem(.separator(), at: index + 2)
            menu.insertItem(self.copySelectionMenuItem(), at: index + 3)
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
        menu.insertItem(self.openImageInNewTabMenuItem(from: item, makeDisposable: isCurrentWindowDisposable), at: index)
        menu.replaceItem(at: index + 1, with: self.openImageInNewWindowMenuItem(from: item, makeDisposable: isCurrentWindowDisposable))
    }

    private func handleDownloadImageItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.replaceItem(at: index, with: self.downloadImageMenuItem(from: item))
    }

    private func handleSearchWebItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.replaceItem(at: index, with: self.searchMenuItem(makeDisposable: isCurrentWindowDisposable))
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
            self?.originalItems = nil
        }
    }
}

// MARK: - Make Context Menu Items
private extension ContextMenuManager {

    func openLinkInNewTabMenuItem(from item: NSMenuItem, makeDisposable: Bool) -> NSMenuItem {
        let title = makeDisposable ? UserText.openLinkInNewDisposableTab : UserText.openLinkInNewTab
        let action = makeDisposable ? #selector(openLinkInNewDisposableTab) : #selector(openLinkInNewTab)
        return makeMenuItem(withTitle: title, action: action, from: item, with: .openLinkInNewWindow)
    }

    func addLinkToBookmarksMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: UserText.addLinkToBookmarks, action: #selector(addLinkToBookmarks), from: item, with: .openLinkInNewWindow, keyEquivalent: "")
    }

    func bookmarkPageMenuItem() -> NSMenuItem {
        NSMenuItem(title: UserText.bookmarkPage, action: #selector(MainViewController.bookmarkThisPage), target: nil, keyEquivalent: "")
    }

    func openLinkInNewWindowMenuItem(from item: NSMenuItem, makeDisposable: Bool) -> NSMenuItem {
        let title = makeDisposable ? UserText.openLinkInNewDisposableWindow : item.title
        let action = makeDisposable ? #selector(openLinkInNewDisposableWindow) : #selector(openLinkInNewWindow)
        return makeMenuItem(withTitle: title, action: action, from: item, with: .openLinkInNewWindow)
    }

    func openFrameInNewWindowMenuItem(from item: NSMenuItem, makeDisposable: Bool) -> NSMenuItem {
        let title = makeDisposable ? UserText.openFrameInNewDisposableWindow : item.title
        let action = makeDisposable ? #selector(openFrameInNewDisposableWindow) : #selector(openFrameInNewWindow)
        return makeMenuItem(withTitle: title, action: action, from: item, with: .openFrameInNewWindow)
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

    func copyLinkMenuItem(withTitle title: String, from openLinkItem: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: title, action: #selector(copyLink), from: openLinkItem, with: .openLinkInNewWindow)
    }

    func copySelectionMenuItem() -> NSMenuItem {
        NSMenuItem(title: UserText.copySelection, action: #selector(copySelection), target: self)
    }

    func copyImageAddressMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: UserText.copyImageAddress, action: #selector(copyImageAddress), from: item, with: .openImageInNewWindow, keyEquivalent: "")
    }

    func openImageInNewTabMenuItem(from item: NSMenuItem, makeDisposable: Bool) -> NSMenuItem {
        let title = makeDisposable ? UserText.openImageInNewDisposableTab : UserText.openImageInNewTab
        let action = makeDisposable ? #selector(openImageInNewDisposableTab) : #selector(openImageInNewTab)
        return makeMenuItem(withTitle: title, action: action, from: item, with: .openImageInNewWindow, keyEquivalent: "")
    }

    func openImageInNewWindowMenuItem(from item: NSMenuItem, makeDisposable: Bool) -> NSMenuItem {
        let title = makeDisposable ? UserText.openImageInNewDisposableWindow : item.title
        let action = makeDisposable ? #selector(openImageInNewDisposableWindow) : #selector(openImageInNewWindow)
        return makeMenuItem(withTitle: title, action: action, from: item, with: .openImageInNewWindow)
    }

    func downloadImageMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: UserText.saveImageAs, action: #selector(saveImageAs), from: item, with: .downloadImage)
    }

    func searchMenuItem(makeDisposable: Bool) -> NSMenuItem {
        let action = makeDisposable ? #selector(searchInDisposable) : #selector(search)
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

        return NSMenuItem(title: title, action: action, target: self, keyEquivalent: keyEquivalent ?? item.keyEquivalent, representedObject: item)
    }

}

// MARK: - Handle Context Menu Items
@objc extension ContextMenuManager {

    func search(_ sender: NSMenuItem) {
        searchCommon(sender, disposable: false)
    }

    func searchInDisposable(_ sender: NSMenuItem) {
        searchCommon(sender, disposable: true)
    }

    private func searchCommon(_ sender: NSMenuItem, disposable: Bool) {
        guard let selectedText,
              let url = URL.makeSearchUrl(from: selectedText),
              let webView
        else {
            assertionFailure("Failed to get search term")
            return
        }

        self.onNewWindow = { _ in
                .allow(.tab(selected: true, disposable: disposable))
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
        openLinkInNewTabCommon(sender, disposable: false)
    }

    func openLinkInNewDisposableTab(_ sender: NSMenuItem) {
        openLinkInNewTabCommon(sender, disposable: true)
    }

    private func openLinkInNewTabCommon(_ sender: NSMenuItem, disposable: Bool) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openLinkInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { _ in .allow(.tab(selected: false, disposable: disposable)) }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func openLinkInNewWindow(_ sender: NSMenuItem) {
        openLinkInNewWindowCommon(sender, disposable: false)
    }

    func openLinkInNewDisposableWindow(_ sender: NSMenuItem) {
        openLinkInNewWindowCommon(sender, disposable: true)
    }

    private func openLinkInNewWindowCommon(_ sender: NSMenuItem, disposable: Bool) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openLinkInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { _ in .allow(.window(active: true, disposable: disposable)) }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func openFrameInNewWindow(_ sender: NSMenuItem) {
        openFrameInNewWindowCommon(sender, disposable: false)
    }

    func openFrameInNewDisposableWindow(_ sender: NSMenuItem) {
        openFrameInNewWindowCommon(sender, disposable: true)
    }

    private func openFrameInNewWindowCommon(_ sender: NSMenuItem, disposable: Bool) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openFrameInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { _ in .allow(.window(active: true, disposable: disposable)) }
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

    func copyLink(_ sender: NSMenuItem) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openLinkInNewWindow,
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

    func openImageInNewTab(_ sender: NSMenuItem) {
        openImageInNewTabCommon(sender, disposable: false)
    }

    func openImageInNewDisposableTab(_ sender: NSMenuItem) {
        openImageInNewTabCommon(sender, disposable: true)
    }

    func openImageInNewTabCommon(_ sender: NSMenuItem, disposable: Bool) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openImageInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { _ in .allow(.tab(selected: true, disposable: disposable)) }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func openImageInNewWindow(_ sender: NSMenuItem) {
        openImageInNewWindowCommon(sender, disposable: false)
    }

    func openImageInNewDisposableWindow(_ sender: NSMenuItem) {
        openImageInNewWindowCommon(sender, disposable: true)
    }

    func openImageInNewWindowCommon(_ sender: NSMenuItem, disposable: Bool) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openImageInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { _ in .allow(.window(active: true, disposable: disposable)) }
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
    func willShowContextMenu(withSelectedText selectedText: String) {
        self.selectedText = selectedText
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
