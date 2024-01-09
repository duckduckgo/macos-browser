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
        VStack(alignment: .leading, spacing: 16) {
            Text(UserText.newFolder)
                .bold()

            VStack(alignment: .leading, spacing: 7) {
                Text("Location:", comment: "Add Folder popover: parent folder picker title")

                BookmarkFolderPicker(folders: model.folders, selectedFolder: $model.parent)
                .accessibilityIdentifier("bookmark.folder.folder.dropdown")
                .disabled(model.isDisabled)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Name:", comment: "Add Folder popover: folder name text field title")

                TextField("", text: $model.folderName)
                    .focusedOnAppear()
                    .accessibilityIdentifier("bookmark.folder.name.textfield")
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(model.isDisabled)
            }
            .padding(.bottom, 16)

            HStack {
                Spacer()

                Button(action: {
                    model.cancel()
                }) {
                    Text(UserText.cancel)
                }
                .accessibilityIdentifier("bookmark.add.cancel.button")
                .disabled(model.isDisabled)

                Button(action: {
                    model.addFolder()
                }) {
                    Text("Add Folder", comment: "Add Folder popover: Create folder button")
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("bookmark.add.add.folder.button")
                .disabled(model.isAddFolderButtonDisabled || model.isDisabled)
            }
        }
        .font(.system(size: 13))
        .padding()
        .frame(width: 300, height: 229)
        .background(Color(.popoverBackground))
    }
}

#Preview {
    let bkman = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [
        BookmarkFolder(id: "1", title: "Folder 1", children: [
            BookmarkFolder(id: "2", title: "Nested Folder", children: [
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
}
