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

import AppKit

final class AddBookmarkFolderPopoverViewModel: ObservableObject {

    private let bookmarkManager: BookmarkManager

    let folders: [FolderViewModel]
    @Published var parent: BookmarkFolder?

    @Published var folderName: String = ""

    @Published private(set) var isDisabled = false

    private let completionHandler: (BookmarkFolder?) -> Void

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
        guard !folderName.isEmpty else {
            assertionFailure("folderName is empty, button should be disabled")
            return
        }

        isDisabled = true
        bookmarkManager.makeFolder(for: folderName, parent: parent) { [completionHandler] result in
            completionHandler(result)
        }
    }

    var isAddFolderButtonDisabled: Bool {
        folderName.isEmpty
    }

}

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
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("bookmark.add.cancel.button")

                Button(action: {
                    model.addFolder()
                }) {
                    Text("Add Folder", comment: "Add Folder popover: Create folder button")
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("bookmark.add.add.folder.button")
                .disabled(model.isAddFolderButtonDisabled)
            }
        }
        .font(.system(size: 13))
        .padding()
        .frame(width: 300, height: 229)
        .background(Color(.popoverBackground))
    }
}

//#Preview {
//    AddBookmarkFolderPopoverView(model: AddBookmarkFolderPopoverViewModel {
//        print("Cancel")
//    })
//}
