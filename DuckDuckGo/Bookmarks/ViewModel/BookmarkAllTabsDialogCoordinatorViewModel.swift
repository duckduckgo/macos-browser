//
//  BookmarkAllTabsDialogCoordinatorViewModel.swift
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
import Combine

final class BookmarkAllTabsDialogCoordinatorViewModel<BookmarkViewModel: BookmarkAllTabsDialogEditing, AddFolderViewModel: BookmarkFolderDialogEditing>: ObservableObject {
    @ObservedObject var bookmarkModel: BookmarkViewModel
    @ObservedObject var folderModel: AddFolderViewModel
    @Published var viewState: ViewState

    private var cancellables: Set<AnyCancellable> = []

    init(bookmarkModel: BookmarkViewModel, folderModel: AddFolderViewModel) {
        self.bookmarkModel = bookmarkModel
        self.folderModel = folderModel
        viewState = .bookmarkAllTabs
        bind()
    }

    func dismissAction() {
        viewState = .bookmarkAllTabs
    }

    func addFolderAction() {
        folderModel.selectedFolder = bookmarkModel.selectedFolder
        viewState = .addFolder
    }

    private func bind() {
        bookmarkModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        folderModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        folderModel.addFolderPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bookmarkFolder in
                self?.bookmarkModel.selectedFolder = bookmarkFolder
            }
            .store(in: &cancellables)
    }
}

extension BookmarkAllTabsDialogCoordinatorViewModel {
    enum ViewState {
        case bookmarkAllTabs
        case addFolder
    }
}
