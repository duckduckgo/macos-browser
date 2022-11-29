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
import Foundation
import WebKit

protocol ContextMenuManagerDelegate: AnyObject {
    func launchSearch(for text: String)
    func prepareForContextMenuDownload()
}


enum NewWindowPolicy {
    case newWindow
    case newTab(selected: Bool)
    case cancel
}

final class ContextMenuManager: NSObject {

    weak var delegate: ContextMenuManagerDelegate?

    private var onNewWindow: ((WKNavigationAction?) -> NewWindowPolicy)?
    private var askForDownloadLocation: Bool?

    private var selectedText: String?

    func decideNewWindowPolicy(for navigationAction: WKNavigationAction) -> NewWindowPolicy? {
        defer {
            onNewWindow = nil
        }
        return onNewWindow?(navigationAction)
    }

    func shouldAskForDownloadLocation() -> Bool? {
        defer {
            askForDownloadLocation = nil
        }
        return askForDownloadLocation
    }

}

// MARK: Context Menu Modification
extension ContextMenuManager {

    /// Defines which functions will handle matching WebKit Menu Items
    private static let menuItemHandlers: [WKMenuItemIdentifier: ((ContextMenuManager) -> (NSMenuItem, Int, NSMenu) -> Void)] = [
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

    private func handleOpenLinkItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.replaceItem(at: index, with: self.openLinkInNewTabMenuItem(from: item))
    }

    private func handleOpenLinkInNewWindowItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.replaceItem(at: index, with: self.openLinkInNewWindowMenuItem(from: item))
    }

    private func handleOpenFrameInNewWindowItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.replaceItem(at: index, with: self.openFrameInNewWindowMenuItem(from: item))
    }

    private func handleDownloadLinkedFileItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.replaceItem(at: index, with: self.downloadMenuItem(from: item))
    }

    private func handleCopyLinkItem(_ copyLinkItem: NSMenuItem, at index: Int, in menu: NSMenu) {
        guard let openLinkItem = menu.item(with: .openLinkInNewWindow) else {
            assertionFailure("WKMenuItemIdentifierCopyLink item not found")
            return
        }
        menu.insertItem(self.addLinkToBookmarksMenuItem(from: openLinkItem), at: index)
        menu.replaceItem(at: index + 1, with: self.copyLinkMenuItem(withTitle: copyLinkItem.title, from: openLinkItem))
    }

    private func handleCopyImageItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.insertItem(.separator(), at: index)

        guard let openImageInNewWindowItem = menu.item(with: .openImageInNewWindow) else {
            assertionFailure("WKMenuItemIdentifierOpenImageInNewWindow item not found")
            return
        }
        menu.insertItem(self.copyImageAddressMenuItem(from: openImageInNewWindowItem), at: index + 1)
    }

    private func handleOpenImageInNewWindowItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.insertItem(self.openImageInNewTabMenuItem(from: item), at: index)
        menu.replaceItem(at: index + 1, with: self.openImageInNewWindowMenuItem(from: item))
    }

    private func handleDownloadImageItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.replaceItem(at: index, with: self.downloadImageMenuItem(from: item))
    }

    private func handleSearchWebItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.replaceItem(at: index, with: self.searchMenuItem())
    }

    private func handleReloadItem(_ item: NSMenuItem, at index: Int, in menu: NSMenu) {
        menu.insertItem(self.bookmarkPageMenuItem(), at: index + 1)
    }

}

// MARK: - NSMenuDelegate
extension ContextMenuManager: WebViewContextMenuDelegate {

    func webView(_ webView: WebView, willOpenContextMenu menu: NSMenu, with event: NSEvent) {
        for (index, item) in menu.items.enumerated().reversed() {
            guard let identifier = item.identifier.flatMap(WKMenuItemIdentifier.init) else { continue }
            Self.menuItemHandlers[identifier]?(self)(item, index, menu)
        }
    }

    func webView(_ webView: WebView, didCloseContextMenu menu: NSMenu, with event: NSEvent?) {
        DispatchQueue.main.async { [weak self] in
            self?.selectedText = nil
        }
    }

}

// MARK: - Make Context Menu Items
private extension ContextMenuManager {

    func openLinkInNewTabMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: UserText.openLinkInNewTab, action: #selector(openLinkInNewTab), from: item, with: .openLink)
    }

    func addLinkToBookmarksMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: UserText.addLinkToBookmarks, action: #selector(addLinkToBookmarks), from: item, with: .openLinkInNewWindow, keyEquivalent: "")
    }

    func bookmarkPageMenuItem() -> NSMenuItem {
        NSMenuItem(title: UserText.bookmarkPage, action: #selector(MainViewController.bookmarkThisPage), target: nil, keyEquivalent: "")
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

    func copyLinkMenuItem(withTitle title: String, from openLinkItem: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: title, action: #selector(copyLink), from: openLinkItem, with: .openLinkInNewWindow)
    }

    func copyImageAddressMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: UserText.copyImageAddress, action: #selector(copyImageAddress), from: item, with: .openImageInNewWindow, keyEquivalent: "")
    }

    func openImageInNewTabMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: UserText.openImageInNewTab, action: #selector(openImageInNewTab), from: item, with: .openImageInNewWindow, keyEquivalent: "")
    }

    func openImageInNewWindowMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: item.title, action: #selector(openImageInNewWindow), from: item, with: .openImageInNewWindow)
    }

    func downloadImageMenuItem(from item: NSMenuItem) -> NSMenuItem {
        makeMenuItem(withTitle: UserText.saveImageAs, action: #selector(saveImageAs), from: item, with: .downloadImage)
    }

    func searchMenuItem() -> NSMenuItem {
        NSMenuItem(title: UserText.searchWithDuckDuckGo, action: #selector(search), target: self)
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
        guard let selectedText = selectedText else {
            assertionFailure("Failed to get search term")
            return
        }

        delegate?.launchSearch(for: selectedText)
    }

    func openLinkInNewTab(_ sender: NSMenuItem) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openLink,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { _ in .newTab(selected: false) }
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

        onNewWindow = { _ in .newWindow }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func openFrameInNewWindow(_ sender: NSMenuItem) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openFrameInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { _ in .newWindow }
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

        delegate?.prepareForContextMenuDownload()
        askForDownloadLocation = true
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func addLinkToBookmarks(_ sender: NSMenuItem) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openLink,
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
            guard let url = navigationAction?.request.url as NSURL? else { return .cancel }

            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.URL], owner: nil)
            url.write(to: pasteboard)
            pasteboard.setString(url.absoluteString ?? "", forType: .string)

            return .cancel
        }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func openImageInNewTab(_ sender: NSMenuItem) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openImageInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { _ in .newTab(selected: true) }
        NSApp.sendAction(action, to: originalItem.target, from: originalItem)
    }

    func openImageInNewWindow(_ sender: NSMenuItem) {
        guard let originalItem = sender.representedObject as? NSMenuItem,
              let identifier = originalItem.identifier.map(WKMenuItemIdentifier.init),
              identifier == .openImageInNewWindow,
              let action = originalItem.action
        else {
            assertionFailure("Original WebKit Menu Item is missing")
            return
        }

        onNewWindow = { _ in .newWindow }
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

        delegate?.prepareForContextMenuDownload()
        askForDownloadLocation = true
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
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
            NSPasteboard.general.setString(url.absoluteString, forType: .URL)

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
