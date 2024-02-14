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
import Combine
import Common

@MainActor
final class AddEditBookmarkDialogViewModel: ObservableObject {

    enum Mode {
        case add
        case edit
    }

    @Published var bookmarkName: String
    @Published var bookmarkURLPath: String
    @Published var isBookmarkFavorite: Bool
    @Published var folders: [FolderViewModel] = []
    @Published var selectedFolder: BookmarkFolder?

    let title: String = ""
    let defaultActionTitle = ""
    var isDefaultActionButtonDisabled: Bool { false }

    private let bookmark: Bookmark
    private let mode: Mode
    private let bookmarkManager: BookmarkManager

    init(
        mode: Mode,
        bookmark: Bookmark,
        bookmarkManager: LocalBookmarkManager = .shared
    ) {
        self.bookmark = bookmark
        self.mode = mode
        self.bookmarkManager = bookmarkManager
        bookmarkName = bookmark.title
        bookmarkURLPath = bookmark.url
        isBookmarkFavorite = bookmark.isFavorite
    }

    func cancelAction(dismiss: () -> Void) {}
    func saveOrAddAction(dismiss: () -> Void) {}
    func addFolderButtonAction() {}
}

struct AddEditBookmarkDialogView: ModalView {
    @ObservedObject private var viewModel: AddEditBookmarkDialogViewModel

    init(viewModel: AddEditBookmarkDialogViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
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
                            onActionButton: viewModel.addFolderButtonAction
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
                        action: viewModel.cancelAction,
                        keyboardShortCut: .cancelAction
                    ), defaultButtonAction: .init(
                        title: viewModel.defaultActionTitle,
                        action: viewModel.saveOrAddAction,
                        keyboardShortCut: .defaultAction
                    ),
                    shouldDisableDefaultButtonAction: viewModel.isDefaultActionButtonDisabled
                )
            }
        )
        .font(.system(size: 13))
        .frame(width: 448, height: 288)
    }
}

// MARK: - AddEditBookmarkDialogViewModel.Mode

private extension AddEditBookmarkDialogViewModel.Mode {

    var title: String {
        switch self {
        case .add:
            return UserText.Bookmarks.Dialog.Title.addBookmark
        case .edit:
            return UserText.Bookmarks.Dialog.Title.editBookmark
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

}

// MARK: - Previews

#Preview("Add Bookmark - Light Mode") {
    let bookmark = Bookmark(id: "1", url: "", title: "", isFavorite: false)
    let viewModel = AddEditBookmarkDialogViewModel(mode: .add, bookmark: bookmark)
    return AddEditBookmarkDialogView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Edit Bookmark - Light Mode") {
    let bookmark = Bookmark(id: "1", url: "www.duckduckgo.com", title: "DuckDuckGo", isFavorite: true)
    let viewModel = AddEditBookmarkDialogViewModel(mode: .edit, bookmark: bookmark)
    return AddEditBookmarkDialogView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Add Bookmark - Dark Mode") {
    let bookmark = Bookmark(id: "1", url: "", title: "", isFavorite: false)
    let viewModel = AddEditBookmarkDialogViewModel(mode: .add, bookmark: bookmark)
    return AddEditBookmarkDialogView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

#Preview("Edit Bookmark - Dark Mode") {
    let bookmark = Bookmark(id: "1", url: "www.duckduckgo.com", title: "DuckDuckGo", isFavorite: true)
    let viewModel = AddEditBookmarkDialogViewModel(mode: .edit, bookmark: bookmark)
    return AddEditBookmarkDialogView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}
