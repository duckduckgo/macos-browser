//
//  BookmarkFolderPicker.swift
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

import AppKit
import SwiftUI

struct BookmarkFolderPicker: View {

    let folders: [FolderViewModel]
    @Binding var selectedFolder: BookmarkFolder?

    var body: some View {

        NSPopUpButtonView(selection: $selectedFolder) {
            let popUpButton = NSPopUpButton()
            popUpButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            return popUpButton
        } content: {

            PopupButtonItem(icon: .bookmarksFolder, title: UserText.bookmarks)

            PopupButtonItem.separator()

            for folder in folders {
                PopupButtonItem(icon: .folder, title: folder.title, indentation: folder.level, selectionValue: folder.entity)
            }
        }

    }

}

#Preview { {
    let folder1 = BookmarkFolder(id: "3", title: "A Folder with a name that normally won‘t fit into the folder picker", children: [])
    let folder2 = BookmarkFolder(id: "4", title: "Nested Folder", children: [])
    let folder3 = BookmarkFolder(id: "5", title: "Another Nested Folder", children: [])
    @State var selectedFolder: BookmarkFolder? = folder2

    return VStack {
        BookmarkFolderPicker(folders: [
            FolderViewModel(entity: folder1, level: 0),
            FolderViewModel(entity: folder2, level: 1),
            FolderViewModel(entity: folder3, level: 2),
        ], selectedFolder: _selectedFolder.projectedValue)
    }.frame(width: 300)

}() }
