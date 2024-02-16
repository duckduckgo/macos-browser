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

    /// The type of operation to perform on a folder
    enum Mode {
        /// Add a new folder. Folders can have a parent folder but not necessarily.
        /// If the users add a folder to a folder whose parent is the root `Bookmarks` folder, then the parent folder is `nil`.
        /// If the users add a folder to a folder whose parent is not the root `Bookmarks` folder, then the parent folder is not `nil`.
        case add(parentFolder: BookmarkFolder? = nil)
        /// Edit an existing folder. Existing folder can have a parent folder but not necessarily.
        /// If the users edit a  folder whose parent is the root `Bookmarks` folder, then the parent folder is `nil`
        /// If the users edit a folder whose parent is not the root `Bookmarks` folder, then the parent folder is not `nil`.
        case edit(folder: BookmarkFolder, parentFolder: BookmarkFolder?)
    }

    @Published var folderName: String
    @Published var selectedFolder: BookmarkFolder?

    let folders: [FolderViewModel]

    var title: String {
        mode.title
    }

    var defaultActionTitle: String {
        mode.defaultActionTitle
    }

    var isDefaultActionButtonDisabled: Bool {
        folderName.trimmingWhitespace().isEmpty
    }

    private var mode: Mode
    private let bookmarkManager: BookmarkManager

    init(mode: Mode, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.mode = mode
        self.bookmarkManager = bookmarkManager
        folderName = mode.folderName
        folders = .init(bookmarkManager.list)
        selectedFolder = mode.parentFolder
    }

    func cancel(dismiss: () -> Void) {
        dismiss()
    }

    func addOrSave(dismiss: () -> Void) {
        guard !folderName.isEmpty else {
            assertionFailure("folderName is empty, button should be disabled")
            return
        }

        let folderName = folderName.trimmingWhitespace()

        switch mode {
        case let .edit(folder, originalParent):
            update(folder: folder, parent: originalParent)
        case .add:
            add(folderWithName: folderName, to: selectedFolder)
        }

        dismiss()
    }

    func addFolderButtonAction() {
//        guard case let .edit(_, parent) = mode else {
//            assertionFailure("Cannot add a folder if we already adding one.")
//            return
//        }
//        self.mode = .add(parentFolder: parent)
//        objectWillChange.send()
    }
}

// MARK: - Private

private extension AddEditBookmarkFolderDialogViewModel {

    #warning("Can we update the tile and move at the same time?")
    func update(folder: BookmarkFolder, parent: BookmarkFolder?) {
        // Update title of the folder
        folder.title = folderName
        bookmarkManager.update(folder: folder)
        // If the original location of the folder changed move it
        if selectedFolder?.id != parent?.id, let selectedFolder {
            bookmarkManager.move(
                objectUUIDs: [folder.id],
                toIndex: nil,
                withinParentFolder: .parent(uuid: selectedFolder.id),
                completion: { _ in }
            )
        }
    }

    func add(folderWithName name: String, to parent: BookmarkFolder?) {
        bookmarkManager.makeFolder(for: name, parent: parent, completion: { _ in })
    }
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
                        keyboardShortCut: .cancelAction,
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

    var folderName: String {
        switch self {
        case .add:
            return ""
        case let .edit(folder, _):
            return folder.title
        }
    }

    var parentFolder: BookmarkFolder? {
        switch self {
        case let .add(parentFolder):
            return parentFolder
        case let .edit(_, parentFolder):
            return parentFolder
        }
    }

}

// MARK: - Previews

#Preview("Add Folder To Bookmarks - Light") {
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .add())
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Add Folder To Bookmarks Subfolder - Light") {
    let bookmarkFolder = BookmarkFolder(id: "", title: "Test")
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .add())
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Edit Folder - Light") {
    let bookmarkFolder = BookmarkFolder(id: "", title: "Test Bookmarks")
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: bookmarkFolder, parentFolder: nil))
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Add Folder - Dark") {
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .add())
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

#Preview("Edit Folder - Dark") {
    let bookmarkFolder = BookmarkFolder(id: "", title: "Test Bookmarks")
    let viewModel = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: bookmarkFolder, parentFolder: nil))
    return AddEditBookmarkFolderDialogView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}
