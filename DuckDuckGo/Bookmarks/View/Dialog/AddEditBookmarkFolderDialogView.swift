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
        AddEditBookmarkFolderView(
            title: viewModel.title,
            buttonsState: .compressed,
            folders: viewModel.folders,
            folderName: $viewModel.folderName,
            selectedFolder: $viewModel.selectedFolder,
            cancelActionTitle: viewModel.cancelActionTitle,
            isCancelActionDisabled: viewModel.isOtherActionDisabled,
            cancelAction: viewModel.cancel,
            defaultActionTitle: viewModel.defaultActionTitle,
            isDefaultActionDisabled: viewModel.isDefaultActionDisabled,
            defaultAction: viewModel.addOrSave
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

    return BookmarksDialogViewFactory.makeAddBookmarkFolderView(parentFolder: nil, bookmarkManager: bookmarkManager)
        .preferredColorScheme(.light)
}

#Preview("Add Folder To Bookmarks Subfolder - Light") {
    let bookmarkFolder = BookmarkFolder(id: "1", title: "DuckDuckGo", children: [])
    let store = BookmarkStoreMock(bookmarks: [bookmarkFolder])
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: store)
    bookmarkManager.loadBookmarks()

    return BookmarksDialogViewFactory.makeAddBookmarkFolderView(parentFolder: bookmarkFolder, bookmarkManager: bookmarkManager)
        .preferredColorScheme(.light)
}

#Preview("Edit Folder - Light") {
    let bookmarkFolder = BookmarkFolder(id: "1", title: "DuckDuckGo", children: [])
    let store = BookmarkStoreMock(bookmarks: [bookmarkFolder])
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: store)
    bookmarkManager.loadBookmarks()

    return BookmarksDialogViewFactory.makeEditBookmarkFolderView(folder: bookmarkFolder, parentFolder: nil, bookmarkManager: bookmarkManager)
        .preferredColorScheme(.light)
}

#Preview("Add Folder To Bookmarks - Dark") {
    let store = BookmarkStoreMock(bookmarks: [])
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: store)
    bookmarkManager.loadBookmarks()

    return BookmarksDialogViewFactory.makeAddBookmarkFolderView(parentFolder: nil, bookmarkManager: bookmarkManager)
        .preferredColorScheme(.dark)
}

#Preview("Add Folder To Bookmarks Subfolder - Dark") {
    let bookmarkFolder = BookmarkFolder(id: "1", title: "DuckDuckGo", children: [])
    let store = BookmarkStoreMock(bookmarks: [bookmarkFolder])
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: store)
    bookmarkManager.loadBookmarks()

    return BookmarksDialogViewFactory.makeAddBookmarkFolderView(parentFolder: bookmarkFolder, bookmarkManager: bookmarkManager)
        .preferredColorScheme(.dark)
}

#Preview("Edit Folder in Subfolder - Dark") {
    let bookmarkFolder = BookmarkFolder(id: "1", title: "DuckDuckGo", children: [])
    let store = BookmarkStoreMock(bookmarks: [bookmarkFolder])
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: store)
    bookmarkManager.loadBookmarks()

    return BookmarksDialogViewFactory.makeEditBookmarkFolderView(folder: bookmarkFolder, parentFolder: bookmarkFolder, bookmarkManager: bookmarkManager)
        .preferredColorScheme(.dark)
}
#endif
