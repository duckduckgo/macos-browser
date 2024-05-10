//
//  AddBookmarkFolderPopoverView.swift
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

struct AddBookmarkFolderPopoverView: ModalView {

    @ObservedObject var model: AddBookmarkFolderPopoverViewModel

    var body: some View {
        AddEditBookmarkFolderView(
            title: model.title,
            buttonsState: .expanded,
            folders: model.folders,
            folderName: $model.folderName,
            selectedFolder: $model.parent,
            cancelActionTitle: model.cancelActionTitle,
            isCancelActionDisabled: model.isCancelActionDisabled,
            cancelAction: { _ in model.cancel() },
            defaultActionTitle: model.defaultActionTitle,
            isDefaultActionDisabled: model.isDefaultActionButtonDisabled,
            defaultAction: { _ in model.addFolder() }
        )
        .font(.system(size: 13))
        .frame(width: 320)
    }
}

#if DEBUG
#Preview("Add Folder - Light") {
    let bkman = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [
        BookmarkFolder(id: "1", title: "Folder 1", children: [
            BookmarkFolder(id: "2", title: "Nested Folder with a name that in theory won‘t fit into the picker", children: [
            ])
        ]),
        BookmarkFolder(id: "3", title: "Another Folder", children: [
            BookmarkFolder(id: "4", title: "Nested Folder", children: [
                BookmarkFolder(id: "5", title: "Another Nested Folder", children: [
                ])
            ])
        ])
    ]))
    bkman.loadBookmarks()
    customAssertionFailure = { _, _, _ in }

    return AddBookmarkFolderPopoverView(model: AddBookmarkFolderPopoverViewModel(bookmarkManager: bkman) {
        print("CompletionHandler:", $0?.title ?? "<nil>")
    })
    .preferredColorScheme(.light)
}

#Preview("Add Folder - Dark") {
    let bkman = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: []))
    bkman.loadBookmarks()
    customAssertionFailure = { _, _, _ in }

    return AddBookmarkFolderPopoverView(model: AddBookmarkFolderPopoverViewModel(bookmarkManager: bkman) {
        print("CompletionHandler:", $0?.title ?? "<nil>")
    })
    .preferredColorScheme(.dark)
}
#endif
