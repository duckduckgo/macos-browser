//
//  BookmarkAllTabsDialogViewModel.swift
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
    var educationalMessage: String { get }
    var folderNameFieldTitle: String { get }
    var locationFieldTitle: String { get }
}

final class BookmarkAllTabsDialogViewModel: BookmarkAllTabsDialogEditing {
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return formatter
    }()

    private let websites: [WebsiteInfo]
    private let foldersStore: BookmarkFoldersStore
    private let bookmarkManager: BookmarkManager

    private var folderCancellable: AnyCancellable?

    @Published private(set) var folders: [FolderViewModel]
    @Published var selectedFolder: BookmarkFolder?
    @Published var folderName: String

    var title: String {
        String(format: UserText.Bookmarks.Dialog.Title.bookmarkOpenTabs, websites.count)
    }
    let cancelActionTitle = UserText.cancel
    let defaultActionTitle = UserText.Bookmarks.Dialog.Action.addAllBookmarks
    let educationalMessage = UserText.Bookmarks.Dialog.Message.bookmarkOpenTabsEducational
    let folderNameFieldTitle = UserText.Bookmarks.Dialog.Field.folderName
    let locationFieldTitle = UserText.Bookmarks.Dialog.Field.location
    let isOtherActionDisabled = false

    var isDefaultActionDisabled: Bool {
        folderName.trimmingWhitespace().isEmpty
    }

    init(
        websites: [WebsiteInfo],
        foldersStore: BookmarkFoldersStore,
        bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
        dateFormatterConfigurationProvider: () -> DateFormatterConfiguration = DateFormatterConfiguration.defaultConfiguration
    ) {
        self.websites = websites
        self.foldersStore = foldersStore
        self.bookmarkManager = bookmarkManager

        folders = .init(bookmarkManager.list)
        selectedFolder = foldersStore.lastBookmarkAllTabsFolderIdUsed.flatMap(bookmarkManager.getBookmarkFolder(withId:))
        folderName = Self.folderName(configuration: dateFormatterConfigurationProvider(), websitesNumber: websites.count)
        bind()
    }

    func cancel(dismiss: () -> Void) {
        dismiss()
    }

    func addOrSave(dismiss: () -> Void) {
        // Save last used folder
        foldersStore.lastBookmarkAllTabsFolderIdUsed = selectedFolder?.id

        // Save all bookmarks
        let parentFolder: ParentFolderType = selectedFolder.flatMap { .parent(uuid: $0.id) } ?? .root
        bookmarkManager.makeBookmarks(for: websites, inNewFolderNamed: folderName, withinParentFolder: parentFolder)

        // Dismiss the view
        dismiss()
    }
}

// MARK: - Private

private extension BookmarkAllTabsDialogViewModel {

    static func folderName(configuration: DateFormatterConfiguration, websitesNumber: Int) -> String {
        Self.dateFormatter.timeZone = configuration.timeZone
        let dateString = Self.dateFormatter.string(from: configuration.date)
        return String(format: UserText.Bookmarks.Dialog.Value.folderName, dateString, websitesNumber)
    }

    func bind() {
        folderCancellable = bookmarkManager.listPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] bookmarkList in
                self?.folders = .init(bookmarkList)
            })
    }

}

// MARK: - DateConfiguration

extension BookmarkAllTabsDialogViewModel {

    struct DateFormatterConfiguration {
        let date: Date
        let timeZone: TimeZone

        static func defaultConfiguration() -> DateFormatterConfiguration {
            .init(date: Date(), timeZone: .current)
        }
    }

}
