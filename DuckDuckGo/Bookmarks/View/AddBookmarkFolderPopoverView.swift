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
        BookmarkDialogContainerView(
            title: UserText.Bookmarks.Dialog.Title.addFolder,
            middleSection: {
                BookmarkDialogStackedContentView(
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.name,
                        content: TextField("", text: $model.folderName)
                            .focusedOnAppear()
                            .accessibilityIdentifier("bookmark.folder.name.textfield")
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14))
                            .disabled(model.isDisabled)
                    ),
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.location,
                        content: BookmarkFolderPicker(folders: model.folders, selectedFolder: $model.parent)
                            .accessibilityIdentifier("bookmark.folder.folder.dropdown")
                            .disabled(model.isDisabled)
                    )
                )
            },
            bottomSection: {
                BookmarkDialogButtonsView(
                    viewState: .expanded,
                    otherButtonAction: .init(
                        title: UserText.cancel,
                        accessibilityIdentifier: "bookmark.add.cancel.button",
                        isDisabled: model.isDisabled,
                        action: { _ in model.cancel() }
                    ),
                    defaultButtonAction: .init(
                        title: UserText.Bookmarks.Dialog.Action.addFolder,
                        accessibilityIdentifier: "bookmark.add.add.folder.button",
                        keyboardShortCut: .defaultAction,
                        isDisabled: model.isAddFolderButtonDisabled || model.isDisabled,
                        action: { _ in model.addFolder() }
                    )
                )
            }
        )
        .padding(.vertical, 16.0)
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

    return AddBookmarkFolderPopoverView(model: AddBookmarkFolderPopoverViewModel(bookmarkManager: bkman) {
        print("CompletionHandler:", $0?.title ?? "<nil>")
    })
    .preferredColorScheme(.dark)
}
#endif
