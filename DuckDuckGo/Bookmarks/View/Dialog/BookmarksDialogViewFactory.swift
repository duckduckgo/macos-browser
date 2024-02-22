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

    static func makeAddBookmarkFolderView(parentFolder: BookmarkFolder?, bookmarkManager: LocalBookmarkManager = .shared) -> some ModalView {
        let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: parentFolder), bookmarkManager: bookmarkManager)
        return AddEditBookmarkFolderDialogView(viewModel: viewModel)
    }

    static func makeEditBookmarkFolderView(folder: BookmarkFolder, parentFolder: BookmarkFolder?, bookmarkManager: LocalBookmarkManager = .shared) -> some ModalView {
        let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: folder, parentFolder: parentFolder), bookmarkManager: bookmarkManager)
        return AddEditBookmarkFolderDialogView(viewModel: viewModel)
    }

    static func makeAddBookmarkView(bookmarkManager: LocalBookmarkManager = .shared) -> some ModalView {
        let viewModel = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)
        return makeAddEditBookmarkDialogView(viewModel: viewModel, bookmarkManager: bookmarkManager)
    }

    static func makeEditBookmarkView(bookmark: Bookmark, bookmarkManager: LocalBookmarkManager = .shared) -> some ModalView {
        let viewModel = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        return makeAddEditBookmarkDialogView(viewModel: viewModel, bookmarkManager: bookmarkManager)
    }

}

private extension BookmarksDialogViewFactory {

    private static func makeAddEditBookmarkDialogView(viewModel: AddEditBookmarkDialogViewModel, bookmarkManager: BookmarkManager) -> some ModalView {
        let addFolderViewModel = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: nil), bookmarkManager: bookmarkManager)
        let viewModel = AddEditBookmarkDialogCoordinatorViewModel(bookmarkModel: viewModel, folderModel: addFolderViewModel)
        return AddEditBookmarkDialogView(viewModel: viewModel)
    }

}
