//
//  MenuItemSelectors.swift
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

@objc protocol LinkMenuItemSelectors {

    func openLinkInNewTab(_ sender: NSMenuItem)
    func openLinkInNewWindow(_ sender: NSMenuItem)
    func downloadLinkedFileAs(_ sender: NSMenuItem)
    func copyLink(_ sender: NSMenuItem)

}

@objc protocol ImageMenuItemSelectors {

    func openImageInNewTab(_ sender: NSMenuItem)
    func openImageInNewWindow(_ sender: NSMenuItem)
    func saveImageAs(_ sender: NSMenuItem)
    func copyImageAddress(_ sender: NSMenuItem)

}

@objc protocol MenuItemSelectors {

    func search(_ sender: NSMenuItem)

}

@objc protocol FolderMenuItemSelectors {

    func newFolder(_ sender: NSMenuItem)
    func renameFolder(_ sender: NSMenuItem)
    func deleteFolder(_ sender: NSMenuItem)
    func openInNewTabs(_ sender: NSMenuItem)

}

@objc protocol BookmarkMenuItemSelectors {

    func openBookmarkInNewTab(_ sender: NSMenuItem)
    func openBookmarkInNewWindow(_ sender: NSMenuItem)
    func toggleBookmarkAsFavorite(_ sender: NSMenuItem)
    func editBookmark(_ sender: NSMenuItem)
    func copyBookmark(_ sender: NSMenuItem)
    func deleteBookmark(_ sender: NSMenuItem)

}
