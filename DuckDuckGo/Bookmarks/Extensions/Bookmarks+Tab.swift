//
//  Bookmarks+Tab.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Foundation

extension Tab {

    @MainActor
    static func withContentOfBookmark(folder: BookmarkFolder, burnerMode: BurnerMode) -> [Tab] {
        folder.children.compactMap { entity -> Tab? in
            guard let url = (entity as? Bookmark)?.urlObject else { return nil }
            return Tab(content: .url(url, source: .bookmark), shouldLoadInBackground: true, burnerMode: burnerMode)
        }
    }

    @MainActor
    static func with(contentsOf bookmarks: [Bookmark], burnerMode: BurnerMode) -> [Tab] {
        bookmarks.compactMap { bookmark -> Tab? in
            guard let url = bookmark.urlObject else { return nil }
            return Tab(content: .url(url, source: .bookmark), shouldLoadInBackground: true, burnerMode: burnerMode)
        }
    }
}

extension TabCollection {

    @MainActor
    static func withContentOfBookmark(folder: BookmarkFolder, burnerMode: BurnerMode) -> TabCollection {
        let tabs = Tab.withContentOfBookmark(folder: folder, burnerMode: burnerMode)
        return TabCollection(tabs: tabs)
    }

}
