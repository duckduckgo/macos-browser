//
//  AddEditBookmarkFolderDialogView.swift
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

struct AddEditBookmarkFolderDialogView: ModalView {
    @ObservedObject private var viewModel: AddEditBookmarkFolderDialogViewModel

    init(viewModel: AddEditBookmarkFolderDialogViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        BookmarkDialogContainerView(
            title: viewModel.title,
            middleSection: {
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
                        content: BookmarkFolderPicker(
                            folders: viewModel.folders,
                            selectedFolder: $viewModel.selectedFolder
                        )
                        .accessibilityIdentifier("bookmark.folder.folder.dropdown")
                    )
                )
            },
            bottomSection: {
                BookmarkDialogButtonsView(
                    viewState: .compressed,
                    otherButtonAction: .init(
                        title: viewModel.cancelActionTitle,
                        keyboardShortCut: .cancelAction,
                        isDisabled: viewModel.isCancelActionDisabled,
                        action: viewModel.cancel
                    ), defaultButtonAction: .init(
                        title: viewModel.defaultActionTitle,
                        keyboardShortCut: .defaultAction,
                        isDisabled: viewModel.isDefaultActionButtonDisabled,
                        action: viewModel.addOrSave
                    )
                )
            }
        )
        .font(.system(size: 13))
        .frame(width: 448, height: 210)
    }
}

// MARK: - Previews
#if DEBUG
#Preview("Add Folder To Bookmarks - Light") {
    let bookmarkFolder = BookmarkFolder(id: "1", title: "DuckDuckGo", children: [])
    let store = BookmarkStoreMock(bookmarks: [bookmarkFolder])
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: store)
    bookmarkManager.loadBookmarks()
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Add Folder To Bookmarks Subfolder - Light") {
    let bookmarkFolder = BookmarkFolder(id: "1", title: "DuckDuckGo", children: [])
    let store = BookmarkStoreMock(bookmarks: [bookmarkFolder])
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: store)
    bookmarkManager.loadBookmarks()
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: bookmarkFolder), bookmarkManager: bookmarkManager)
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Edit Folder - Light") {
    let bookmarkFolder = BookmarkFolder(id: "1", title: "DuckDuckGo", children: [])
    let store = BookmarkStoreMock(bookmarks: [bookmarkFolder])
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: store)
    bookmarkManager.loadBookmarks()
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: bookmarkFolder, parentFolder: nil), bookmarkManager: bookmarkManager)
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Add Folder To Bookmarks - Dark") {
    let store = BookmarkStoreMock(bookmarks: [])
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: store)
    bookmarkManager.loadBookmarks()
    customAssertionFailure = { _, _, _ in }
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

#Preview("Add Folder To Bookmarks Subfolder - Dark") {
    let bookmarkFolder = BookmarkFolder(id: "1", title: "DuckDuckGo", children: [])
    let store = BookmarkStoreMock(bookmarks: [bookmarkFolder])
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: store)
    bookmarkManager.loadBookmarks()
    customAssertionFailure = { _, _, _ in }
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: bookmarkFolder), bookmarkManager: bookmarkManager)
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

#Preview("Edit Folder in Subfolder - Dark") {
    let bookmarkFolder = BookmarkFolder(id: "1", title: "DuckDuckGo", children: [])
    let store = BookmarkStoreMock(bookmarks: [bookmarkFolder])
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: store)
    bookmarkManager.loadBookmarks()
    customAssertionFailure = { _, _, _ in }
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: bookmarkFolder, parentFolder: bookmarkFolder), bookmarkManager: bookmarkManager)
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}
#endif
