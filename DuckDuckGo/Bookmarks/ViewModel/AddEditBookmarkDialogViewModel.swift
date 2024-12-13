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

    /// The type of operation to perform on a bookmark.
    enum Mode {
        /// Add a new bookmark. Bookmarks can have a parent folder but not necessarily.
        /// If the users add a bookmark to the root `Bookmarks` folder, then the parent folder is `nil`.
        /// If the users add a bookmark to a different folder then the parent folder is not `nil`.
        /// If the users add a bookmark from the bookmark shortcut and `Tab` has a page loaded, then the `tabWebsite` is not `nil`.
        /// When adding a bookmark from favorite screen the `shouldPresetFavorite` flag should be set to `true`.
        case add(tabWebsite: WebsiteInfo? = nil, parentFolder: BookmarkFolder? = nil, shouldPresetFavorite: Bool = false)
        /// Edit an existing bookmark.
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

    init(mode: Mode, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        let isFavorite = mode.bookmarkURL.flatMap(bookmarkManager.isUrlFavorited) ?? false
        self.mode = mode
        self.bookmarkManager = bookmarkManager
        folders = .init(bookmarkManager.list)
        switch mode {
        case let .add(websiteInfo, parentFolder, shouldPresetFavorite):
            // When adding a new bookmark with website info we need to show the bookmark name and URL only if the bookmark is not bookmarked already.
            // Scenario we click on the "Add Bookmark" button from Bookmarks shortcut Panel. If Tab has a Bookmark loaded we present the dialog with prepopulated name and URL from the tab.
            // If we save and click again on the "Add Bookmark" button we don't want to try re-add the same bookmark. Hence we present a dialog that is not pre-populated.
            let isAlreadyBookmarked = websiteInfo.flatMap { bookmarkManager.isUrlBookmarked(url: $0.url) } ?? false
            let websiteName = isAlreadyBookmarked ? "" : websiteInfo?.title ?? ""
            let websiteURLPath = isAlreadyBookmarked ? "" : websiteInfo?.url.absoluteString ?? ""
            bookmarkName = websiteName
            bookmarkURLPath = websiteURLPath
            isBookmarkFavorite = shouldPresetFavorite ? true : isFavorite
            selectedFolder = parentFolder
        case let .edit(bookmark):
            bookmarkName = bookmark.title
            bookmarkURLPath = bookmark.urlObject?.absoluteString ?? ""
            isBookmarkFavorite = isFavorite
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
            .sink(receiveValue: { [weak self] bookmarkList in
                self?.folders = .init(bookmarkList)
            })
    }

    func updateBookmark(_ bookmark: Bookmark, url: URL, name: String, isFavorite: Bool, location: BookmarkFolder?) {
        // If the URL or Title or Favorite is changed update bookmark
        if bookmark.url != url.absoluteString || bookmark.title != name || bookmark.isFavorite != isBookmarkFavorite {
            bookmarkManager.update(bookmark: bookmark, withURL: url, title: name, isFavorite: isFavorite)
        }

        // If the bookmark changed parent location, move it.
        if shouldMove(bookmark: bookmark) {
            let parentFolder: ParentFolderType = selectedFolder.flatMap { .parent(uuid: $0.id) } ?? .root
            bookmarkManager.move(objectUUIDs: [bookmark.id], toIndex: nil, withinParentFolder: parentFolder, completion: { _ in })
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

    func shouldMove(bookmark: Bookmark) -> Bool {
        // There's a discrepancy in representing the root folder. A bookmark belonging to the root folder has `parentFolderUUID` equal to `bookmarks_root`.
        // There's no `BookmarkFolder` to represent the root folder, so the root folder is represented by a nil selectedFolder.
        // Move Bookmarks if its parent folder is != from the selected folder but ONLY if:
        //   - The selected folder is not nil. This ensure we're comparing a subfolder with any bookmark parent folder.
        //   - The selected folder is nil and the bookmark parent folder is not the root folder. This ensure we're not unnecessarily moving the items within the same root folder.
        bookmark.parentFolderUUID != selectedFolder?.id && (selectedFolder != nil || selectedFolder == nil && !bookmark.isParentFolderRoot)
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

    var bookmarkURL: URL? {
        switch self {
        case let .add(tabInfo, _, _):
            return tabInfo?.url
        case let .edit(bookmark):
            return bookmark.urlObject
        }
    }

}

private extension Bookmark {

    var isParentFolderRoot: Bool {
        parentFolderUUID == "bookmarks_root"
    }

}
