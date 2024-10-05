//
//  AddBookmarkPopoverViewModel.swift
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

@MainActor
final class AddBookmarkPopoverViewModel: ObservableObject {

    private let bookmarkManager: BookmarkManager

    @Published private(set) var bookmark: Bookmark

    @Published private(set) var folders: [FolderViewModel] = []

    @Published var selectedFolder: BookmarkFolder? {
        didSet {
            if oldValue?.id != selectedFolder?.id {
                bookmarkManager.add(bookmark: bookmark, to: selectedFolder) { _ in
                    // this is an invalid callback fired before bookmarks finish reloading
                }
            }
        }
    }

    @Published var isBookmarkFavorite: Bool {
        didSet {
            bookmark.isFavorite = isBookmarkFavorite
            bookmarkManager.update(bookmark: bookmark)
        }
    }

    @Published var bookmarkTitle: String {
        didSet {
            bookmark.title = bookmarkTitle.trimmingWhitespace()
            bookmarkManager.update(bookmark: bookmark)
        }
    }

    @Published var addFolderViewModel: AddBookmarkFolderPopoverViewModel?

    let isDefaultActionButtonDisabled: Bool = false

    private var bookmarkListCancellable: AnyCancellable?

    init(bookmark: Bookmark,
         bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
        self.bookmark = bookmark
        self.bookmarkTitle = bookmark.title
        self.isBookmarkFavorite = bookmark.isFavorite

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
        bookmarkManager.remove(bookmark: bookmark, undoManager: nil)
        dismiss()
    }

    func doneButtonAction(dismiss: () -> Void) {
        dismiss()
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
