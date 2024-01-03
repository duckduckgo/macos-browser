//
//  AddBookmarkModalViewModel.swift
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

struct AddBookmarkModalViewModel {

    let bookmarkManager: BookmarkManager

    let title: String
    let addButtonTitle: String

    private let originalBookmark: Bookmark?
    private let parent: BookmarkFolder?

    private let completionHandler: (Bookmark?) -> Void

    var bookmarkTitle: String = ""
    var bookmarkAddress: String = ""

    private var hasValidInput: Bool {
        guard let url = bookmarkAddress.url else { return false }

        return !bookmarkTitle.isEmpty && url.isValid
    }

    var isAddButtonDisabled: Bool { !hasValidInput }

    func cancel(dismiss: () -> Void) {
        completionHandler(nil)
        dismiss()
    }

    func addOrSave(dismiss: () -> Void) {
        guard let url = bookmarkAddress.url else {
            assertionFailure("invalid URL, button should be disabled")
            return
        }

        var result: Bookmark?
        if let bookmark = originalBookmark {
            bookmark.title = bookmarkTitle

            bookmarkManager.update(bookmark: bookmark)
            _ = bookmarkManager.updateUrl(of: bookmark, to: url)
            result = bookmark

        } else if !bookmarkManager.isUrlBookmarked(url: url) {
            result = bookmarkManager.makeBookmark(for: url, title: bookmarkTitle, isFavorite: false, index: nil, parent: parent)
        }

        completionHandler(result)
        dismiss()
    }

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
         currentTabWebsite website: WebsiteInfo? = nil,
         parent: BookmarkFolder? = nil,
         completionHandler: @escaping (Bookmark?) -> Void = { _ in }) {

        self.bookmarkManager = bookmarkManager

        title = UserText.newBookmark
        addButtonTitle = UserText.bookmarkDialogAdd

        if let website,
           !LocalBookmarkManager.shared.isUrlBookmarked(url: website.url) {
            bookmarkTitle = website.title ?? ""
            bookmarkAddress = website.url.absoluteString
        }
        self.parent = parent
        self.originalBookmark = nil

        self.completionHandler = completionHandler
    }

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
         originalBookmark: Bookmark,
         completionHandler: @escaping (Bookmark?) -> Void = { _ in }) {

        self.bookmarkManager = bookmarkManager

        title = UserText.updateBookmark
        addButtonTitle = UserText.save

        self.parent = nil
        self.originalBookmark = originalBookmark

        bookmarkTitle = originalBookmark.title
        bookmarkAddress = originalBookmark.url

        self.completionHandler = completionHandler
    }

}
