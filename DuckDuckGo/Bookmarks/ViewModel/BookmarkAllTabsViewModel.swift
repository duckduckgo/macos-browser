//
//  BookmarkAllTabsViewModel.swift
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

import Foundation
import Combine

@MainActor
protocol BookmarkAllTabsDialogEditing: BookmarksDialogViewModel {
    var folderName: String { get set }
}

final class BookmarkAllTabsViewModel: BookmarkAllTabsDialogEditing {
    private let websites: [WebsiteInfo]
    private let bookmarkManager: BookmarkManager

    private var cancellables: Set<AnyCancellable> = []

    @Published private(set) var folders: [FolderViewModel] = []
    @Published var selectedFolder: BookmarkFolder?
    @Published var folderName: String

    let title = ""
    let cancelActionTitle = ""
    let defaultActionTitle = ""
    let isOtherActionDisabled = false

    var isDefaultActionDisabled: Bool {
        !folderName.trimmingWhitespace().isEmpty
    }

    init(
        websites: [WebsiteInfo],
        bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
        dateProvider: () -> Date = Date.init
    ) {
        self.websites = websites
        self.bookmarkManager = bookmarkManager

        let date = ISO8601DateFormatter().string(from: dateProvider())
        folderName = date + " - \(websites.count) Tabs"
    }

    func addFolderAction() {
        
    }

    func cancel(dismiss: () -> Void) {
        dismiss()
    }

    func addOrSave(dismiss: () -> Void) {
        dismiss()
    }
}
