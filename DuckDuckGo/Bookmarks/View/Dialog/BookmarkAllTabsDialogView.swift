//
//  BookmarkAllTabsDialogView.swift
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

struct BookmarkAllTabsDialogView: ModalView {
    @ObservedObject private var viewModel: BookmarkAllTabsViewModel

    init(viewModel: BookmarkAllTabsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        BookmarkDialogContainerView(
            title: viewModel.title,
            middleSection: {
                Text(verbatim: "These bookmarks will be saved in a new folder:")
                BookmarkDialogStackedContentView(
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.name,
                        content: TextField("", text: $viewModel.folderName)
                            .focusedOnAppear()
                            .accessibilityIdentifier("bookmark.add.name.textfield")
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14))
                    ),
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.location,
                        content: BookmarkDialogFolderManagementView(
                            folders: viewModel.folders,
                            selectedFolder: $viewModel.selectedFolder,
                            onActionButton: viewModel.addFolderAction
                        )
                    )
                )
            },
            bottomSection: {
                BookmarkDialogButtonsView(
                    viewState: .init(.compressed),
                    otherButtonAction: .init(
                        title: viewModel.cancelActionTitle,
                        isDisabled: viewModel.isOtherActionDisabled,
                        action: viewModel.cancel
                    ),
                    defaultButtonAction: .init(
                        title: viewModel.defaultActionTitle,
                        keyboardShortCut: .defaultAction,
                        isDisabled: viewModel.isDefaultActionDisabled,
                        action: viewModel.addOrSave
                    )
                )
            }
        )
        .frame(width: 448, height: 241)
    }
}

//#Preview {
//    BookmarkAllTabsDialogView()
//}

struct BookmarkAllTabsCoordinatorView: ModalView {
    @ObservedObject private var viewModel: BookmarkAllTabsDialogCoordinatorViewModel<BookmarkAllTabsViewModel, AddEditBookmarkFolderDialogViewModel>

    init(viewModel: BookmarkAllTabsDialogCoordinatorViewModel<BookmarkAllTabsViewModel, AddEditBookmarkFolderDialogViewModel>) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            switch viewModel.viewState {
            case .bookmarkAllTabs:
                bookmarkAllTabsView
            case .addFolder:
                addFolderView
            }
        }
        .font(.system(size: 13))
    }

    private var bookmarkAllTabsView: some View {
        BookmarkAllTabsDialogView(viewModel: viewModel.bookmarkModel)
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
            cancelAction: viewModel.folderModel.cancel(dismiss:),
            defaultActionTitle: viewModel.folderModel.defaultActionTitle,
            isDefaultActionDisabled: viewModel.folderModel.isDefaultActionDisabled,
            defaultAction: viewModel.folderModel.addOrSave
        )
        .frame(width: 448, height: 210)
    }
}
