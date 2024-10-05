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
protocol BookmarkFolderDialogEditing: BookmarksDialogViewModel {
    var addFolderPublisher: AnyPublisher<BookmarkFolder, Never> { get }
    var folderName: String { get set }
}

@MainActor
final class AddEditBookmarkFolderDialogViewModel: BookmarkFolderDialogEditing {

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
    @Published private(set) var folders: [FolderViewModel]

    private var folderCancellable: AnyCancellable?

    var title: String {
        mode.title
    }

    var cancelActionTitle: String {
        mode.cancelActionTitle
    }

    var defaultActionTitle: String {
        mode.defaultActionTitle
    }

    let isOtherActionDisabled = false

    var isDefaultActionDisabled: Bool {
        folderName.trimmingWhitespace().isEmpty
    }

    var addFolderPublisher: AnyPublisher<BookmarkFolder, Never> {
        addFolderSubject.eraseToAnyPublisher()
    }

    private let mode: Mode
    private let bookmarkManager: BookmarkManager
    private let addFolderSubject: PassthroughSubject<BookmarkFolder, Never> = .init()

    init(mode: Mode, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.mode = mode
        self.bookmarkManager = bookmarkManager
        folderName = mode.folderName
        folders = .init(bookmarkManager.list)
        selectedFolder = mode.parentFolder

        bind()
    }

    func cancel(dismiss: () -> Void) {
        reset()
        dismiss()
    }

    func addOrSave(dismiss: () -> Void) {
        defer {
            reset()
            dismiss()
        }

        guard !folderName.isEmpty else {
            assertionFailure("folderName is empty, button should be disabled")
            return
        }

        let folderName = folderName.trimmingWhitespace()

        switch mode {
        case let .edit(folder, originalParent):
            // If there are no pending changes dismiss
            guard folder.title != folderName || selectedFolder?.id != originalParent?.id else { return }
            // Otherwise update Folder.
            update(folder: folder, originalParent: originalParent, newParent: selectedFolder)
        case .add:
            add(folderWithName: folderName, to: selectedFolder)
        }
    }

}

// MARK: - Private

private extension AddEditBookmarkFolderDialogViewModel {

    func bind() {
        folderCancellable = bookmarkManager.listPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] bookmarkList in
                self?.folders = .init(bookmarkList)
            })
    }

    func update(folder: BookmarkFolder, originalParent: BookmarkFolder?, newParent: BookmarkFolder?) {
        // If the original location of the folder changed move it to the new folder.
        if selectedFolder?.id != originalParent?.id {
            // Update the title anyway.
            folder.title = folderName
            let parentFolderType: ParentFolderType = newParent.flatMap { ParentFolderType.parent(uuid: $0.id) } ?? .root
            bookmarkManager.update(folder: folder, andMoveToParent: parentFolderType)
        } else if folder.title != folderName { // If only title changed just update the folder title without updating its parent.
            folder.title = folderName
            bookmarkManager.update(folder: folder)
        }
    }

    func add(folderWithName name: String, to parent: BookmarkFolder?) {
        bookmarkManager.makeFolder(named: name, parent: parent) { [weak self] bookmarkFolder in
            guard case .success(let bookmarkFolder) = bookmarkFolder else { return }
            self?.addFolderSubject.send(bookmarkFolder)
        }
    }

    func reset() {
        self.folderName = ""
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
