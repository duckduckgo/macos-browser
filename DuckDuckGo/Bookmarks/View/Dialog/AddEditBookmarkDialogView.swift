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
    @ObservedObject private var viewModel: AddEditBookmarkDialogViewModel
    @EnvironmentObject private var addFolderViewModel: AddEditBookmarkFolderDialogViewModel

    @State private var isAddFolderPresented = false

    init(viewModel: AddEditBookmarkDialogViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        if isAddFolderPresented {
            addFolderView
        } else {
            addEditBookmarkView
        }
    }

    private var addEditBookmarkView: some View {
        BookmarkDialogContainerView(
            title: viewModel.title,
            middleSection: {
                BookmarkDialogStackedContentView(
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.name,
                        content: TextField("", text: $viewModel.bookmarkName)
                            .focusedOnAppear()
                            .accessibilityIdentifier("bookmark.add.name.textfield")
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14))
                    ),
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.url,
                        content: TextField("", text: $viewModel.bookmarkURLPath)
                            .accessibilityIdentifier("bookmark.add.url.textfield")
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14))
                    ),
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.location,
                        content: BookmarkDialogFolderManagementView(
                            folders: viewModel.folders,
                            selectedFolder: $viewModel.selectedFolder,
                            onActionButton: {
                                isAddFolderPresented = true
                            }
                        )
                    )
                )
                BookmarkFavoriteView(isFavorite: $viewModel.isBookmarkFavorite)
            },
            bottomSection: {
                BookmarkDialogButtonsView(
                    viewState: .compressed,
                    otherButtonAction: .init(
                        title: UserText.cancel,
                        keyboardShortCut: .cancelAction,
                        action: viewModel.cancelAction
                    ), defaultButtonAction: .init(
                        title: viewModel.defaultActionTitle,
                        keyboardShortCut: .defaultAction,
                        isDisabled: viewModel.isDefaultActionButtonDisabled,
                        action: viewModel.saveOrAddAction
                    )
                )
            }
        )
        .font(.system(size: 13))
        .frame(width: 448, height: 288)
    }

    private var addFolderView: some View {
        AddEditBookmarkFolderView(
            title: addFolderViewModel.title,
            buttonsState: .compressed,
            folders: addFolderViewModel.folders,
            folderName: $addFolderViewModel.folderName,
            selectedFolder: $addFolderViewModel.selectedFolder,
            cancelActionTitle: addFolderViewModel.cancelActionTitle,
            isCancelActionDisabled: addFolderViewModel.isCancelActionDisabled,
            cancelAction: { _ in
                isAddFolderPresented = false
            },
            defaultActionTitle: addFolderViewModel.defaultActionTitle,
            isDefaultActionDisabled: addFolderViewModel.isDefaultActionButtonDisabled,
            defaultAction: { _ in
                addFolderViewModel.addOrSave {
                    isAddFolderPresented = false
                }
            }
        )
        .font(.system(size: 13))
        .frame(width: 448, height: 210)
        .onAppear {
            addFolderViewModel.selectedFolder = viewModel.selectedFolder
        }
    }
}

// MARK: - Previews

//#Preview("Add Bookmark - Light Mode") {
//    let bookmark = Bookmark(id: "1", url: "", title: "", isFavorite: false)
//    let viewModel = AddEditBookmarkDialogViewModel(mode: .add, bookmark: bookmark)
//    return AddEditBookmarkDialogView(viewModel: viewModel)
//        .preferredColorScheme(.light)
//}
//
//#Preview("Edit Bookmark - Light Mode") {
//    let bookmark = Bookmark(id: "1", url: "www.duckduckgo.com", title: "DuckDuckGo", isFavorite: true)
//    let viewModel = AddEditBookmarkDialogViewModel(mode: .edit, bookmark: bookmark)
//    return AddEditBookmarkDialogView(viewModel: viewModel)
//        .preferredColorScheme(.light)
//}
//
//#Preview("Add Bookmark - Dark Mode") {
//    let bookmark = Bookmark(id: "1", url: "", title: "", isFavorite: false)
//    let viewModel = AddEditBookmarkDialogViewModel(mode: .add, bookmark: bookmark)
//    return AddEditBookmarkDialogView(viewModel: viewModel)
//        .preferredColorScheme(.dark)
//}
//
//#Preview("Edit Bookmark - Dark Mode") {
//    let bookmark = Bookmark(id: "1", url: "www.duckduckgo.com", title: "DuckDuckGo", isFavorite: true)
//    let viewModel = AddEditBookmarkDialogViewModel(mode: .edit, bookmark: bookmark)
//    return AddEditBookmarkDialogView(viewModel: viewModel)
//        .preferredColorScheme(.dark)
//}
