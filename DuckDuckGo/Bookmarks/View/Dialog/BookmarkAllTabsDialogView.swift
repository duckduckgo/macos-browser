//
//  BookmarkAllTabsDialogView.swift
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

struct BookmarkAllTabsDialogView: ModalView {
    @ObservedObject private var viewModel: BookmarkAllTabsDialogCoordinatorViewModel<BookmarkAllTabsDialogViewModel, AddEditBookmarkFolderDialogViewModel>

    init(viewModel: BookmarkAllTabsDialogCoordinatorViewModel<BookmarkAllTabsDialogViewModel, AddEditBookmarkFolderDialogViewModel>) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            switch viewModel.viewState {
            case .bookmarkAllTabs:
                bookmarkAllTabsView
            case .addFolder:
                addFolderView
            }
        }
        .font(.system(size: 13))
    }

    private var bookmarkAllTabsView: some View {
        BookmarkDialogContainerView(
            title: viewModel.bookmarkModel.title,
            middleSection: {
                Text(viewModel.bookmarkModel.educationalMessage)
                    .multilineText()
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                BookmarkDialogStackedContentView(
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.folderName,
                        content: TextField("", text: $viewModel.bookmarkModel.folderName)
                            .focusedOnAppear()
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14))
                    ),
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.location,
                        content: BookmarkDialogFolderManagementView(
                            folders: viewModel.bookmarkModel.folders,
                            selectedFolder: $viewModel.bookmarkModel.selectedFolder,
                            onActionButton: viewModel.addFolderAction
                        )
                    )
                )
            },
            bottomSection: {
                BookmarkDialogButtonsView(
                    viewState: .init(.compressed),
                    otherButtonAction: .init(
                        title: viewModel.bookmarkModel.cancelActionTitle,
                        isDisabled: viewModel.bookmarkModel.isOtherActionDisabled,
                        action: viewModel.bookmarkModel.cancel
                    ),
                    defaultButtonAction: .init(
                        title: viewModel.bookmarkModel.defaultActionTitle,
                        keyboardShortCut: .defaultAction,
                        isDisabled: viewModel.bookmarkModel.isDefaultActionDisabled,
                        action: viewModel.bookmarkModel.addOrSave
                    )
                )
            }

        )
        .frame(width: 448)
    }

    private var addFolderView: some View {
        AddEditBookmarkFolderView(
            title: viewModel.folderModel.title,
            buttonsState: .compressed,
            folders: viewModel.folderModel.folders,
            folderName: $viewModel.folderModel.folderName,
            selectedFolder: $viewModel.folderModel.selectedFolder,
            cancelActionTitle: viewModel.folderModel.cancelActionTitle,
            isCancelActionDisabled: viewModel.folderModel.isOtherActionDisabled,
            cancelAction: { _ in
                viewModel.dismissAction()
            },
            defaultActionTitle: viewModel.folderModel.defaultActionTitle,
            isDefaultActionDisabled: viewModel.folderModel.isDefaultActionDisabled,
            defaultAction: { _ in
                viewModel.folderModel.addOrSave {
                    viewModel.dismissAction()
                }
            }
        )
        .frame(width: 448, height: 210)
    }
}

#if DEBUG
#Preview("Bookmark All Tabs - Light") {
    let parentFolder = BookmarkFolder(id: "7", title: "DuckDuckGo")
    let bookmark = Bookmark(id: "1", url: "www.duckduckgo.com", title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "7")
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [bookmark, parentFolder]))
    bookmarkManager.loadBookmarks()
    let websitesInfo: [WebsiteInfo] = [
        .init(.init(content: .url(URL.duckDuckGo, credential: nil, source: .ui)))!,
        .init(.init(content: .url(URL.duckDuckGoEmail, credential: nil, source: .ui)))!,
    ]

    return BookmarksDialogViewFactory.makeBookmarkAllOpenTabsView(websitesInfo: websitesInfo, bookmarkManager: bookmarkManager)
        .preferredColorScheme(.light)
}

#Preview("Bookmark All Tabs - Dark") {
    let parentFolder = BookmarkFolder(id: "7", title: "DuckDuckGo")
    let bookmark = Bookmark(id: "1", url: "www.duckduckgo.com", title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "7")
    let bookmarkManager = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [bookmark, parentFolder]))
    bookmarkManager.loadBookmarks()
    let websitesInfo: [WebsiteInfo] = [
        .init(.init(content: .url(URL.duckDuckGo, credential: nil, source: .ui)))!,
        .init(.init(content: .url(URL.duckDuckGoEmail, credential: nil, source: .ui)))!,
    ]

    return BookmarksDialogViewFactory.makeBookmarkAllOpenTabsView(websitesInfo: websitesInfo, bookmarkManager: bookmarkManager)
        .preferredColorScheme(.dark)
}
#endif
