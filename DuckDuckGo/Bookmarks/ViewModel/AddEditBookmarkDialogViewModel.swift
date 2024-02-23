//
//  AddEditBookmarkDialogViewModel.swift
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
import Combine

@MainActor
protocol BookmarkDialogEditing: BookmarksDialogViewModel {
    var bookmarkName: String { get set }
    var bookmarkURLPath: String { get set }
    var isBookmarkFavorite: Bool { get set }

    var isURLFieldHidden: Bool { get }
}

@MainActor
final class AddEditBookmarkDialogViewModel: BookmarkDialogEditing {

    enum Mode {
        case add(tabWebsite: WebsiteInfo? = nil, parentFolder: BookmarkFolder? = nil)
        case edit(bookmark: Bookmark)
    }

    @Published var bookmarkName: String
    @Published var bookmarkURLPath: String
    @Published var isBookmarkFavorite: Bool

    @Published private(set) var folders: [FolderViewModel]
    @Published var selectedFolder: BookmarkFolder?

    private var folderCancellable: AnyCancellable?

    var title: String {
        mode.title
    }

    let isURLFieldHidden: Bool = false

    var cancelActionTitle: String {
        mode.cancelActionTitle
    }

    var defaultActionTitle: String {
        mode.defaultActionTitle
    }

    private var hasValidInput: Bool {
        guard let url = bookmarkURLPath.url else { return false }
        return !bookmarkName.trimmingWhitespace().isEmpty && url.isValid
    }

    let isOtherActionDisabled: Bool = false

    var isDefaultActionDisabled: Bool { !hasValidInput }

    private let mode: Mode
    private let bookmarkManager: BookmarkManager

    init(mode: Mode, bookmarkManager: LocalBookmarkManager = .shared) {
        self.mode = mode
        self.bookmarkManager = bookmarkManager
        bookmarkName = mode.bookmarkName ?? ""
        bookmarkURLPath = mode.bookmarkURLPath?.absoluteString ?? ""
        isBookmarkFavorite = mode.bookmarkURLPath.flatMap(bookmarkManager.isUrlFavorited) ?? false
        folders = .init(bookmarkManager.list)
        switch mode {
        case let .add(_, parentFolder):
            selectedFolder = parentFolder
        case let .edit(bookmark):
            selectedFolder = folders.first(where: { $0.id == bookmark.parentFolderUUID })?.entity
        }
        bind()
    }

    func cancel(dismiss: () -> Void) {
        dismiss()
    }

    func addOrSave(dismiss: () -> Void) {
        guard let url = bookmarkURLPath.url else {
            assertionFailure("Invalid URL, default action button should be disabled.")
            return
        }

        let trimmedBookmarkName = bookmarkName.trimmingWhitespace()

        switch mode {
        case .add:
            addBookmark(withURL: url, name: trimmedBookmarkName, isFavorite: isBookmarkFavorite, to: selectedFolder)
        case let .edit(bookmark):
            updateBookmark(bookmark, url: url, name: trimmedBookmarkName, isFavorite: isBookmarkFavorite, location: selectedFolder)
        }
        dismiss()
    }
}

private extension AddEditBookmarkDialogViewModel {

    func bind() {
        folderCancellable = bookmarkManager.listPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { bookmarkList in
                self.folders = .init(bookmarkList)
            })
    }

    func updateBookmark(_ bookmark: Bookmark, url: URL, name: String, isFavorite: Bool, location: BookmarkFolder?) {
        var bookmark = bookmark

        // If URL changed update URL first as updating the Bookmark altogether will throw an error as the bookmark can't be fetched by URL.
        if bookmark.url != url.absoluteString {
            bookmark = bookmarkManager.updateUrl(of: bookmark, to: url) ?? bookmark
        }

        if bookmark.title != name || bookmark.isFavorite != isBookmarkFavorite {
            bookmark.title = name
            bookmark.isFavorite = isBookmarkFavorite
            bookmarkManager.update(bookmark: bookmark)
        }
        if bookmark.parentFolderUUID != selectedFolder?.id {
            let parentFoler: ParentFolderType = selectedFolder.flatMap { .parent(uuid: $0.id) } ?? .root
            bookmarkManager.move(objectUUIDs: [bookmark.id], toIndex: nil, withinParentFolder: parentFoler, completion: { _ in })
        }
    }

    func addBookmark(withURL url: URL, name: String, isFavorite: Bool, to parent: BookmarkFolder?) {
        // If a bookmark already exist with the new URL, update it
        if let existingBookmark = bookmarkManager.getBookmark(for: url) {
            updateBookmark(existingBookmark, url: url, name: name, isFavorite: isFavorite, location: parent)
        } else {
            bookmarkManager.makeBookmark(for: url, title: name, isFavorite: isFavorite, index: nil, parent: parent)
        }
    }
}

private extension AddEditBookmarkDialogViewModel.Mode {

    var title: String {
        switch self {
        case .add:
            return UserText.Bookmarks.Dialog.Title.addBookmark
        case .edit:
            return UserText.Bookmarks.Dialog.Title.editBookmark
        }
    }

    var cancelActionTitle: String {
        switch self {
        case .add, .edit:
            return UserText.cancel
        }
    }

    var defaultActionTitle: String {
        switch self {
        case .add:
            return UserText.Bookmarks.Dialog.Action.addBookmark
        case .edit:
            return UserText.save
        }
    }

    var bookmarkName: String? {
        switch self {
        case let .add(tabInfo, _):
            return tabInfo?.title
        case let .edit(bookmark):
            return bookmark.title
        }
    }

    var bookmarkURLPath: URL? {
        switch self {
        case let .add(tabInfo, _):
            return tabInfo?.url
        case let .edit(bookmark):
            return bookmark.urlObject
        }
    }

}
