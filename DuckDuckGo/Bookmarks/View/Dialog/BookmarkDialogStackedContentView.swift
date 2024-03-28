//
//  BookmarkDialogStackedContentView.swift
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

struct BookmarkDialogStackedContentView: View {
    private let items: [Item]

    init(_ items: Item...) {
        self.items = items
    }

    init(_ items: [Item]) {
        self.items = items
    }

    var body: some View {
        TwoColumnsListView(
            horizontalSpacing: 16.0,
            verticalSpacing: 20.0,
            rowHeight: 22.0,
            leftColumn: {
                ForEach(items, id: \.title) { item in
                    if !item.isContentViewHidden {
                        Text(item.title)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                }
            },
            rightColumn: {
                ForEach(items, id: \.title) { item in
                    if !item.isContentViewHidden {
                        item.content
                    }
                }
            }
        )
    }
}

// MARK: - BookmarkModalStackedContentView + Item

extension BookmarkDialogStackedContentView {
    struct Item {
        fileprivate let title: String
        fileprivate let content: AnyView
        fileprivate let isContentViewHidden: Bool

        init(title: String, content: any View, isContentViewHidden: Bool = false) {
            self.title = title
            self.content = AnyView(content)
            self.isContentViewHidden = isContentViewHidden
        }
    }
}

// MARK: - Preview

#Preview {
    @State var name: String = "DuckDuckGo"
    @State var url: String = "https://www.duckduckgo.com"
    @State var selectedFolder: BookmarkFolder?

    return BookmarkDialogStackedContentView(
        .init(
            title: "Name",
            content:
                TextField("", text: $name)
                .textFieldStyle(.roundedBorder)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 14))

        ),
        .init(
            title: "URL",
            content:
                TextField("", text: $url)
                .textFieldStyle(.roundedBorder)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 14))
        ),
        .init(
            title: "Location",
            content:
                BookmarkDialogFolderManagementView(
                    folders: [],
                    selectedFolder: $selectedFolder,
                    onActionButton: { }
                )
        )
    )
    .padding([.horizontal, .vertical])
    .frame(width: 400)
}
