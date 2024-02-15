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

@MainActor
final class AddEditBookmarkFolderDialogViewModel: ObservableObject {

    enum Mode {
        case add
        case edit
    }

    @Published var folderName: String
    @Published var folders: [FolderViewModel] = []
    @Published var selectedFolder: BookmarkFolder?

    let title: String = "Test Title"
    let defaultActionTitle = "Test Action Title"
    var isDefaultActionButtonDisabled: Bool { false }

    private let mode: Mode

    init(mode: Mode, folderName: String) {
        self.mode = mode
        self.folderName = folderName
    }

    func cancel(dismiss: () -> Void) {}
    func addOrSave(dismiss: () -> Void) {}
    func addFolderButtonAction() {}
}

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
                        content: BookmarkDialogFolderManagementView(
                            folders: viewModel.folders,
                            selectedFolder: $viewModel.selectedFolder,
                            onActionButton: viewModel.addFolderButtonAction
                        )
                    )
                )
            },
            bottomSection: {
                BookmarkDialogButtonsView(
                    viewState: .compressed,
                    otherButtonAction: .init(
                        title: UserText.cancel,
                        action: viewModel.cancel,
                        keyboardShortCut: .cancelAction
                    ), defaultButtonAction: .init(
                        title: viewModel.defaultActionTitle,
                        action: viewModel.addOrSave,
                        keyboardShortCut: .defaultAction
                    ),
                    shouldDisableDefaultButtonAction: viewModel.isDefaultActionButtonDisabled
                )
            }
        )
        .font(.system(size: 13))
        .frame(width: 448, height: 210)
    }
}

// MARK: - AddEditBookmarkFolderDialogViewModel.Mode

extension AddEditBookmarkFolderDialogViewModel.Mode {

    var title: String {
        switch self {
        case .add:
            return UserText.Bookmarks.Dialog.Title.addFolder
        case .edit:
            return UserText.Bookmarks.Dialog.Title.editFolder
        }
    }

    var defaultActionTitle: String {
        switch self {
        case .add:
            return UserText.Bookmarks.Dialog.Action.addFolder
        case .edit:
            return UserText.save
        }
    }

}

// MARK: - Previews

#Preview("Add Folder - Light") {
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .add, folderName: "")
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Edit Folder - Light") {
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .edit, folderName: "Test Bookmarks")
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Add Folder - Dark") {
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .add, folderName: "")
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

#Preview("Edit Folder - Dark") {
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .edit, folderName: "Test Bookmarks")
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}
