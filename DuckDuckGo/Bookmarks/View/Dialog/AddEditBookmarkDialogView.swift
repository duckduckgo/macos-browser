//
//  AddEditBookmarkDialogView.swift
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

struct AddEditBookmarkDialogView: ModalView {
    @ObservedObject private var viewModel: AddEditBookmarkDialogCoordinatorViewModel<AddEditBookmarkDialogViewModel, AddEditBookmarkFolderDialogViewModel>

    init(viewModel: AddEditBookmarkDialogCoordinatorViewModel<AddEditBookmarkDialogViewModel, AddEditBookmarkFolderDialogViewModel>) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            switch viewModel.viewState {
            case .bookmark:
                addEditBookmarkView
            case .folder:
                addFolderView
            }
        }
        .font(.system(size: 13))
    }

    private var addEditBookmarkView: some View {
        AddEditBookmarkView(
            title: viewModel.bookmarkModel.title,
            buttonsState: .compressed,
            bookmarkName: $viewModel.bookmarkModel.bookmarkName,
            bookmarkURLPath: $viewModel.bookmarkModel.bookmarkURLPath,
            isBookmarkFavorite: $viewModel.bookmarkModel.isBookmarkFavorite,
            folders: viewModel.bookmarkModel.folders,
            selectedFolder: $viewModel.bookmarkModel.selectedFolder,
            isURLFieldHidden: false,
            addFolderAction: viewModel.addFolderAction,
            otherActionTitle: viewModel.bookmarkModel.cancelActionTitle,
            isOtherActionDisabled: viewModel.bookmarkModel.isOtherActionDisabled,
            otherAction: viewModel.bookmarkModel.cancel,
            isOtherActionTriggeredByEscKey: true,
            defaultActionTitle: viewModel.bookmarkModel.defaultActionTitle,
            isDefaultActionDisabled: viewModel.bookmarkModel.isDefaultActionDisabled,
            defaultAction: viewModel.bookmarkModel.addOrSave
        )
        .frame(width: 448)
    }

    private var addFolderView: some View {
        AddEditBookmarkFolderView(
            title: viewModel.folderModel.title,
            buttonsState: .compressed,
            folders: viewModel.folderModel.folders,
            folderName: $viewModel.folderModel.folderName,
            selectedFolder: $viewModel.folderModel.selectedFolder,
            cancelActionTitle: viewModel.folderModel.cancelActionTitle,
            isCancelActionDisabled: viewModel.folderModel.isOtherActionDisabled,
            cancelAction: { _ in
                viewModel.dismissAction()
            },
            defaultActionTitle: viewModel.folderModel.defaultActionTitle,
            isDefaultActionDisabled: viewModel.folderModel.isDefaultActionDisabled,
            defaultAction: { _ in
                viewModel.folderModel.addOrSave {
                    viewModel.dismissAction()
                }
            }
        )
        .frame(width: 448, height: 210)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Add Bookmark - Light Mode") {
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: []))
    bookmarkManager.loadBookmarks()

    return BookmarksDialogViewFactory.makeAddBookmarkView(parent: nil, bookmarkManager: bookmarkManager)
        .preferredColorScheme(.light)
}

#Preview("Add Bookmark - Dark Mode") {
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: []))
    bookmarkManager.loadBookmarks()

    return BookmarksDialogViewFactory.makeAddBookmarkView(parent: nil, bookmarkManager: bookmarkManager)
        .preferredColorScheme(.dark)
}

#Preview("Edit Bookmark - Light Mode") {
    let parentFolder = BookmarkFolder(id: "7", title: "DuckDuckGo")
    let bookmark = Bookmark(id: "1", url: "www.duckduckgo.com", title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "7")
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [bookmark, parentFolder]))
    bookmarkManager.loadBookmarks()

    return BookmarksDialogViewFactory.makeEditBookmarkView(bookmark: bookmark, bookmarkManager: bookmarkManager)
        .preferredColorScheme(.light)
}

#Preview("Edit Bookmark - Dark Mode") {
    let parentFolder = BookmarkFolder(id: "7", title: "DuckDuckGo")
    let bookmark = Bookmark(id: "1", url: "www.duckduckgo.com", title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "7")
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [bookmark, parentFolder]))
    bookmarkManager.loadBookmarks()

    return BookmarksDialogViewFactory.makeEditBookmarkView(bookmark: bookmark, bookmarkManager: bookmarkManager)
        .preferredColorScheme(.dark)
}
#endif
