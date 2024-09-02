//
//  MenuItemSelectors.swift
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

@objc protocol BookmarksMenuItemSelectors {
    func newFolder(_ sender: Any?)
    func moveToEnd(_ sender: NSMenuItem)
    @objc optional func manageBookmarks(_ sender: NSMenuItem)
}

@objc protocol BookmarkMenuItemSelectors: BookmarksMenuItemSelectors {

    func openBookmarkInNewTab(_ sender: NSMenuItem)
    func openBookmarkInNewWindow(_ sender: NSMenuItem)
    func toggleBookmarkAsFavorite(_ sender: NSMenuItem)
    func editBookmark(_ sender: NSMenuItem)
    func copyBookmark(_ sender: NSMenuItem)
    func deleteBookmark(_ sender: NSMenuItem)
    func deleteEntities(_ sender: NSMenuItem)

}

@objc protocol FolderMenuItemSelectors: BookmarksMenuItemSelectors {

    func editFolder(_ sender: NSMenuItem)
    func deleteFolder(_ sender: NSMenuItem)
    func openInNewTabs(_ sender: NSMenuItem)
    func openAllInNewWindow(_ sender: NSMenuItem)

}

@objc protocol BookmarkSearchMenuItemSelectors {

    func showInFolder(_ sender: NSMenuItem)
}

@objc protocol BookmarkSortMenuItemSelectors {

    func manualSort(_ sender: NSMenuItem)
    func sortByNameAscending(_ sender: NSMenuItem)
    func sortByNameDescending(_ sender: NSMenuItem)
}
