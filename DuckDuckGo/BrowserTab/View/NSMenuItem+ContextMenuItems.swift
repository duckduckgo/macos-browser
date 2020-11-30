//
//  NSMenuItem+ContextMenuItems.swift
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

class URLContextMenuItem: NSMenuItem {

    var url: URL?

}

// swiftlint:disable line_length
extension NSMenuItem {

    static let contextMenuBack = NSMenuItem(title: UserText.navigateBack, action: #selector(NavigationMenuItemSelectors.back(_:)), keyEquivalent: "")
    static let contextMenuForward = NSMenuItem(title: UserText.navigateForward, action: #selector(NavigationMenuItemSelectors.forward(_:)), keyEquivalent: "")
    static let contextMenuReload = NSMenuItem(title: UserText.reloadPage, action: #selector(NavigationMenuItemSelectors.reloadPage(_:)), keyEquivalent: "")

    static let linkContextMenuItems: [NSMenuItem] = [

        URLContextMenuItem(title: UserText.openLinkInNewTab, action: #selector(LinkMenuItemSelectors.openLinkInNewTab(_:)), keyEquivalent: ""),
        URLContextMenuItem(title: UserText.openLinkInNewWindow, action: #selector(LinkMenuItemSelectors.openLinkInNewWindow(_:)), keyEquivalent: ""),
        NSMenuItem.separator(),
        URLContextMenuItem(title: UserText.downloadLinkedFile, action: #selector(LinkMenuItemSelectors.downloadLinkedFile(_:)), keyEquivalent: ""),
        NSMenuItem.separator(),
        URLContextMenuItem(title: UserText.copyLink, action: #selector(LinkMenuItemSelectors.copyLink(_:)), keyEquivalent: "")

    ]

    static let imageContextMenuItems: [NSMenuItem] = [
        URLContextMenuItem(title: UserText.openImageInNewTab, action: #selector(ImageMenuItemSelectors.openImageInNewTab(_:)), keyEquivalent: ""),
        URLContextMenuItem(title: UserText.openImageInNewWindow, action: #selector(ImageMenuItemSelectors.openImageInNewWindow(_:)), keyEquivalent: ""),
        URLContextMenuItem(title: UserText.saveImageToDownloads, action: #selector(ImageMenuItemSelectors.saveImageToDownloads(_:)), keyEquivalent: ""),
        NSMenuItem.separator(),
        URLContextMenuItem(title: UserText.copyImageAddress, action: #selector(ImageMenuItemSelectors.copyImageAddress(_:)), keyEquivalent: ""),
        URLContextMenuItem(title: UserText.copyImage, action: #selector(ImageMenuItemSelectors.copyImage(_:)), keyEquivalent: "")
    ]

}
// swiftlint:enable line_length

@objc protocol NavigationMenuItemSelectors {

    func back(_ sender: Any?)
    func forward(_ sender: Any?)
    func reloadPage(_ sender: Any?)

}

@objc protocol LinkMenuItemSelectors {

    func openLinkInNewTab(_ sender: URLContextMenuItem)
    func openLinkInNewWindow(_ sender: URLContextMenuItem)
    func downloadLinkedFile(_ sender: URLContextMenuItem)
    func copyLink(_ sender: URLContextMenuItem)

}

@objc protocol ImageMenuItemSelectors {

    func openImageInNewTab(_ sender: URLContextMenuItem)
    func openImageInNewWindow(_ sender: URLContextMenuItem)
    func saveImageToDownloads(_ sender: URLContextMenuItem)
    func copyImageAddress(_ sender: URLContextMenuItem)
    @objc optional func copyImage(_ sender: URLContextMenuItem)

}
