//
//  AddBookmarkFolderPopoverViewModel.swift
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

import Combine
import Foundation

final class AddBookmarkFolderPopoverViewModel: ObservableObject {

    private let bookmarkManager: BookmarkManager
    let folders: [FolderViewModel]
    private let completionHandler: (BookmarkFolder?) -> Void

    @Published var parent: BookmarkFolder?
    @Published var folderName: String = ""
    @Published private(set) var isDisabled = false

    var title: String {
        UserText.Bookmarks.Dialog.Title.addFolder
    }

    var cancelActionTitle: String {
        UserText.cancel
    }

    var defaultActionTitle: String {
        UserText.Bookmarks.Dialog.Action.addFolder
    }

    let isCancelActionDisabled = false

    var isDefaultActionButtonDisabled: Bool {
        folderName.trimmingWhitespace().isEmpty || isDisabled
    }

    init(bookmark: Bookmark? = nil,
         folderName: String = "",
         bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
         completionHandler: @escaping (BookmarkFolder?) -> Void = {_ in }) {

        self.folders = .init(bookmarkManager.list)
        self.bookmarkManager = bookmarkManager
        self.folderName = folderName
        self.completionHandler = completionHandler
        self.parent = bookmark.flatMap { bookmark in
            folders.first(where: { $0.id == bookmark.parentFolderUUID })?.entity
        }
    }

    func cancel() {
        completionHandler(nil)
    }

    func addFolder() {
        guard !folderName.trimmingWhitespace().isEmpty else {
            assertionFailure("folderName is empty, button should be disabled")
            return
        }

        isDisabled = true
        bookmarkManager.makeFolder(named: folderName.trimmingWhitespace(), parent: parent) { [completionHandler] result in
            completionHandler(try? result.get())
        }
    }

    var isAddFolderButtonDisabled: Bool {
        folderName.trimmingWhitespace().isEmpty
    }

}
