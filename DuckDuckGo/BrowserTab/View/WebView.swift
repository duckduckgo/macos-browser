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

    static let itemSelectors: [String: Selector] = [
        // Links
        "WKMenuItemIdentifierOpenLink": #selector(LinkMenuItemSelectors.openLinkInNewTab(_:)),
        "WKMenuItemIdentifierOpenLinkInNewWindow": #selector(LinkMenuItemSelectors.openLinkInNewWindow(_:)),
        "WKMenuItemIdentifierDownloadLinkedFile": #selector(LinkMenuItemSelectors.downloadLinkedFileAs(_:)),
        "WKMenuItemIdentifierCopyLink": #selector(LinkMenuItemSelectors.copyLink(_:)),

        // Images
        "WKMenuItemIdentifierOpenImageInNewWindow": #selector(ImageMenuItemSelectors.openImageInNewWindow(_:)),
        "WKMenuItemIdentifierDownloadImage": #selector(ImageMenuItemSelectors.saveImageAs(_:)),

        "WKMenuItemIdentifierSearchWeb": #selector(MenuItemSelectors.search(_:))
    ]

    static let itemTitles: [String: String] = [
        "WKMenuItemIdentifierOpenLink": UserText.openLinkInNewTab,
        "WKMenuItemIdentifierDownloadImage": UserText.saveImageAs,
        "WKMenuItemIdentifierDownloadLinkedFile": UserText.downloadLinkedFileAs,
        "WKMenuItemIdentifierSearchWeb": UserText.searchWithDuckDuckGo
    ]

    static private let maxMagnification: CGFloat = 3.0
    static private let minMagnification: CGFloat = 0.5
    static private let magnificationStep: CGFloat = 0.1

    var canZoomToActualSize: Bool {
        self.window != nil && self.magnification != 1.0
    }

    var canZoomIn: Bool {
        self.window != nil && self.magnification < Self.maxMagnification
    }

    var canZoomOut: Bool {
        self.window != nil && self.magnification > Self.minMagnification
    }

    func zoomIn() {
        guard canZoomIn else { return }
        self.magnification = min(self.magnification + Self.magnificationStep, Self.maxMagnification)
    }

    func zoomOut() {
        guard canZoomOut else { return }
        self.magnification = max(self.magnification - Self.magnificationStep, Self.minMagnification)
    }

    deinit {
        self.configuration.userContentController.removeAllUserScripts()
    }

    // MARK: - Menu

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)

        updateActionsAndTitles(menu.items)

        menu.insertItemBeforeItemWithIdentifier("WKMenuItemIdentifierOpenLinkInNewWindow",
                                                title: "Open Link in Burner Tab",
                                                target: uiDelegate,
                                                selector: #selector(LinkMenuItemSelectors.openLinkInBurnerTab(_:)))

        menu.insertItemBeforeItemWithIdentifier("WKMenuItemIdentifierOpenImageInNewWindow",
                                                title: UserText.openImageInNewTab,
                                                target: uiDelegate,
                                                selector: #selector(ImageMenuItemSelectors.openImageInNewTab(_:)))

        menu.insertSeparatorBeforeItemWithIdentifier("WKMenuItemIdentifierCopyImage")

        menu.insertItemBeforeItemWithIdentifier("WKMenuItemIdentifierCopyImage",
                                                title: UserText.copyImageAddress,
                                                target: uiDelegate,
                                                selector: #selector(ImageMenuItemSelectors.copyImageAddress(_:)))

        // calling .menuWillOpen here manually as it's already calling the latter Menu Owner's willOpenMenu at this point
        (uiDelegate as? NSMenuDelegate)?.menuWillOpen?(menu)
    }

    private func updateActionsAndTitles(_ items: [NSMenuItem]) {
        items.forEach {
            guard let id = $0.identifier?.rawValue else { return }

            if let selector = Self.itemSelectors[id] {
                $0.target = uiDelegate
                $0.action = selector
            }

            if let title = Self.itemTitles[id] {
                $0.title = title
            }
        }
    }

    // MARK: - Developer Tools

    @nonobjc var mainFrame: AnyObject? {
        guard self.responds(to: NSSelectorFromString("_mainFrame")) else {
            assertionFailure("WKWebView does not respond to _mainFrame")
            return nil
        }
        return self.perform(NSSelectorFromString("_mainFrame"))?.takeUnretainedValue()
    }

    @discardableResult
    private func inspectorPerform(_ selectorName: String, with object: Any? = nil) -> Unmanaged<AnyObject>? {
        guard self.responds(to: NSSelectorFromString("_inspector")),
              let inspector = self.value(forKey: "_inspector") as? NSObject,
              inspector.responds(to: NSSelectorFromString(selectorName)) else {
            assertionFailure("_WKInspector does not respond to \(selectorName)")
            return nil
        }
        return inspector.perform(NSSelectorFromString(selectorName), with: object)
    }

    var isInspectorShown: Bool {
        guard let result = inspectorPerform("isVisible") else { return false }
        return result.toOpaque() == UnsafeMutableRawPointer(bitPattern: 0x1)
    }

    @nonobjc func openDeveloperTools() {
        inspectorPerform("show")
    }

    @nonobjc func closeDeveloperTools() {
        inspectorPerform("close")
    }

    @nonobjc func openJavaScriptConsole() {
        inspectorPerform("showConsole")
    }

    @nonobjc func showPageSource() {
        guard let mainFrameHandle = self.mainFrame else { return }
        inspectorPerform("showMainResourceForFrame:", with: mainFrameHandle)
    }

    @nonobjc func showPageResources() {
        inspectorPerform("showResources")
    }

}
