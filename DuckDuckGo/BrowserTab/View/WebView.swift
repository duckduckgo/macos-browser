//
//  WebView.swift
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
import WebKit
import os.log

final class WebView: WKWebView {

    static let itemSelectors: [NSUserInterfaceItemIdentifier: Selector] = [
        // Links
        .openLink: #selector(LinkMenuItemSelectors.openLinkInNewTab(_:)),
        .openLinkInNewWindow: #selector(LinkMenuItemSelectors.openLinkInNewWindow(_:)),
        .downloadLinkedFile: #selector(LinkMenuItemSelectors.downloadLinkedFile(_:)),

        // Images
        .openImageInNewWindow: #selector(ImageMenuItemSelectors.openImageInNewWindow(_:)),
        .downloadImage: #selector(ImageMenuItemSelectors.saveImageToDownloads(_:))
    ]

    static let itemTitles: [NSUserInterfaceItemIdentifier: String] = [
        .openLink: UserText.openLinkInNewTab
    ]

    // MARK: - Menu

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)

        updateActionsAndTitles(menu.items)

        menu.insertItemBeforeItemWithIdentifier(.openImageInNewWindow,
                                                title: UserText.openImageInNewTab,
                                                target: uiDelegate,
                                                selector: #selector(ImageMenuItemSelectors.openImageInNewTab(_:)))

        menu.insertSeparatorBeforeItemWithIdentifier(.copyImage)

        menu.insertItemBeforeItemWithIdentifier(.copyImage,
                                                title: UserText.copyImageAddress,
                                                target: uiDelegate,
                                                selector: #selector(ImageMenuItemSelectors.copyImageAddress(_:)))

    }

    private func updateActionsAndTitles(_ items: [NSMenuItem]) {
        items.forEach {
            guard let id = $0.identifier else { return }

            if let selector = Self.itemSelectors[id] {
                $0.target = uiDelegate
                $0.action = selector
            }

            if let title = Self.itemTitles[id] {
                $0.title = title
            }
        }
    }

}

fileprivate extension NSUserInterfaceItemIdentifier {
    static let openImageInNewWindow = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenImageInNewWindow")
    static let copyImage = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierCopyImage")
    static let downloadImage = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierDownloadImage")
    static let openLink = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenLink")
    static let openLinkInNewWindow = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenLinkInNewWindow")
    static let downloadLinkedFile = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierDownloadLinkedFile")
}

// MARK: - SessionState
extension WebView {

    private static let _restoreFromS = "_restoreFromS"
    private static let _s = "_s"
    private static let essionStateData = "essionStateData"

    struct DoesNotSupportRestoreFromSessionData: Error {}

    func sessionStateData() throws -> Data? {
        let sel = NSSelectorFromString(Self._s + Self.essionStateData)
        guard self.responds(to: sel) else { throw DoesNotSupportRestoreFromSessionData() }
        return self.perform(sel)?.takeUnretainedValue() as? Data
    }

    func restoreSessionState(from data: Data) throws {
        let sel = NSSelectorFromString(Self._restoreFromS + Self.essionStateData + ":")
        guard self.responds(to: sel) else { throw DoesNotSupportRestoreFromSessionData() }
        self.perform(sel, with: data as NSData)
    }

}
