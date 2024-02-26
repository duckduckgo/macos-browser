//
//  BookmarksDialogViewFactory.swift
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

import SwiftUI

@MainActor
enum BookmarksDialogViewFactory {

    /// Creates an instance of AddEditBookmarkFolderDialogView for adding a Bookmark Folder.
    /// - Parameters:
    ///   - parentFolder: An optional `BookmarkFolder`. When adding a folder to the root bookmark folder pass `nil`. For any other folder pass the `BookmarkFolder` the new folder should be within.
    ///   - bookmarkManager: An instance of `BookmarkManager`. This should be used for `#previews` only.
    /// - Returns: An instance of AddEditBookmarkFolderDialogView
    static func makeAddBookmarkFolderView(parentFolder: BookmarkFolder?, bookmarkManager: LocalBookmarkManager = .shared) -> AddEditBookmarkFolderDialogView {
        let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: parentFolder), bookmarkManager: bookmarkManager)
        return AddEditBookmarkFolderDialogView(viewModel: viewModel)
    }

    /// Creates an instance of AddEditBookmarkFolderDialogView for editing a Bookmark Folder.
    /// - Parameters:
    ///   - folder: The `BookmarkFolder` to edit.
    ///   - parentFolder: An optional `BookmarkFolder`. When editing a folder within the root bookmark folder pass `nil`. For any other folder pass the `BookmarkFolder` the folder belongs to.
    ///   - bookmarkManager: An instance of `BookmarkManager`. This should be used for `#previews` only.
    /// - Returns: An instance of AddEditBookmarkFolderDialogView
    static func makeEditBookmarkFolderView(folder: BookmarkFolder, parentFolder: BookmarkFolder?, bookmarkManager: LocalBookmarkManager = .shared) -> AddEditBookmarkFolderDialogView {
        let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: folder, parentFolder: parentFolder), bookmarkManager: bookmarkManager)
        return AddEditBookmarkFolderDialogView(viewModel: viewModel)
    }

    /// Creates an instance of AddEditBookmarkDialogView for adding a Bookmark.
    /// - Parameters:
    ///   - currentTab: An optional `WebsiteInfo`. When adding a bookmark from the bookmark shortcut panel, if the `Tab` has loaded a web page pass the information via the `currentTab`. If the `Tab` has not loaded a tab pass `nil`. If adding a `Bookmark` from the `Manage Bookmark` settings page, pass `nil`.
    ///  - bookmarkManager: An instance of `BookmarkManager`. This should be used for `#previews` only.
    /// - Returns: An instance of AddEditBookmarkDialogView
    static func makeAddBookmarkView(currentTab: WebsiteInfo?, bookmarkManager: LocalBookmarkManager = .shared) -> AddEditBookmarkDialogView {
        let viewModel = AddEditBookmarkDialogViewModel(mode: .add(tabWebsite: currentTab), bookmarkManager: bookmarkManager)
        return makeAddEditBookmarkDialogView(viewModel: viewModel, bookmarkManager: bookmarkManager)
    }

    /// Creates an instance of AddEditBookmarkDialogView for editing a Bookmark.
    /// - Parameters:
    ///   - bookmark: The `Bookmark` to edit.
    ///   - bookmarkManager: An instance of `BookmarkManager`. This should be used for `#previews` only.
    /// - Returns: An instance of AddEditBookmarkDialogView
    static func makeEditBookmarkView(bookmark: Bookmark, bookmarkManager: LocalBookmarkManager = .shared) -> AddEditBookmarkDialogView {
        let viewModel = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        return makeAddEditBookmarkDialogView(viewModel: viewModel, bookmarkManager: bookmarkManager)
    }

}

private extension BookmarksDialogViewFactory {

    private static func makeAddEditBookmarkDialogView(viewModel: AddEditBookmarkDialogViewModel, bookmarkManager: BookmarkManager) -> AddEditBookmarkDialogView {
        let addFolderViewModel = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: nil), bookmarkManager: bookmarkManager)
        let viewModel = AddEditBookmarkDialogCoordinatorViewModel(bookmarkModel: viewModel, folderModel: addFolderViewModel)
        return AddEditBookmarkDialogView(viewModel: viewModel)
    }

}
