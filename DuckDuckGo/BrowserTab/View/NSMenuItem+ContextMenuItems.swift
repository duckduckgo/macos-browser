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

class ImageContextMenuItem: NSMenuItem {

    var url: URL?

    func apply(_ url: URL) -> Self {
        self.url = url
        return self
    }

}

class LinkContextMenuItem: NSMenuItem {

    var url: URL?

    func apply(_ url: URL) -> Self {
        self.url = url
        return self
    }

}

// swiftlint:disable line_length
extension NSMenuItem {

    static let contextMenuBack = NSMenuItem(title: "Back", action: #selector(NavigationMenuItemSelectors.back(_:)), keyEquivalent: "")
    static let contextMenuForward = NSMenuItem(title: "Forward", action: #selector(NavigationMenuItemSelectors.forward(_:)), keyEquivalent: "")
    static let contextMenuReload = NSMenuItem(title: "Reload Page", action: #selector(NavigationMenuItemSelectors.reloadPage(_:)), keyEquivalent: "")

    static let contextMenuOpenLinkInNewTab = LinkContextMenuItem(title: "Open Link In New Tab", action: #selector(LinkMenuItemSelectors.openLinkInNewTab(_:)), keyEquivalent: "")
    static let contextMenuOpenLinkInNewWindow = LinkContextMenuItem(title: "Open Link In New Window", action: #selector(LinkMenuItemSelectors.openLinkInNewWindow(_:)), keyEquivalent: "")
    static let contextMenuDownloadLinkedFile = LinkContextMenuItem(title: "Download Linked File", action: #selector(LinkMenuItemSelectors.downloadLinkedFile(_:)), keyEquivalent: "")
    static let contextMenuCopyLink = LinkContextMenuItem(title: "Copy Link", action: #selector(LinkMenuItemSelectors.copyLink(_:)), keyEquivalent: "")

    static let contextMenuOpenImageInNewTab = ImageContextMenuItem(title: "Open Image in New Tab", action: #selector(ImageMenuItemSelectors.openImageInNewTab(_:)), keyEquivalent: "")
    static let contextMenuOpenImageInNewWindow = ImageContextMenuItem(title: "Open Image in New Window", action: #selector(ImageMenuItemSelectors.openImageInNewWindow(_:)), keyEquivalent: "")
    static let contextMenuSaveImageToDownloads = ImageContextMenuItem(title: "Save Image to \"Downloads\"", action: #selector(ImageMenuItemSelectors.saveImageToDownloads(_:)), keyEquivalent: "")

}
// swiftlint:enable line_length

@objc protocol NavigationMenuItemSelectors {

    func back(_ sender: Any?)
    func forward(_ sender: Any?)
    func reloadPage(_ sender: Any?)

}

@objc protocol LinkMenuItemSelectors {

    func openLinkInNewTab(_ sender: Any?)
    func openLinkInNewWindow(_ sender: Any?)
    func downloadLinkedFile(_ sender: Any?)
    func copyLink(_ sender: Any?)

}

@objc protocol ImageMenuItemSelectors {

    func openImageInNewTab(_ sender: Any?)
    func openImageInNewWindow(_ sender: Any?)
    func saveImageToDownloads(_ sender: Any?)

}
