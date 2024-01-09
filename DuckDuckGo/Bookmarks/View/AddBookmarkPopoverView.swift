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

import Cocoa
import Combine

@MainActor
final class AddBookmarkPopoverViewModel: ObservableObject {

    private let bookmarkManager: BookmarkManager

    @Published private(set) var bookmark: Bookmark

    @Published private(set) var folders: [FolderViewModel] = [] {
        didSet {
            print("didSet", folders.map { $0.title + " - " + $0.id })
        }
    }

    @Published var selectedFolder: BookmarkFolder? {
        didSet {
            if oldValue?.id != selectedFolder?.id {
                bookmarkManager.add(bookmark: bookmark, to: selectedFolder) { [weak self] _ in
                    self?.reloadBookmark()
                }
            }
        }
    }

    @Published var addFolderViewModel: AddBookmarkFolderPopoverViewModel?

    private var bookmarkListCancellable: AnyCancellable?

    init(bookmark: Bookmark,
         bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
        self.bookmark = bookmark
        self.bookmarkTitle = bookmark.title

        bookmarkListCancellable = bookmarkManager.listPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.folders = .init(list)
                self?.reloadBookmark()
            }
    }

    private func reloadBookmark() {
        bookmark = bookmarkManager.getBookmark(for: bookmark.url.url ?? .empty) ?? bookmark
        resetSelectedFolder()
    }

    private func resetSelectedFolder() {
        selectedFolder = folders.first(where: { $0.id == bookmark.parentFolderUUID })?.entity
    }

    func removeButtonAction(dismiss: () -> Void) {
        bookmarkManager.remove(bookmark: bookmark)
        dismiss()
    }

    func doneButtonAction(dismiss: () -> Void) {
        dismiss()
    }

    func favoritesButtonAction() {
        bookmark.isFavorite.toggle()

        bookmarkManager.update(bookmark: bookmark)
    }

    func addFolderButtonAction() {
        addFolderViewModel = .init(bookmark: bookmark, bookmarkManager: bookmarkManager) { [bookmark, bookmarkManager, weak self] newFolder in
            if let newFolder {
                bookmarkManager.move(objectUUIDs: [bookmark.id],
                                     toIndex: 1,
                                     withinParentFolder: .parent(uuid: newFolder.id),
                                     completion: { [weak self] _ in
                    self?.reloadBookmark()
                })
            }
            self?.resetAddFolderState()
        }
    }

    private func resetAddFolderState() {
        addFolderViewModel = nil
    }

    @Published var bookmarkTitle: String {
        didSet {
            bookmark.title = bookmarkTitle

            bookmarkManager.update(bookmark: bookmark)
        }
    }

}

struct FolderViewModel: Identifiable, Equatable {

    let entity: BookmarkFolder
    let level: Int

    var id: BookmarkFolder.ID {
        entity.id
    }

    var title: String {
        BookmarkViewModel(entity: entity).menuTitle
    }

}

extension [FolderViewModel] {

    init(_ list: BookmarkList?) {
        guard let topLevelEntities = list?.topLevelEntities else {
            assertionFailure("Tried to refresh bookmark folder picker, but couldn't get bookmark list")
            self = []
            return
        }
        self.init(entities: topLevelEntities, level: 0)
    }

    private init(entities: [BaseBookmarkEntity], level: Int) {
        self = []
        for entity in entities {
            guard let folder = entity as? BookmarkFolder else { continue }
            let item = FolderViewModel(entity: folder, level: level)
            self.append(item)

            let childModels = Self(entities: folder.children, level: level + 1)
            self.append(contentsOf: childModels)
        }
    }

}

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
                HStack { // TODO: align
                    if model.bookmark.isFavorite {
                        Image(.favorite)
                        Text(UserText.removeFromFavorites)
                    } else {
                        Image(.favoriteFilled)
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
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("bookmark.add.remove.button")

                Button {
                    model.doneButtonAction(dismiss: dismiss.callAsFunction)
                } label: {
                    Text(UserText.done)
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("bookmark.add.done.button")
            }

        }
        .font(.system(size: 13))
        .padding(EdgeInsets(top: 19, leading: 19, bottom: 19, trailing: 19))
        .frame(width: 300, height: 229)
        .background(Color(.popoverBackground))
    }

}

struct BookmarkFolderPicker: View {

    let folders: [FolderViewModel]
    @Binding var selectedFolder: BookmarkFolder?

    var body: some View {

        NSPopUpButtonView(selection: $selectedFolder, viewCreator: NSPopUpButton.init) {

            PopupButtonItem(icon: .folder, title: UserText.bookmarks)

            PopupButtonItem.separator()

            for folder in folders {
                PopupButtonItem(icon: .folder, title: folder.title, indentation: folder.level, selectionValue: folder.entity)
            }
        }

    }

}

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
