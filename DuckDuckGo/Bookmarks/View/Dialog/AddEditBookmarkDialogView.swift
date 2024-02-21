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
        BookmarkDialogContainerView(
            title: viewModel.bookmarkModel.title,
            middleSection: {
                BookmarkDialogStackedContentView(
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.name,
                        content: TextField("", text: $viewModel.bookmarkModel.bookmarkName)
                            .focusedOnAppear()
                            .accessibilityIdentifier("bookmark.add.name.textfield")
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14))
                    ),
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.url,
                        content: TextField("", text: $viewModel.bookmarkModel.bookmarkURLPath)
                            .accessibilityIdentifier("bookmark.add.url.textfield")
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14))
                    ),
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.location,
                        content: BookmarkDialogFolderManagementView(
                            folders: viewModel.bookmarkModel.folders,
                            selectedFolder: $viewModel.bookmarkModel.selectedFolder,
                            onActionButton: {
                                viewModel.addFolderAction()
                            }
                        )
                    )
                )
                BookmarkFavoriteView(isFavorite: $viewModel.bookmarkModel.isBookmarkFavorite)
            },
            bottomSection: {
                BookmarkDialogButtonsView(
                    viewState: .compressed,
                    otherButtonAction: .init(
                        title: UserText.cancel,
                        keyboardShortCut: .cancelAction,
                        isDisabled: viewModel.bookmarkModel.isOtherActionDisabled,
                        action: viewModel.bookmarkModel.cancel
                    ), defaultButtonAction: .init(
                        title: viewModel.bookmarkModel.defaultActionTitle,
                        keyboardShortCut: .defaultAction,
                        isDisabled: viewModel.bookmarkModel.isDefaultActionDisabled,
                        action: viewModel.bookmarkModel.addOrSave
                    )
                )
            }
        )
        .frame(width: 448, height: 288)
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
    let bookmarkViewModel = AddEditBookmarkDialogViewModel(mode: .add, bookmarkManager: bookmarkManager)
    let folderViewModel = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: nil), bookmarkManager: bookmarkManager)
    let viewModel = AddEditBookmarkDialogCoordinatorViewModel(bookmarkModel: bookmarkViewModel, folderModel: folderViewModel)
    return AddEditBookmarkDialogView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Add Bookmark - Light Mode") {
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: []))
    bookmarkManager.loadBookmarks()
    let bookmarkViewModel = AddEditBookmarkDialogViewModel(mode: .add, bookmarkManager: bookmarkManager)
    let folderViewModel = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: nil), bookmarkManager: bookmarkManager)
    let viewModel = AddEditBookmarkDialogCoordinatorViewModel(bookmarkModel: bookmarkViewModel, folderModel: folderViewModel)
    return AddEditBookmarkDialogView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

#Preview("Edit Bookmark - Light Mode") {
    let parentFolder = BookmarkFolder(id: "7", title: "DuckDuckGo")
    let bookmark = Bookmark(id: "1", url: "www.duckduckgo.com", title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "7")
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [bookmark, parentFolder]))
    bookmarkManager.loadBookmarks()
    let bookmarkViewModel = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
    let folderViewModel = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: nil), bookmarkManager: bookmarkManager)
    let viewModel = AddEditBookmarkDialogCoordinatorViewModel(bookmarkModel: bookmarkViewModel, folderModel: folderViewModel)
    return AddEditBookmarkDialogView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Edit Bookmark - Dark Mode") {
    let parentFolder = BookmarkFolder(id: "7", title: "DuckDuckGo")
    let bookmark = Bookmark(id: "1", url: "www.duckduckgo.com", title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "7")
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [bookmark, parentFolder]))
    bookmarkManager.loadBookmarks()
    let bookmarkViewModel = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
    let folderViewModel = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: nil), bookmarkManager: bookmarkManager)
    let viewModel = AddEditBookmarkDialogCoordinatorViewModel(bookmarkModel: bookmarkViewModel, folderModel: folderViewModel)
    return AddEditBookmarkDialogView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}
#endif
