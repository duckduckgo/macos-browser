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
        VStack(alignment: .leading, spacing: 19) {
            Text("Bookmark Added", comment: "Bookmark Added popover title")
                .fontWeight(.bold)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 10) {
                TextField("", text: $model.bookmarkTitle)
                    .focusedOnAppear()
                    .accessibilityIdentifier("bookmark.add.name.textfield")
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 14))

                HStack {
                    BookmarkFolderPicker(folders: model.folders,
                                         selectedFolder: $model.selectedFolder)
                    .accessibilityIdentifier("bookmark.add.folder.dropdown")

                    Button {
                        model.addFolderButtonAction()
                    } label: {
                        Image(.addFolder)
                    }
                    .accessibilityIdentifier("bookmark.add.new.folder.button")
                    .buttonStyle(StandardButtonStyle())
                }
            }

            Divider()

            Button {
                model.favoritesButtonAction()
            } label: {
                HStack(spacing: 8) {
                    if model.bookmark.isFavorite {
                        Image(.favoriteFilled)
                        Text(UserText.removeFromFavorites)
                    } else {
                        Image(.favorite)
                        Text(UserText.addToFavorites)
                    }
                }
            }
            .accessibilityIdentifier("bookmark.add.add.to.favorites.button")
            .buttonStyle(.borderless)
            .foregroundColor(Color.button)

            HStack {
                Spacer()

                Button {
                    model.removeButtonAction(dismiss: dismiss.callAsFunction)
                } label: {
                    Text("Remove", comment: "Remove bookmark button title")
                }
                .accessibilityIdentifier("bookmark.add.remove.button")

                Button {
                    model.doneButtonAction(dismiss: dismiss.callAsFunction)
                } label: {
                    Text(UserText.done)
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("bookmark.add.done.button")
            }

        }
        .font(.system(size: 13))
        .padding(EdgeInsets(top: 19, leading: 19, bottom: 19, trailing: 19))
        .frame(width: 300, height: 229)
        .background(Color(.popoverBackground))
    }

}

#if DEBUG
#Preview { {
    let bkm = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: false, parentFolderUUID: "1")
    let bkman = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [
        BookmarkFolder(id: "1", title: "Folder 1", children: [
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
}() }
#endif
