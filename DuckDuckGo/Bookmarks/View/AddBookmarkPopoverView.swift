//
//  AddBookmarkPopoverView.swift
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
import SwiftUIExtensions

struct AddBookmarkPopoverView: View {

    @ObservedObject private var model: AddBookmarkPopoverViewModel
    @Environment(\.dismiss) private var dismiss

    init(model: AddBookmarkPopoverViewModel) {
        self.model = model
    }

    var body: some View {
        if let addFolderViewModel = model.addFolderViewModel {
            AddBookmarkFolderPopoverView(model: addFolderViewModel)
        } else {
            addBookmarkView
        }
    }

    @MainActor
    private var addBookmarkView: some View {
        AddEditBookmarkView(
            title: UserText.Bookmarks.Dialog.Title.addedBookmark,
            buttonsState: .expanded,
            bookmarkName: $model.bookmarkTitle,
            bookmarkURLPath: nil,
            isBookmarkFavorite: $model.isBookmarkFavorite,
            folders: model.folders,
            selectedFolder: $model.selectedFolder,
            isURLFieldHidden: true,
            addFolderAction: model.addFolderButtonAction,
            otherActionTitle: UserText.delete,
            isOtherActionDisabled: false,
            otherAction: model.removeButtonAction,
            isOtherActionTriggeredByEscKey: false,
            defaultActionTitle: UserText.done,
            isDefaultActionDisabled: model.isDefaultActionButtonDisabled,
            defaultAction: model.doneButtonAction
        )
        .font(.system(size: 13))
        .frame(width: 320)
    }

}

#if DEBUG
#Preview("Bookmark Added - Light") {
    let bkm = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: false, parentFolderUUID: "1")
    let bkman = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [
        BookmarkFolder(id: "1", title: "Folder with a name that shouldn‘t fit into the picker", children: [
            bkm,
            BookmarkFolder(id: "2", title: "Nested Folder", children: [
                ])
        ]),
        Bookmark(id: "b2", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "1"),
        BookmarkFolder(id: "3", title: "Another Folder", children: [
            BookmarkFolder(id: "4", title: "Nested Folder", children: [
                BookmarkFolder(id: "5", title: "Another Nested Folder", children: [
                ])
            ])
        ])
    ]))
    bkman.loadBookmarks()
    customAssertionFailure = { _, _, _ in }

    return AddBookmarkPopoverView(model: AddBookmarkPopoverViewModel(bookmark: bkm, bookmarkManager: bkman))
        .preferredColorScheme(.light)
}

#Preview("Bookmark Added - Dark") {
    let bkm = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: false, parentFolderUUID: "1")
    let bkman = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [
        BookmarkFolder(id: "1", title: "Folder with a name that shouldn‘t fit into the picker", children: [])]))
    bkman.loadBookmarks()

    return AddBookmarkPopoverView(model: AddBookmarkPopoverViewModel(bookmark: bkm, bookmarkManager: bkman))
        .preferredColorScheme(.dark)
}
#endif
