//
//  AddEditBookmarkFolderDialogViewModel.swift
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

import Foundation
import Combine

@MainActor
protocol BookmarkFolderDialogViewModel: ObservableObject {
    var title: String { get }
    var folderName: String { get }
    var folders: [FolderViewModel] { get }
    var selectedFolder: BookmarkFolder? { get }

    func cancel()
    func addOrSave()
}

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

    var cancelActionTitle: String {
        mode.cancelActionTitle
    }

    var defaultActionTitle: String {
        mode.defaultActionTitle
    }

    let isCancelActionDisabled = false

    var isDefaultActionButtonDisabled: Bool {
        folderName.trimmingWhitespace().isEmpty
    }

    private let mode: Mode
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

}

// MARK: - Private

private extension AddEditBookmarkFolderDialogViewModel {

    func update(folder: BookmarkFolder, parent: BookmarkFolder?) {
        // Update the title of the folder
        if folder.title != folderName {
            folder.title = folderName
            bookmarkManager.update(folder: folder)
        }
        // If the original location of the folder changed move it to the new folder.
        if selectedFolder?.id != parent?.id {
            let parentFolderType: ParentFolderType = selectedFolder.flatMap { ParentFolderType.parent(uuid: $0.id) } ?? .root
            bookmarkManager.move(
                objectUUIDs: [folder.id],
                toIndex: nil,
                withinParentFolder: parentFolderType,
                completion: { _ in }
            )
        }
    }

    func add(folderWithName name: String, to parent: BookmarkFolder?) {
        bookmarkManager.makeFolder(for: name, parent: parent, completion: { _ in })
    }

}

// MARK: - AddEditBookmarkFolderDialogViewModel.Mode

private extension AddEditBookmarkFolderDialogViewModel.Mode {

    var title: String {
        switch self {
        case .add:
            return UserText.Bookmarks.Dialog.Title.addFolder
        case .edit:
            return UserText.Bookmarks.Dialog.Title.editFolder
        }
    }

    var cancelActionTitle: String {
        switch self {
        case .add, .edit:
            return UserText.cancel
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
