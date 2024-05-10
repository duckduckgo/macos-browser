//
//  AddEditBookmarkFolderView.swift
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

struct AddEditBookmarkFolderView: View {
    enum ButtonsState {
        case compressed
        case expanded
    }

    let title: String
    let buttonsState: ButtonsState
    let folders: [FolderViewModel]
    @Binding var folderName: String
    @Binding var selectedFolder: BookmarkFolder?

    let cancelActionTitle: String
    let isCancelActionDisabled: Bool
    let cancelAction: @MainActor (_ dismiss: () -> Void) -> Void

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
                        content: TextField("", text: $folderName)
                            .focusedOnAppear()
                            .accessibilityIdentifier("bookmark.add.name.textfield")
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14))
                    ),
                    .init(
                        title: UserText.Bookmarks.Dialog.Field.location,
                        content: BookmarkFolderPicker(
                            folders: folders,
                            selectedFolder: $selectedFolder
                        )
                        .accessibilityIdentifier("bookmark.folder.folder.dropdown")
                    )
                )
            },
            bottomSection: {
                BookmarkDialogButtonsView(
                    viewState: .init(buttonsState),
                    otherButtonAction: .init(
                        title: cancelActionTitle,
                        keyboardShortCut: .cancelAction,
                        isDisabled: isCancelActionDisabled,
                        action: cancelAction
                    ), defaultButtonAction: .init(
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

private extension BookmarkDialogButtonsView.ViewState {

    init(_ state: AddEditBookmarkFolderView.ButtonsState) {
        switch state {
        case .compressed:
            self = .compressed
        case .expanded:
            self = .expanded
        }
    }
}

#Preview("Compressed") {
    @State var folderName = ""
    @State var selectedFolder: BookmarkFolder?

    return AddEditBookmarkFolderView(
        title: "Test Title",
        buttonsState: .compressed,
        folders: [],
        folderName: $folderName,
        selectedFolder: $selectedFolder,
        cancelActionTitle: UserText.cancel,
        isCancelActionDisabled: false,
        cancelAction: { _ in },
        defaultActionTitle: UserText.save,
        isDefaultActionDisabled: false,
        defaultAction: { _ in }
    )
}

#Preview("Expanded") {
    @State var folderName = ""
    @State var selectedFolder: BookmarkFolder?

    return AddEditBookmarkFolderView(
        title: "Test Title",
        buttonsState: .expanded,
        folders: [],
        folderName: $folderName,
        selectedFolder: $selectedFolder,
        cancelActionTitle: UserText.cancel,
        isCancelActionDisabled: false,
        cancelAction: { _ in },
        defaultActionTitle: UserText.save,
        isDefaultActionDisabled: false,
        defaultAction: { _ in }
    )
}
