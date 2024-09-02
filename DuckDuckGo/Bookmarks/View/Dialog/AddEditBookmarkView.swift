//
//  AddEditBookmarkView.swift
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

struct AddEditBookmarkView: View {
    let title: String
    let buttonsState: BookmarksDialogButtonsState

    @Binding var bookmarkName: String
    var bookmarkURLPath: Binding<String>?
    @Binding var isBookmarkFavorite: Bool

    let folders: [FolderViewModel]
    @Binding var selectedFolder: BookmarkFolder?

    let isURLFieldHidden: Bool

    let addFolderAction: () -> Void

    let otherActionTitle: String
    let isOtherActionDisabled: Bool
    let otherAction: @MainActor (_ dismiss: () -> Void) -> Void
    let isOtherActionTriggeredByEscKey: Bool

    let defaultActionTitle: String
    let isDefaultActionDisabled: Bool
    let defaultAction: @MainActor (_ dismiss: () -> Void) -> Void

    var body: some View {
        BookmarkDialogContainerView(
            title: title,
            middleSection: {
                BookmarkDialogStackedContentView(
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.name,
                        content: TextField("", text: $bookmarkName)
                            .focusedOnAppear()
                            .accessibilityIdentifier("bookmark.add.name.textfield")
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14))
                    ),
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.url,
                        content: TextField("", text: bookmarkURLPath ?? .constant(""))
                            .accessibilityIdentifier("bookmark.add.url.textfield")
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14)),
                        isContentViewHidden: isURLFieldHidden
                    ),
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.location,
                        content: BookmarkDialogFolderManagementView(
                            folders: folders,
                            selectedFolder: $selectedFolder,
                            onActionButton: addFolderAction
                        )
                    )
                )
                BookmarkFavoriteView(isFavorite: $isBookmarkFavorite)
            },
            bottomSection: {
                BookmarkDialogButtonsView(
                    viewState: .init(buttonsState),
                    otherButtonAction: .init(
                        title: otherActionTitle,
                        keyboardShortCut: isOtherActionTriggeredByEscKey ? .cancelAction : nil,
                        isDisabled: isOtherActionDisabled,
                        action: otherAction
                    ),
                    defaultButtonAction: .init(
                        title: defaultActionTitle,
                        keyboardShortCut: .defaultAction,
                        isDisabled: isDefaultActionDisabled,
                        action: defaultAction
                    )
                )
            }
        )
    }

}

// MARK: - BookmarksDialogButtonsState

enum BookmarksDialogButtonsState {
    case compressed
    case expanded
}

extension BookmarkDialogButtonsView.ViewState {
    init(_ state: BookmarksDialogButtonsState) {
        switch state {
        case .compressed:
            self = .compressed
        case .expanded:
            self = .expanded
        }
    }
}
