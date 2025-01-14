//
//  NSMenuItemExtension.swift
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

import AppKit

extension NSMenuItem {

    static var empty: NSMenuItem {
        let item = NSMenuItem(title: UserText.bookmarksBarFolderEmpty)
        item.isEnabled = false
        return item
    }

    convenience init(bookmarkViewModel: BookmarkViewModel) {
        self.init()

        title = bookmarkViewModel.menuTitle
        image = bookmarkViewModel.menuFavicon
        representedObject = bookmarkViewModel.entity
        action = bookmarkViewModel.entity.isFolder ? nil : #selector(MainViewController.openBookmark(_:))
    }

    convenience init(bookmarkViewModels: [BookmarkViewModel]) {
        self.init()

        title = UserText.bookmarksOpenInNewTabs
        representedObject = bookmarkViewModels
        action = #selector(MainViewController.openAllInTabs(_:))
    }
}
