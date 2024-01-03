//
//  AddBookmarkFolderModalViewModel.swift
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

struct AddBookmarkFolderModalViewModel {

    let bookmarkManager: BookmarkManager

    let title: String
    let addButtonTitle: String
    let originalFolder: BookmarkFolder?
    let parent: BookmarkFolder?

    var folderName: String = ""

    var isAddButtonDisabled: Bool {
        folderName.isEmpty
    }

    init(folder: BookmarkFolder,
         bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
         completionHandler: @escaping (BookmarkFolder?) -> Void = { _ in }) {
        self.bookmarkManager = bookmarkManager
        self.originalFolder = folder
        self.parent = nil
        self.title = UserText.renameFolder
        self.addButtonTitle = UserText.save
    }

    init(parent: BookmarkFolder? = nil,
         bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
         completionHandler: @escaping (BookmarkFolder?) -> Void = { _ in }) {
        self.bookmarkManager = bookmarkManager
        self.originalFolder = nil
        self.parent = parent
        self.title = UserText.newFolder
        self.addButtonTitle = UserText.newFolderDialogAdd
    }

    func cancel(dismiss: () -> Void) {
        dismiss()
    }

    func addFolder(dismiss: () -> Void) {
        guard !folderName.isEmpty else {
            assertionFailure("folderName is empty, button should be disabled")
            return
        }

        if let folder = originalFolder {
            folder.title = folderName
            bookmarkManager.update(folder: folder)

        } else {
            bookmarkManager.makeFolder(for: folderName, parent: parent, completion: { _ in })
        }

        dismiss()
    }

}
