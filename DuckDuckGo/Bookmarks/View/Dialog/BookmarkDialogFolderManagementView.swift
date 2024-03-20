//
//  BookmarkDialogFolderManagementView.swift
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

struct BookmarkDialogFolderManagementView: View {
    private let folders: [FolderViewModel]
    private var selectedFolder: Binding<BookmarkFolder?>
    private let onActionButton: @MainActor () -> Void

    init(
        folders: [FolderViewModel],
        selectedFolder: Binding<BookmarkFolder?>,
        onActionButton: @escaping @MainActor () -> Void
    ) {
        self.folders = folders
        self.selectedFolder = selectedFolder
        self.onActionButton = onActionButton
    }

    var body: some View {
        HStack {
            BookmarkFolderPicker(
                folders: folders,
                selectedFolder: selectedFolder
            )
            .accessibilityIdentifier("bookmark.add.folder.dropdown")

            Button {
                onActionButton()
            } label: {
                Image(.addFolder)
            }
            .accessibilityIdentifier("bookmark.add.new.folder.button")
            .buttonStyle(StandardButtonStyle())
        }
    }
}

#Preview {
    @State var selectedFolder: BookmarkFolder? = BookmarkFolder(id: "1", title: "Nested Folder", children: [])
    let folderViewModels: [FolderViewModel] = [
        .init(
            entity: .init(
                id: "1",
                title: "Nested Folder",
                parentFolderUUID: nil,
                children: []
            ),
            level: 1
        )
    ]

    return BookmarkDialogFolderManagementView(
        folders: folderViewModels,
        selectedFolder: $selectedFolder,
        onActionButton: {}
    )
    .frame(width: 400)
}
